<##
    .SYNOPSIS
    Script to create New Network Security Group and adding rules to it.

    .DESCRIPTION
    Script to create New Network Security Group and adding rules to it.

    .PARAMETER ClientID

    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzureUserName

    User name for Azure login. This should be an Organizational account (not Hotmail/Outlook account)

    .PARAMETER AzurePassword

    Password for Azure user account.

    .PARAMETER AzureSubscriptionID

    Azure Subscription ID to use for this activity.

    .PARAMETER ResourceGroupName

    Name of the Azure ARM resource group to use for this command.

    .PARAMETER Location

    Azure Location to use for creating/saving/accessing resources (should be a valid location. Refer to https://azure.microsoft.com/en-us/regions/ for more details.)

    .PARAMETER NSGGroupName

    Azure NSGGroup to be used for this command.

    .PARAMETER UpdateAction

    Update Action i.e Add, Remove and Update existing rule

    .PARAMETER RuleName

    Name of the NSG Rule to be used for this command. e.g Web-rule, DB-Rule etc.

    .PARAMETER SourceAddressPrefix

    Source Address Prefix to be used for this command. e.g 10.0.1.0/24,10.0.1.10/32

    .PARAMETER SourcePortRange

    Sorce Port range to be used for this command.e.g 3000-3300, 5200

    .PARAMETER DestinationAddressPrefix

    Destination Address Prefix to be used for this command. e.g 10.0.2.0/24,10.0.2.10/32

    .PARAMETER DestinationPortRange

    Destination Port range to be used for this command.e.g 3800-3900, 5700

    .PARAMETER RuleAction

    Access mechanism to be used for this command. e.g Allow, Deny

    .PARAMETER Protocol

    Name of the Protocol to be used for this command. e.g TCP, UDP

    .PARAMETER FlowDirection

    Direction of the traffic flow to be used for this command.e.g Inbound, Outbound

    .PARAMETER Priority

    Priority number to be used for this command.e.g Inbound, Outbound

    .INPUTS
    All parameter values in String format.

    .OUTPUTS
    String. Result of the command output.

    .NOTES
     Purpose of script: The script is to Update the NSG group
     Minimum requirements: PowerShell Version 1.2.1
     Initially written by: Bhaskar Desharaju
     Update/revision History:
     =======================
     Updated by    Date      Reason
     ==========    ====      ======

    .EXAMPLE
    C:\PS> .\Update-NSGGroup.ps1 -ClientID 12345 -AzureUserName bhaskar@netenrich.com -AzurePassword Password123 -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ResourceGroupName testgrp -Location 'East Asia' -NSGGroupName testnsggrp -UpdateAction Add -RuleName test1 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange * -RuleAction Allow -Protocol TCP -FlowDirection Inbound -Priority 100

    .EXAMPLE
    C:\PS> .\Update-NSGGroup.ps1 -ClientID 12345 -AzureUserName bhaskar@netenrich.com -AzurePassword Password123 -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ResourceGroupName testgrp -Location 'East Asia' -NSGGroupName testnsggrp -UpdateAction Update -RuleName test1 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange * -RuleAction deny -Protocol Upd -FlowDirection Outbound -Priority 200

    .EXAMPLE
    C:\PS> .\Update-NSGGroup.ps1 -ClientID 12345 -AzureUserName bhaskar@netenrich.com -AzurePassword Password123 -AzureSubscriptionID ca68598c-ecc3-4abc-b7a2-1ecef33f278d -ResourceGroupName testgrp -Location 'East Asia' -NSGGroupName testnsggrp -UpdateAction Remove -RuleName test1

    .LINK
    http://www.netenrich.com/
#>
[CmdletBinding()]
Param
(
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$ClientID,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzureUserName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzurePassword,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$AzureSubscriptionID,
	
	[Parameter(ValueFromPipelineByPropertyName)]
    [String]$ResourceGroupName,

	[Parameter(ValueFromPipelineByPropertyName)]
    [String]$Location,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$NSGGroupName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [String]$UpdateAction,
    
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$RuleName,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SourceAddressPrefix,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$SourcePortRange,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DestinationAddressPrefix,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DestinationPortRange,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$RuleAction,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$Protocol,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$FlowDirection,

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$Priority
)

Begin
{
    # Name the Log file based on script name
    [DateTime]$LogFileTime = Get-Date
    $FileTimeStamp = $LogFileTime.ToString("dd-MMM-yyyy_HHmmss")
    $LogFileName = "$ClientID-$($MyInvocation.MyCommand.Name.Replace('.ps1',''))-$FileTimeStamp.log"
    $LogFilePath = "C:\NEPortal\$LogFileName"

    $ScriptUploadConfig = $null
    Function Get-BlobURIForLogFile
    {
        Try
        {
            $UC = Select-Xml -Path "C:\NEPortal\NEPortalApp.Config" -XPath configuration/appSettings -ErrorAction SilentlyContinue | Select -ExpandProperty Node | Select -ExpandProperty add
            $UploadConfig = [ordered]@{}; $UC | % { $UploadConfig += @{ $_.key = $_.Value } }
            $Script:ScriptUploadConfig = [PSCustomObject]$UploadConfig

            $Container = $ScriptUploadConfig.Container
            $StorageAccName = $ScriptUploadConfig.StorageAccName
            $StorageAccKey = $ScriptUploadConfig.StorageAccKey

            ($context = New-AzureStorageContext -StorageAccountName $StorageAccName -StorageAccountKey $StorageAccKey -ErrorAction Stop) | Out-Null
        }
        Catch
        {
            Return "Error processing blob URI. Check if storage credentials are correct in 'C:\NEPortal\NEPortalApp.Config'"
        }
        Return "$($context.BlobEndPoint)$($ScriptUploadConfig.Container)/$($LogFilename)"
    }

    $LogFileBlobURI = Get-BlobURIForLogFile

    # ======================================================================
    # Write-Log function defination
    # ======================================================================
    Function Write-LogFile
    {
        Param([String]$FilePath, [String]$LogText, [Switch]$Overwrite = $false)

        [DateTime]$LogTime = Get-Date
        $TimeStamp = $LogTime.ToString("dd-MMM-yyyy hh:mm:ss tt")
        $InputLine = "[$TimeStamp] : $LogText"

        If($FilePath -like "*.???")
        { $CheckPath = Split-Path $FilePath; }
        Else
        { $CheckPath = $FilePath }

        If(Test-Path -Path $CheckPath -ErrorAction SilentlyContinue)
        {
            # Correct path Now check if it is a File or Folder
            ($IsFolder = (Get-Item $FilePath -ErrorAction SilentlyContinue) -is [System.IO.DirectoryInfo]) | Out-Null
            If($IsFolder)
            {
                If($FilePath.EndsWith("\")) { $FilePath = $FilePath.TrimEnd(1) }
                $FilePath = "$FilePath\Log_$($LogTime.ToString('dd-MMM-yyyy_hh.mm.ss')).log"
            }
        }
        Else
        {
            Try
            {
                If(-not($FilePath -like "*.???"))
                {
                    If($FilePath.EndsWith("\")) { $FilePath = $FilePath.TrimEnd(1) }
                    $FilePath = "$FilePath\Log_$($LogTime.ToString('dd-MMM-yyyy_HH.mm.ss')).log"
                    (New-Item -Path $FilePath -ItemType File -Force -ErrorAction Stop) | Out-Null
                }
                Else
                {
                    (New-Item -Path $CheckPath -ItemType Directory -Force -ErrorAction Stop) | Out-Null
                }
            }
            Catch
            { 
                "Error creating output folder for Log file $(Split-Path $FilePath).`n$($Error[0].Exception.Message)"
            }
        }

        If($Overwrite)
        {
            $InputLine | Out-File -FilePath $FilePath -Force
        }
        Else
        {
            $InputLine | Out-File -FilePath $FilePath -Force -Append
        }
    }

    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script Execution started: $($MyInvocation.MyCommand.Name). For Client ID: $ClientID ]####" -Overwrite

    # Check minumum required version of Azure PowerShell
    $AzurePSVersion = (Get-Module -ListAvailable -Name Azure -ErrorAction Stop).Version
    If($AzurePSVersion -ge $ScriptUploadConfig.RequiredPSVersion)
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Required version of Azure PowerShell is available."
    }
    Else 
    {
       $ObjOut = "Required version of Azure PowerShell not available. Stopping execution.`nDownload and install required version from: http://aka.ms/webpi-azps.`
        `r`nRequired version of Azure PowerShell is $($ScriptUploadConfig.RequiredPSVersion). Current version on host machine is $($AzurePSVersion.ToString())."
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Write-Output $output
        Exit
    }

   Function Check-PortInput
    {
        Param
        (
           [String]$SPort,[String]$Name
        )

        Try
        {
            if($SPort -eq '*')
            {
            }
            elseif($SPort -match '^\d{1,5}$')
            {
                $SPort = [Int32]$SPort
                if($SPort -notin (0..65535))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. $Name $SPort parameter value is Invalid.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. $Name $SPort parameter value is Invalid."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            elseif($SPort -match '^\d{1,5}\-\d{1,5}$')
            {
                $SPorts = $SPort.Split("-")
                $SPort1 = [Int32]$SPorts[0]
                $SPort2 = [Int32]$SPorts[1]
                if(($SPort1 -notin (0..65535)) -or ($SPort2 -notin (0..65535)))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. One of the $Name range value $SPort1 $SPort2 is invalid.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. One of the $Name range value $SPort1 $SPort2 is invalid."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                elseif($SPort2 -lt $SPort1)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. $Name range $SPort is invalid.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. $Name range $SPort is invalid."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }else{}
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The provided port range is invalid.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. The provided $Name range is invalid."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. $Name parameter value is not valid.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Validation failed. $Name parameter value is not valid."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }

    Function Check-AddressPrefixInput
    {
        Param
        (
            [string]$Saddress,[string]$Name
        )

        Try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Validating if SourceAddressPrefix is valid input. Only ERRORs will be logged."
            if(($Saddress -notin ('*','Internet','AzureLoadBalancer','VirtualNetwork')))
            {
                if($Saddress -match '^(\d{1,3}\.){3}\d{1,3}$|^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$')
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validating if $Name is valid IP Address. Only ERRORs will be logged."
                    $checkIP = $Saddress.Split("/")[0]
                    If([bool]($checkIP -as [ipaddress])) { <# Valid IP address #>}
                    Else
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. $Name '$Saddress' is NOT a valid IP address.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. $Name '$Saddress' is NOT a valid IP address."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. $Name '$Saddress' is NOT a valid input.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. $Name '$Saddress' is NOT a valid input."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. $Name '$Saddress' is NOT a valid input.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. $Name '$Saddress' is NOT a valid input."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
        catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. $Name '$Saddress' is NOT a valid input.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Validation failed. $Name '$Saddress' is NOT a valid input."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }

    Function Validate-AllParameters
    {
        Try
        {
            # Validate parameter: ClientID
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ClientID. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ClientID))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ClientID parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ClientID parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzureUserName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzureUserName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzureUserName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzureUserName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzureUserName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzurePassword
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzurePassword. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzurePassword))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzurePassword parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzurePassword parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: AzureSubscriptionID
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: AzureSubscriptionID. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($AzureSubscriptionID))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. AzureSubscriptionID parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. AzureSubscriptionID parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: ResourceGroupName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: ResourceGroupName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($ResourceGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. ResourceGroupName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. ResourceGroupName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: NSGGroupName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: NSGGroupName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($NSGGroupName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. NSGGroupName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. NSGGroupName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }

            # Validate parameter: UpdateAction
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: UpdateAction. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($UpdateAction))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. UpdateAction parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. UpdateAction parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            Else
            {
                if($UpdateAction -notin ('Add','Remove','Update'))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid UpdateAction was provided for flow direction $UpdateAction parameter.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Invalid UpdateAction was provided for flow direction $UpdateAction parameter."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }                
            }

			# Validate parameter: RuleName
            Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RuleName. Only ERRORs will be logged."
            If([String]::IsNullOrEmpty($RuleName))
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RuleName parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                $ObjOut = "Validation failed. RuleName parameter value is empty."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
            if($RuleName.Contains(","))
            {
                $Script:RuleNames = @()
                $Script:RuleNames = $RuleName.Split(",")

                $UniueRuleNames = $RuleNames | Select -Unique
                $RuleRes = Compare-Object -ReferenceObject $UniueRuleNames -DifferenceObject $RuleNames
                if($RuleRes -ne $null)
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Duplicate Rule names have been provided.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Duplicate Rule names have been provided."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            
            if($UpdateAction -in ('Add','Update'))
            {
                # Validate parameter: FlowDirection
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: FlowDirection. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($FlowDirection))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. FlowDirection parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. FlowDirection parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($FlowDirection.Contains(","))
                {
                    $Script:FlowDirections = @()
                    $Script:FlowDirections = $FlowDirection.Split(",")

                    foreach($Flow in $FlowDirections)
                    {
                        if($Flow -notin ('Inbound','Outbound'))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid Direction was provided for flow direction $Flow parameter.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. Invalid Direction was provided for flow direction $Flow parameter."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    if($FlowDirection -notin ('Inbound','Outbound'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid Direction was provided for flow direction $FlowDirection parameter.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. Invalid Direction was provided for flow direction $FlowDirection parameter."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: Priority
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Priority. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($Priority))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Priority parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Priority parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($Priority.Contains(","))
                {
                    $Script:Priorities = @()
                    $Script:Priorities = $Priority.Split(",")
                    $UniquePri = $Priorities | Select -Unique
                    $Res = Compare-Object -ReferenceObject $UniquePri -DifferenceObject $Priorities
                    if($Res -ne $null)
                    {
                        $PriIndex=0
                        while($PriIndex -lt $Priorities.length)
                        {   
                            $CurrNumber=$Priorities[$PriIndex]
                            for($i=0;$i -lt $Priorities.length;$i++)
                            {          
                                if(($CurrNumber -eq $Priorities[$i]) -and ($i -gt $PriIndex))
                                {
                                    if($FlowDirections[$PriIndex] -eq $FlowDirections[$i])
                                    {
                                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Conflict rules. No two rules will have same Priority and same Flow Direction.`r`n<#BlobFileReadyForUpload#>"
                                        $ObjOut = "Validation failed. Conflict rules provided. No two rules will have same Priority and same Flow Direction."
                                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                                        Write-Output $output
                                        Exit
                                    }
                                    break;
                                }
                            }   
                            $PriIndex++;
                        }
                    }

                    foreach($prior in $Priorities)
                    {
                        $Pri = [Int32]$prior
                        if($Pri -notin (100..4096))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The value of priority $prior is not valid.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. The value of priority $prior is not valid."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    $Pri = [Int32]$Priority
                    if($Pri -notin (100..4096))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. The value of priority $Priority is not valid.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. The value of priority $Priority is not valid."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: SourceAddressPrefix
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SourceAddressPrefix. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($SourceAddressPrefix))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SourceAddressPrefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. SourceAddressPrefix parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($SourceAddressPrefix.Contains(","))
                {
                    $Script:SourceAddressPrefixes = @()
                    $Script:SourceAddressPrefixes = $SourceAddressPrefix.Split(",")

                    foreach($Saddress in $SourceAddressPrefixes)
                    {
                        Check-AddressPrefixInput -Saddress $Saddress                              
                    }                
                }
                else
                {
                    Check-AddressPrefixInput -Saddress $SourceAddressPrefix
                }    

                # Validate parameter: SourcePortRange
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: SourcePortRange. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($SourcePortRange))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. SourcePortRange parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. SourcePortRange parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($SourcePortRange.Contains(","))
                {
                    $Script:SourcePortRanges = @()
                    $Script:SourcePortRanges = $SourcePortRange.Split(",")
                    foreach($SPort in  $Script:SourcePortRanges)
                    {
                        Check-PortInput -SPort $SPort
                    }
                }
                else
                {
                    Check-PortInput -SPort $SourcePortRange
                }

                # Validate parameter: DestinationAddressPrefix
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DestinationAddressPrefix. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($DestinationAddressPrefix))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DestinationAddressPrefix parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. DestinationAddressPrefix parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($DestinationAddressPrefix.Contains(","))
                {
                    $Script:DestinationAddressPrefixs = @()
                    $Script:DestinationAddressPrefixs = $DestinationAddressPrefix.Split(",")

                    foreach($Daddress in $Script:DestinationAddressPrefixs)
                    {
                        Check-AddressPrefixInput -Saddress $Daddress                         
                    }                
                }
                else
                {
                    Check-AddressPrefixInput -Saddress $DestinationAddressPrefix
                }

                # Validate parameter: DestinationPortRange
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: DestinationPortRange. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($DestinationPortRange))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. DestinationPortRange parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. DestinationPortRange parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($DestinationPortRange.Contains(","))
                {
                    $Script:DestinationPortRanges = @()
                    $Script:DestinationPortRanges = $DestinationPortRange.Split(",")
                    foreach($DPort in $DestinationPortRanges)
                    {
                        Check-PortInput -SPort $DPort
                    }
                }
                else
                {
                    Check-PortInput -SPort $DestinationPortRange
                }

                # Validate parameter: RuleAction
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: RuleAction. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($RuleAction))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. RuleAction parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. RuleAction parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                if($RuleAction.Contains(","))
                {
                    $Script:RuleActions = @()
                    $Script:RuleActions = $RuleAction.Split(",")

                    foreach($Rule in $Script:RuleActions)
                    {
                        if($Rule -notin ('Allow','Deny'))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid action was provided for RuleAction $RuleAction parameter.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. Invalid action was provided for RuleAction $RuleAction parameter."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    if($RuleAction -notin ('Allow','Deny'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid action was provided for RuleAction $RuleAction parameter.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. Invalid action was provided for RuleAction $RuleAction parameter."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }

                # Validate parameter: Protocol
                Write-LogFile -FilePath $LogFilePath -LogText "Validating Parameters: Protocol. Only ERRORs will be logged."
                If([String]::IsNullOrEmpty($Protocol))
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Protocol parameter value is empty.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Protocol parameter value is empty."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
                If($Protocol.Contains(","))
                {
                    $Script:Protocols = @()
                    $Script:Protocols = $Protocol.Split(",")

                    foreach($Pro in $Script:Protocols)
                    {
                        if($Pro -notin ('Tcp','Udp','*'))
                        {
                            Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid action was provided for RuleAction $RuleAction parameter.`r`n<#BlobFileReadyForUpload#>"
                            $ObjOut = "Validation failed. Invalid action was provided for RuleAction $RuleAction parameter."
                            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                            Write-Output $output
                            Exit
                        }
                    }
                }
                else
                {
                    if($Protocol -notin ('Tcp','Udp','*'))
                    {
                        Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Invalid Protocol was provided for Protocol $Protocol parameter.`r`n<#BlobFileReadyForUpload#>"
                        $ObjOut = "Validation failed. Invalid Protocol was provided for Protocol $Protocol parameter."
                        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                        Write-Output $output
                        Exit
                    }
                }
            }

            $Script:ParamCount = $RuleNames.Count
            if($Script:RuleNames.Count -eq 0)
            {
            }
            Elseif($Script:RuleNames.Count -ge 1)
            {
                if(($($Script:RuleNames.Count) -gt 1) -and ($Script:Priorities.Count -eq $Script:ParamCount) -and ($Script:FlowDirections.Count -eq $Script:ParamCount) -and ( $Script:RuleActions.Count -eq $Script:ParamCount) -and ($Script:SourceAddressPrefixes.Count -eq $Script:ParamCount) -and ($Script:SourcePortRanges.Count -eq $Script:ParamCount) -and ($Script:DestinationAddressPrefixs.Count -eq $Script:ParamCount) -and ($Script:DestinationPortRanges.Count -eq $Script:ParamCount) -and ($Script:Protocols.Count -eq $Script:ParamCount))
                {}
                else
                {
                    Write-LogFile -FilePath $LogFilePath -LogText "Validation failed. Multiple rules have been provided with less number of parameters.`r`n<#BlobFileReadyForUpload#>"
                    $ObjOut = "Validation failed. Multiple rules have been provided with less number of parameters."
                    $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                    Write-Output $output
                    Exit
                }
            }
            else {
                
            }
        }
        Catch
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Error while validating parameters: $($Error[0].Exception.Message)`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Error while validating parameters: $($Error[0].Exception.Message)"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }

    Function Login-ToAzureAccount
    {
        Try
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Attempting to login to Azure RM subscription" 
            $SecurePassword = ConvertTo-SecureString -AsPlainText $AzurePassword -Force
            $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $AzureUserName, $securePassword
            (Login-AzureRmAccount -Credential $Cred -SubscriptionId $AzureSubscriptionID -ErrorAction Stop) | Out-Null
            Write-LogFile -FilePath $LogFilePath -LogText "Login to Azure RM successful"
        }
        Catch
        {
            $ObjOut = "Error logging in to Azure Account.`n$($Error[0].Exception.Message)"
            Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
}
Process
{
    # 1.  Validating all Parameters
    Validate-AllParameters

    # 2. Login to Azure RM Account

    Login-ToAzureAccount

    # 3. Registering Azure Provider Namespaces
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Registering the Azure resource providers." 

        # Required Provider name spaces as of now
        $ReqNameSpces = @("Microsoft.Compute","Microsoft.Storage","Microsoft.Network")
        foreach($NameSpace in $ReqNameSpces)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Registering the provider $NameSpace" 
            ($Status = Register-AzureRmResourceProvider -ProviderNamespace $NameSpace -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
            If($Status)
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Verifying the provider $NameSpace Registration."
                ($state = Get-AzureRmResourceProvider -ProviderNamespace $NameSpace -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                while($state.RegistrationState -ne 'Registered')
                {
                    ($state = Get-AzureRmResourceProvider -ProviderNamespace $NameSpace -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null 
                }
                Write-LogFile -FilePath $LogFilePath -LogText "Registering the provider $NameSpace is successful." 
            }
            else
            {
                Write-LogFile -FilePath $LogFilePath -LogText "Registering the provider $NameSpace was not successful.`r`n<#BlobFileReadyForUpload#>" 
                $ObjOut = "Registering the provider $NameSpace was not successful."
                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                Write-Output $output
                Exit
            }
        }
    }
    catch
    {
        $ObjOut = "Error while registering the Resource provide namespace.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 4. Checking for the reosurce group existence
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Checking existance of resource group '$ResourceGroupName'"
        $ResourceGroup = $null
        ($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        If($ResourceGroup -ne $null) # Resource Group already exists
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Resource Group already exists"
        }
        Else 
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The resource group $ResourceGroupName does not exist.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "The resource group $ResourceGroupName does not exist."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while getting Azure Resource Group details.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 5. Checking for NSG Group Existence, if NSG available exit, else go ahead
    Try
    {
        # Variable declaration
        $Groups = $null
        Write-LogFile -FilePath $LogFilePath -LogText "Verifying the NSG existence in the resource group."

        ($Groups = Get-AzureRmNetworkSecurityGroup -Name $NSGGroupName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
        if($Groups -ne $null)
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The network security group is already exist."
            ($NSGRules =  Get-AzureRmNetworkSecurityRuleConfig -Name $RuleName -NetworkSecurityGroup $Groups -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null

            Switch ($UpdateAction)
            {
                                                'Add' {
                                                            if($NSGRules -ne $null)
                                                            {
                                                                Write-LogFile -FilePath $LogFilePath -LogText "The Network Security Group Rule $RuleName is already exist.`r`n<#BlobFileReadyForUpload#>"
                                                                $ObjOut = "The Network Security Group Rule $RuleName is already exist"
                                                                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                                                                Write-Output $output
                                                                Exit
                                                            }
                                                            Break
                                                        }
                ($UpdateAction -in ('Update','Remove')) {
                                                            if($NSGRules -eq $null)
                                                            {
                                                                Write-LogFile -FilePath $LogFilePath -LogText "The network security resource group rule $NSGGroupName does not exist.`r`n<#BlobFileReadyForUpload#>"
                                                                $ObjOut = "The network security resource group rule $NSGGroupName does not exist."
                                                                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                                                                Write-Output $output
                                                                Exit
                                                            }
                                                            break
                                                        }
            }

        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The network security resource group $NSGGroupName does not exist.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "The network security resource group $NSGGroupName does not exist."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    catch
    {
        $ObjOut = "Error while checking and creating Network Security Group.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }

    # 6. Adding or Updating or Removing the rules in NSG Group. 
    Try
    {
        Write-LogFile -FilePath $LogFilePath -LogText "Updating the NSG Group $NSGGroupName with details provided."
        
        Switch ($UpdateAction)
        {
              'Add' {
                            Write-LogFile -FilePath $LogFilePath -LogText "Adding the Network Security Group rules to the $NSGGroupName group."
                            if($Script:ParamCount -gt 1)
                            {
                                for($i=0;$i -lt $Script:ParamCount;$i++)
                                {
                                    ($AddStatus = Add-AzureRmNetworkSecurityRuleConfig -Name ($Script:RuleNames[$i]) -NetworkSecurityGroup $Groups -Protocol ($Script:Protocols[$i]) -SourceAddressPrefix ($Script:SourceAddressPrefixes[$i]) -SourcePortRange ($Script:SourcePortRanges[$i]) -DestinationAddressPrefix ($Script:DestinationAddressPrefixs[$i]) -DestinationPortRange ($Script:DestinationPortRanges[$i]) -Access ($Script:RuleActions[$i]) -Priority ($Script:Priorities[$i]) -Direction ($Script:FlowDirections[$i]) -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                                }
                            }
                            Else
                            {
                                ($AddStatus = Add-AzureRmNetworkSecurityRuleConfig -Name $RuleName -NetworkSecurityGroup $Groups -Protocol $Protocol -SourceAddressPrefix $SourceAddressPrefix -SourcePortRange $SourcePortRange -DestinationAddressPrefix $DestinationAddressPrefix -DestinationPortRange $DestinationPortRange -Access $RuleAction -Priority $Priority -Direction $FlowDirection -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
                            }

                            if($AddStatus.ProvisioningState -eq 'Succeeded')
                            {
                                Write-LogFile -FilePath $LogFilePath -LogText "NSG Rule $RuleName has been added to NSG $NSGGroupName configuration."
                            }
                            Else
                            {
                                Write-LogFile -FilePath $LogFilePath -LogText "Unable to add the NSG rule $RuleName to the NSG $NSGGroupName configuration.`r`n<#BlobFileReadyForUpload#>"
                                $ObjOut = "Unable to add the NSG rule $RuleName to the NSG $NSGGroupName configuration."
                                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                                Write-Output $output
                                Exit
                            }
                            Break
                     }
            'Update' {
                           Write-LogFile -FilePath $LogFilePath -LogText "Updating the Network Security Group rules $RuleName to the NSG $NSGGroupName Configuration."
                           ($UpdateStatus = Set-AzureRmNetworkSecurityRuleConfig -Name $($NSGRules.Name) -NetworkSecurityGroup $Groups -Protocol $Protocol -SourcePortRange $SourcePortRange -DestinationPortRange $DestinationPortRange -SourceAddressPrefix $SourceAddressPrefix -DestinationAddressPrefix $DestinationAddressPrefix -Access $RuleAction -Priority $Priority -Direction $FlowDirection -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                           if($UpdateStatus.ProvisioningState -eq 'Succeeded')
                           {
                                Write-LogFile -FilePath $LogFilePath -LogText "Updating the Network Security Group rules $RuleName to the NSG $NSGGroupName Configuration."
                           }
                           Else
                           {
                                Write-LogFile -FilePath $LogFilePath -LogText "Unable to update the NSG Rule $RuleName for NSG $NSGGroupName configuration.`r`n<#BlobFileReadyForUpload#>"
                                $ObjOut = "Unable to update the NSG Rule $RuleName for NSG $NSGGroupName."
                                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                                Write-Output $output
                                Exit
                           }
                           Break
                     }
            'Remove' {
                          Write-LogFile -FilePath $LogFilePath -LogText "Removing the existing NSG Rule $RuleName from $NSGGroupName."
                          ($RemoveStatus = Remove-AzureRmNetworkSecurityRuleConfig -Name $RuleName -NetworkSecurityGroup $Groups -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) | Out-Null
                          if($RemoveStatus.ProvisioningState -eq 'Succeeded')
                          {
                                Write-LogFile -FilePath $LogFilePath -LogText "NSG Rule $RuleName has been removed from the NSG $NSGGroupName configuration."
                          }
                          Else
                          {
                                Write-LogFile -FilePath $LogFilePath -LogText "Unable to remove $RuleName from the NSG $NSGGroupName configuration.`r`n<#BlobFileReadyForUpload#>"
                                $ObjOut = "Unable to remove $RuleName from the NSG $NSGGroupName configuration."
                                $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
                                Write-Output $output
                                Exit
                          }
                          Break
                     }
        }

        Write-LogFile -FilePath $LogFilePath -LogText "Setting the Rule $RuleName changes to NSg Group $NSGGroupName"

        ($NsgRuleStatus = Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $CreatedNSG -ErrorAction Stop -WarningAction SilentlyContinue) | Out-Null
        if($NsgRuleStatus.ProvisioningState -eq 'Succeeded')
        {
            Write-LogFile -FilePath $LogFilePath -LogText "The NSG $NSGRules has been updated successfully.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "The NSG $NSGRules has been updated successfully."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Success"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
        }
        else
        {
            Write-LogFile -FilePath $LogFilePath -LogText "Unable to update the NSG group $NSGGroupName.`r`n<#BlobFileReadyForUpload#>"
            $ObjOut = "Unable to update the NSG group $NSGGroupName."
            $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
            Write-Output $output
            Exit
        }
    }
    Catch
    {
        $ObjOut = "Error while updating the network security rules.$($Error[0].Exception.Message)"
        $output = (@{"Response" = [Array]$ObjOut; Status = "Failed"; BlobURI = $LogFileBlobURI} | ConvertTo-Json).ToString().Replace('\u0027',"'")
        Write-Output $output
        Write-LogFile -FilePath $LogFilePath -LogText "$ObjOut`r`n<#BlobFileReadyForUpload#>"
        Exit
    }
}
End
{
    Write-LogFile -FilePath $LogFilePath -LogText "####[ Script execution completed cuccessfully: $($MyInvocation.MyCommand.Name) ]####`r`n<#BlobFileReadyForUpload#>"
}
