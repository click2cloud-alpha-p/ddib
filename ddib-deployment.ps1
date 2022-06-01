########################## Setting Environment variables  #####################################

$azure_username = 'sanchit.gangulwar@click2cloud.net'
$azure_password = 'Iamc00l@7875'
$azure_subscriptionID = '797407a8-807d-4152-9a74-9a7d582191e7'
$resourceGroup = 'new-ddib-rg-2'
$rgLocation = 'eastus'
$powerBIworkspace ='New-Engagement-Accelerators-Manufacturing-2'
$storageAccountAzure = 'newdreamdemosa'
$sql_admin_login_password = 'ROOT#123'


# Import modules

Import-Module MicrosoftPowerBIMgmt
Import-Module MicrosoftPowerBIMgmt.Profile

########################################### Setting Environment variables  ##################################################

$secure_password = $azure_password | ConvertTo-SecureString -asPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $azure_username, $secure_password

$global:tenantId = ''
$global:powerBIworkspaceGuID = ''

#############################################################################################################################


# Login to Azure 
function loginToAzure() {
    # Check account login exists    
    $azLoginExists = az account show --subscription $azure_subscriptionID  2>&1 >>$null
    $azCheck = Write-Output $?
    if ($azCheck -eq $false) {
	    Write-Host "Login into azure" -ForegroundColor Green
        az login -u $azure_username -p $azure_password
        # Get tenant ID
        $global:tenantId = (az account show | ConvertFrom-Json).tenantId
    } else {

       Write-Host "Account already logged in, skip account login" -ForegroundColor Yellow
       $global:tenantId = (az account show | ConvertFrom-Json).tenantId
    } 
}

#  CreateResourceGroup creates resource group 
function createResourceGroup() {
    #check resource-group exists
    $azureRgExists = az group exists --name $resourceGroup --subscription $azure_subscriptionID 
    if ($azureRgExists -eq $false) {
	    #Create resource group
	    Write-Host "Creating resource group $resourceGroup in region $rgLocation" -ForegroundColor Green
	    az group create `
		    --name=$resourceGroup `
		    --location=$rgLocation `
            --subscription=$azure_subscriptionID `
		    --output=jsonc
    } else {
        Write-Host "Resource group $resourceGroup already exists, skip create resource group" -ForegroundColor Yellow 

    } 
}

# Create Storage Account in Azure
function createStorageAccount(){
     #check storage account exists
    az storage account show --name $storageAccountAzure --resource-group $resourceGroup --subscription $azure_subscriptionID
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Creating storage account $storageAccountAzure in resource group $resourceGroup" -ForegroundColor Green
        # Create storage account
        az storage account create `
            --name=$storageAccountAzure `
            --resource-group=$resourceGroup `
            --location=$rgLocation `
            --sku='Standard_LRS'
        } else {
            Write-Host "Storage account $storageAccountAzure already exists, skip create storage account" -ForegroundColor Yellow 
        }
}



# Create workspace in powerBI
function createPowerBIworkspace() {
    # Login to PowerBI
    Write-Host "Login to PowerBI" -ForegroundColor Green
    Connect-PowerBIServiceAccount -Credential $Credential

    # Check PowerBi workspace exists
    $powerBIworkspaceExist = Get-PowerBIWorkspace -Name $powerBIworkspace 
    
    if ($null -eq $powerBIworkspaceExist ) {
	    Write-Host "Creating PowerBI workspace $powerBIworkspace" -ForegroundColor Green
        # Create new workspace
        New-PowerBIWorkspace -Name $powerBIworkspace
        # Get GuID of PowerBI workspace
        $global:powerBIworkspaceGuID = Get-PowerBIWorkspace -Name $powerBIworkspace | ForEach-Object -MemberName Id
        Write-Host "powerBIworkspaceGuID $global:powerBIworkspaceGuID" -ForegroundColor Cyan
    } else {
        Write-Host "Workspace already exists, skip create workspace" -ForegroundColor Yellow
        $global:powerBIworkspaceGuID = Get-PowerBIWorkspace -Name $powerBIworkspace | ForEach-Object -MemberName Id
        Write-Host "powerBIworkspaceGuID $global:powerBIworkspaceGuID" -ForegroundColor Cyan
    } 
}


# Create Custom Deployment in Azure
function createCustomDeployment(){
    # Check custom deployment exists
    $environment_code = Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 6 | ForEach-Object {[char]$_}) ).ToLower()
    az deployment group show --name 'Custom_Deployments' --resource-group $resourceGroup --subscription $azure_subscriptionID
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Custom Deployments already exists, skip create custom deployment" -ForegroundColor Yellow
    } else {
	Write-Host "Creating Custom Deployments in resource group $resourceGroup" -ForegroundColor Green
        # Create a custom deployment
        az deployment group create `
            --name='Custom_Deployments' `
            --resource-group=$resourceGroup `
            --subscription=$azure_subscriptionID `
            --template-uri="https://raw.githubusercontent.com/microsoft/Azure-Analytics-and-AI-Engagement/main/Manufacturing/automation/mainTemplate-shell.json" `
            --parameters environment_code=$environment_code pbi_workspace_id=$global:powerBIworkspaceGuID sql_administrator_login_password=$sql_admin_login_password
    }
}


# Execute manufacturing setup
function runManufacturingSetup() {
    # Execute the manufacturing setup script
    . $PSScriptRoot/manufacturingSetup-shell.ps1

}









loginToAzure
createResourceGroup
createStorageAccount
createPowerBIworkspace
createCustomDeployment
runManufacturingSetup
