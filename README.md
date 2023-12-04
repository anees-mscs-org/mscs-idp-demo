**Prequisites**:
https://github.com/charmbracelet/gum#installation

**NOTE**: You need to be the organization admin to run this demo

**Steps**:

1. Fork this repository under your GitHub organization with repository name as `idp-demo`

2. Create org admin token (ORG_ADMIN_TOKEN). Under Personal access token settings of the org, enroll access via Personal Access Token(s).  `Personal access token (classic)` was used in this demo.
The actual token needs to be created under user profile Developer settings with below scopes:
   - Read/Write access to repositories (repo)
   - Delete repositories (delete_repo)
   - Codespace secrets (codespace)
   - Read/Write access to repository hooks (admin:repo_hook)
   - Workflows access (workflow)
   - Admin access (admin:org, admin:org_hook)

3. Clone the forked repo on your local
4. Authenticate Github CLI, run 'gh auth login' and follow the instructions.
5. run ./setup.sh

Deployed ArgoCD app will be available on `gitops.${INGRESS_HOST}.nip.io`, where INGRESS_HOST IP can be found in the `.env` file on local once setup is completed.
