# Edge Manageability Framework: Multi-Tenancy Tool

> NOTE: This tool is almost exclusively AI generated using Google Antigravity

A robust, portable CLI tool for managing EMF multi-tenancy, ensuring consistency across Orchestrator and Keycloak.

## Features
*   **Workflow Driven**: Dedicated commands for Org, Project, and User workflows.
*   **Interactive**: Lists available resources (Orgs, Projects) for easy selection.
*   **Robust**: Handles API polling (waiting for provisioning) automatically.
*   **Constraint Checking**: 
    *   Ensures users belong to only one Organization.
    *   Ensures users have only one `Edge-Onboarding-Group`.
*   **Portable**: Runs in Docker/Podman with zero system dependencies.

## Configuration

Create a `.env` file or pass these environment variables to the container:

| Variable | Description | Required | Default |
| :--- | :--- | :--- | :--- |
| `CLUSTER_FQDN` | Base domain of the cluster (e.g. `cluster.example.com`). Used to derive `keycloak.*` and `api.*` URLs. | **Yes** | - |
| `KEYCLOAK_ADMIN_PASS` | Password for the Keycloak Platform Admin. | **Yes** | - |
| `KEYCLOAK_ADMIN_USER` | Username for the Keycloak Platform Admin. | No | `admin` |
| `VERIFY_SSL` | Verify SSL Certificates. Set to `false` for self-signed certs (not recommended). | No | `true` |
| `POLL_TIMEOUT` | Seconds to wait for resource provisioning. | No | `60` |
| `no_proxy` | Comma-separated domains to bypass proxy (crucial for internal clusters). | No | - |

## Usage

### Prerequisites
*   Docker or Podman

> **Note**: If running behind a corporate proxy, ensure `no_proxy` includes your cluster domain.
> ```bash
> docker run -e no_proxy=$no_proxy ...
> ```

### Quick Start (Container)

1.  **Build the image**:
    ```bash
    cd emfscripts/antigravity
    docker build -t emf-manager .
    ```

2.  **Run logic**:
    ```bash
    # Create an env file with CLUSTER_FQDN
    # The tool will automatically derive Keycloak and EMF URLs.
    docker run -it --rm --network host \
        -e CLUSTER_FQDN="a.tiberedge.com" \
        -e KEYCLOAK_ADMIN_PASS="tojDUI>9@E))R|7(Mjk6E{yB4" \
        emf-manager org create
    ```

3.  **Run Interactive Setup**:
    ```bash
    docker run -it --rm --network host --env-file .env emf-manager project create
    ```

    **Manage Users**:
    ```bash
    docker run -it --rm --network host --env-file .env emf-manager user manage
    ```

### Interactive Shell Mode
For faster operations, you can enter the container shell and run commands directly without restarting the container:

```bash
# Start shell
docker run -it --rm --network host --env-file .env emf-manager bash

# Inside the shell:
python main.py org list
python main.py org create

python main.py project list
python main.py project create

python main.py user list --search "onboard"
python main.py user manage
```

## Workflows

### Organization
*   **Create**: Creates an Org and a default `{org}-admin` user.
*   **List**: Displays all organizations and their status.

### Project
*   **Create**: 
    *   Authenticates as the Organization Admin (prompts for Org Admin password).
    *   Creates Project in EMF.
    *   Creates an Onboarding User (`{org}-{project}-onboard`).
    *   Updates the Org Admin with project management permissions.
*   **List**: Lists projects within a specific Organization (requires Org Admin authentication).

### User
*   **Manage**: Add or Update users with specific roles (Project Admin, Project User, etc.).
    *   *Note*: When adding users to projects, the tool warns but allows multi-project membership within an Org.
*   **List**: Search for users by username or email.

### Command Help
Run with `--help` to see options:
```bash
docker run -it --rm emf-manager --help
docker run -it --rm emf-manager org create --help
```
