#!/bin/sh
set -e

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'Setup for the Internal Developer Platform demo' \

gum confirm '
Are you ready to start?
Feel free to say "No" and inspect the script if you prefer setting up resources manually.
' || exit 0

# rm -f .env

################
# Requirements #
################

echo "
## You will need following tools installed:
|Name            |Required             |More info                                          |
|----------------|---------------------|---------------------------------------------------|
|Charm Gum       |Yes                  |'https://github.com/charmbracelet/gum#installation'|
|GitHub CLI      |Yes                  |'https://cli.github.com/'                     |
|jq              |Yes                  |'https://stedolan.github.io/jq/download'           |
|yq              |Yes                  |'https://github.com/mikefarah/yq#install'          |
|kubectl         |Yes                  |'https://kubernetes.io/docs/tasks/tools/#kubectl'  |
|helm            |Yes                  |'https://helm.sh/docs/intro/install/'              |
|AWS CLI         |Yes        					 |'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'|
|eksctl          |Yes         |'https://eksctl.io/introduction/#installation'     |
" | gum format

gum confirm "
Do you have those tools installed?
" || exit 0


gum confirm "
Are you loggedin to GitHub CLI?,  if not please run 'gh auth login' and follow the instructions.
" || exit 0


# AWS
HYPERSCALER=aws
echo "export HYPERSCALER=$HYPERSCALER" >> .env

###############
# GitHub Repo #
###############

echo
echo

GITHUB_ORG=$(gum input --placeholder "GitHub organization (do NOT use GitHub username)" --value "$GITHUB_ORG")
echo "export GITHUB_ORG=$GITHUB_ORG" >> .env

GITHUB_USER=$(gum input --placeholder "GitHub username" --value "$GITHUB_USER")
echo "export GITHUB_USER=$GITHUB_USER" >> .env

gh repo set-default ${GITHUB_ORG}/idp-demo

gum confirm "
We need to authorize GitHub CLI to manage your secrets. You need to be the organization admin.
" && gh auth refresh --hostname github.com --scopes admin:org  || exit 0

gum confirm "
We need to create GitHub secret ORG_ADMIN_TOKEN under the organization.
" \
    && ORG_ADMIN_TOKEN=$(gum input --placeholder "Please enter GitHub organization admin token." --password) \
    && gh secret set ORG_ADMIN_TOKEN --body "$ORG_ADMIN_TOKEN" --org ${GITHUB_ORG} --visibility all

DOCKERHUB_USER=$(gum input --placeholder "Please enter Docker Hub user")
echo "export DOCKERHUB_USER=$DOCKERHUB_USER" >> .env

gum confirm "
We need to create GitHub secret DOCKERHUB_USER.
" \
    && gh secret set DOCKERHUB_USER --body "$DOCKERHUB_USER" --org ${GITHUB_ORG} --visibility all

gum confirm "
We need to create GitHub secret DOCKERHUB_TOKEN.
" \
    && DOCKERHUB_TOKEN=$(gum input --placeholder "Please enter Docker Hub token (more info: https://docs.docker.com/docker-hub/access-tokens)." --password) \
    && gh secret set DOCKERHUB_TOKEN --body "$DOCKERHUB_TOKEN" --org ${GITHUB_ORG} --visibility all

export KUBECONFIG=$PWD/kubeconfig.yaml
echo "export KUBECONFIG=$KUBECONFIG" >> .env


###############
# AWS SETUP #
###############

AWS_ACCESS_KEY_ID=$(gum input --placeholder "AWS Access Key ID" --value "$AWS_ACCESS_KEY_ID")
echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> .env

AWS_SECRET_ACCESS_KEY=$(gum input --placeholder "AWS Secret Access Key" --value "$AWS_SECRET_ACCESS_KEY" --password)
echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> .env

AWS_ACCOUNT_ID=$(gum input --placeholder "AWS Account ID" --value "$AWS_ACCOUNT_ID")
echo "export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID" >> .env

export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

eksctl create cluster --config-file eksctl-config.yaml --kubeconfig $KUBECONFIG

eksctl create addon --name aws-ebs-csi-driver --cluster dot --service-account-role-arn arn:aws:iam::$AWS_ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole --force

kubectl create namespace crossplane-system

echo "[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
" >aws-creds.conf

kubectl --namespace crossplane-system create secret generic aws-creds --from-file creds=./aws-creds.conf

set +e
aws secretsmanager create-secret --name production-postgresql --region us-east-1 --secret-string '{"password": "YouWillNeverFindOut"}'
set -e

kubectl create namespace external-secrets

kubectl create namespace production

kubectl --namespace production create secret generic aws --from-literal access-key-id=$AWS_ACCESS_KEY_ID --from-literal secret-access-key=$AWS_SECRET_ACCESS_KEY

##############
# Crossplane #
##############

helm repo add crossplane-stable https://charts.crossplane.io/stable

helm repo update

helm upgrade --install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace --wait

kubectl apply --filename crossplane-config/provider-kubernetes-incluster.yaml

kubectl apply --filename crossplane-config/provider-helm-incluster.yaml

kubectl wait --for=condition=healthy provider.pkg.crossplane.io --all --timeout=300s

kubectl apply --filename crossplane-config/config-sql.yaml

kubectl apply --filename crossplane-config/config-app.yaml

gum spin --spinner line --title "Waiting for the cluster to stabilize (1 minute)..." -- sleep 60

kubectl wait --for=condition=healthy provider.pkg.crossplane.io --all --timeout=600s


kubectl apply --filename crossplane-config/provider-config-$HYPERSCALER-official.yaml


#################
# Setup Traefik #
#################

helm upgrade --install traefik traefik --repo https://helm.traefik.io/traefik --namespace traefik --create-namespace --wait

gum spin --spinner line --title "Waiting for the ELB DNS to propagate..." -- sleep 120

INGRESS_HOSTNAME=$(kubectl --namespace traefik get service traefik --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")

INGRESS_HOST=$(dig +short $INGRESS_HOSTNAME | sed -n 1p) 

echo "export INGRESS_HOST=$INGRESS_HOST" >> .env

##############
# Kubernetes #
##############

yq --inplace ".server.ingress.hosts[0] = \"gitops.${INGRESS_HOST}.nip.io\"" argocd/helm-values.yaml

# cd idp-demo
export REPO_URL=$(git config --get remote.origin.url)
# cd ..

yq --inplace ".spec.source.repoURL = \"${REPO_URL}\"" argocd/apps.yaml

yq --inplace ".spec.source.repoURL = \"${REPO_URL}\"" argocd/schema-hero.yaml

kubectl apply --filename k8s/namespaces.yaml

##################
# GitHub Actions #
##################

yq --inplace ".on.workflow_dispatch.inputs.repo-user.default = \"${GITHUB_USER}\"" .github/workflows/create-app-db.yaml

yq --inplace ".on.workflow_dispatch.inputs.image-repo.default = \"docker.io/${DOCKERHUB_USER}\"" .github/workflows/create-app-db.yaml

cat port/backend-app-action.json \
    | jq ".[0].userInputs.properties.\"repo-org\".default = \"$GITHUB_ORG\"" \
    | jq ".[0].invocationMethod.org = \"$GITHUB_ORG\"" \
    > port/backend-app-action.json.tmp

mv port/backend-app-action.json.tmp port/backend-app-action.json

gh repo view --web $GITHUB_ORG/idp-demo

echo "
Open \"Actions\" on Github and enable GitHub Actions (if not already enabled)."

gum input --placeholder "
Press the enter key to continue."

##########
# Install ArgoCD
##########

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'Executing "source .env" to set the environment variables.'

source .env

helm upgrade --install argocd argo-cd \
    --repo https://argoproj.github.io/argo-helm \
    --namespace argocd --create-namespace \
    --values argocd/helm-values.yaml --wait

echo "ArgoCD accessible on http://gitops.$INGRESS_HOST.nip.io"

kubectl apply --filename argocd/project.yaml

kubectl apply --filename argocd/apps.yaml


gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'Resetting argocd password to "password"'
gum input --placeholder "
Press the enter key to continue."

#bcrypt(password)=$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'


##################################
# Schema Management (SchemaHero) #
##################################

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'adding schema management commit to Github.' 

cp argocd/schema-hero.yaml infra/.
git add .
git commit -m "Add SchemaHero"
git push


#########################################
# Secrets Management (External Secrets) #
#########################################
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'adding secrets management commits to Github.' 


cp argocd/external-secrets.yaml infra/.
git add . 
git commit -m "External Secrets"
git push

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'IMPORTANT!!, OPEN argoCD UI, to make sure "external-secrets" app is syncronized before proceeding further' 
gum input --placeholder "
Press the enter key to continue."
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'adding aws secrets yaml commit to Github.' 

cp eso/secret-store-aws.yaml infra/.
git add . 
git commit -m "External Secrets Store"
git push



#########################################
# Graphical User Interface (GUI) (Port) #
#########################################
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'1. Open https://app.getport.io in a browser

2. Register (if not already).

3. Select the "Builder" page.

4. Click the "+ Add" button, select  "Choose from template",
followed with  "Map your Kubernetes ecosystem".

5. Click the  "Get this template" button, keep  "Are you using
ArgoCD" set to  "False", and click the  "Next" button, ignore
the instructions to run a script and click the "Done" button.'

gum input --placeholder "
Press the enter key to continue."

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'Follow the instructions from https://github.com/apps/getport-io to install the Port GitHub App.'
gum input --placeholder "
Press the enter key to continue."

# Add port blueprints
echo "copy content of file 'port/environment-blueprint.json' and add it as a custom blueprint in builder view of port"

gum input --placeholder "
Press the enter key to continue."

echo "copy content of file 'port/backend-app-blueprint.json' and add it as a custom blueprint in builder view of port"

CLIENT_ID=$(gum input --placeholder "PORT CLIENT_ID" )
CLIENT_SECRET=$(gum input --placeholder "PORT CLIENT_SECRET" )

export CLIENT_ID=$CLIENT_ID
export CLIENT_SECRET=$CLIENT_SECRET
cat argocd/port.yaml \
    | sed -e "s@CLIENT_ID@$CLIENT_ID@g" \
    | sed -e "s@CLIENT_SECRET@$CLIENT_SECRET@g" \
    | tee infra/port.yaml

gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'adding port ui commits to Github.' 
gum input --placeholder "
Press the enter key to continue."

git add .
git commit -m "Port"
git push


# Add port app action
echo 'copy content of file 'port/backend-app-action.json' and Open “Backend App” blueprint schema and click on “Edit JSON” under the three dots menu on the builder view of port. Paste the copied json under the Actions tab'

gum input --placeholder "
Press the enter key to continue."


###########
# Copy kubeconfig.yaml to default location #
###########
gum confirm "
We need to copy generated kubeconfig.yaml to ~/.kube/config, note: overwrites existing config file.
" \
    && cp kubeconfig.yaml ~/.kube/config || exit 0


gum style \
	--foreground 212 --border-foreground 212 --border double \
	--margin "1 2" --padding "2 4" \
	'The setup is complete.  You can now start using the Internal Developer Platform.'\
	'Use Self-service view of port website to create new application depoyments'
