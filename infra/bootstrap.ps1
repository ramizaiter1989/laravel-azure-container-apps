<#
.SYNOPSIS
  One-time Azure setup for GitHub Actions deploys (OIDC, no stored passwords).

.DESCRIPTION
  1. Registers the resource providers Container Apps needs.
  2. Creates the resource group.
  3. Creates an Entra ID app registration + service principal for GitHub Actions,
     with a federated credential trusted only for this repo's main branch.
  4. Grants it Contributor on THAT resource group only (least privilege).
  5. Stores the IDs and a fresh Laravel APP_KEY as GitHub repository secrets.

  Requires: Azure CLI (az), GitHub CLI (gh), both signed in.
  Safe to re-run: existing resources are reused.

.EXAMPLE
  ./infra/bootstrap.ps1 -Repo ramizaiter1989/laravel-azure-container-apps
#>
param(
    [Parameter(Mandatory)] [string] $Repo,
    [string] $ResourceGroup = 'rg-vehicle-quote-api',
    [string] $Location = 'germanywestcentral',
    [string] $AppRegistrationName = 'gh-vehicle-quote-api-deploy'
)

$ErrorActionPreference = 'Stop'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

Step 'Checking sign-in'
$account = az account show --output json | ConvertFrom-Json
if (-not $account) { throw 'Run "az login" first.' }
gh auth status | Out-Null
$subscriptionId = $account.id
$tenantId = $account.tenantId
Write-Host "Subscription: $($account.name) ($subscriptionId)"

Step 'Registering resource providers (first time can take a minute)'
foreach ($ns in 'Microsoft.App', 'Microsoft.OperationalInsights') {
    az provider register --namespace $ns --wait | Out-Null
}

Step "Resource group $ResourceGroup in $Location"
az group create --name $ResourceGroup --location $Location --output none

Step "App registration $AppRegistrationName"
$appId = az ad app list --display-name $AppRegistrationName --query '[0].appId' --output tsv
if (-not $appId) {
    $appId = az ad app create --display-name $AppRegistrationName --query appId --output tsv
}
$spId = az ad sp list --filter "appId eq '$appId'" --query '[0].id' --output tsv
if (-not $spId) {
    $spId = az ad sp create --id $appId --query id --output tsv
}

Step 'Federated credential (GitHub OIDC, main branch only)'
$credName = 'github-main'
$existing = az ad app federated-credential list --id $appId --query "[?name=='$credName'].name" --output tsv
if (-not $existing) {
    $cred = @{
        name      = $credName
        issuer    = 'https://token.actions.githubusercontent.com'
        subject   = "repo:${Repo}:ref:refs/heads/main"
        audiences = @('api://AzureADTokenExchange')
    } | ConvertTo-Json -Compress
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp -Value $cred -Encoding utf8
    az ad app federated-credential create --id $appId --parameters "@$tmp" --output none
    Remove-Item $tmp
}

Step 'Contributor role on the resource group only'
$scope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup"
$hasRole = az role assignment list --assignee $spId --scope $scope --role Contributor --query '[0].id' --output tsv
if (-not $hasRole) {
    az role assignment create --assignee-object-id $spId --assignee-principal-type ServicePrincipal `
        --role Contributor --scope $scope --output none
}

Step 'GitHub repository secrets and variables'
gh secret set AZURE_CLIENT_ID --repo $Repo --body $appId
gh secret set AZURE_TENANT_ID --repo $Repo --body $tenantId
gh secret set AZURE_SUBSCRIPTION_ID --repo $Repo --body $subscriptionId
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
gh secret set APP_KEY --repo $Repo --body ("base64:" + [Convert]::ToBase64String($bytes))
gh variable set AZURE_RESOURCE_GROUP --repo $Repo --body $ResourceGroup

Step 'Done'
Write-Host 'Push to main (or re-run the workflow) to deploy. The URL is printed in the deploy job summary.'
