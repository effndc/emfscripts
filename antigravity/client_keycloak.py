import requests
from typing import List, Dict, Optional
from config import Config
from utils import handle_request_error

class KeycloakClient:
    def __init__(self):
        self.base_url = Config.KEYCLOAK_URL
        self.realm = Config.KEYCLOAK_REALM
        self.token = None

    def login(self, username: str = None, password: str = None):
        if not username:
             username = Config.KEYCLOAK_ADMIN_USER
        if not password:
             password = Config.KEYCLOAK_ADMIN_PASS
        
        url = f"{self.base_url}/realms/{self.realm}/protocol/openid-connect/token"
        data = {
            "username": username,
            "password": password,
            "grant_type": "password",
            "client_id": Config.KEYCLOAK_CLIENT_ID,
            "scope": Config.KEYCLOAK_SCOPE,
        }
        resp = requests.post(url, data=data, verify=Config.VERIFY_SSL) 
        if resp.status_code != 200:
            handle_request_error(resp, "Login failed")
        self.token = resp.json()["access_token"]

    def _headers(self):
        if not self.token:
            self.login()
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
    
    def get_realm_password_policy(self) -> str:
        """Fetches the password policy description from the realm."""
        url = f"{self.base_url}/admin/realms/{self.realm}"
        resp = requests.get(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
             handle_request_error(resp, "Get Realm Policy")
        
        data = resp.json()
        return data.get("passwordPolicy", "No explicit policy found (check Keycloak Console)")

    def get_user(self, username: str) -> Optional[Dict]:
        url = f"{self.base_url}/admin/realms/{self.realm}/users"
        resp = requests.get(url, headers=self._headers(), params={"username": username, "exact": "true"}, verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
            handle_request_error(resp, f"Get user {username}")
        
        users = resp.json()
        return users[0] if users else None

    def create_user(self, username: str, password: str, email: Optional[str] = None) -> str:
        """Creates a user and returns their ID."""
        # Check if exists
        existing = self.get_user(username)
        if existing:
            return existing["id"]

        url = f"{self.base_url}/admin/realms/{self.realm}/users"
        payload = {
            "username": username,
            "enabled": True,
            "email": email or f"{username}@{Config.KEYCLOAK_REALM}",
            "emailVerified": True,
            "credentials": [{
                "type": "password",
                "value": password,
                "temporary": False
            }]
        }
        resp = requests.post(url, headers=self._headers(), json=payload, verify=Config.VERIFY_SSL)
        if resp.status_code != 201:
            handle_request_error(resp, f"Create user {username}")
        
        # Fetch ID
        return self.get_user(username)["id"]

    def search_users(self, query: str) -> List[Dict]:
        """Search users by username, email, etc."""
        url = f"{self.base_url}/admin/realms/{self.realm}/users"
        # 'search' param does fuzzy search across fields
        resp = requests.get(url, headers=self._headers(), params={"search": query}, verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
            handle_request_error(resp, f"Search users {query}")
        return resp.json()

    def get_group_by_path(self, path: str) -> Optional[Dict]:
        # Keycloak API for group path usually is not direct search, using search instead
        # Or poll for it.
        # EMF creates groups like "[OrgUUID]_Project-Manager-Group"
        # We can search for the name.
        url = f"{self.base_url}/admin/realms/{self.realm}/groups"
        # Searching by name
        resp = requests.get(url, headers=self._headers(), params={"search": path}, verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
             handle_request_error(resp, f"Get group {path}")
        
        groups = resp.json()
        # Filter for exact match or reliable partial
        for g in groups:
            if path == g["name"]: 
                return g
        return None

    def add_user_to_group(self, user_id: str, group_id: str):
        url = f"{self.base_url}/admin/realms/{self.realm}/users/{user_id}/groups/{group_id}"
        resp = requests.put(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code not in [204, 200]: # 204 No Content is success
             handle_request_error(resp, f"Add user {user_id} to group {group_id}")

    def get_user_groups(self, user_id: str) -> List[Dict]:
        url = f"{self.base_url}/admin/realms/{self.realm}/users/{user_id}/groups"
        resp = requests.get(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
             handle_request_error(resp, f"Get groups for user {user_id}")
        return resp.json()

    def validate_user_constraints(self, user_id: str, new_group_name: str):
        """
        Enforce constraints:
        1. Single Organization (Group format: [UUID]_Project-Manager-Group or similar)
        2. Single Edge-Onboarding-Group
        3. Do not add exact duplicate group (idempotency check done by caller usually, but good to know)
        """
        current_groups = self.get_user_groups(user_id)
        
        # Check 1: Edge-Onboarding-Group uniqueness
        if "Edge-Onboarding-Group" in new_group_name:
            for g in current_groups:
                if "Edge-Onboarding-Group" in g["name"]:
                    # If it's the SAME group, it's fine (idempotent)
                    if g["name"] == new_group_name:
                        return
                    raise ValueError(f"User is already in an Onboarding group: {g['name']}")

        # Check 2: Single Organization
        # Extract UUID from new_group_name (Assumes UUID_Suffix format)
        # e.g. "550e8400-e29b-41d4-a716-446655440000_Project-Manager-Group"
        if "_" in new_group_name:
            new_org_uuid = new_group_name.split("_")[0]
            
            # Simple heuristic: If a group starts with a DIFFERENT UUID, it's a violation.
            # We assume UUID is 36 chars.
            if len(new_org_uuid) == 36:
                for g in current_groups:
                    if "_" in g["name"]:
                        existing_uuid = g["name"].split("_")[0]
                        if len(existing_uuid) == 36 and existing_uuid != new_org_uuid:
                            # Note: This logic is imperfect for Project groups (ProjectUUID != OrgUUID).
                            # Ideally we should validate hierarchy.
                            # For safety in this MVP, we will only WARN for now, or we can rely on caller.
                            # Given user feedback, rigid blocking here breaks valid flows.
                            # Changing to Warning/Log:
                            import logging
                            logging.warning(f"Potential Multi-Org violation: User belongs to {existing_uuid}, adding to {new_org_uuid}. Proceeding cautiously.")
                            # raise ValueError(f"User belongs to another Org ({existing_uuid}). Cannot add to {new_org_uuid}.")
