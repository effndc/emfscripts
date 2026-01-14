import os
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Base Domain
    CLUSTER_FQDN: str = os.getenv("CLUSTER_FQDN", "")

    # Keycloak
    # If KEYCLOAK_URL is set, use it. Else derive from FQDN.
    KEYCLOAK_URL: str = os.getenv("KEYCLOAK_URL", "").rstrip("/")
    if not KEYCLOAK_URL and CLUSTER_FQDN:
        KEYCLOAK_URL = f"https://keycloak.{CLUSTER_FQDN}"

    KEYCLOAK_REALM: str = os.getenv("KEYCLOAK_REALM", "master")
    KEYCLOAK_CLIENT_ID: str = os.getenv("KEYCLOAK_CLIENT_ID", "system-client")
    KEYCLOAK_SCOPE: str = os.getenv("KEYCLOAK_SCOPE", "openid")
    KEYCLOAK_ADMIN_USER: str = os.getenv("KEYCLOAK_ADMIN_USER", "admin")
    KEYCLOAK_ADMIN_PASS: str = os.getenv("KEYCLOAK_ADMIN_PASS", "admin")

    # EMF
    # If EMF_API_URL is set, use it. Else derive from FQDN.
    EMF_API_URL: str = os.getenv("EMF_API_URL", "").rstrip("/")
    if not EMF_API_URL and CLUSTER_FQDN:
        EMF_API_URL = f"https://api.{CLUSTER_FQDN}"

    # SSL Config
    VERIFY_SSL: bool = os.getenv("VERIFY_SSL", "true").lower() == "true"

    # Polling Defaults
    POLL_INTERVAL: int = int(os.getenv("POLL_INTERVAL", "2"))
    POLL_TIMEOUT: int = int(os.getenv("POLL_TIMEOUT", "60"))

    @classmethod
    def validate(cls):
        missing = []
        if not cls.KEYCLOAK_URL and not cls.CLUSTER_FQDN: 
            missing.append("CLUSTER_FQDN (or KEYCLOAK_URL)")
        if not cls.EMF_API_URL and not cls.CLUSTER_FQDN: 
            missing.append("CLUSTER_FQDN (or EMF_API_URL)")
        
        if missing:
            raise ValueError(f"Missing required environment variables: {', '.join(missing)}")
