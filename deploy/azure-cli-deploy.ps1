param ($subscriptionId, $namePrefix)

Write-Host "Setting the parameters:"
$location = "westeurope"
$resourceGroup = "$namePrefix-rg"
$buildBicepPath = ".\deploy\build\main.bicep"
$releaseAPIMBicepPath = ".\deploy\release\apim_apis.bicep"
$deploymentNameBuild = $namePrefix+"build"
$deploymentNameAPIMRelease = $namePrefix+"apimrelease"

Write-Host "Login to Azure CLI:"
az login --use-device-code
az account set -s $subscriptionId

Write-Host "Build"
Write-Host "Deploy Infrastructure as Code:"
$buildResult = az deployment sub create --name $deploymentNameBuild --location $location --template-file $buildBicepPath --parameters namePrefix=$namePrefix --output json | ConvertFrom-Json

if ($buildResult.properties.provisioningState -eq "Succeeded") {
    Write-Host "Infrastructure deployment completed successfully"
    
    Write-Host "Release"
    Write-Host "Retrieve API Management Instance & Application Insights Name:"
    
    # Wait a moment for resources to be fully available
    Start-Sleep -Seconds 30
    
    Write-Host "Querying API Management instances in resource group: $resourceGroup"
    $apimName = az apim list --resource-group $resourceGroup --subscription $subscriptionId --query "[0].name" -o tsv
    
    if ([string]::IsNullOrEmpty($apimName)) {
        Write-Error "No API Management instance found in resource group $resourceGroup"
        exit 1
    }
    
    Write-Host "Querying Application Insights in resource group: $resourceGroup"
    $appInsightsName = az monitor app-insights component show -g $resourceGroup --subscription $subscriptionId --query "[0].appId" -o tsv
    
    if ([string]::IsNullOrEmpty($appInsightsName)) {
        Write-Error "No Application Insights instance found in resource group $resourceGroup"
        exit 1
    }
    
    Write-Host "API Management Instance: $apimName"
    Write-Host "Application Insights: $appInsightsName"

    Write-Host "Release API definition to API Management:"
    $releaseResult = az deployment group create --name $deploymentNameAPIMRelease --resource-group $resourceGroup --template-file $releaseAPIMBicepPath --parameters apimName=$apimName appInsightsName=$appInsightsName --output json | ConvertFrom-Json
    
    if ($releaseResult.properties.provisioningState -eq "Succeeded") {
        Write-Host "API release deployment completed successfully"
    } else {
        Write-Error "API release deployment failed"
        exit 1
    }
} else {
    Write-Error "Infrastructure deployment failed. Cannot proceed with API release."
    exit 1
}
