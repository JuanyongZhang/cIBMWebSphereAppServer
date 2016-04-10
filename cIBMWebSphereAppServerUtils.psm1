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

enum PBCFilter {
    All
    NO_SUBTYPES
    SELECTED_SUBTYPES
}

# Global Variables / Resource Configuration
$IBM_REGPATH = "HKLM:\Software\IBM\"
$IBM_REGPATH_64 = "HKLM:\Software\Wow6432Node\IBM\"
$IBM_REGPATH_USER = "HKCU:\Software\IBM\"
$IBM_REGPATH_USER_64 = "HKCU:\Software\Wow6432Node\IBM\"

$WAS_SVC_PREFIX = "IBM WebSphere Application Server V"

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

    Write-Debug "Get-IBMWebSphereProductRegistryPath::ENTRY(ProductName=$ProductName,Version=$Version)"

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
            $LoggedOnSids += ".DEFAULT" # Adds default to the list of users to search
            foreach ($sid in $LoggedOnSids) {
                if ([IntPtr]::Size -eq 8) {
                    $ibmProductPath = ("HKU:\$sid\Software\Wow6432Node\IBM\" + $ProductName)
                    if (!(Test-Path($ibmProductPath))) {
                        $ibmProductPath = ("HKU:\$sid\Software\IBM\" + $ProductName)
                        if (!(Test-Path($ibmProductPath))) {
                            $ibmProductPath = $null
                        } else {
                            Write-Debug "IBM Product Found under a different user"
                            break
                        }
                    } else {
                        Write-Debug "IBM Product Found under a different user"
                        break
                    }
                } else {
                    $ibmProductPath = ("HKU:\$sid\Software\IBM\" + $ProductName)
                    if (!(Test-Path($ibmProductPath))) {
                        $ibmProductPath = $null
                    } else {
                        Write-Debug "IBM Product Found under a different user"
                        break
                    }
                }
            }
        } catch { 
            Write-Warning -Message $_.Exception.Message 
        }
    }

    Write-Debug "Get-IBMWebSphereProductRegistryPath returning path: $ibmProductPath"

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
        Write-Debug "Get-IBMWebSphereProductRegistryPath returning version path: $ibmProductVersionPath"
        if (!($versionNotFound)) {
            $ibmProductPath = $ibmProductVersionPath
        }
    }
    
    Write-Debug "Get-IBMWebSphereProductRegistryPath returning path: $ibmProductPath"
    
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

    Write-Debug "Get-IBMWebSphereAppServerRegistryPath::ENTRY(WASEdition=$WASEdition,Version=$Version)"
    
    $wasProductName = $null
    switch ($WASEdition) {
        "Base"      { $wasProductName = "WebSphere Application Server"; continue }
        "ND"        { $wasProductName = "WebSphere Application Server Network Deployment"; continue }
        "Express"   { $wasProductName = "WebSphere Application Server Express"; continue }
        "Developer" { $wasProductName = "WebSphere Application Server"; continue }
        "Liberty"   { $wasProductName = "WebSphere Application Server Liberty Profile"; continue }
    }

    $wasPath = Get-IBMWebSphereProductRegistryPath $wasProductName $Version
    
    Write-Debug "Get-IBMWebSphereAppServerRegistryPath returning path: $wasPath"
    
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

    Write-Debug "Get-IBMWebSphereAppServerInstallLocation::ENTRY(WASEdition=$WASEdition,Version=$Version)"
    
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
# Get-IBMWASProfilePath
#   Returns the location of the profile specified
##############################################################################################################
Function Get-IBMWASProfilePath() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$true,position=0)]
        [String] $ProfileName,

        [parameter(Mandatory=$false,position=1)]
        [WASEdition] $WASEdition = [WASEdition]::ND
    )
    [string] $profilePath = $null
    $wasInstDir = Get-IBMWebSphereAppServerInstallLocation $WASEdition
    if ($wasInstDir -and (Test-Path($wasInstDir) -PathType Container)) {
        try {
            $profileProc = Invoke-ManageProfiles -WASAppServerPath $wasInstDir -Commands @("-getPath", "-profileName", $ProfileName)
        } catch {
            Write-Warning "An exception occurred while retriving profile. Profile named $ProfileName not found"
        }
        if ($profileProc -and $profileProc.StdOut -and (Test-Path($profileProc.StdOut.Trim()))) {
            $profilePath = $profileProc.StdOut.Trim()
        } else {
            Write-Warning "Profile named $ProfileName not found"
        }
    }
    
    Return $profilePath
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

    Write-Debug "Get-IBMWebSphereProductVersionInfo::ENTRY(ProductDirectory=$ProductDirectory)"
    
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
# Install-IBMWebSphereAppServerFixpack
#   Installs IBM WebSphere Application Server Fixpack
##############################################################################################################
Function Install-IBMWebSphereAppServerFixpack() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$false)]
        [WASEdition]
        $WASEdition = [WASEdition]::Base,

        [parameter(Mandatory=$false)]
        [System.Version]
        $Version = "8.5.0.0",
        
        [parameter(Mandatory = $true)]
		[System.String]
    	$WebSphereInstallationDirectory,

    	[parameter(Mandatory = $true)]
		[System.String[]]
		$SourcePath,

        [System.Management.Automation.PSCredential]
		$SourcePathCredential
	)
    
    [string] $productId = $null
    if (($WASEdition -eq [WASEdition]::ND) -and ($Version.ToString(2) -eq "8.5")) {
        $productId = "com.ibm.websphere.ND.v85"
    } else {
        Write-Error "Fixpack version not supported at this time"
    }
    
    [bool] $updated = $false
    [string] $appServerDir = $WebSphereInstallationDirectory
    if (!((Split-Path $appServerDir -Leaf) -eq "AppServer")) {
        $appServerDir = Join-Path -Path $appServerDir -ChildPath "AppServer"
    }
    
    # Stop all servers
    Stop-AllWebSphereServers
    
    $updated = Install-IBMProductViaCmdLine -ProductId $productId -InstallationDirectory $appServerDir `
        -SourcePath $SourcePath -SourcePathCredential $SourcePathCredential -ErrorAction Stop
    
    if ($updated) {
        # Start all servers
        Start-AllWebSphereServers
    }
    
    Return $updated
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
    $WasCells = Get-IBMWebSphereTopology $ProfilePath -ErrorAction Stop
    
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

##############################################################################################################
# Invoke-WsAdmin
#   Wrapper function for wsadmin scripts, supports script files or commands.
##############################################################################################################
Function Invoke-WsAdmin() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true,position=0)]
        [String]
        $ProfilePath,

        [Parameter(Mandatory=$false,position=1)]
        [String]
        $ScriptPath = $null,

        [Parameter(Mandatory=$false,position=2)]
        [String[]]
        $Commands = $null,
        
        [Parameter(Mandatory=$false,position=3)]
        [String[]]
        $Arguments = @(),
        
        [Parameter(Mandatory=$false,position=4)]
        [String[]]
        $ModulesPaths = @(),

        [Parameter(Mandatory=$false,position=5)]
        [System.Management.Automation.PSCredential]
        $WebSphereAdministratorCredential,
        
        [Parameter(Mandatory=$false,position=6)]
        [ValidateSet('jython', 'jacl')]
        [String]
        $Lang = 'jython',
        
        [parameter(Mandatory=$false,position=7)]
        [String]
        $OutputFilter = 'WASX',
        
        [switch]
        $DiscardStandardOut,

        [switch]
        $DiscardStandardErr
    )

    [string] $wsAdminBat = Join-Path -Path $ProfilePath -ChildPath "bin\wsadmin.bat"
    [PSCustomObject] $wsAdminProcess = @{
        StdOut = $null
        StdErr = $null
        ExitCode = $null
    }
    if (Test-Path($wsAdminBat)) {
        [string[]] $wsArgs = $null
        if (($Commands -ne $null) -and ($Commands.Count -gt 0)) {
            $wsArgs = @("-lang", $Lang)
            Foreach ($wsAdminCmd in $Commands) {
                $wsArgs += @("-c", ('"' + $wsAdminCmd + '"'))
            }
        } elseif ($ScriptPath -ne $null) {
            $wsArgs = @("-lang", $Lang, "-f", ('"' + $ScriptPath + '"'))
            if ($Lang -eq 'jython') {
                # Add script path to python paths to load modules defined on the same location
                $ModulesPaths += Split-Path($ScriptPath)
            }
        }
        if ($wsArgs -ne $null) {
            # Add credentials
            if ($WebSphereAdministratorCredential) {
                $wasUserName = $WebSphereAdministratorCredential.UserName
                $wasPwd = $WebSphereAdministratorCredential.GetNetworkCredential().Password
                $wsArgs += @("-user", $wasUserName, "-password", $wasPwd)
            }
            # Add modules paths for jython scripts
            if (($Lang -eq 'jython') -and ($ModulesPaths.Count -gt 0)) {
                $jythonPathsStr = $ModulesPaths -join ';' -replace '\\','/'
                $wsArgs += ('-javaoption "-Dpython.path=' + $jythonPathsStr + '"')
            }
            
            # Add arguments if specified
            if ($Arguments.Count -gt 0) {
                Foreach ($wsadminArg in $Arguments) {
                    $wsArgs += ('"' + $wsadminArg + '"')
                }
            }
            $discStdOut = $DiscardStandardOut.IsPresent
            $discStdErr = $DiscardStandardErr.IsPresent
            $wsAdminProcess = Invoke-ProcessHelper -ProcessFileName $wsAdminBat -ProcessArguments $wsArgs `
                                -WorkingDirectory (Split-Path($wsAdminBat)) -DiscardStandardOut:$discStdOut -DiscardStandardErr:$discStdErr
            if ($wsAdminProcess -and (!($wsAdminProcess.StdErr)) -and ($wsAdminProcess.ExitCode -eq 0)) {
                $exceptions = Select-String -InputObject $wsAdminProcess.StdOut -Pattern "Exception" -AllMatches
                $success = ($exceptions.Matches.Count -eq 0)
                if ($success -and (!([string]::IsNullOrEmpty($OutputFilter)))) {
                    $filteredOutput = $null
                    ($wsAdminProcess.StdOut -split [environment]::NewLine) | ? {
                        if (!([string]$_).Contains($OutputFilter)) {
                            $filteredOutput += $_
                        }
                    }
                    if ($filteredOutput) {
                        $wsAdminProcess.StdOut = $filteredOutput
                    }
                } else {
                    if (!($success)) {
                        $errorMsg = (&{if($wsAdminProcess) {$wsAdminProcess.StdOut} else {$null}})
                        Write-Error "An exception occurred while executing the wsadmin.bat process: $errorMsg"
                    }
                }
            } else {
                $errorMsg = $null
                if ($wsAdminProcess -and $wsAdminProcess.StdErr) {
                    $errorMsg = $wsAdminProcess.StdErr
                } else {
                    $errorMsg = $wsAdminProcess.StdOut
                }
                $exitCode = (&{if($wsAdminProcess) {$wsAdminProcess.ExitCode} else {$null}})
                Write-Error "An error occurred while executing the wsadmin.bat process. ExitCode: $exitCode Mesage: $errorMsg"
            }
        } else {
            Write-Error "Invalid parameters.  You must specify either a Jython File Path or Jython Commands"
        }
    } else {
        Write-Error "Unable to locate wsadmin.bat using: $wsAdminBat"
    }
    Return $wsAdminProcess
}

##############################################################################################################
# Set-WsAdminTempDir
#   Updates the temporary directory that wsadmin scripts use
##############################################################################################################
Function Set-WsAdminTempDir() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [parameter(Mandatory=$true,position=0)]
        [string]
        $ProfilePath,
        
        [parameter(Mandatory=$true,position=1)]
        [string]
        $TempDir
    )
    [bool] $success = $false
    if ((Test-Path($TempDir)) -and (Test-Path($ProfilePath))) {
        $wsadminPropsPath = Join-Path -Path $ProfilePath -ChildPath "properties\wsadmin.properties"
        if (Test-Path $wsadminPropsPath) {
            [hashtable] $wsadminProp = @{}
            $wsadminProp.Add("com.ibm.ws.scripting.tempdir", ($TempDir -replace "\\","/"))
            Write-Verbose "Updating temp folder in wsadmin.properties"
            Set-JavaProperties $wsadminPropsPath $wsadminProp
            $success = $true
        } else {
            Write-Error "$wsadminPropsPath could not be located"
        }
    } else {
        Write-Error "The temp directory specified: $TempDir or the profile dir: $ProfilePath are invalid"
    }
    Return $success
}

##############################################################################################################
# Get-WsAdminTempDir
#   Retrieves the temporary directory that wsadmin scripts are using
##############################################################################################################
Function Get-WsAdminTempDir() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [parameter(Mandatory=$true,position=0)]
        [string]
        $ProfilePath
    )
    [string] $tempDir = $null
    if (Test-Path($ProfilePath)) {
        $wsadminPropsPath = Join-Path -Path $ProfilePath -ChildPath "properties\wsadmin.properties"
        if (Test-Path $wsadminPropsPath) {
            [hashtable] $wsadminProp = Get-JavaProperties $wsadminPropsPath @("com.ibm.ws.scripting.tempdir")
            if ($wsadminProp) {
                $tempDir = $wsadminProp["com.ibm.ws.scripting.tempdir"]
            }
        } else {
            Write-Error "$wsadminPropsPath could not be located"
        }
    } else {
        Write-Error "The profile dir: $ProfilePath is invalid"
    }
    Return $tempDir
}

##############################################################################################################
# New-IBMWebSphereProfile
#   Creates a new WebSphere profile using manageprofiles.bat
##############################################################################################################
Function New-IBMWebSphereProfile() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [parameter(Mandatory=$true)]
        [string] $ProfileName,
        
        [parameter(Mandatory=$true)]
        [String] $NodeName,
        
        [string] $ProfilePath,
 
        [String] $CellName,
        
        [String] $HostName,
        
        [String] $ServerName,
        
        [String] $TemplatePath,
        
        [Bool] $EnableSecurity,
        
        [System.Management.Automation.PSCredential] $AdminCredential,
        
        [String] $DmgrHost,
        
        [Int] $DmgrPort = 8879,
        
        [Bool] $isMgmt
    )

    [bool] $profileCreated = $false
    
    if (!($isMgmt) -and (!($DmgrHost) -or (!$AdminCredential))) {
        Write-Error "Unable to create profile. Dmgr settings not specified correctly"
    }
    
    [string] $WASAppServerHome = Get-IBMWebSphereAppServerInstallLocation ND
    
    if (!$WASAppServerHome) {
        Write-Error "Unable to find the WebSphere App Server Home Directory"
    }
    
    if (!$ProfilePath) {
        $ProfilePath = Join-Path $WASAppServerHome -ChildPath "profiles\$ProfileName"
    }
    
    
    [string[]] $profileCmd = @('-create')
    $profileCmd += ('-templatePath', ('"' + $TemplatePath + '"'))
    $profileCmd += ('-profileName', $ProfileName)
    $profileCmd += ('-profilePath', $ProfilePath)
    
    if ($CellName) {
        $profileCmd += ('-cellName', $CellName)
    }
    if ($HostName) {
        $profileCmd += ('-hostName', $HostName)
    }
    if ($ServerName -and (!$isMgmt)) {
    	$profileCmd += ('-serverName', $ServerName)
    }
    
    
    if ($AdminCredential) {
        $adminUserName = $AdminCredential.UserName
        $adminPwd = $AdminCredential.GetNetworkCredential().Password
        
        # Security should be enabled by default on dmgr profiles or if enable security is specified
        if ($EnableSecurity -or $isMgmt) {
			$profileCmd += ('-enableAdminSecurity', 'true')
	        $profileCmd += ('-adminUserName', $adminUserName)
	        $profileCmd += ('-adminPassword', ('"' + $adminPwd + '"'))
        }
        # If is not a dmgr profile, you need to specified the dmgr authentication information
        if (!$isMgmt) {
            $profileCmd += ('-dmgrAdminUserName', $adminUserName)
            $profileCmd += ('-dmgrAdminPassword', ('"' + $adminPwd + '"'))
        }
    }
    
    # If is not a dmgr profile, specify the host/port
    if (!$isMgmt) {
        if ($DmgrHost -and $DmgrPort) {
            $profileCmd += ('-dmgrHost', $DmgrHost)
            $profileCmd += ('-dmgrPort', $DmgrPort)
        } else {
            Write-Warning "Attempting to create a profile without specifying dmgr host/port"
        }
    }
    
    $mpProcess = Invoke-ManageProfiles -WASAppServerPath $WASAppServerHome -Commands $profileCmd

    if ($mpProcess -and $mpProcess.StdOut) {
        if ($mpProcess.StdOut.Trim().StartsWith("INSTCONFSUCCESS:")) {
            $profileCreated = $true
        }
    }
    
    Return $profileCreated
}

##############################################################################################################
# Invoke-ManageProfiles
#   Wrapper function for manageprofiles.bat
##############################################################################################################
Function Invoke-ManageProfiles() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true,position=0)]
        [String]
        $WASAppServerPath,

        [Parameter(Mandatory=$true,position=1)]
        [String[]]
        $Commands,
        
        [Parameter(Mandatory=$false,position=2)]
        [System.Management.Automation.PSCredential]
        $AdminCredential
    )

    [string] $manageProfilesBat = Join-Path -Path $WASAppServerPath -ChildPath "bin\manageprofiles.bat"
    [PSCustomObject] $manageProfileProcess = @{
        StdOut = $null
        StdErr = $null
        ExitCode = $null
    }
    if (Test-Path($manageProfilesBat)) {
        [string[]] $mpArgs = $Commands
        # Add credentials
        if ($AdminCredential) {
            $adminUserName = $AdminCredential.UserName
            $adminPwd = $AdminCredential.GetNetworkCredential().Password
            $mpArgs += @("-adminUserName", $adminUserName, "-adminPassword", $adminPwd)
        }
        $manageProfileProcess = Invoke-ProcessHelper -ProcessFileName $manageProfilesBat -ProcessArguments $mpArgs `
                            -WorkingDirectory (Split-Path($manageProfilesBat))
        if (!$manageProfileProcess -or (($manageProfileProcess.StdErr)) -and ($manageProfileProcess.ExitCode -ne 0)) {
            $errorMsg = $null
            if ($manageProfileProcess -and $manageProfileProcess.StdErr) {
                $errorMsg = $manageProfileProcess.StdErr
            } else {
                $errorMsg = $manageProfileProcess.StdOut
            }
            $exitCode = (&{if($manageProfileProcess) {$manageProfileProcess.ExitCode} else {$null}})
            Write-Error "An error occurred while executing the manageprofiles.bat process. ExitCode: $exitCode Mesage: $errorMsg"
        }
    } else {
        Write-Error "Unable to locate manageprofiles.bat using: $manageProfilesBat"
    }
    Return $manageProfileProcess
}

##############################################################################################################
# Stop-WebSphereServer
#   Stops the WebSphere Application Server using its Windows Service
##############################################################################################################
Function Stop-WebSphereServer {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$True, Position=0)]
        [String]
        $ServerName
    )

    $wasSvcName = "*" + $WAS_SVC_PREFIX + "*" + $serverName
    $wasSvc = Get-Service -DisplayName $wasSvcName

    if ($wasSvc.Status -ne "Stopped") {
        Write-Verbose "Stopping WebSphere Server: $serverName via Windows Service"
        Stop-Service $wasSvc
    } else {
        Write-Verbose "WebSphere Server: $serverName already stopped"
    }
}

##############################################################################################################
# Stop-AllWebSphereServers
#   Stops the WebSphere Application Server using its Windows Service
##############################################################################################################
Function Stop-AllWebSphereServers {
    [CmdletBinding(SupportsShouldProcess=$False)]
	Param()
	
	Write-Verbose "Stopping All WebSphere Servers"
    $wasSvcName = "*" + $WAS_SVC_PREFIX + "*"
    Get-Service -DisplayName $wasSvcName | Foreach {
        $currSvcName = $_.DisplayName 
        if ($_.Status -ne "Stopped") {
            Write-Verbose "Stopping WebSphere Server: $currSvcName via Windows Service"
            Stop-Service $_
        } else {
            Write-Verbose "WebSphere Server: $currSvcName. already stopped"
        }
    }
}

##############################################################################################################
# Start-AllWebSphereServers
#   Starts all the WebSphere Application Servers using its Windows Service
##############################################################################################################
Function Start-AllWebSphereServers {
    [CmdletBinding(SupportsShouldProcess=$False)]
	Param()
	
	Write-Verbose "Starting All WebSphere Servers"
    $wasSvcName = "*" + $WAS_SVC_PREFIX + "*"
    Get-Service -DisplayName $wasSvcName | Foreach {
        $currSvcName = $_.DisplayName 
        if ($_.Status -ne "Running") {
            Write-Verbose "Starting WebSphere Server: $currSvcName via Windows Service"
            Start-Service $_
        } else {
            Write-Verbose "WebSphere Server: $currSvcName. already started"
        }
    }
}

##############################################################################################################
# Start-WebSphereServer
#   Starts the WebSphere Application Server using its Windows Service
##############################################################################################################
Function Start-WebSphereServer() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [String]
        $ServerName
    )

    $wasSvcName = "*" + $WAS_SVC_PREFIX + "*" + $serverName
    $wasSvc = Get-Service -DisplayName $wasSvcName

    if ($wasSvc.Status -ne "Running") {
        Write-Verbose "Starting WebSphere Server: $serverName via Windows Service"
        Start-Service $wasSvc
    }
}

##############################################################################################################
# Test-WebSphereServerStatusViaBatch
#   Checks the WebSphere Application Server status using the serverStatus Batch Job
##############################################################################################################
Function Test-WebSphereServerStatusViaBatch()  {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [String] $ServerName,

        [parameter(Mandatory=$true, Position=1)]
        [string] $ProfileDir,

        [parameter(Mandatory=$true, Position=2)]
        [PSCredential] $WebSphereAdministratorCredential
    )

    $started = $false
    $profileBin = Join-Path -Path $ProfileDir -ChildPath "bin"
    if (Test-Path($profileBin)) {
        $serverStatusCmd = Join-Path -Path $profileBin -ChildPath "serverStatus.bat"
        $statusArgs = @($ServerName, "-username", $WebSphereAdministratorCredential.UserName, "-password", $WebSphereAdministratorCredential.GetNetworkCredential().Password)
        $serverStatusProc = Invoke-ProcessHelper -ProcessFileName $serverStatusCmd -ProcessArguments $statusArgs -WorkingDirectory $profileBin
        if ($serverStatusProc -and (!($serverStatusProc.StdErr))) {
            if ($serverStatusProc.StdOut.Contains(" is STARTED")) {
                $started = $true
            } elseif ($serverStatusProc.StdOut.Contains("appears to be stopped")) {
                $started = $false
            } else {
                Write-Verbose ($serverStatusProc.StdOut)
            }
        } else {
            Write-Error "An error occurred while executing the serverStatus.bat process"
        }
    } else {
        Write-Error "Invalid profile directory"
    }
    Return $started
}

##############################################################################################################
# Start-WebSphereServerViaBatch
#   Starts the WebSphere Application Server using the startServer Batch Job
##############################################################################################################
Function Start-WebSphereServerViaBatch() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [String] $ServerName,

        [parameter(Mandatory=$true, Position=1)]
        [String] $ProfileDir
    )

    $started = $false
    $profileBin = Join-Path -Path $ProfileDir -ChildPath "bin"
    if (Test-Path($profileBin)) {
        $startServerCmd = Join-Path -Path $profileBin -ChildPath "startServer.bat"
        $startServerProc = Invoke-ProcessHelper -ProcessFileName $startServerCmd -ProcessArguments @($ServerName) -WorkingDirectory $profileBin
        if ($startServerProc -and (!($startServerProc.StdErr))) {
            if ($startServerProc.StdOut.Contains("An instance of the server may already be running")) {
                $started = $true
            } elseif ($startServerProc.StdOut.Contains("open for e-business; process id is")) {
                $started = $true
            } elseif ($startServerProc.StdOut.Contains("java.io.FileNotFoundException")) {
                $started = $false
                Write-Error "Invalid server name: $ServerName"
            } else {
                Write-Verbose ($startServerProc.StdOut)
            }
        } else {
            Write-Error "An error occurred while executing the startServer.bat process"
        }
    } else {
        Write-Error "Invalid profile directory"
    }
    Return $started
}

##############################################################################################################
# Stop-WebSphereServerViaBatch
#   Stops the WebSphere Application Server using the stopServer Batch Job
##############################################################################################################
Function Stop-WebSphereServerViaBatch()  {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [String]
        $ServerName,

        [parameter(Mandatory=$true, Position=1)]
        [string]
        $ProfileDir,

        [parameter(Mandatory=$true, Position=2)]
        [System.Management.Automation.PSCredential]
        $WebSphereAdministratorCredential
    )

    $stopped = $false
    $profileBin = Join-Path -Path $ProfileDir -ChildPath "bin"
    if (Test-Path($profileBin)) {
        $stopServerCmd = Join-Path -Path $profileBin -ChildPath "stopServer.bat"
        $stopArgs = @($ServerName, "-username", $WebSphereAdministratorCredential.UserName, "-password", $WebSphereAdministratorCredential.GetNetworkCredential().Password)
        $stopServerProc = Invoke-ProcessHelper -ProcessFileName $stopServerCmd -ProcessArguments $stopArgs -WorkingDirectory $profileBin
        if ($stopServerProc -and (!($stopServerProc.StdErr))) {
            if ($stopServerProc.StdOut.Contains("cannot be reached.")) {
                $stopped = $true
            } elseif ($stopServerProc.StdOut.Contains("stop completed.")) {
                $stopped = $true
            } elseif ($stopServerProc.StdOut.Contains("java.io.FileNotFoundException")) {
                $stopped = $false
                Write-Error "Invalid server name: $ServerName"
            } else {
                Write-Verbose ($stopServerProc.StdOut)
            }
        } else {
            Write-Error "An error occurred while executing the stopServer.bat process"
        }
    } else {
        Write-Error "Invalid profile directory"
    }
    Return $stopped
}

##############################################################################################################
# Test-WebSphereServerService
#   Returns true if the WebSphere Application Server is running
##############################################################################################################
Function Test-WebSphereServerService() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [String]
        $ServerName
    )

    Try {
        $wasSvcName = "*" + $WAS_SVC_PREFIX + "*" + $serverName
        $wasSvc = Get-Service -DisplayName $wasSvcName
        
        if ($wasSvc.Status -eq "Running") {
            Return $true
        } else {
            Return $false
        }
    } Catch {
        Return $false
    }
}

##############################################################################################################
# Test-WebSphereServerServiceExists
#   Returns true if the WebSphere Application Server Windows Service Exists
##############################################################################################################
Function Test-WebSphereServerServiceExists() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [String]
        $ServerName
    )

    Try {
        $wasSvcName = "*" + $WAS_SVC_PREFIX + "*" + $serverName
        if (Get-Service -DisplayName $wasSvcName) {
            Return $true
        } else {
            Return $false
        }
    } Catch {
        Return $false
    }
}

##############################################################################################################
# Start-WebSphereNodeAgent
#   Starts the WebSphere Node Agent
##############################################################################################################
Function Start-WebSphereNodeAgent {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$false, Position=0)]
        [String]
        $NodeName,
        
        [parameter(Mandatory=$true,position=1)]
        [string]
        $ProfileDir,
        
        [parameter(Mandatory=$true,position=2)]
        [System.Management.Automation.PSCredential]
        $WebSphereAdministratorCredential
    )

    $wasSvcName = "*" + $WAS_SVC_PREFIX + "*NODEAGENT"
    $wasSvc = Get-Service -DisplayName $wasSvcName
    
    if ($wasSvc) {
        if ($wasSvc.Status -ne "Running") {
            Write-Verbose "Starting Node Agent via Windows Service"
            Start-Service $wasSvc
            if (($ProfileDir) -and (Test-Path($ProfileDir))) {
                $naPidFile = Join-Path -Path $ProfileDir -ChildPath "logs\nodeagent\nodeagent.pid"
                if (Test-Path($naPidFile)) {
                    $sleepTimer = 0;
                    Write-Verbose "Waiting for Node Agent PID file to be created: $naPidFile"
                    while(!(Test-Path $naPidFile)) {
                        sleep -s 10
                        $sleepTimer += 10
                        # Wait maximum of 10 minutes for portal to start after service is initialized
                        if ($sleepTimer -ge 600) {
                            break
                        }
                    }
                }
            }
        } else {
            Write-Verbose "Node agent already started"
        }
    }
}

##############################################################################################################
# Stop-WebSphereNodeAgent
#   Stops the WebSphere Node Agent
##############################################################################################################
Function Stop-WebSphereNodeAgent {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [String]
        $NodeName,
        
        [parameter(Mandatory=$true,position=1)]
        [string]
        $ProfileDir,
        
        [parameter(Mandatory=$true,position=2)]
        [System.Management.Automation.PSCredential]
        $WebSphereAdministratorCredential
    )

    $wasSvcName = "*" + $WAS_SVC_PREFIX + "*NODEAGENT"
    $wasSvc = Get-Service -DisplayName $wasSvcName
    
    if ($wasSvc) {
        if ($wasSvc.Status -ne "Stopped") {
            Write-Verbose "Stopping Node Agent via Windows Service"
            Stop-Service $wasSvc
        } else {
            Write-Verbose "Node agent already stopped"
        }
    }
}

##############################################################################################################
# Start-WebSphereDmgr
#   Starts the WebSphere Deployment Manager
##############################################################################################################
Function Start-WebSphereDmgr {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [parameter(Mandatory=$true,position=1)]
        [string] $DmgrProfileDir,
        
        [parameter(Mandatory=$true,position=2)]
        [System.Management.Automation.PSCredential] $WebSphereAdministratorCredential
    )

    $wasSvcName = "*" + $WAS_SVC_PREFIX + "*DMGR"
    $wasSvc = Get-Service -DisplayName $wasSvcName
    
    if ($wasSvc) {
        if ($wasSvc.Status -ne "Running") {
            Write-Verbose "Starting WebSphere Deployment Manager via Windows Service"
            Start-Service $wasSvc
            $dmgrPidFile = Join-Path -Path $DmgrProfileDir -ChildPath "logs\dmgr\dmgr.pid"
            if (Test-Path($dmgrPidFile)) {
                $sleepTimer = 0;
                Write-Verbose "Waiting for DMGR PID file to be created: $dmgrPidFile"
                while(!(Test-Path $dmgrPidFile)) {
                    sleep -s 10
                    $sleepTimer += 10
                    # Wait maximum of 10 minutes for portal to start after service is initialized
                    if ($sleepTimer -ge 600) {
                        break
                    }
                }
            }
        } else {
            Write-Verbose "WebSphere Deployment Manager already started"
        }
    }
}

##############################################################################################################
# Stop-WebSphereDmgr
#   Stops the WebSphere Deployment Manager
##############################################################################################################
Function Stop-WebSphereDmgr {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [parameter(Mandatory=$true,position=1)]
        [string] $DmgrProfileDir,
        
        [parameter(Mandatory=$true,position=2)]
        [System.Management.Automation.PSCredential] $WebSphereAdministratorCredential
    )

    $wasSvcName = "*" + $WAS_SVC_PREFIX + "*DMGR"
    $wasSvc = Get-Service -DisplayName $wasSvcName
    
    if ($wasSvc) {
        if ($wasSvc.Status -ne "Stopped") {
            Write-Verbose "Stopping WebSphere Deployment Manager via Windows Service"
            Stop-Service $wasSvc
        } else {
            Write-Verbose "WebSphere Deployment Manager already stopped"
        }
    }
}

Function Get-IBMResources([string] $resourceId) {
    if (!([String]::IsNullOrEmpty($resourceId))) {
        [string[]] $resourcesSplit = $resourceId.Split(':')
        [string[]] $resources = @()
        foreach ($resource in $resourcesSplit) {
            if ($resource.Trim().EndsWith("=")) {
                $resources += ($resource.Substring(0, $resource.Length - 1))
            } else {
                $resources += $resource
            }
        }

        Return $resources
    }
}

Function Get-IBMBaseResources([string[]] $resource1, [string[]] $resource2) {
    [string[]] $baseResource = @()
    if ($resource1 -and $resource2) {
        $baseResource = (Compare-Object $resource1 $resource2 -SyncWindow 1 -ExcludeDifferent -IncludeEqual).InputObject
    }
    return $baseResource
}

Function Get-IBMDeltaResources([string[]] $resource1, [string[]] $resource2) {
    [string[]] $deltaResource = @()
    if ($resource1 -and $resource2) {
        $deltaResource = (Compare-Object $resource1 $resource2 -SyncWindow 1).InputObject
    }
    return $deltaResource
}

##############################################################################################################
# Import-IBMWebSpherePropertyBasedConfig
#   Parses a property file created by the Property-Based Configuration Framework in WebSphere 
##############################################################################################################
Function Import-IBMWebSpherePropertyBasedConfig() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$true,position=0)]
        [string]
        $PropertyFilePath
    )

    [hashtable] $props = @{}
    [string[]] $resourceBaseKeys = @("ResourceType", "ImplementingResourceType")
	
	if (Test-Path $PropertyFilePath){
		$file = gc $PropertyFilePath
        [hashtable] $currentResource = @{}
        [string] $parentResourceId = $null
		[string] $currentResourceId = $null
        [boolean] $envSection = $false
        [string] $propertiesLabel = "Properties"
		foreach($line in $file) {
            if ($line.StartsWith("EnvironmentVariablesSection")) {
                $envSection = $true
            }
			if ((!($line.StartsWith('#'))) -and
				(!($line.StartsWith(';'))) -and
				(!($line.StartsWith(";"))) -and
				(!($line.StartsWith('`'))) -and
				(($line.Contains('=')))) {
				[string] $propName=$line.split('=', 2)[0]
                [string] $propValue=$line.split('=', 2)[1]
                
                if (!($envSection)) {
                    if (("ResourceId" -eq $propName) -and $props.ContainsKey($propName)) {
                        # Next resource id
                        if ($currentResourceId -ne $propValue) {
                            $currentResource = @{}
                            #TODO Handle multi resource / nested PBC files
                            Write-Warning "Can't handle importing PBC files with more than one resource. TODO."
                            <# Identify child resource
                            $propertiesLabel = "Properties"
                            $parentResource = Get-IBMResources $parentResourceId
                            $childResource = Get-IBMResources $propValue
                            $delta = Get-IBMDeltaResources $parentResource $childResource
                            #>
                        } else {
                            # Same resource id, change based on attribute info
                        }
                    } elseif (("ResourceId" -eq $propName) -and !$parentResourceId) {
                        # First resource id (base)
                        $propertiesLabel = "Properties"
                        $currentResourceId = $propValue
                        $parentResourceId = $propValue
                        $props.Add($currentResourceId, $currentResource)
                    } else {
                        # Property handling
                        # Parse value
                        if ($propValue.IndexOf('#') -gt 0) {
                            $propValue = $propValue.Substring(0, $propValue.IndexOf('#'))
                            $propValue = $propValue.Trim()
                        }
                        # Handle resource keys
                        if ($resourceBaseKeys.Contains($propName)) {
                            Write-Host ("Adding: " + $propName + "=" + $propValue) -ForegroundColor DarkYellow
                            $currentResource.Add($propName, $propValue)
                        } else {
                            if ("AttributeInfo" -eq $propName) {
                                $propertiesLabel = $propValue
                            } else {
                                # Add resource properties
                                if ($currentResource.ContainsKey($propertiesLabel)) {
                                    $currentResource[$propertiesLabel].Add($propName, $propValue)
                                } else {
                                    [hashtable] $subProps = @{}
                                    $subProps.Add($propName, $propValue)
                                    $currentResource.Add($propertiesLabel, $subProps)
                                }
                            }
                        }
                    }
                }
			}
		}
	} else {
		Write-Error "Property Based Config file: $PropertyFilePath not found"
	}

    Return $props
}

##############################################################################################################
# Export-IBMWebSpherePropertyBasedConfig
#   Extracts properties to a file based on the Resource Id or Config Data, returns true if extracted
##############################################################################################################
Function Export-IBMWebSpherePropertyBasedConfig() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory = $true, position=0)]
		[String] $ProfilePath,
        
        [parameter(Mandatory = $false, position=2)]
		[String] $ResourceId,

        [parameter(Mandatory = $false, position=3)]
		[Hashtable] $ConfigData,
        
        [Parameter(Mandatory = $true, position=4)]
        [PSCredential] $WebSphereAdministratorCredential,

        [parameter(Mandatory = $true, position=5)]
		[String] $TargetPropertyFile,
        
        [parameter(Mandatory = $false, position=6)]
        [PBCFilter] $FilterMechanism,
        
        [parameter(Mandatory = $false, position=7)]
		[String[]] $SelectedSubTypes
    )

    if ((!($ResourceId)) -and (!($ConfigData))) {
        Write-Error "You must specified either a Resource Id or ConfigData to extract properties"
    }

    [string[]] $wsadminCommands = @()
    [string] $extractArgs = $null
    if ($ResourceId) {
        $wsadminCommands += ("rsrcID = '" + $ResourceId + "'")
        $extractArgs = "rsrcID, '-propertiesFileName " + $TargetPropertyFile + "'"
    } else {
        $configDataStr = ""
        foreach ($configKey in $ConfigData.Keys) {
            $configDataStr += (" " + $configKey + "=" + $ConfigData[$configKey])
        }
        $extractArgs = "'[-propertiesFileName " + $TargetPropertyFile + " -configData" + $configDataStr
        if ($FilterMechanism -eq [PBCFilter]::SELECTED_SUBTYPES) {
            $extractArgs += " -filterMechanism SELECTED_SUBTYPES -selectedSubTypes ["
            $extractArgs += ($SelectedSubTypes -join " ") + "]"
        }
        $extractArgs += " -options [[PortablePropertiesFile true]]"
        $extractArgs += "]'"
    }

    $extractTask = "AdminTask.extractConfigProperties(" + $extractArgs + ")"
    $extractTask | Out-Host
    $wsadminCommands += $extractTask

    $wsadminProcess = Invoke-WsAdmin -ProfilePath $ProfilePath -Commands $wsadminCommands -WebSphereAdministratorCredential $WebSphereAdministratorCredential

    Return ($wsadminProcess -and ($wsadminProcess.ExitCode -eq '0'))
}

##############################################################################################################
# Test-IBMWebSpherePropertyBasedConfig
#   Returns true if the properties specified in the PBC file are already present and valid
##############################################################################################################
Function Test-IBMWebSpherePropertyBasedConfig() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory = $true, position=0)]
		[String] $ProfilePath,
        
        [parameter(Mandatory = $true, position=1)]
		[String] $PropertyFile,
        
        [Parameter(Mandatory = $true, position=2)]
        [PSCredential] $WebSphereAdministratorCredential,
        
        [parameter(Mandatory = $false, position=3)]
		[String] $VariablesMapFile,
        
        [parameter(Mandatory = $false, position=4)]
		[Hashtable] $VariablesMap,
        
        [parameter(Mandatory = $false, position=5)]
		[String] $ReportFile
	)

    if (!(Test-Path $PropertyFile -PathType Leaf)) {
        Write-Error "You must specified a valid properties file. Invalid file: $ProfileFile"
    }
    $configIsValid = $false

    [string[]] $wsadminCommands = @()
    [string[]] $validateArgs = @()
    $validateArgs += ("-propertiesFileName", ('\"' + $PropertyFile.Replace("\","\\") + '\"'))
    # If report file is not specified use temp and remove it
    $deleteReportFile = $false
    if (!($ReportFile)) {
        $ReportFile = Join-Path (Get-IBMTempDir) "validateProperties-$(get-date -f yyyyMMddHHmmss).txt"
        $deleteReportFile = $true
    }
    $validateArgs += ("-reportFileName", ('\"' + $ReportFile.Replace("\","\\") + '\"'), "-reportFilterMechanism", "Errors_And_Changes")
    if ($VariablesMapFile) {
        $validateArgs += ("-variablesMapFileName", ('\"' + $VariablesMapFile.Replace("\","\\") + '\"'))
    }
    if ($VariablesMap) {
        $variableStr = "["
        foreach ($varKey in $VariablesMap.Keys) {
            $variableStr += "[" + ($varKey + " " + $VariablesMap[$varKey] + "]")
        }
        $variableStr = $variableStr.Trim()
        $variableStr += "]"
        $validateArgs += ("-variablesMap", $variableStr)
    }

    $validateArgsStr = "'[" + ($validateArgs -join " ") + "]'"
    $validateTask = "AdminTask.validateConfigProperties(" + $validateArgsStr + ")"
    $wsadminCommands += $validateTask

    $wsadminProcess = Invoke-WsAdmin -ProfilePath $ProfilePath -Commands $wsadminCommands -WebSphereAdministratorCredential $WebSphereAdministratorCredential

    if ($wsadminProcess -and ($wsadminProcess.StdOut -and $wsadminProcess.StdOut -eq "'true'")) {
        gc $ReportFile | Foreach-Object {
            $currLine = ([string]$_).Trim()
            if ($currLine.Length -gt 0) {
                if (([string]$_).StartsWith("ADMG0824I")) {
                    $configIsValid = $true
                } elseif (!([string]$_).StartsWith("ADMG0825I")) {
                    $configIsValid = $false
                }
            }
        }
        if (!$configIsValid) {
            [string[]] $output = (gc $ReportFile)
            Write-Warning ($output -join [environment]::NewLine)
        }
        if ((Test-Path $ReportFile) -and $deleteReportFile) {
            rm $ReportFile -Force | Out-Null
        }
    }

    Return $configIsValid
}

##############################################################################################################
# Set-IBMWebSpherePropertyBasedConfig
#   Updates WebSphere with the properties specified in the PBC file
##############################################################################################################
Function Set-IBMWebSpherePropertyBasedConfig() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory = $true, position=0)]
		[String]
		$ProfilePath,
        
        [parameter(Mandatory = $true, position=1)]
		[String]
		$PropertyFile,
        
        [Parameter(Mandatory = $true, position=2)]
        [System.Management.Automation.PSCredential]
        $WebSphereAdministratorCredential,
        
        [parameter(Mandatory = $false, position=3)]
		[String]
		$VariablesMapFile,
        
        [parameter(Mandatory = $false, position=4)]
		[Hashtable]
		$VariablesMap,
        
        [parameter(Mandatory = $false, position=5)]
		[String]
		$ReportFile
	)

    if (!(Test-Path $PropertyFile -PathType Leaf)) {
        Write-Error "You must specified a valid properties file. Invalid file: $ProfileFile"
    }
    
    $configApplied = $false

    [string[]] $wsadminCommands = @()
    [string[]] $applyArgs = @()
    $applyArgs += ("-propertiesFileName", ('\"' + $PropertyFile.Replace("\","\\") + '\"'))
    # If report file is not specified use temp and remove it
    $deleteReportFile = $false
    if (!($ReportFile)) {
        $ReportFile = Join-Path (Get-IBMTempDir) "tempProperties-$(get-date -f yyyyMMddHHmmss).txt"
        $deleteReportFile = $true
    }
    $applyArgs += ("-reportFileName", ('\"' + $ReportFile.Replace("\","\\") + '\"'), "-reportFilterMechanism", "Errors_And_Changes")
    
    if ($VariablesMapFile) {
        $applyArgs += ("-variablesMapFileName", ('\"' + $VariablesMapFile.Replace("\","\\") + '\"'))
    }
    if ($VariablesMap) {
        $variableStr = "["
        foreach ($varKey in $VariablesMap.Keys) {
            $variableStr += "[" + ($varKey + " " + $VariablesMap[$varKey] + "]")
        }
        $variableStr = $variableStr.Trim()
        $variableStr += "]"
        $applyArgs += ("-variablesMap", $variableStr)
    }

    $applyArgsStr = "'[" + ($applyArgs -join " ") + "]'"
    $applyTask = "AdminTask.applyConfigProperties(" + $applyArgsStr + ")"
    $wsadminCommands += $applyTask
    
    $wsadminProcess = Invoke-WsAdmin -ProfilePath $ProfilePath -Commands $wsadminCommands -WebSphereAdministratorCredential $WebSphereAdministratorCredential
    
    if ($wsadminProcess -and ($wsadminProcess.StdOut -and $wsadminProcess.StdOut -eq "''")) {
        [int] $configCounter = 0
        gc $ReportFile | Foreach-Object {
            $currLine = ([string]$_).Trim()
            if ($currLine.Length -gt 0) {
                if ($currLine.StartsWith("ADMG0824I")) {
                    $configCounter++
                } elseif ($currLine.StartsWith("ADMG0825I")) {
                    $configCounter++
                } elseif ($currLine.StartsWith("ADMG0820I")) {
                    $configCounter++
                } elseif ($currLine.StartsWith("ADMG0821I")) {
                    $configCounter++
                }   
            }
        }
        $configApplied = ($configCounter -eq 4)
        if (!$configApplied) {
            [string[]] $output = (gc $ReportFile)
            Write-Error ($output -join [environment]::NewLine)
        }
        if ((Test-Path $ReportFile) -and $deleteReportFile) {
            rm $ReportFile -Force | Out-Null
        }
    }

    Return $configApplied
}