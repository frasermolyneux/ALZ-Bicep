param (
  [Parameter(Mandatory = $false)] [string] $acrName,
  [Parameter(Mandatory = $false)] [string] $azureResourceGroup = 'rsg-private-bicep-registry',
  [Parameter(Mandatory = $false)] [string] $azureLocation = 'EastUs',
  [Parameter(Mandatory = $false)] [string] $versionTag = 'V1'
)

#Create resource group
az group create --name $azureResourceGroup --location $azureLocation

#Deploy Container Registry into Resource Group
if ("" -eq $acrName) {
  az deployment group create --template-file infra-as-code/bicep/CRML/containerRegistry/containerRegistry.bicep --resource-group $azureResourceGroup --name deployACR
}
else {
  az deployment group create --template-file infra-as-code/bicep/CRML/containerRegistry/containerRegistry.bicep --parameters parAcrName=$acrName --resource-group $azureResourceGroup --name deployACR
}


#Query the Deployment to get the login server to pass.
#https://docs.microsoft.com/en-us/cli/azure/query-azure-cli#get-a-single-value
$azureContainerRegistryName = $(az deployment group show -n deployACR -g $azureResourceGroup --query properties.outputs.outLoginServer.value -o tsv)

#Leverage Powershell too loop through all bicep modules within the repository
#convert the filename to lower case as Azure Container Registry doesnt support Camelcase
#Leverage az bicep to publish module to Azure Container Registry created above

$modulePaths = @(
  "$pwd/infra-as-code/bicep/modules/*/*.bicep"
  "$pwd/infra-as-code/bicep/modules/policy/*/*.bicep"
)

$files = Get-ChildItem $modulePaths

foreach ($file in $files) {
  #Grab the Full Path and Name and Filename only and store as variables
  $filewithPath = $file.FullName
  $fileShortName = $file.Name
  #Grab bicep module name and set to lowercase for Container Registry support
  $filenamelower = $($fileShortName.Substring(0, $fileShortName.length - 6)).toLower()
  Write-Output "Publishing $filewithPath to ACR: $azureContainerRegistryName"
  az bicep publish --file "$filewithPath" --target "br:$azureContainerRegistryName/bicep/modules/$($filenamelower):$versionTag"
}
