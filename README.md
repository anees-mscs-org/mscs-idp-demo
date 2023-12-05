**INTERNAL DEVELOPER PLATFORM DEMO**

Codebase for Masters Thesis submission for `REDUCING THE GAP BETWEEN DEVOPS AND DEVELOPERS: EMPOWERING DEVELOPERS WITH INTERNAL DEVELOPER PLATFORMS`

SYED ANEES - DECEMBER 2023


---

# Prequisites:

https://github.com/charmbracelet/gum#installation

---

# Steps:

1. Fork this repository under your GitHub organization with repository name as `idp-demo`. You need to be organization admin of an org to run this demo.

2. Create org admin token (ORG_ADMIN_TOKEN). Under Personal access token settings of the org, enroll access via Personal Access Token(s). `Personal access token (classic)` was used in this demo.
   The actual token needs to be created under user profile Developer settings with below scopes:

   - Read/Write access to repositories (repo)
   - Delete repositories (delete_repo)
   - Codespace secrets (codespace)
   - Read/Write access to repository hooks (admin:repo_hook)
   - Workflows access (workflow)
   - Admin access (admin:org, admin:org_hook)


3. Update permissions under organization settings in Actions > General view,  select below access for Workflow Permissions:

   - Read and write permissions
   - Allow GitHub Actions to create and approve pull requests

4. Clone the forked repo on your local
5. Authenticate Github CLI, run 'gh auth login' and follow the instructions.
6. run ./setup.sh

---

# Overview:

1. Creates an EKS cluster on AWS cloud
2. Adds secrets to github organization under https://github.com/organizations/org-name/settings/secrets/actions (DOCKERHUB_TOKEN, DOCKERHUB_USER, ORG_ADMIN_TOKEN, KUBECONFIG_PREVIEWS)
3. Creates various namespace segregation on Kubernetes cluster.
4. Installs crossplane, Traefik, port-k8s-exporter
5. Sets up github actions
6. ArgoCD deployment to monitor `apps` and `infra` folders of this repo. Any resource configs commited into these folders are picked up by argocd and relevants application deployment or infrastructure changes are made on kubernetes and AWS cloud.
7. Instructions to add port.io blueprints to create simple user interfaces for application developers

---

# Deployed tools

1. Port UI - portal for application developers to use pre-configured infrastructure resources by the platfrom team.
2. ArgoCD - portal for platform team to view deployed apps and infra resources. ArgoCD available on `gitops.${INGRESS_HOST}.nip.io`, where INGRESS_HOST IP can be found in the `.env` file on local once setup is completed.
3. Interacting with k8s cluster - In the forked idp-demo folder, platform team can use `kubectl` to access k8s resources.

```
export AWS_ACCESS_KEY_ID=***
export AWS_SECRET_ACCESS_KEY=***
kubectl get namespaces
```

---

# Known issues

1. The `Create Repo` step of the pipeline `.github/workflows/create-app-db.yaml` intermittently(though rarely) fails. It uses a tool called `devstream` to replace templated variables with user inputted values from port UI. It uses caching and rarely fails to create the transit branch. Which leads to creation of an empty git repository for the application being deployed.  Current workaround is to wait for few mins and try deploying the app again. The error is as below:

```
2023-12-04 21:05:58 ⚠ [WARN]  Failed to create transit branch: GET https://api.github.com/repos/anees-mscs-org/app12/git/ref/heads/main: 409 Git Repository is empty. []
Error: -04 21:05:58 !! [ERROR]  repo-scaffolding/myapp Create failed with error: GET https://api.github.com/repos/anees-mscs-org/app12/git/ref/heads/main: 409 Git Repository is empty. []
2023-12-04 21:05:58 ℹ [INFO]  -------------------- [  Processing aborted.  ] --------------------
Error: -04 21:05:58 !! [ERROR]  Errors Map: key(repo-scaffolding/myapp/Create) -> value(GET https://api.github.com/repos/anees-mscs-org/app12/git/ref/heads/main: 409 Git Repository is empty. [])
Error: -04 21:05:58 !! [ERROR]  Apply failed => some error(s) occurred during plugins apply process.
```

2. Application pod tries to boot-up before the Database secret is added to kubernetes state. Which leads to
   `CreateContainerConfigError` error.

```
-> kubectl get pods -n production
NAME                     READY   STATUS                       RESTARTS   AGE
app11-599c5d8557-t5qj5   0/1     CreateContainerConfigError   0          40s
app11-controller-0       1/1     Running                      0          40s
```

```
# Detailed logs
-> kubectl describe pod app11-599c5d8557-t5qj5  -n production
  Warning  Failed     15s (x5 over 52s)  kubelet            Error: secret "app11" not found
```

```
# Wait for the relevant secret to get added
-> kubectl get secrets --all-namespaces | grep app11
production          app11                                               Opaque                              4      23m
production          app11-password                                      Opaque                              1      28m
```

```
# Delete the pod and let it boot-up again as defined by the replicaset count
-> kubectl delete pod app11-599c5d8557-t5qj5 -n production
-> kubectl get pods -n production
NAME READY STATUS RESTARTS AGE
app11-599c5d8557-7rtlc 1/1 Running 0 23m
app11-controller-0 1/1 Running 0 29m
```
