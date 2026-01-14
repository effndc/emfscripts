import requests
from typing import Dict, Any, Optional
from config import Config
from utils import handle_request_error

class EMFClient:
    def __init__(self, token: str):
        self.base_url = Config.EMF_API_URL
        self.token = token

    def _headers(self):
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "accept": "application/json"
        }

    def create_org(self, name: str, description: str):
        url = f"{self.base_url}/v1/orgs/{name}"
        payload = {"description": description}
        # kc-utils.sh sends "accept: application" for create
        headers = self._headers()
        headers["accept"] = "application"
        resp = requests.put(url, headers=headers, json=payload, verify=Config.VERIFY_SSL) 
        if resp.status_code != 200:
             handle_request_error(resp, f"Create Org {name}")

    def get_org_status(self, name: str) -> Optional[str]:
        url = f"{self.base_url}/v1/orgs/{name}"
        resp = requests.get(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
            return None # Or raise
        
        data = resp.json()
        return data.get("status", {}).get("orgStatus", {}).get("statusIndicator")

    def get_org_uuid(self, name: str) -> Optional[str]:
        url = f"{self.base_url}/v1/orgs/{name}"
        resp = requests.get(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
            return None
        
        data = resp.json()
        return data.get("status", {}).get("orgStatus", {}).get("uID")

    def create_project(self, name: str, description: str):
        url = f"{self.base_url}/v1/projects/{name}"
        payload = {"description": description}
        # kc-utils.sh sends "accept: application" for create
        headers = self._headers()
        headers["accept"] = "application/json"
        
        # update_if_exists only if explicitly needed? Script didn't use it in createProjectInOrg but did in other places? 
        # kc-utils.sh line 129: curl ... -d ...
        # No Params.
        resp = requests.put(url, headers=headers, json=payload, verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
             handle_request_error(resp, f"Create Project {name}")

    def get_project_status(self, name: str) -> Optional[str]:
        url = f"{self.base_url}/v1/projects/{name}"
        resp = requests.get(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
            return None
        
        data = resp.json()
        return data.get("status", {}).get("projectStatus", {}).get("statusIndicator")

    def get_project_uuid(self, name: str) -> Optional[str]:
        url = f"{self.base_url}/v1/projects/{name}"
        resp = requests.get(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
            return None
        
        data = resp.json()
        return data.get("status", {}).get("projectStatus", {}).get("uID")

    def list_orgs(self) -> Dict[str, str]:
        """Returns name:uuid dict"""
        url = f"{self.base_url}/v1/orgs"
        resp = requests.get(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
            return {}
        
        # Schema says Listorg.Org returns list of objects with name, spec, status
        data = resp.json()
        orgs = {}
        for item in data:
            name = item.get("name")
            uuid = item.get("status", {}).get("orgStatus", {}).get("uID")
            if name and uuid:
                orgs[name] = uuid
        return orgs

    def list_projects(self) -> Dict[str, str]:
        """Returns name:uuid dict"""
        url = f"{self.base_url}/v1/projects"
        resp = requests.get(url, headers=self._headers(), verify=Config.VERIFY_SSL)
        if resp.status_code != 200:
            return {}
        
        data = resp.json()
        projects = {}
        for item in data:
            name = item.get("name")
            uuid = item.get("status", {}).get("projectStatus", {}).get("uID")
            if name and uuid:
                projects[name] = uuid
        return projects
