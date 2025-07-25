param ($subscriptionId, $namePrefix)

Write-Host "Setting the paramaters:"
$location = "westeurope"
$resourceGroup = "$namePrefix-rg"
$buildBicepPath = ".\deploy\build\main.bicep"
$releaseAPIMBicepPath = ".\deploy\release\apim_apis.bicep"
$deploymentNameBuild = $namePrefix+"build"
$deploymentNameAPIMRelease = $namePrefix+"apimrelease"

Write-Host "Login to Azure:"
Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

Write-Host "Build"
Write-Host "Deploy Infrastructure as Code:"
$buildResult = New-AzSubscriptionDeployment -name $deploymentNameBuild -namePrefix $namePrefix -location $location -TemplateFile $buildBicepPath

if ($buildResult.ProvisioningState -eq "Succeeded") {
    Write-Host "Infrastructure deployment completed successfully"
    
    Write-Host "Release"
    Write-Host "Retrieve API Management Instance & Application Insights Name:"
    
    # Set Azure CLI context
    az account set -s $subscriptionId
    
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
} else {
    Write-Error "Infrastructure deployment failed. Cannot proceed with API release."
    exit 1
}
    Write-Host "API Management Instance: $apimName"
    Write-Host "Application Insights: $appInsightsName"

    Write-Host "Release API definition to API Management:"
    $releaseResult = New-AzResourceGroupDeployment -Name $deploymentNameAPIMRelease -ResourceGroupName $resourceGroup -apimName $apimName -appInsightsName $appInsightsName -TemplateFile $releaseAPIMBicepPath
    
    if ($releaseResult.ProvisioningState -eq "Succeeded") {
        Write-Host "API release deployment completed successfully"
    } else {
        Write-Error "API release deployment failed"
        exit 1
    }
