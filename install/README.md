# Install Scripts

These scripts are what I leverage in ny lab during installation of the EMF Orchestrator.  As written these scripts are intended to be executed directly on the system where you install the orchestrator software.

`install-check.sh` ran immediately after the EMF `onprem_installer.sh` returns to the shell, this script checks for the final completion of the install process.  When complete it will direct you to login and provide credentials.

`fqdn-to-bind.sh` (WIP) is used to generate a bind friendly DNS file that I can import to my DNS service (CloudFlare) web UI.

`fqdn-self-signed.sh` generates a list of URLs that you must visit in your browser to manually trust each end point for the GUI to work, this is only needed when using self-signed certs. This script automates that process. 

`testdns.sh` is used to verify your DNS entries exist.
