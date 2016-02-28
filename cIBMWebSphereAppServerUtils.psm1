##############################################################################################################
########                               IBM WebSphere App Server CmdLets                              #########
##############################################################################################################

enum WASEdition {
    Base
    ND
    Express
    Developer
    Liberty
}

enum StartupType {
    Automatic
    Manual
    Disabled
}

# Global Variables / Resource Configuration
$IBM_REGPATH = "HKLM:\Software\IBM\"
$IBM_REGPATH_64 = "HKLM:\Software\Wow6432Node\IBM\"
$IBM_REGPATH_USER = "HKCU:\Software\IBM\"
$IBM_REGPATH_USER_64 = "HKCU:\Software\Wow6432Node\IBM\"

##############################################################################################################
# Get-IBMWebSphereProductRegistryPath
#   Returns the registry path for the IBM WebSphere Product specified
##############################################################################################################
Function Get-IBMWebSphereProductRegistryPath() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$true,position=0)]
        [String]
        $ProductName,

        [parameter(Mandatory=$false,position=1)]
        [System.Version]
        $Version
    )

    Write-Verbose "Get-IBMWebSphereProductRegistryPath::ENTRY(ProductName=$ProductName,Version=$Version)"

    $ibmProductPath = $null
    if ([IntPtr]::Size -eq 8) {
        $ibmProductPath = ($IBM_REGPATH_64 + $ProductName)
        if (!(Test-Path($ibmProductPath))) {
            $ibmProductPath = ($IBM_REGPATH_USER_64 + $ProductName)
            if (!(Test-Path($ibmProductPath))) {
                $ibmProductPath = ($IBM_REGPATH + $ProductName)
                if (!(Test-Path($ibmProductPath))) {
                    $ibmProductPath = ($IBM_REGPATH_USER + $ProductName)
                    if (!(Test-Path($ibmProductPath))) {
                        $ibmProductPath = $null
                    }
                }
            }
        }
    } else {
        $ibmProductPath = ($IBM_REGPATH + $ProductName)
        if (!(Test-Path($ibmProductPath))) {
            $ibmProductPath = ($IBM_REGPATH_USER + $ProductName)
            if (!(Test-Path($ibmProductPath))) {
                $ibmProductPath = $null
            }
        }
    }

    if (!$ibmProductPath) {
        try {
            New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
            $LoggedOnSids = (Get-ChildItem HKU: | where { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' }).PSChildName
            foreach ($sid in $LoggedOnSids) {
                if ([IntPtr]::Size -eq 8) {
                    $ibmProductPath = ("HKU:\$sid\Software\Wow6432Node\IBM\" + $ProductName)
                    if (!(Test-Path($ibmProductPath))) {
                        $ibmProductPath = ("HKU:\$sid\Software\IBM\" + $ProductName)
                        if (!(Test-Path($ibmProductPath))) {
                            $ibmProductPath = $null
                        } else {
                            Write-Warning "IBM Product Found under a different user"
                            break
                        }
                    } else {
                        Write-Warning "IBM Product Found under a different user"
                        break
                    }
                } else {
                    $ibmProductPath = ("HKU:\$sid\Software\IBM\" + $ProductName)
                    if (!(Test-Path($ibmProductPath))) {
                        $ibmProductPath = $null
                    } else {
                        Write-Warning "IBM Product Found under a different user"
                        break
                    }
                }
            }
        } catch { 
            Write-Warning -Message $_.Exception.Message 
        }
    }

    Write-Verbose "Get-IBMWebSphereProductRegistryPath returning path: $ibmProductPath"

    if ($ibmProductPath -and $Version) {
        $versionNotFound = $false
        $ibmProductVersionPath = Join-Path -Path $ibmProductPath -ChildPath $Version
        if (!(Test-Path($ibmProductVersionPath))) {
            $ibmProductVersionPath = Join-Path -Path $ibmProductPath -ChildPath ($Version.ToString(3) + ".0")
            if (!(Test-Path($ibmProductVersionPath))) {
                $ibmProductVersionPath = Join-Path -Path $ibmProductPath -ChildPath ($Version.ToString(2) + ".0.0")
                if (!(Test-Path($ibmProductVersionPath))) {
                    $ibmProductVersionPath = $null
                    $versionNotFound = $true
                }
            }
        }
        Write-Verbose "Get-IBMWebSphereProductRegistryPath returning version path: $ibmProductVersionPath"
        if (!($versionNotFound)) {
            $ibmProductPath = $ibmProductVersionPath
        }
    }
    
    Write-Verbose "Get-IBMWebSphereProductRegistryPath returning path: $ibmProductPath"
    
    Return $ibmProductPath
}

##############################################################################################################
# Get-IBMWebSphereAppServerRegistryPath
#   Returns the registry path for IBM WebSphere Application Server based on the edition specified
##############################################################################################################
Function Get-IBMWebSphereAppServerRegistryPath() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$false,position=0)]
        [WASEdition]
        $WASEdition = [WASEdition]::Base,

        [parameter(Mandatory=$false,position=1)]
        [System.Version]
        $Version = "8.5.0.0"
    )

    Write-Verbose "Get-IBMWebSphereAppServerRegistryPath::ENTRY(WASEdition=$WASEdition,Version=$Version)"
    
    $wasProductName = $null
    switch ($WASEdition) {
        "Base"      { $wasProductName = "WebSphere Application Server"; continue }
        "ND"        { $wasProductName = "WebSphere Application Server Network Deployment"; continue }
        "Express"   { $wasProductName = "WebSphere Application Server Express"; continue }
        "Developer" { $wasProductName = "WebSphere Application Server"; continue }
        "Liberty"   { $wasProductName = "WebSphere Application Server Liberty Profile"; continue }
    }

    $wasPath = Get-IBMWebSphereProductRegistryPath $wasProductName $Version
    
    Write-Verbose "Get-IBMWebSphereAppServerRegistryPath returning path: $wasPath"
    
    Return $wasPath
}

##############################################################################################################
# Get-IBMWebSphereAppServerInstallLocation
#   Returns the location where IBM WebSphere Application Server is installed
##############################################################################################################
Function Get-IBMWebSphereAppServerInstallLocation() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$false,position=0)]
        [WASEdition]
        $WASEdition = [WASEdition]::Base,

        [parameter(Mandatory=$false,position=1)]
        [System.Version]
        $Version = "8.5.0.0"
    )

    Write-Verbose "Get-IBMWebSphereAppServerInstallLocation::ENTRY(WASEdition=$WASEdition,Version=$Version)"
    
    $wasPath = Get-IBMWebSphereAppServerRegistryPath -WASEdition $WASEdition -Version $Version
    if ($wasPath -and $wasPath.StartsWith("HKU:")) {
        New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
    }
    
    if (($wasPath) -and (Test-Path($wasPath))) {
        $wasHome = (Get-ItemProperty($wasPath)).InstallLocation
        if ($wasHome -and (Test-Path $wasHome)) {
            Write-Verbose "Get-IBMWebSphereAppServerInstallLocation returning $wasHome"
            Return $wasHome
        }
    }
    Return $null
}

##############################################################################################################
# Get-IBMWebSphereProductVersionInfo
#   Returns a hashtable containing version information of the IBM Products installed in the specified product
#   directory
##############################################################################################################
Function Get-IBMWebSphereProductVersionInfo() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$true,position=0)]
        [string]
        $ProductDirectory
    )

    Write-Verbose "Get-IBMWebSphereProductVersionInfo::ENTRY(ProductDirectory=$ProductDirectory)"
    
    #Validate Parameters
    [string] $versionInfoBat = Join-Path -Path $ProductDirectory -ChildPath "bin\versionInfo.bat"
    if (!(Test-Path($versionInfoBat))) {
        Write-Error "Invalid Product Directory: $ProductDirectory versionInfo.bat not found"
        Return $null
    }
        
    [hashtable] $VersionInfo = @{}
    $versionInfoProcess = Invoke-ProcessHelper -ProcessFileName $versionInfoBat
    
    if ($versionInfoProcess -and ($versionInfoProcess.ExitCode -eq 0)) {
        $output = $versionInfoProcess.StdOut
        if ($output) {
            # Parse installation info
            $matchFound = $output -match "\nInstallation\s+\n\-+\s\n((.|\n)*?)Product\sList"
            if ($matchFound -and $matches -and ($matches.Count -gt 1)) {
                $matches[1] -Split "\n" | % {
                    $matchLine = $_.trim()
                    if (!([string]::IsNullOrEmpty($matchLine))) {
                        $nameValue = $matchLine -split "\s\s+"
                        $VersionInfo.Add($nameValue[0].trim(), $nameValue[1].trim())
                    }
                }
            }
            # Parse list of installed products
            $matchFound = $output -match "\nProduct\sList\s+\n\-+\s\n((.|\n)*?)Installed\sProduct"
            if ($matchFound -and $matches -and ($matches.Count -gt 1)) {
                [hashtable] $products = @{}
                $matches[1] -Split "\n" | % {
                    $matchLine = $_.trim()
                    if (!([string]::IsNullOrEmpty($matchLine))) {
                        $nameValue = $matchLine -split "\s\s+"
                        $products.Add($nameValue[0].trim(), $null)
                    }
                }

                # Parse product specific info
                $pattern = "Installed\sProduct\s+\n\-+\s\n(.|\n)*?\n\s\n"
                $output | Select-String -AllMatches $pattern | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value | % {
                    $prodMatchFound = $_ -match "Installed\sProduct\s+\n\-+\s\n((.|\n)*?)\n\s\n"
                    if ($prodMatchFound -and $matches -and ($matches.Count -gt 1)) {
                        [hashtable] $product = @{}
                        $currentKey = $null
                        $matches[1] -Split "\n" | % {
                            [string] $matchLine = $_.trim()
                            if (!([string]::IsNullOrEmpty($matchLine))) {
                                if ($matchLine.IndexOf("   ") -gt 0) {
                                    $nameValue = $matchLine -split "\s\s+"
                                    if ($nameValue) {
                                        $currentKey = $nameValue[0].trim()
                                        $product.Add($currentKey, $nameValue[1].trim())
                                    }
                                } else {
                                    $valueArray = @()
                                    $currentValue = $product[$currentKey]
                                    $valueArray += $currentValue
                                    $valueArray += $matchLine
                                    $product[$currentKey] = $valueArray
                                }
                            }
                        }
                        if ($products.ContainsKey($product.ID)) {
                            $products[$product.ID] = $product
                        }
                    }
                }
                $VersionInfo.Add("Products", $products)
            } else {
                Write-Error "Unable to parse any product from output: $output"
            }
        } else {
            Write-Error "No output returned from versionInfo.bat"
        }
    } else {
        $errorMsg = (&{if($versionInfoProcess) {$versionInfoProcess.StdOut} else {$null}})
        Write-Error "An error occurred while executing the versionInfo.bat process: $errorMsg"
    }
    
    return $VersionInfo
}

##############################################################################################################
# Install-IBMWebSphereAppServer
#   Installs IBM WebSphere Application Server
##############################################################################################################
Function Install-IBMWebSphereAppServer() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory = $true)]
		[System.String]
		$InstallMediaConfig,
        
        [parameter(Mandatory = $true)]
		[System.String]
		$ResponseFileTemplate,
        
    	[parameter(Mandatory = $true)]
		[System.String]
    	$InstallationDirectory,
        
        [parameter(Mandatory = $true)]
		[System.String]
    	$IMSharedLocation,

    	[parameter(Mandatory = $true)]
		[System.String]
		$SourcePath,

        [System.Management.Automation.PSCredential]
		$SourcePathCredential
	)
    
    $installed = $false
    [Hashtable] $Variables = @{}
    $Variables.Add("sharedLocation", $IMSharedLocation)
    $Variables.Add("wasInstallLocation", $InstallationDirectory)
    
    $installed = Install-IBMProduct -InstallMediaConfig $InstallMediaConfig `
        -ResponseFileTemplate $ResponseFileTemplate -Variables $Variables `
        -SourcePath $SourcePath -SourcePathCredential $SourcePathCredential -ErrorAction Stop

    Return $installed
}

##############################################################################################################
# New-IBMWebSphereAppServerWindowsService
#   Creates a new windows service for starting/stopping the WAS server specified, returns the display name of
#   the service created
##############################################################################################################
Function New-IBMWebSphereAppServerWindowsService() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory = $true, position=0)]
		[System.String]
		$ProfilePath,
        
        [parameter(Mandatory = $true, position=1)]
		[System.String]
		$ServerName,
        
        [parameter(Mandatory=$false,position=2)]
        [WASEdition]
        $WASEdition = [WASEdition]::Base,
        
        [parameter(Mandatory = $false, position=3)]
        [System.Management.Automation.PSCredential]
        $WebSphereAdministratorCredential,
        
        [parameter(Mandatory=$false,position=4)]
        [StartupType]
        $StartupType = [StartupType]::Manual,
        
        [parameter(Mandatory = $false, position=5)]
		[System.String]
		$ProfileLogRoot,
        
        [parameter(Mandatory = $false, position=6)]
        [System.Management.Automation.PSCredential]
        $WindowsServiceAccount
	)
    
    $svcName = $null
    if (!(Test-Path($ProfilePath) -PathType Container)) {
        Write-Error "Invalid WebSphere Profile Path: $ProfilePath"
        Return $null
    }
    try {
        $appServerHome = Get-IBMWebSphereAppServerInstallLocation -WASEdition $WASEdition
        $wasSvcExePath = Join-Path -Path $appServerHome -ChildPath "\bin\WASService.exe"
        if (Test-Path($wasSvcExePath) -PathType Leaf) {
            # Attempt to get service status
            $wasSvcArgs = @('-status', $ServerName)
            $wasSvcProcess = Invoke-ProcessHelper -ProcessFileName $wasSvcExePath -ProcessArguments $wasSvcArgs
            $createService = $false
            if ($wasSvcProcess) {
                [string] $output = $wasSvcProcess.StdOut
                if ($output.IndexOf("The specified service does not exist") -ge 0) {
                    $createService = $true
                } else {
                    Write-Warning "Unable to create new windows service for the WAS server named: $ServerName, it already exists"
                }
            }
            if ($createService) {
                # Create Service
                $wasSvcArgs = @('-add', $ServerName, '-serverName', $ServerName, '-profilePath', $ProfilePath)
        
                $wasSvcStopArgs = @()
                if ($WebSphereAdministratorCredential -ne $null) {
                    [string]$wasAdminUsr = $WebSphereAdministratorCredential.UserName
                    [string]$wasAdminPwd = $WebSphereAdministratorCredential.GetNetworkCredential().Password
                    $wasSvcStopArgs = '"-user ' + $wasAdminUsr + ' -password ' + $wasAdminPwd + '"'
                    $wasSvcArgs += ('-stopArgs', $wasSvcStopArgs, '-encodeParams')
                }
                if ($WindowsServiceAccount -ne $null) {
                    [string]$svcAccUsr = $WindowsServiceAccount.UserName
                    [string]$svcAccPwd = $WindowsServiceAccount.GetNetworkCredential().Password
                    $wasSvcArgs += ('-userid', $svcAccUsr, '-password', $svcAccPwd)
                }
                if ($ProfileLogRoot -and (Test-Path($ProfileLogRoot) -PathType Container)) {
                    $wasSvcArgs += ('-logRoot', $ProfileLogRoot)
                }
                if ($StartupType -ne $null) {
                    $wasSvcArgs += ('-startType', ($StartupType.ToString().ToLower()))
                }
                $wasSvcProcess = Invoke-ProcessHelper -ProcessFileName $wasSvcExePath -ProcessArguments $wasSvcArgs
                if ($wasSvcProcess -and ($wasSvcProcess.ExitCode -eq 0)) {
                    [string] $output = $wasSvcProcess.StdOut
                    if ($output.IndexOf("service successfully added") -gt 0) {
                        $svcNameStartIdx = $output.IndexOf("IBM WebSphere Application Server")
                        $svcNameLen = ($output.IndexOf("service successfully added") - $svcNameStartIdx - 1)
                        $svcName = ($output.Substring($svcNameStartIdx, $svcNameLen)).Trim()
                    } else {
                        Write-Error "An issue occurred while creating the windows service, output did not include that the service was successfully added: $output"
                    }
                } else {
                    $errorMsg = (&{if($wasSvcProcess) {$wasSvcProcess.StdOut} else {$null}})
                    Write-Error "An issue occurred while creating the windows service, WASService.exe returned: $errorMsg"
                }
            }
        } else {
            Write-Error "Unable to locate the WASService.exe file: $wasSvcExePath"
        }
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Error "An issue occurred while creating the windows service: $ErrorMessage"
    }
    
    Return $svcName
}

##############################################################################################################
# Get-IBMWebSphereTopology
#   Returns the WebSphere Topology for the profile specified
##############################################################################################################
Function Get-IBMWebSphereTopology() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory = $true,position=0)]
		[System.String]
		$ProfilePath
	)
    
    $WasCells = @{}
    if (!(Test-Path($ProfilePath) -PathType Container)) {
        Write-Error "Invalid WebSphere Profile Path: $ProfilePath"
        Return $null
    }
    try {
        Get-ChildItem -Path (Join-Path -Path $ProfilePath -ChildPath "\config\cells\") | ForEach-Object {
            $WasNodes = @{}
            Get-ChildItem -Path (Join-Path $_.FullName -ChildPath "\nodes\") | ForEach-Object {
                $WasServers = @()
                Get-ChildItem -Path (Join-Path $_.FullName -ChildPath "\servers\") | ForEach-Object {
                    $WasServers += $_.BaseName
                }
                $WasNodes.Add($_.BaseName, $WasServers)
            }
            $WasCells.Add($_.BaseName, $WasNodes)
        }
    } catch {
        Write-Error "Invalid WebSphere Profile Path: $ProfilePath"
    }
    
    Return $WasCells
}

##############################################################################################################
# Test-IBMWebSphereTopology
#   Returns true if the topology verification is successful
##############################################################################################################
Function Test-IBMWebSphereTopology() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory = $true, position=0)]
		[System.String]
		$ProfilePath,
        
        [parameter(Mandatory = $true, position=1)]
		[System.String]
		$CellName,
        
        [parameter(Mandatory = $true, position=2)]
		[System.String]
		$NodeName,
        
        [parameter(Mandatory = $true, position=3)]
		[System.String[]]
		$ServerName
	)
    
    $TopologyExists = $false
    $WasCells = Get-WebSphereTopology $ProfilePath -ErrorAction Stop
    
    if ($WasCells.ContainsKey($CellName)) {
        if ($WasCells.$CellName.ContainsKey($NodeName)) {
            $nodeServers = $WasCells.$CellName[$NodeName]
            if ((Compare-Object $nodeServers $ServerName | where {$_.SideIndicator -eq "=>"}).InputObject.Count -eq 0) {
                $TopologyExists = $true
            }
        }
    }
    
    Return $TopologyExists
}