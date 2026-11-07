#!/usr/bin/env bash
# Creates what the pipeline needs, once, with the session of the subscription owner.
# It stores no credential. GitHub reaches Azure through a federated identity.
#
# Usage: ALERT_EMAIL=name@example.com infra/bootstrap/bootstrap.sh
set -euo pipefail

org=plazofiscal-devops
repo=plazofiscal-platform
location=mexicocentral
group=fiscal-plazo-demo-rg-main
identity=fiscal-plazo-demo-id-deployer
reviewers=(Melo088 Gafoxxx)

: "${ALERT_EMAIL:?set ALERT_EMAIL to receive budget alerts}"
subscription=$(az account show --query id --output tsv)
tenant=$(az account show --query tenantId --output tsv)
account="plazofiscal$(printf '%s' "$subscription" | sha256sum | cut -c1-8)"

az group create --name "$group" --location "$location" --output none

az storage account create --name "$account" --resource-group "$group" --location "$location" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false --output none
scope=$(az storage account show --name "$account" --resource-group "$group" --query id --output tsv)
az role assignment create --assignee "$(az ad signed-in-user show --query id --output tsv)" \
  --role "Storage Blob Data Contributor" --scope "$scope" --output none
az storage container create --name tfstate --account-name "$account" --auth-mode login --output none

az identity create --name "$identity" --resource-group "$group" --location "$location" --output none
client=$(az identity show --name "$identity" --resource-group "$group" --query clientId --output tsv)
principal=$(az identity show --name "$identity" --resource-group "$group" --query principalId --output tsv)

group_scope=$(az group show --name "$group" --query id --output tsv)
az role assignment create --assignee-object-id "$principal" --assignee-principal-type ServicePrincipal \
  --role Contributor --scope "$group_scope" --output none
az role assignment create --assignee-object-id "$principal" --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" --scope "$scope" --output none

# GitHub documents two subject formats, and newer repositories use the one with immutable IDs.
org_id=$(gh api "orgs/$org" --jq .id)
repo_id=$(gh api "repos/$org/$repo" --jq .id)
for environment in azure-up azure-down; do
  for subject in \
    "repo:$org/$repo:environment:$environment" \
    "repo:$org@$org_id/$repo@$repo_id:environment:$environment"; do
    name="github-$environment-$(printf '%s' "$subject" | sha256sum | cut -c1-8)"
    az identity federated-credential create --name "$name" --identity-name "$identity" \
      --resource-group "$group" --issuer https://token.actions.githubusercontent.com \
      --subject "$subject" --audiences api://AzureADTokenExchange --output none
  done
done

reviewer_json=$(for login in "${reviewers[@]}"; do
  gh api "users/$login" --jq '{type: "User", id: .id}'
done | jq --slurp --compact-output .)

jq --null-input --argjson reviewers "$reviewer_json" \
  '{reviewers: $reviewers, prevent_self_review: false,
    deployment_branch_policy: {protected_branches: false, custom_branch_policies: true}}' |
  gh api --method PUT "repos/$org/$repo/environments/azure-up" --input - >/dev/null
jq --null-input \
  '{deployment_branch_policy: {protected_branches: false, custom_branch_policies: true}}' |
  gh api --method PUT "repos/$org/$repo/environments/azure-down" --input - >/dev/null

for environment in azure-up azure-down; do
  gh api --method POST "repos/$org/$repo/environments/$environment/deployment-branch-policies" \
    -f name=main -f type=branch >/dev/null
  gh secret set AZURE_CLIENT_ID --repo "$org/$repo" --env "$environment" --body "$client"
  gh secret set AZURE_TENANT_ID --repo "$org/$repo" --env "$environment" --body "$tenant"
  gh secret set AZURE_SUBSCRIPTION_ID --repo "$org/$repo" --env "$environment" --body "$subscription"
  gh variable set TF_STATE_ACCOUNT --repo "$org/$repo" --env "$environment" --body "$account"
done

start=$(date +%Y-%m-01)
end=$(date -d "+11 months" +%Y-%m-01)
body=$(jq --null-input --arg email "$ALERT_EMAIL" --arg start "$start" --arg end "$end" '{properties: {
  category: "Cost", amount: 40, timeGrain: "Monthly",
  timePeriod: {startDate: ($start + "T00:00:00Z"), endDate: ($end + "T00:00:00Z")},
  notifications: {
    half: {enabled: true, operator: "GreaterThan", threshold: 50, contactEmails: [$email]},
    high: {enabled: true, operator: "GreaterThan", threshold: 90, contactEmails: [$email]}}}}')
if ! az rest --method put \
  --url "https://management.azure.com$group_scope/providers/Microsoft.Consumption/budgets/plazofiscal?api-version=2023-11-01" \
  --body "$body" --output none; then
  echo "The budget could not be created. Create it in the portal before the first run." >&2
fi

echo "Bootstrap complete. Run the Platform up workflow from GitHub Actions."
