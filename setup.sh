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
|GitHub CLI      |Yes                  |'https://youtu.be/BII6ZY2Rnlc'                     |
|jq              |Yes                  |'https://stedolan.github.io/jq/download'           |
|yq              |Yes                  |'https://github.com/mikefarah/yq#install'          |
|kubectl         |Yes                  |'https://kubernetes.io/docs/tasks/tools/#kubectl'  |
|helm            |Yes                  |'https://helm.sh/docs/intro/install/'              |
|AWS CLI         |If using AWS         |'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'|
|eksctl          |If using AWS         |'https://eksctl.io/introduction/#installation'     |
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

gum confirm "Fork the anees-mscs-org/mscs-idp-demo repository?" && gh repo fork anees-mscs-org/mscs-idp-demo --clone --remote --org ${GITHUB_ORG} || exit 0
