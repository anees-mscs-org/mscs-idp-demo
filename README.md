Codebase for Masters Thesis submission for `REDUCING THE GAP BETWEEN DEVOPS AND DEVELOPERS: EMPOWERING DEVELOPERS WITH INTERNAL DEVELOPER PLATFORMS`

SYED ANEES - DECEMBER 2023

-----

**Prequisites**:

https://github.com/charmbracelet/gum#installation


-----
**Steps**:

1. Fork this repository under your GitHub organization with repository name as `idp-demo`.  You need to be organization admin of an org to run this demo.

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

-----

**Overview**:

1. Creates an EKS cluster on AWS cloud
2. Adds secrets to github organization under https://github.com/organizations/org-name/settings/secrets/actions (DOCKERHUB_TOKEN, DOCKERHUB_USER, ORG_ADMIN_TOKEN)
3. Creates various namespace segregation on Kubernetes cluster.
4. Installs crossplane, Traefik, port-k8s-exporter
5. Sets up github actions
6. ArgoCD deployment to monitor `apps` and `infra` folders of this repo. Any resource configs commited into these folders are picked up by argocd and relevants application deployment  or infrastructure changes are made on kubernetes and AWS cloud.
7. Instructions to add port.io blueprints to create simple user interfaces for application developers

-----

**Deployed tools**
1. Port UI - portal for application developers to use pre-configured infrastructure resources by the platfrom team.
2. ArgoCD - portal for platform team to view deployed apps and infra resources. ArgoCD available on `gitops.${INGRESS_HOST}.nip.io`, where INGRESS_HOST IP can be found in the `.env` file on local once setup is completed.
3. Interacting with k8s cluster - In the forked idp-demo folder, platform team can use `kubectl` to access k8s resources.
```
export AWS_ACCESS_KEY_ID=***
export AWS_SECRET_ACCESS_KEY=***
kubectl get namespaces
```


