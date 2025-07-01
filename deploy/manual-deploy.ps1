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
    az account set -s $subscriptionId
    
    # Wait a moment for resources to be fully available
    Start-Sleep -Seconds 30
    
    $apimName = az apim list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{Name:name}" -o tsv
    $appInsightsName = az monitor app-insights component show -g $resourceGroup --query "[].{applicationId:applicationId}" -o tsv
} else {
    Write-Error "Infrastructure deployment failed. Cannot proceed with API release."
    exit 1
}
    Write-Host "API Management Instance:"$apimName
    Write-Host "Application Insights:"$appInsightsName

    if ($apimName -and $appInsightsName) {
        Write-Host "Release API definition to API Management:"
        New-AzResourceGroupDeployment -Name $deploymentNameAPIMRelease -ResourceGroupName $resourceGroup -apimName $apimName -appInsightsName $appInsightsName -TemplateFile $releaseAPIMBicepPath
    } else {
        Write-Error "Could not retrieve APIM or Application Insights names. Deployment failed."
        exit 1
    }
