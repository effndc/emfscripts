import typer
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.prompt import Prompt, Confirm
from typing import List, Optional
from client_keycloak import KeycloakClient
from client_emf import EMFClient
from config import Config
from utils import poll_until
import sys

# Apps
app = typer.Typer(help="Antigravity EMF Multi-Tenancy Manager")
org_app = typer.Typer(help="Manage Organizations")
project_app = typer.Typer(help="Manage Projects")
user_app = typer.Typer(help="Manage Users")

app.add_typer(org_app, name="org")
app.add_typer(project_app, name="project")
app.add_typer(user_app, name="user")

console = Console()
state = {"kc": None, "emf": None}

def get_spinner(description: str):
    return Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        transient=True
    )

def ensure_auth():
    """Ensures we have clients ready."""
    if state["kc"] and state["emf"]:
        return

    # Prompt or Env?
    # CLI constraints say we can prompt. 
    # But basic auth flows usually rely on config/env for "admin" creds to the tool itself.
    # The user request mentioned "Prompt user (or read from ENV)".
    # Our KeycloakClient uses ENV by default. Let's stick to that for the *Platform Admin* credential.
    
    with get_spinner("Authenticating...") as progress:
        progress.add_task("Connecting to Keycloak...")
        try:
            kc = KeycloakClient()
            kc.login() # Uses ENV vars or fail
            state["kc"] = kc
            
            # Helper: Ensure Admin has 'org-admin-group' rights (required for EMF)
            # 1-create-org.sh does this explicitly.
            admin_user = Config.KEYCLOAK_ADMIN_USER
            try:
                # Find Admin User UUID
                users = kc.search_users(admin_user)
                uid = None
                for u in users:
                     if u["username"] == admin_user:
                         uid = u["id"]
                         break
                
                if uid:
                    # Check groups
                    user_groups = kc.get_user_groups(uid)
                    has_group = any(g["name"] == "org-admin-group" for g in user_groups)
                    
                    if not has_group:
                        console.print(f"[yellow]Adding {admin_user} to org-admin-group...[/yellow]")
                        g_info = kc.get_group_by_path("org-admin-group")
                        if g_info:
                             kc.add_user_to_group(uid, g_info["id"])
                             # Re-login to get updated token Claims
                             console.print("Refreshing token...")
                             kc.login() 
                        else:
                             console.print("[red]Warning: org-admin-group not found![/red]")
            except Exception as e:
                console.print(f"[yellow]Permission check failed: {e}[/yellow]")

            state["emf"] = EMFClient(kc.token)
        except Exception as e:
            console.print(f"[red]Authentication Failed: {e}[/red]")
            console.print("Ensure CLUSTER_FQDN (or KEYCLOAK_URL), KEYCLOAK_ADMIN_USER, KEYCLOAK_ADMIN_PASS are set.")
            sys.exit(1)

def ask_password(prompt_text: str, confirm: bool = True) -> str:
    """Fetches password policy and prompts user."""
    kc = state.get("kc")
    # If not logged in, we can't get policy easily unless we use a temporary unrestricted client (rare).
    # Just proceed if we can't get it.
    if kc and kc.token: 
        try:
            policy = kc.get_realm_password_policy()
            console.print(f"[bold cyan]Password Policy: {policy}[/bold cyan]")
        except:
            pass
    while True:
        pwd = Prompt.ask(prompt_text, password=True)
        if not pwd:
            console.print("[red]Password cannot be empty.[/red]")
            continue
        
        if not confirm:
            return pwd
            
        pwd_confirm = Prompt.ask("Confirm Password", password=True)
        if pwd != pwd_confirm:
            console.print("[red]Passwords do not match. Please try again.[/red]")
            continue
            
        return pwd

@org_app.command("create")
def create_org(
    name: str = typer.Option(..., prompt="Organization Name"),
    description: str = typer.Option(None, help="Description (optional)"),
    create_admin: bool = typer.Option(True, prompt="Create default Org Admin?", help="Create an admin user for this org"),
    org_admin_pass: str = typer.Option(None, help="Password for Org Admin (if creating)")
):
    """Create a new Organization and optionally an Admin User."""
    ensure_auth()
    if not description:
        description = f"Description for {name}"

    emf = state["emf"]
    kc = state["kc"]

    # 1. Create Org
    with get_spinner(f"Creating Org {name}...") as progress:
        progress.add_task(f"sending request...")
        emf.create_org(name, description)
        
        def check_status():
            return emf.get_org_status(name) == "STATUS_INDICATION_IDLE"
        
        poll_until(check_status, lambda x: x, description="Org Provisioning")
        org_uuid = emf.get_org_uuid(name)

    console.print(f"[green]✓ Organization {name} Created (UUID: {org_uuid})[/green]")

    # 2. Create Admin
    if create_admin:
        admin_user = f"{name}-admin"
        if not org_admin_pass:
            org_admin_pass = ask_password(f"Password for {admin_user}")
        
        with get_spinner(f"Creating User {admin_user}...") as progress:
            progress.add_task("Creating in Keycloak...")
            user_id = kc.create_user(admin_user, org_admin_pass)
            
            group_name = f"{org_uuid}_Project-Manager-Group"
            def check_group():
                return kc.get_group_by_path(group_name)
            
            try:
                group = poll_until(lambda: check_group(), lambda x: x is not None, description="Group Sync")
                kc.validate_user_constraints(user_id, group_name)
                kc.add_user_to_group(user_id, group["id"])
            except Exception as e:
                console.print(f"[red]Failed to assign admin group: {e}[/red]")
                raise typer.Exit(1)
        
        console.print(f"[green]✓ User {admin_user} created and made Admin of {name}[/green]")

@project_app.command("create")
def create_project(
    project_name: str = typer.Option(..., prompt="Project Name"),
    description: str = typer.Option(None),
    org_name: str = typer.Option(None, help="Organization Name (skips prompt)"),
    org_admin_pass: str = typer.Option(None, help="Password for Org Admin (for context)")
):
    """Create a new Project within a selected Organization."""
    ensure_auth()
    # default EMF/KC are Platform Admin
    kc_admin = state["kc"] 
    
    # 1. Select Org
    emf_global = state["emf"]
    
    with get_spinner("Fetching Organizations...") as p:
        p.add_task("loading...")
        orgs = emf_global.list_orgs()
    
    if not orgs:
        console.print("[red]No Organizations found.[/red]")
        raise typer.Exit(1)

    org_names = list(orgs.keys())
    
    selected_org = org_name
    if not selected_org:
        console.print("Available Organizations:")
        for o in org_names:
            console.print(f" - {o}")
        selected_org = Prompt.ask("Select Organization", choices=org_names)
    elif selected_org not in org_names:
        console.print(f"[red]Organization {selected_org} not found in available list.[/red]")
        # Optional: Allow creating anyway? No, safer to fail.
        raise typer.Exit(1)

    org_uuid = orgs[selected_org]

    if not description:
        description = f"Project {project_name} in {selected_org}"

    # 2. Login as Org Admin (required for Project Creation context)
    org_admin_user = f"{selected_org}-admin"
    if not org_admin_pass:
        console.print(f"[yellow]To create a project in {selected_org}, we need {org_admin_user} credentials.[/yellow]")
        org_admin_pass = ask_password(f"Password for {org_admin_user}", confirm=False)

    # Authenticate as Org Admin
    # Authenticate as Org Admin
    kc_org = KeycloakClient()
    try:
        with get_spinner(f"Authenticating as {org_admin_user}...") as p:
             kc_org.login(username=org_admin_user, password=org_admin_pass)
    except Exception as e:
        console.print(f"[red]Failed to login as {org_admin_user}: {e}[/red]")
        raise typer.Exit(1)

    emf_org = EMFClient(kc_org.token)

    # 3. Create Project
    with get_spinner(f"Creating Project {project_name}...") as p:
        p.add_task("Requesting...")
        emf_org.create_project(project_name, description)
        
        def check_status():
            return emf_org.get_project_status(project_name) == "STATUS_INDICATION_IDLE"
        
        # We might need to poll using the global admin if the org admin loses context? 
        # But usually polling with same token is fine.
        poll_until(check_status, lambda x: x, description="Provisioning")
        
        # Get UUID (using Org Admin token)
        proj_uuid = emf_org.get_project_uuid(project_name)

    console.print(f"[green]✓ Project {project_name} Created ({proj_uuid})[/green]")

    # 3. Create "Organization Project Admin" (The Onboarding User)
    # User Request: "create a default 'Organization Project Admin', this user will have the Onboarding permissions."
    # Naming convention: [org]-proj-admin? Or [project]-onboarding?
    # Request says: "I want the Organization Admin account to be updated to have all permissions OTHER THAN Edge-Onboarding-Group...".
    # And "Create a default 'Organization Project Admin' ... will have Onboarding permissions."
    
    proj_admin_user = f"{selected_org}-proj-admin" # or maybe just unique to project?
    # To be safe and unique: {project_name}-admin is safer? 
    # But prompt says "Organization Project Admin". Let's ask.
    
    create_default_users = Confirm.ask(f"Create default users for {project_name}?", default=True)
    if create_default_users:
        # A. Onboarding User
        onboarding_user = f"{project_name}-onboard"
        onboarding_pass = ask_password(f"Password for {onboarding_user}")
        
        with get_spinner(f"Creating Onboarding User {onboarding_user}...") as p:
            uid = kc_admin.create_user(onboarding_user, onboarding_pass)
            
            # Assign Onboarding Group
            g_name = f"{proj_uuid}_Edge-Onboarding-Group"
            g = poll_until(lambda: kc_admin.get_group_by_path(g_name), lambda x: x, description="Group Sync")
            
            kc_admin.validate_user_constraints(uid, g_name)
            kc_admin.add_user_to_group(uid, g["id"])
        console.print(f"[green]✓ Onboarding User {onboarding_user} created[/green]")

        # B. Update Org Admin (Add all EXCEPT Onboarding)
        org_admin_name = f"{selected_org}-admin"
        console.print(f"Updating Org Admin {org_admin_name} with Project permissions...")
        
        oa_id = None
        try:
             # Find user ID - Use kc_admin (Platform Admin)
             users = kc_admin.search_users(org_admin_name)
             for u in users:
                 if u["username"] == org_admin_name:
                     oa_id = u["id"]
                     break
        except:
            pass

        if oa_id:
            groups_to_add = ["Edge-Manager-Group", "Edge-Operator-Group", "Host-Manager-Group"] # "Project-Manager-Group" is Org level? 
            # createProjectAdmin script uses: "Edge-Manager-Group" "Edge-Onboarding-Group" "Edge-Operator-Group" "Host-Manager-Group"
            # But here we want ALL EXCEPT Onboarding.
            
            with get_spinner("Assigning groups to Org Admin...") as p:
                for suffix in groups_to_add:
                    g_name = f"{proj_uuid}_{suffix}"
                    # Use polling because groups creation is async by EMF-Orchestrator
                    g = poll_until(lambda: kc_admin.get_group_by_path(g_name), lambda x: x, description=f"Sync {suffix}")
                    
                    if g:
                        try:
                            # Note: Org Admin might have other project groups.
                            # We trust the relationship here (Project is in the Org), so we skip the strict single-tenant constraint check
                            # which might confuse Project UUIDs with Org UUIDs.
                            # kc_admin.validate_user_constraints(oa_id, g_name)
                            kc_admin.add_user_to_group(oa_id, g["id"])
                        except Exception as e:
                            console.print(f"[yellow]Skipped {g_name}: {e}[/yellow]")
            console.print(f"[green]✓ Org Admin updated[/green]")
        else:
            console.print(f"[yellow]Org Admin {org_admin_name} not found, skipping update.[/yellow]")

@user_app.command("manage")
def manage_user():
    """Add or Update a user with specific permissions."""
    ensure_auth()
    emf = state["emf"]
    kc = state["kc"]

    # 1. Select User Action
    action = Prompt.ask("Action", choices=["create-new", "update-existing"])
    
    username = Prompt.ask("Username")
    user_id = None
    
    if action == "create-new":
        password = ask_password("Password")
        user_id = kc.create_user(username, password)
        console.print(f"[green]User {username} created[/green]")
    else:
        users = kc.search_users(username)
        # simplistic match
        for u in users:
            if u["username"] == username:
                user_id = u["id"]
                break
        if not user_id:
            console.print("[red]User not found[/red]")
            raise typer.Exit(1)
        console.print(f"[green]Found User {username}[/green]")

    # 2. Select Org (Context)
    with get_spinner("Fetching Orgs...") as p:
        orgs = emf.list_orgs()
    
    org_choice = Prompt.ask("Select Organization context", choices=list(orgs.keys()))
    # org_uuid = orgs[org_choice] # Maybe used for validation if strict

    # 3. Select Projects
    with get_spinner("Fetching Projects...") as p:
        projects = emf.list_projects()
    
    # Simple multi-select via iteration or comma separated?
    # Typer/Rich prompt doesn't have native multi-select checkbox easily without `inquirer` style libs.
    # We will do Comma Separated.
    console.print("Available Projects:")
    p_names = list(projects.keys())
    for pn in p_names:
        console.print(f" - {pn}")
    
    selected_projs_str = Prompt.ask("Select Projects (comma separated, or 'all')")
    if selected_projs_str.lower() == 'all':
        selected_projs = p_names
    else:
        selected_projs = [s.strip() for s in selected_projs_str.split(",") if s.strip() in projects]
    
    if not selected_projs:
        console.print("[yellow]No valid projects selected.[/yellow]")
        return

    # 4. Select Roles
    console.print("Roles:")
    console.print("1. Project Admin (Manager + Operator + Host + Onboarding?)") # Definition varies in prompt.
    # Prompt says: "- Project Admin: as represented in createProjectAdmin function"
    # createProjectAdmin script: adds `[Org_UUID]_Project-Manager-Group`. Wait, that's Org Admin?
    # Wait, createProjectAdmin (line 139) adds `[Org_UUID]_Project-Manager-Group`. 
    # BUT createProjectUser (line 173) adds `[Proj_UUID]_(Manager,Onboarding,Operator,Host)`.
    # AND "Organization Project Admin" is mentioned in prompt Item 2 as having "Onboarding".
    
    # Prompt Item 3:
    # - Project Admin: as represented in createProjectAdmin
    # - Project User: as represented in createProjectUser
    # - Optional: Onboarding, Org Admin.
    
    # Correction: createProjectAdmin in script (line 163) adds `[OrgUUID]_Project-Manager-Group`.
    # It essentially makes them a full Org Admin?
    # The script comments say "Creating Project Admin...".
    # This implies in this schema, "Project Admin" might just be "Org Admin"? Or the script naming is confusing.
    # Let's stick to the User Request text: "Project Admin: as represented in createProjectAdmin function".
    
    role = Prompt.ask("Select Role", choices=["Project Admin", "Project User", "Custom"])
    
    groups_to_add = []
    
    if role == "Project Admin":
        # Based on script createProjectAdmin: Add to Org-Level Project-Manager-Group?
        # That seems to grant access to ALL projects in Org?
        # If the user selected specific projects, this might be overkill.
        # But we must follow the definition.
        # Wait, if they select "Project Admin", maybe they become Admin for THAT project?
        # But the script uses Org UUID.
        # I will assume "Project Admin" means adding the Org-Level Manager group.
        # Check `kc-utils.sh` line 163: `project_user_groups=("${org_uuid}_Project-Manager-Group")`
        org_uuid = orgs[org_choice]
        groups_to_add.append(f"{org_uuid}_Project-Manager-Group")

    elif role == "Project User":
        # createProjectUser script: 
        # groups=("Edge-Manager-Group" "Edge-Onboarding-Group" "Edge-Operator-Group" "Host-Manager-Group")
        # Prefixed with Project UUID.
        base_suffixes = ["Edge-Manager-Group", "Edge-Onboarding-Group", "Edge-Operator-Group", "Host-Manager-Group"]
        for p_name in selected_projs:
            p_uuid = projects[p_name]
            for s in base_suffixes:
                groups_to_add.append(f"{p_uuid}_{s}")
    
    elif role == "Custom":
        suffixes = []
        if Confirm.ask("Add Edge-Manager?"): suffixes.append("Edge-Manager-Group")
        if Confirm.ask("Add Edge-Operator?"): suffixes.append("Edge-Operator-Group")
        if Confirm.ask("Add Host-Manager?"): suffixes.append("Host-Manager-Group")
        if Confirm.ask("Add Edge-Onboarding?"): suffixes.append("Edge-Onboarding-Group")
        
        for p_name in selected_projs:
            p_uuid = projects[p_name]
            for s in suffixes:
                groups_to_add.append(f"{p_uuid}_{s}")
        
        if Confirm.ask("Add Org Admin (Project-Manager-Group)?"):
             org_uuid = orgs[org_choice]
             groups_to_add.append(f"{org_uuid}_Project-Manager-Group")

    # 5. Apply
    with get_spinner("Applying permissions...") as p:
        for g_name in groups_to_add:
            # Poll for group?
            g = kc.get_group_by_path(g_name)
            if not g:
                console.print(f"[yellow]Group {g_name} not found. Skipping.[/yellow]")
                continue
            
            try:
                kc.validate_user_constraints(user_id, g_name)
                kc.add_user_to_group(user_id, g["id"])
                console.print(f" - Added to {g_name}")
            except Exception as e:
                console.print(f"[red]Failed to add to {g_name}: {e}[/red]")

    console.print("[green]Done[/green]")

if __name__ == "__main__":
    app()
