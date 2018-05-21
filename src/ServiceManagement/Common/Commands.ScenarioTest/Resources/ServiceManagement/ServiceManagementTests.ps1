﻿# ----------------------------------------------------------------------------------
#
# Copyright Microsoft Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------

$PLACEHOLDER = "PLACEHOLDER1@";

<#
.SYNOPSIS
Tests Create-AzureVM with valid information.
#>
function Test-GetAzureVM
{
    # Setup
    $location = Get-DefaultLocation
    $imgName = Get-DefaultImage $location


    $storageName = getAssetName
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location

    Set-CurrentStorageAccountName $storageName

    $vmName = "vm1"
    $svcName = Get-CloudServiceName
    $extProp1 = @{"extended1"="property1";"extended2"="property2"}

    # Test
    New-AzureService -ServiceName $svcName -Location $location -ExtendedProperty $extProp1
    $result = Get-AzureService -ServiceName $svcName
    Assert-AreEqual "property1" $result.ExtendedProperties["extended1"]
    Assert-AreEqual "property2" $result.ExtendedProperties["extended2"]

    New-AzureQuickVM -Windows -ImageName $imgName -Name $vmName -ServiceName $svcName -AdminUsername "pstestuser" -Password $PLACEHOLDER
    $result = Get-AzureVM -ServiceName $svcName -Name $vmName

    $extProp2 =  @{"extended1"="property2";"extended2"="property1"}
    Set-AzureService -ServiceName $svcName -ExtendedProperty $extProp2

    $result = Get-AzureService -ServiceName $svcName
    Assert-AreEqual "property2" $result.ExtendedProperties["extended1"]
    Assert-AreEqual "property1" $result.ExtendedProperties["extended2"]

    $result = Get-AzureVM -ServiceName $svcName -Name $vmName

    # Cleanup
    Cleanup-CloudService $svcName
}


<#
.SYNOPSIS
Test Get-AzureLocation
#>
function Test-GetAzureLocation
{
    $locations = Get-AzureLocation;

    foreach ($loc in $locations)
    {
        $svcName = getAssetName;
        $st = New-AzureService -ServiceName $svcName -Location $loc.Name;
        
        # Cleanup
        Cleanup-CloudService $svcName
    }
}

# Test Service Management Cloud Exception
function Run-ServiceManagementCloudExceptionTests
{
    $compare = "*OperationID : `'*`'";
    Assert-ThrowsLike { $st = Get-AzureService -ServiceName '*' } $compare;
    Assert-ThrowsLike { $st = Get-AzureVM -ServiceName '*' } $compare;
    Assert-ThrowsLike { $st = Get-AzureAffinityGroup -Name '*' } $compare;
}

# Test Start/Stop-AzureVM for Multiple VMs
function Run-StartAndStopMultipleVirtualMachinesTest
{
    # Virtual Machine cmdlets are now showing a non-terminating error message for ResourceNotFound
    # To continue script, $ErrorActionPreference should be set to 'SilentlyContinue'.
    $tempErrorActionPreference = $ErrorActionPreference;
    $ErrorActionPreference='SilentlyContinue';

    # Setup
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $vmNameList = @("vm01", "vm02", "test04");
    $svcName = 'pstest' + (Get-CloudServiceName);
    $userName = "pstestuser";
    $password = $PLACEHOLDER;

    # Test
    New-AzureService -ServiceName $svcName -Location $location;

    try
    {
        foreach ($vmName in $vmNameList)
        {
            New-AzureQuickVM -Windows -ImageName $imgName -Name $vmName -ServiceName $svcName -AdminUsername $userName -Password $password;
        }

        # Get VM List
        $vmList = Get-AzureVM -ServiceName $svcName;

        # Test Stop
        Stop-AzureVM -Force -ServiceName $svcName -Name $vmNameList[0];
        Stop-AzureVM -Force -ServiceName $svcName -Name $vmNameList[0],$vmNameList[1];
        Stop-AzureVM -Force -ServiceName $svcName -Name $vmNameList;
        Stop-AzureVM -Force -ServiceName $svcName -Name '*';
        Stop-AzureVM -Force -ServiceName $svcName -Name 'vm*';
        Stop-AzureVM -Force -ServiceName $svcName -Name 'vm*','test*';
        Stop-AzureVM -Force -ServiceName $svcName -VM $vmList[0];
        Stop-AzureVM -Force -ServiceName $svcName -VM $vmList[0],$vmList[1];
        Stop-AzureVM -Force -ServiceName $svcName -VM $vmList;

        # Test Start
        Start-AzureVM -ServiceName $svcName -Name $vmNameList[0];
        Start-AzureVM -ServiceName $svcName -Name $vmNameList[0],$vmNameList[1];
        Start-AzureVM -ServiceName $svcName -Name $vmNameList;
        Start-AzureVM -ServiceName $svcName -Name '*';
        Start-AzureVM -ServiceName $svcName -Name 'vm*';
        Start-AzureVM -ServiceName $svcName -Name 'vm*','test*';
        Start-AzureVM -ServiceName $svcName -VM $vmList[0];
        Start-AzureVM -ServiceName $svcName -VM $vmList[0],$vmList[1];
        Start-AzureVM -ServiceName $svcName -VM $vmList;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $svcName;
        $ErrorActionPreference = $tempErrorActionPreference;
    }
}

# Run Auto-Generated Hosted Service Cmdlet Tests
function Run-AutoGeneratedHostedServiceCmdletTests
{
    # Setup
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $vmNameList = @("vm01", "vm02", "test04");
    $svcName = 'pstest' + (Get-CloudServiceName);
    $userName = "pstestuser";
    $password = $PLACEHOLDER;

    try
    {
        # Create Parameters
        $svcCreateParams = New-AzureComputeParameterObject -FriendlyName 'HostedServiceCreateParameters';
        $svcCreateParams.ServiceName = $svcName;
        $svcCreateParams.Location = $location;
        $svcCreateParams.Description = $svcName;
        $svcCreateParams.Label = $svcName;

        # Invoke Create
        $st = Invoke-AzureComputeMethod -MethodName 'HostedServiceCreate' -HostedServiceCreateParameters $svcCreateParams;

        Assert-AreEqual $st.StatusCode 'Created';
        Assert-NotNull $st.RequestId;

        # Invoke Get
        $svcGetResult = Invoke-AzureComputeMethod -MethodName 'HostedServiceGet' -ServiceName $svcName;
        Assert-AreEqual $svcGetResult.ServiceName $svcName;
        Assert-AreEqual $svcGetResult.Properties.Description $svcName;
        Assert-AreEqual $svcGetResult.Properties.Label $svcName;

        # Update Parameters
        $svcUpdateParams = New-AzureComputeParameterObject -FriendlyName 'HostedServiceUpdateParameters';
        $svcUpdateParams.Description = 'update1';
        $svcUpdateParams.Label = 'update2';

        # Invoke Update
        $svcGetResult2 = Invoke-AzureComputeMethod -MethodName 'HostedServiceUpdate' -ServiceName $svcName -HostedServiceUpdateParameters $svcUpdateParams;

        # Invoke Get
        $svcGetResult2 = Invoke-AzureComputeMethod -MethodName 'HostedServiceGet' -ServiceName $svcName;
        Assert-AreEqual $svcGetResult2.ServiceName $svcName;
        Assert-AreEqual $svcGetResult2.Properties.Description $svcUpdateParams.Description;
        Assert-AreEqual $svcGetResult2.Properties.Label $svcUpdateParams.Label;

        # Invoke List
        $svcListResult = Invoke-AzureComputeMethod -MethodName 'HostedServiceList';
        Assert-True { ($svcListResult | where { $_.ServiceName -eq $svcName }).Count -gt 0 };

        # Invoke Delete
        $st = Invoke-AzureComputeMethod -MethodName 'HostedServiceDelete' -ServiceName $svcName;
        Assert-AreEqual $st.StatusCode 'OK';
        Assert-NotNull $st.RequestId;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $svcName;
    }
}

# Run Auto-Generated Virtual Machine Cmdlet Tests
function Run-AutoGeneratedVirtualMachineCmdletTests
{
    # Setup
    $location = Get-DefaultLocation;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $svcName = 'pstest' + (Get-CloudServiceName);
    $userName = "pstestuser";
    $password = $PLACEHOLDER;

    try
    {
        # Create Hosted Service Parameters
        $svcCreateParams = New-AzureComputeParameterObject -FriendlyName 'HostedServiceCreateParameters';
        $svcCreateParams.ServiceName = $svcName;
        $svcCreateParams.Location = $location;
        $svcCreateParams.Description = $svcName;
        $svcCreateParams.Label = $svcName;

        # Invoke Hosted Service Create
        $st = Invoke-AzureComputeMethod -MethodName 'HostedServiceCreate' -ArgumentList $svcCreateParams;
        Assert-AreEqual $st.StatusCode 'Created';
        Assert-NotNull $st.RequestId;

        # Invoke Hosted Service Get
        $svcGetResult = Invoke-AzureComputeMethod -MethodName 'HostedServiceGet' -ArgumentList $svcName;
        Assert-AreEqual $svcGetResult.ServiceName $svcName;
        Assert-AreEqual $svcGetResult.Properties.Description $svcName;
        Assert-AreEqual $svcGetResult.Properties.Label $svcName;

        # Invoke Virtual Machine OS Image List
        $images = (Invoke-AzureComputeMethod -MethodName 'VirtualMachineOSImageList').Images;
        $image = $images | where { $_.OperatingSystemType -eq 'Windows' -and $_.LogicalSizeInGB -le 100 } | select -First 1;

        # Create Virtual Machine Deployment Create Parameters
        $vmDeployment = New-AzureComputeParameterObject -FriendlyName 'VirtualMachineCreateDeploymentParameters';
        $vmDeployment.Name = $svcName;
        $vmDeployment.Label = $svcName;
        $vmDeployment.DeploymentSlot = 'Production';
        $vmDeployment.Roles = New-AzureComputeParameterObject -FriendlyName 'VirtualMachineRoleList';
        $vmDeployment.Roles.Add((New-AzureComputeParameterObject -FriendlyName 'VirtualMachineRole'));
        $vmDeployment.Roles[0].RoleName = $svcName;
        $vmDeployment.Roles[0].RoleSize = 'Large';
        $vmDeployment.Roles[0].RoleType = 'PersistentVMRole';
        $vmDeployment.Roles[0].ProvisionGuestAgent = $false;
        $vmDeployment.Roles[0].ResourceExtensionReferences = $null;
        $vmDeployment.Roles[0].DataVirtualHardDisks = $null;
        $vmDeployment.Roles[0].OSVirtualHardDisk = New-AzureComputeParameterObject -FriendlyName 'VirtualMachineOSVirtualHardDisk';
        $vmDeployment.Roles[0].OSVirtualHardDisk.SourceImageName = $image.Name;
        $vmDeployment.Roles[0].OSVirtualHardDisk.MediaLink = "http://${storageName}.blob.core.windows.net/myvhds/${svcName}.vhd";
        $vmDeployment.Roles[0].OSVirtualHardDisk.ResizedSizeInGB = 128;
        $vmDeployment.Roles[0].OSVirtualHardDisk.HostCaching = 'ReadWrite';
        $vmDeployment.Roles[0].ConfigurationSets = New-AzureComputeParameterObject -FriendlyName 'VirtualMachineConfigurationSetList';
        $vmDeployment.Roles[0].ConfigurationSets.Add((New-AzureComputeParameterObject -FriendlyName 'VirtualMachineConfigurationSet'));
        $vmDeployment.Roles[0].ConfigurationSets[0].ConfigurationSetType = "WindowsProvisioningConfiguration";
        $vmDeployment.Roles[0].ConfigurationSets[0].AdminUserName = $userName;
        $vmDeployment.Roles[0].ConfigurationSets[0].AdminPassword = $password;
        $vmDeployment.Roles[0].ConfigurationSets[0].ComputerName = 'test';
        $vmDeployment.Roles[0].ConfigurationSets[0].HostName = "${svcName}.cloudapp.net";
        $vmDeployment.Roles[0].ConfigurationSets[0].EnableAutomaticUpdates = $false;
        $vmDeployment.Roles[0].ConfigurationSets[0].TimeZone = "Pacific Standard Time";

        # Invoke Virtual Machine Create Deployment
        $st = Invoke-AzureComputeMethod -MethodName 'VirtualMachineCreateDeployment' -ArgumentList $svcName,$vmDeployment;
        Assert-AreEqual $st.StatusCode 'OK';
        Assert-NotNull $st.RequestId;

        # Invoke Virtual Machine Get
        $st = Invoke-AzureComputeMethod -MethodName 'VirtualMachineGet' -ArgumentList $svcName,$svcName,$svcName;
        Assert-AreEqual $st.RoleName $svcName;

        # Invoke Hosted Service Delete
        $st = Invoke-AzureComputeMethod -MethodName 'HostedServiceDeleteAll' -ArgumentList $svcName;
        Assert-AreEqual $st.StatusCode 'OK';
        Assert-NotNull $st.RequestId;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $svcName;
    }
}

# Run dSMS Hosted Service test
function Run-DSMSHostedServiceTest
{
    # Setup
    $svcName = 'pstest' + (Get-CloudServiceName);
    $location = Get-DefaultLocation;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $testMode = Get-ComputeTestMode;
    if ($testMode.ToLower() -ne 'playback')
    {
        $cspkg = '.\Resources\ServiceManagement\Files\dSMSTest.cspkg';
    }
    else
    {
        $cspkg = "https://${storageName}.blob.azure.windows.net/blob/dSMSTest.cspkg";
    }
    $cscfg = "$TestOutputRoot\Resources\ServiceManagement\Files\dSMSTest.cscfg";
    $cscfgChanged = "$TestOutputRoot\Resources\ServiceManagement\Files\dSMSTest-changed.cscfg";

    # Create a temporary self-signed cert
    $cert = New-SelfSignedCertificate -DnsName "example.local" -CertStoreLocation "Cert:\CurrentUser\My";
    $certPath = "Cert:\CurrentUser\My\$($cert.Thumbprint)"
    # Update the cscfg to use the new cert
    (Get-Content $cscfg) | ForEach-Object {$_ -replace "\{\{PLACEHOLDER\}\}", $cert.Thumbprint} | Set-Content $cscfgChanged;

    try
    {
        # Create Hosted Service
        $result = New-AzureService -ServiceName $svcName -Location $location -Label $svcName -Description $svcName;

        # Upload the certificate
        Add-AzureCertificate -ServiceName $svcName -CertToDeploy $cert;

        # Deploy to staging
        $result = New-AzureDeployment -ServiceName $svcName -Package $cspkg -Configuration $cscfgChanged -Label $svcName -Slot Staging;

        # Get Deployment
        $deploy = Get-AzureDeployment -ServiceName $svcName -Slot Staging;

        # Make a change
        $newConfig = $deploy.Configuration -replace 'Setting name="DummySetting" value="Foo"', 'Setting name="DummySetting" value="Bar"';
        $newConfig | Set-Content $cscfgChanged;

        # Update configuration
        $result = Set-AzureDeployment -Config -ServiceName $svcName -Configuration $cscfgChanged -Slot Staging;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $svcName;
        Cleanup-Storage $storageName;
        if (Test-Path $cscfgChanged)
        {
            Remove-Item $cscfgChanged;
        }
        if (Test-Path $certPath)
        {
            Remove-Item $certPath
        }
    }
}

# Run New-AzureComputeArgumentList Cmdlet Tests Using Method Names
function Run-NewAzureComputeArgumentListTests
{
    $command = Get-Command -Name 'New-AzureComputeArgumentList';
    $all_methods = $command.Parameters['MethodName'].Attributes.ValidValues;

    foreach ($method in $all_methods)
    {
        $args = New-AzureComputeArgumentList -MethodName $method;
        foreach ($arg in $args)
        {
            Assert-NotNull $arg;
        }

        Write-Verbose "Invoke-AzureComputeMethod -MethodName $method -ArgumentList $args;";

        if ($args.Count -gt 0)
        {
            # If the method requires any inputs, empty/null input call would fail
            Assert-Throws { Invoke-AzureComputeMethod -MethodName $method -ArgumentList $args; }
        }
        else
        {
            # If the method doesn't requires any inputs, it shall succeed.
            $st = Invoke-AzureComputeMethod -MethodName $method;
        }
    }
}

# Run New-AzureComputeParameterObject Cmdlet Tests
function Run-NewAzureComputeParameterObjectTests
{
    $command = Get-Command -Name 'New-AzureComputeParameterObject';

    $all_friendly_names = $command.Parameters['FriendlyName'].Attributes.ValidValues;
    foreach ($friendly_name in $all_friendly_names)
    {
        $param = New-AzureComputeParameterObject -FriendlyName $friendly_name;
        Assert-NotNull $param;
    }

    $all_full_names = $command.Parameters['FullName'].Attributes.ValidValues;
    foreach ($full_name in $all_full_names)
    {
        $param = New-AzureComputeParameterObject -FullName $full_name;
        Assert-NotNull $param;

        $param_type_name = $param.GetType().ToString().Replace('+', '.');
        $full_name_query = $full_name.Replace('+', '.').Replace('<', '*').Replace('>', '*');
        Assert-True { $param_type_name -like $full_name_query } "`'$param_type_name`' & `'$full_name`'";
    }
}

# Run Set-AzurePlatformVMImage Cmdlet Negative Tests
function Run-AzurePlatformVMImageNegativeTest
{
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;
    $replicate_locations = (Get-AzureLocation | where { $_.Name -like '*US*' } | select -ExpandProperty Name);

    $c1 = New-AzurePlatformComputeImageConfig -Offer test -Sku test -Version test;
    $c2 = New-AzurePlatformMarketplaceImageConfig -PlanName test -Product test -Publisher test -PublisherId test;

    Assert-ThrowsContains `
        { Set-AzurePlatformVMImage -ImageName $imgName -ReplicaLocations $replicate_locations -ComputeImageConfig $c1 -MarketplaceImageConfig $c2 } `
        "ForbiddenError: This operation is not allowed for this subscription.";

    foreach ($mode in @("MSDN", "Private", "Public"))
    {
        Assert-ThrowsContains `
            { Set-AzurePlatformVMImage -ImageName $imgName -Permission $mode } `
            "ForbiddenError: This operation is not allowed for this subscription.";
    }
}

# Run Auto-Generated Service Extension Cmdlet Tests
function Run-AutoGeneratedServiceExtensionCmdletTests
{
    # Setup
    $location = Get-DefaultLocation;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $svcName = 'pstest' + (Get-CloudServiceName);

    try
    {
        # Create Hosted Service Parameters
        $svcCreateParams = New-AzureComputeParameterObject -FriendlyName 'HostedServiceCreateParameters';
        $svcCreateParams.ServiceName = $svcName;
        $svcCreateParams.Location = $location;
        $svcCreateParams.Description = $svcName;
        $svcCreateParams.Label = $svcName;

        # Invoke Hosted Service Create
        $st = Invoke-AzureComputeMethod -MethodName 'HostedServiceCreate' -ArgumentList $svcCreateParams;
        Assert-AreEqual $st.StatusCode 'Created';
        Assert-NotNull $st.RequestId;

        # New-AzureDeployment (in Azure.psd1)
        $testMode = Get-ComputeTestMode;
        if ($testMode.ToLower() -ne 'playback')
        {
            $cspkg = '.\Resources\ServiceManagement\Files\OneWebOneWorker.cspkg';
        }
        else
        {
            $cspkg = "https://${storageName}.blob.azure.windows.net/blob/OneWebOneWorker.cspkg";
        }
        $cscfg = "$TestOutputRoot\Resources\ServiceManagement\Files\OneWebOneWorker.cscfg";

        $st = New-AzureDeployment -ServiceName $svcName -Package $cspkg -Configuration $cscfg -Label $svcName -Slot Production;

        $deployment = Get-AzureDeployment -ServiceName $svcName -Slot Production;
        $config = $deployment.Configuration;

        # Invoke Hosted Service Add Extension
        $p1 = New-AzureComputeArgumentList -MethodName HostedServiceAddExtension;
        $p1[0].Value = $svcName;
        $p1[1].Value.Id = 'test';
        $p1[1].Value.PublicConfiguration =
@"
<?xml version="1.0" encoding="UTF-8"?>
<PublicConfig>
  <UserName>pstestuser</UserName>
  <Expiration></Expiration>
</PublicConfig>
"@;
        $p1[1].Value.PrivateConfiguration =
@"
<?xml version="1.0" encoding="UTF-8"?>
<PrivateConfig>
  <Password>pstestuser</Password>
</PrivateConfig>
"@;
        $p1[1].Value.ProviderNamespace = 'Microsoft.Windows.Azure.Extensions';
        $p1[1].Value.Type = 'RDP';
        $p1[1].Value.Version = '1.*';
        $d1 = ($p1 | select -ExpandProperty Value);
        $st = Invoke-AzureComputeMethod -MethodName HostedServiceAddExtension -ArgumentList $d1;

        # Invoke Deployment Change Configuration
        $p2 = New-AzureComputeArgumentList -MethodName DeploymentChangeConfigurationBySlot;
        $p2[0].Value = $svcName;
        $p2[1].Value = [Microsoft.WindowsAzure.Management.Compute.Models.DeploymentSlot]::Production;
        $p2[2].Value = New-Object -TypeName Microsoft.WindowsAzure.Management.Compute.Models.DeploymentChangeConfigurationParameters;
        $p2[2].Value.Configuration = $deployment.Configuration;
        $p2[2].Value.ExtensionConfiguration = New-Object -TypeName Microsoft.WindowsAzure.Management.Compute.Models.ExtensionConfiguration;
        $p2[2].Value.ExtensionConfiguration.AllRoles.Add('test');
        $d2 = ($p2 | select -ExpandProperty Value);
        $st = Invoke-AzureComputeMethod -MethodName DeploymentChangeConfigurationBySlot -ArgumentList $d2;

        # Invoke Hosted Service Delete
        $st = Invoke-AzureComputeMethod -MethodName 'HostedServiceDeleteAll' -ArgumentList $svcName;
        Assert-AreEqual $st.StatusCode 'OK';
        Assert-NotNull $st.RequestId;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $svcName;
    }
}

# Run Service Extension Set Cmdlet Tests
function Run-ServiceExtensionSetCmdletTests
{
    # Setup
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $svcName = 'pstest' + (Get-CloudServiceName);
    $userName = "pstestuser";
    $password = $PLACEHOLDER;
    $sPassword = ConvertTo-SecureString $password -AsPlainText -Force;
    $credential = New-Object System.Management.Automation.PSCredential ($userName, $sPassword);

    # Test
    New-AzureService -ServiceName $svcName -Location $location;

    try
    {
        # New-AzureDeployment (in Azure.psd1)
        $testMode = Get-ComputeTestMode;
        if ($testMode.ToLower() -ne 'playback')
        {
            $cspkg = '.\Resources\ServiceManagement\Files\OneWebOneWorker.cspkg';
        }
        else
        {
            $cspkg = "https://${storageName}.blob.azure.windows.net/blob/OneWebOneWorker.cspkg";
        }
        $cscfg = "$TestOutputRoot\Resources\ServiceManagement\Files\OneWebOneWorker.cscfg";

        # Staging 1st
        $st = New-AzureDeployment -ServiceName $svcName -Package $cspkg -Configuration $cscfg -Label $svcName -Slot Staging;
        $st = Set-AzureServiceRemoteDesktopExtension -ServiceName $svcName -Slot Staging -Credential $credential;
        $ex = Get-AzureServiceExtension -ServiceName $svcName -Slot Staging;
        $st = Move-AzureDeployment -ServiceName $svcName;
        $ex = Get-AzureServiceExtension -ServiceName $svcName -Slot Production;

        # Staging 2nd
        $st = New-AzureDeployment -ServiceName $svcName -Package $cspkg -Configuration $cscfg -Label $svcName -Slot Staging;
        $st = Set-AzureServiceRemoteDesktopExtension -ServiceName $svcName -Slot Staging -Credential $credential;
        $ex = Get-AzureServiceExtension -ServiceName $svcName -Slot Staging;
        $st = Move-AzureDeployment -ServiceName $svcName;
        $ex = Get-AzureServiceExtension -ServiceName $svcName -Slot Production;

        # Set Extensions
        $st = Set-AzureServiceRemoteDesktopExtension -ServiceName $svcName -Slot Production -Credential $credential;
        $st = Set-AzureServiceRemoteDesktopExtension -ServiceName $svcName -Slot Staging -Credential $credential;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $svcName;
    }
}

# Run Service Deployment Extension Cmdlet Tests
function Run-ServiceDeploymentExtensionCmdletTests
{
    # Setup
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $svcName = 'pstest' + (Get-CloudServiceName);
    $userName = "pstestuser";
    $password = $PLACEHOLDER;
    $sPassword = ConvertTo-SecureString $password -AsPlainText -Force;
    $credential = New-Object System.Management.Automation.PSCredential ($userName, $sPassword);

    # Test
    New-AzureService -ServiceName $svcName -Location $location;

    try
    {
        # New-AzureDeployment (in Azure.psd1)
        $testMode = Get-ComputeTestMode;
        if ($testMode.ToLower() -ne 'playback')
        {
            $cspkg = "$TestOutputRoot\Resources\ServiceManagement\Files\LongRoleName.Cloud.cspkg";
        }
        else
        {
            $cspkg = "https://${storageName}.blob.azure.windows.net/blob/LongRoleName.Cloud.cspkg";
        }
        $cscfg = "$TestOutputRoot\Resources\ServiceManagement\Files\LongRoleName.Cloud.cscfg";

        $webRoleNameWithSpaces = "WebRole1 With Spaces In Name";
        $workerRoleLongName = "Microsoft.Contoso.Department.ProjectCodeName.Worker";
        $rdpCfg1 = New-AzureServiceRemoteDesktopExtensionConfig -Credential $credential -Role $webRoleNameWithSpaces
        $rdpCfg2 = New-AzureServiceRemoteDesktopExtensionConfig -Credential $credential -Role $workerRoleLongName;
        $adCfg1 = New-AzureServiceADDomainExtensionConfig -Role $webRoleNameWithSpaces -WorkgroupName 'test1';
        $adCfg2 = New-AzureServiceADDomainExtensionConfig -Role $workerRoleLongName -WorkgroupName 'test2';
        $extProp1 = @{"extended1"="property1";"extended2"="property2"}

        $st = New-AzureDeployment -ServiceName $svcName -Package $cspkg -Configuration $cscfg -Label $svcName -Slot Production `
                                  -ExtensionConfiguration $rdpCfg1,$adCfg1 -ExtendedProperty $extProp1;
        $exts = Get-AzureServiceExtension -ServiceName $svcName -Slot Production;
        Assert-True { $exts.Count -eq 2 };

        $deployment = Get-AzureDeployment -ServiceName $svcName -Slot Production;
        Assert-AreEqual 2 $deployment.ExtendedProperty.Count;
        Assert-AreEqual "extended1" $deployment.ExtendedProperty[0].Name;
        Assert-AreEqual "property1" $deployment.ExtendedProperty[0].Value;
        Assert-AreEqual "extended2" $deployment.ExtendedProperty[1].Name;
        Assert-AreEqual "property2" $deployment.ExtendedProperty[1].Value;

        $st = New-AzureDeployment -ServiceName $svcName -Package $cspkg -Configuration $cscfg -Label $svcName -Slot Staging `
                                  -ExtensionConfiguration $rdpCfg2,$adCfg2;
        $exts = Get-AzureServiceExtension -ServiceName $svcName -Slot Staging;
        Assert-True { $exts.Count -eq 2 };

        $deployment = Get-AzureDeployment -ServiceName $svcName -Slot Staging;
        Assert-AreEqual 0 $deployment.ExtendedProperty.Count;

        $extProp2 = @{"extended1"="property2";"extended2"="property1"}
        $st = Set-AzureDeployment -Config -ServiceName $svcName -Configuration $cscfg -Slot Production `
                                  -ExtensionConfiguration $rdpCfg2 -ExtendedProperty $extProp2;
        $exts = Get-AzureServiceExtension -ServiceName $svcName -Slot Production;
        Assert-True { $exts.Count -eq 1 };

        $deployment = Get-AzureDeployment -ServiceName $svcName -Slot Production;
        Assert-AreEqual 2 $deployment.ExtendedProperty.Count;
        Assert-AreEqual "extended1" $deployment.ExtendedProperty[0].Name;
        Assert-AreEqual "property2" $deployment.ExtendedProperty[0].Value;
        Assert-AreEqual "extended2" $deployment.ExtendedProperty[1].Name;
        Assert-AreEqual "property1" $deployment.ExtendedProperty[1].Value;

        $st = Set-AzureDeployment -Config -ServiceName $svcName -Configuration $cscfg -Slot Staging `
                                  -ExtensionConfiguration $rdpCfg1,$adCfg1 -ExtendedProperty $extProp2;
        $exts = Get-AzureServiceExtension -ServiceName $svcName -Slot Staging;
        Assert-True { $exts.Count -eq 2 };

        $deployment = Get-AzureDeployment -ServiceName $svcName -Slot Staging;
        Assert-AreEqual 2 $deployment.ExtendedProperty.Count;
        Assert-AreEqual "extended1" $deployment.ExtendedProperty[0].Name;
        Assert-AreEqual "property2" $deployment.ExtendedProperty[0].Value;
        Assert-AreEqual "extended2" $deployment.ExtendedProperty[1].Name;
        Assert-AreEqual "property1" $deployment.ExtendedProperty[1].Value;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $svcName;
    }
}

# Run Data Collection Cmdlet Tests
function Run-EnableAndDisableDataCollectionTests
{
    $st = Enable-AzureDataCollection;

    $locations = Get-AzureLocation;
    foreach ($loc in $locations)
    {
        $svcName = getAssetName;
        $st = New-AzureService -ServiceName $svcName -Location $loc.Name;
        
        # Cleanup
        Cleanup-CloudService $svcName
    }

    $st = Disable-AzureDataCollection;
}

<#
.SYNOPSIS
Tests Move-AzureService
#>
function Test-MigrateAzureDeployment
{
    # Setup
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;

    $storageName = getAssetName;
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;
    Set-CurrentStorageAccountName $storageName;

    $vmName = "vm1";
    $svcName = Get-CloudServiceName;

    # Test
    New-AzureService -ServiceName $svcName -Location $location;
    New-AzureQuickVM -Windows -ImageName $imgName -Name $vmName -ServiceName $svcName -AdminUsername "pstestuser" -Password $PLACEHOLDER;
    Get-AzureVM -ServiceName $svcName -Name $vmName;

    Move-AzureService -Prepare -ServiceName $svcName -DeploymentName $svcName -CreateNewVirtualNetwork;
    $vm = Get-AzureVM -ServiceName $svcName -Name $vmName;
    Assert-AreEqual "Prepared" $vm.VM.MigrationState;

    try
    {
        Move-AzureService -Commit -ServiceName $svcName -DeploymentName $svcName -ErrorAction Stop;
    }
    catch
    {}
    $vm = Get-AzureVM -ServiceName $svcName -Name $vmName;
    Assert-AreEqual "CommitFailed" $vm.VM.MigrationState;

    # Cleanup failed because the service is being migrated.
    #Cleanup-CloudService $svcName
}

<#
.SYNOPSIS
Tests Move-AzureService with Abort
#>
function Test-MigrationAbortAzureDeployment
{
    # Setup
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;

    $storageName = getAssetName;
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;
    Set-CurrentStorageAccountName $storageName;

    $vmName = "vm1";
    $svcName = Get-CloudServiceName;

    # Test
    New-AzureService -ServiceName $svcName -Location $location;
    New-AzureQuickVM -Windows -ImageName $imgName -Name $vmName -ServiceName $svcName -AdminUsername "pstestuser" -Password $PLACEHOLDER -WaitForBoot;
    Get-AzureVM -ServiceName $svcName -Name $vmName;

    $result = Move-AzureService -Validate -ServiceName $svcName -DeploymentName $svcName -CreateNewVirtualNetwork;
    Assert-True {$result.Result.Contains("Validation Passed.")}
    $vm = Get-AzureVM -ServiceName $svcName -Name $vmName;

    Move-AzureService -Prepare -ServiceName $svcName -DeploymentName $svcName -CreateNewVirtualNetwork;
    $vm = Get-AzureVM -ServiceName $svcName -Name $vmName;
    Assert-AreEqual "Prepared" $vm.VM.MigrationState;

    Move-AzureService -Abort -ServiceName $svcName -DeploymentName $svcName;
    $vm = Get-AzureVM -ServiceName $svcName -Name $vmName;
    Assert-Null $vm.VM.MigrationState;

    # Cleanup
    Cleanup-CloudService $svcName;
}

<#
.SYNOPSIS
Tests Move-AzureService with Abort
#>
function Test-MigrationValidateAzureDeployment
{
    # Setup
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;

    $storageName = getAssetName;
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;
    Set-CurrentStorageAccountName $storageName;

    $vmName = "vm1";
    $svcName = Get-CloudServiceName;

    # Test
    New-AzureService -ServiceName $svcName -Location $location;
    New-AzureQuickVM -Windows -ImageName $imgName -Name $vmName -ServiceName $svcName -AdminUsername "pstestuser" -Password $PLACEHOLDER;
    Get-AzureVM -ServiceName $svcName -Name $vmName;

    $result = Move-AzureService -Validate -ServiceName $svcName -DeploymentName $svcName -CreateNewVirtualNetwork;
    Assert-True {$result.Result.Contains("Validation Failed.")}
    Assert-AreNotEqual 0 $result.ValidationMessages.Count;
}

<#
.SYNOPSIS
Tests Move-AzureVirtualNetwork with Prepare and Commit
#>
function Test-MigrateAzureVNet
{
    # Setup
    $TestOutputRoot = [System.AppDomain]::CurrentDomain.BaseDirectory;
    $location = Get-DefaultLocation
    $affName = "WestUsAffinityGroup";
    $vnetConfigPath = "$TestOutputRoot\Resources\ServiceManagement\Files\vnetconfig.netcfg";
    $vnetName = "NewVNet1";

    # Test

    Set-AzureVNetConfig -ConfigurationPath $vnetConfigPath;

    Get-AzureVNetSite;

    Move-AzureVirtualNetwork -Prepare -VirtualNetworkName $vnetName;

    Get-AzureVNetSite;

    Move-AzureVirtualNetwork -Commit -VirtualNetworkName $vnetName;

    Get-AzureVNetSite;

    # Cleanup
    Remove-AzureVNetConfig
}

<#
.SYNOPSIS
Tests Move-AzureVirtualNetwork with Prepare and Abort
#>
function Test-MigrationAbortAzureVNet
{
    # Setup
    $TestOutputRoot = [System.AppDomain]::CurrentDomain.BaseDirectory;
    $location = Get-DefaultLocation
    $affName = "WestUsAffinityGroup";
    $vnetConfigPath = "$TestOutputRoot\Resources\ServiceManagement\Files\vnetconfig.netcfg";
    $vnetName = "NewVNet1";

    # Test

    Set-AzureVNetConfig -ConfigurationPath $vnetConfigPath;
    Get-AzureVNetSite;

    $result = Move-AzureVirtualNetwork -Validate -VirtualNetworkName $vnetName;
    Assert-True {$result.Result.Contains("Validation Passed.")}
    Get-AzureVNetSite;

    Move-AzureVirtualNetwork -Prepare -VirtualNetworkName $vnetName;
    Get-AzureVNetSite;

    Move-AzureVirtualNetwork -Abort -VirtualNetworkName $vnetName;
    Get-AzureVNetSite;

    # Cleanup
    Remove-AzureVNetConfig
}

<#
.SYNOPSIS
Tests Move-AzureStorageAccount with Prepare and Commit
#>
function Test-MigrateAzureStorageAccount
{
    # Setup
    $location = "Central US";
    $storageName = getAssetName;
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;
    Get-AzureStorageAccount -StorageAccountName $storageName;

    # Test
    Move-AzureStorageAccount -Prepare -StorageAccountName $storageName;
    Get-AzureStorageAccount -StorageAccountName $storageName;

    Move-AzureStorageAccount -Commit -StorageAccountName $storageName;
    Assert-ThrowsContains { Get-AzureStorageAccount -StorageAccountName $storageName; } "ResourceNotFound";
}

<#
.SYNOPSIS
Tests Move-AzureStorageAccount with Prepare and Abort
#>
function Test-MigrationAbortAzureStorageAccount
{
    # Setup
    $location = "Central US";
    $storageName = getAssetName;
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;
    Get-AzureStorageAccount -StorageAccountName $storageName;

    # Test
    $result = Move-AzureStorageAccount -Validate -StorageAccountName $storageName;
    Assert-True {$result.Result.Contains("Validation Passed.")}
    Get-AzureStorageAccount -StorageAccountName $storageName;

    Move-AzureStorageAccount -Prepare -StorageAccountName $storageName;
    $result = Get-AzureStorageAccount -StorageAccountName $storageName;
    Assert-AreEqual "Prepared" $result.MigrationState;
    $resultOut = $result | Out-String;

    Move-AzureStorageAccount -Abort -StorageAccountName $storageName;
    $result = Get-AzureStorageAccount -StorageAccountName $storageName;
    Assert-Null $result.MigrationState;
    $resultOut = $result | Out-String;

    # Cleanup
    Remove-AzureStorageAccount -StorageAccountName $storageName;
}

<#
.SYNOPSIS
Tests Move-AzureNetworkSecurityGroup
#>
function Test-MigrationNetworkSecurityGroup
{
    # Setup
    $securityGroupName = getAssetName
    $location = Get-DefaultLocation
    New-AzureNetworkSecurityGroup -Name $securityGroupName -location $location

    # Validate move
    $status = Move-AzureNetworkSecurityGroup -NetworkSecurityGroupName $securityGroupName -Validate
    Assert-NotNull $status
    Assert-Null $status.ValidationMessages

    # Prepare move
    Move-AzureNetworkSecurityGroup -NetworkSecurityGroupName $securityGroupName -Prepare

    # Abort Move
    Move-AzureNetworkSecurityGroup -NetworkSecurityGroupName $securityGroupName -Abort

    # Remove
    $isDeleted = Remove-AzureNetworkSecurityGroup -Name $securityGroupName -Force -PassThru
}

<#
.SYNOPSIS
Tests Move-AzureRouteTable
#>
function Test-MigrationRouteTable
{
    # Setup
    $routeTableName = getAssetName
    $location = Get-DefaultLocation
    New-AzureRouteTable -Name $routeTableName -location $location

    # Validate move
    $status = Move-AzureRouteTable -RouteTableName $routeTableName -Validate
    Assert-NotNull $status
    Assert-Null $status.ValidationMessages

    # Prepare move
    Move-AzureRouteTable -RouteTableName $routeTableName -Prepare

    # Abort Move
    Move-AzureRouteTable -RouteTableName $routeTableName -Abort

    # Remove
    $isDeleted = Remove-AzureRouteTable -Name $routeTableName -Force -PassThru
}

<#
.SYNOPSIS
Tests Move-AzureReservedIP
#>
function Test-MigrationAzureReservedIP
{
    # Setup
    $name = getAssetName
    $location = Get-DefaultLocation

    # Test Create Reserved IP
    New-AzureReservedIP -ReservedIPName $name -Location $location
    $reservedIP = Get-AzureReservedIP -ReservedIPName $name

    # Assert
    Assert-NotNull($reservedIP)
    Assert-AreEqual $reservedIP.Location $location
    
    # Validate move
    $status = Move-AzureReservedIP -ReservedIPName $name -Validate
    Assert-NotNull $status
    Assert-Null $status.ValidationMessages

    # Prepare move
    Move-AzureReservedIP -ReservedIPName $name -Prepare

    # Abort Move
    Move-AzureReservedIP -ReservedIPName $name -Abort

    #Test Remove reserved IP
    $removeReservedIP = Remove-AzureReservedIP -ReservedIPName $name -Force
    Assert-AreEqual $removeReservedIP.OperationStatus "Succeeded"
}

<#
.SYNOPSIS
Tests New-AzureReservedIPWithTags
#>
function Test-AzureReservedIPWithIPTags
{
    # Setu
    $name = getAssetName
    $location = "West Central US"
    $iptag  = New-AzureIPTag -IPTagType "FirstPartyUsage" -Value "/tagTypes/SystemService/operators/Microsoft/platforms/Azure/services/Microsoft.AzureAD"
    # Test Create Reserved IP
    New-AzureReservedIP -ReservedIPName $name -Location $location -IPTagList $iptag
    $reservedIP = Get-AzureReservedIP -ReservedIPName $name 
    #-IPTags $iptag
    # Assert
    Assert-NotNull($reservedIP)
    Assert-AreEqual $reservedIP.Location $location
    Assert-NotNull($reservedIP.IPTags)
   
    #Test Remove reserved IP
    $removeReservedIP = Remove-AzureReservedIP -ReservedIPName $name -Force
    Assert-AreEqual $removeReservedIP.OperationStatus "Succeeded"
}

function Test-NewAzureVMWithBYOL
{
    # Setup
    $location = "Central US";
    $storageName = "mybyolosimagerdfe";

    $vm1Name = "vm1";
    $vm2Name = "vm2";
    $svcName = Get-CloudServiceName;

    $vmSize = "Small";
    $licenseType = "Windows_Server";
    $imgName = getAssetName;
    $userName = "User" + $svcName;
    $pass = $PLACEHOLDER;

    $media1 = "http://mybyolosimagerdfe.blob.core.windows.net/myvhd/" + $svcName + "0.vhd";
    $media2 = "http://mybyolosimagerdfe.blob.core.windows.net/myvhd/" + $svcName + "1.vhd";

    Set-CurrentStorageAccountName $storageName;

    Add-AzureVMImage -ImageName $imgName `
        -MediaLocation "https://mybyolosimagerdfe.blob.core.windows.net/vhdsrc/win2012-tag0.vhd" `
        -OS "Windows" `
        -Label "BYOL Image" `
        -RecommendedVMSize $vmSize `
        -IconUri "http://www.bing.com" `
        -SmallIconUri "http://www.bing.com" `
        -ShowInGui;

    # Test
    New-AzureService -ServiceName $svcName -Location $location;

    $vm1 = New-AzureVMConfig -Name $vm1Name -ImageName $imgName -InstanceSize $vmSize `
         -LicenseType $licenseType -HostCaching ReadWrite -MediaLocation $media1;

    $vm1 = Add-AzureProvisioningConfig -VM $vm1 -Windows -Password $pass -AdminUsername $userName;

    $vm2 = New-AzureVMConfig -Name $vm2Name -ImageName $imgName -InstanceSize $vmSize `
         -LicenseType $licenseType -HostCaching ReadWrite -MediaLocation $media2;

    $vm2 = Add-AzureProvisioningConfig -VM $vm2 -Windows -Password $pass -AdminUsername $userName;

    New-AzureVM -ServiceName $svcName -VMs $vm1,$vm2

    $vm1result = Get-AzureVM -ServiceName $svcName -Name $vm1Name;
    $vm2result = Get-AzureVM -ServiceName $svcName -Name $vm2Name;

    Update-AzureVM -ServiceName $svcName -Name $vm1Name -VM $vm1result.VM;

    $vm1result = Get-AzureVM -ServiceName $svcName -Name $vm1Name;
    $vm2result = Get-AzureVM -ServiceName $svcName -Name $vm2Name;

    # Cleanup
    Cleanup-CloudService $svcName
}

# Test Redeploy VM
function Run-RedeployVirtualMachineTest
{
    # Setup
    $location = Get-DefaultLocation;
    $imgName = Get-DefaultImage $location;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $vmName = "vm01";
    $svcName = 'pstest' + (Get-CloudServiceName);
    $userName = "pstestuser";
    $password = $PLACEHOLDER;

    # Test
    New-AzureService -ServiceName $svcName -Location $location;

    try
    {
        New-AzureQuickVM -Windows -ImageName $imgName -Name $vmName -ServiceName $svcName -AdminUsername $userName -Password $password;
        # Get VM
        $vm = Get-AzureVM -ServiceName $svcName -Name $vmName;

        # Test Redeploy
        $vm | Restart-AzureVM -Redeploy;

        $vm = Get-AzureVM -ServiceName $svcName -Name $vmName;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $svcName;
    }
}

# Test Initiate Maintenance VM
function Run-InitiateMaintenanceTest
{
    # Depending on the environment, the initiate maintenance operation may return 200
    # or 400 with error message like "User initiated maintenance on the virtual machine was
    # successfully completed". Both are expected reponses.
    # To continue script, $ErrorActionPreference should be set to 'SilentlyContinue'.
    $tempErrorActionPreference = $ErrorActionPreference;
    $ErrorActionPreference = 'SilentlyContinue';
    
    # Setup
    $location = "Central US EUAP";
    $imgName = Get-DefaultImage $location;

    $storageName = 'pstest' + (getAssetName);
    New-AzureStorageAccount -StorageAccountName $storageName -Location $location;

    # Associate the new storage account with the current subscription
    Set-CurrentStorageAccountName $storageName;

    $vmName = "psvm01";
    $svcName = 'pstest' + (Get-CloudServiceName);
    $userName = "pstestuser";
    $password = $PLACEHOLDER;

    # Test
    New-AzureService -ServiceName $svcName -Location $location;

    try
    {
        New-AzureQuickVM -Windows -ImageName $imgName -Name $vmName -ServiceName $svcName -AdminUsername $userName -Password $password;
        #Start-Sleep -s 300; #Uncomment this line for record mode testing.

        # Get VM
        $vm = Get-AzureVM -ServiceName $svcName -Name $vmName;
        Assert-NotNull $vm;
        Assert-NotNull $vm.MaintenanceStatus;

        # Test Initiate Maintenance
        $result = Restart-AzureVM -InitiateMaintenance -ServiceName $svcName -Name $vmName;

        $vm = Get-AzureVM -ServiceName $svcName -Name $vmName
        Assert-NotNull $vm.MaintenanceStatus; 
    }
    catch
    {
        Assert-True {$result.Result.Contains("User initiated maintenance on the Virtual Machine was successfully completed.")};
        $vm = Get-AzureVM -ServiceName $svcName -Name $vmName
        Assert-NotNull $vm.MaintenanceStatus;
    }
    finally
    {
        # Cleanup
        Cleanup-CloudService $srcName;
        $ErrorActionPreference = $tempErrorActionPreference;
    }
}
