##############################################################################################################
########                               IBM WebSphere App Server CmdLets                              #########
##############################################################################################################

# Import external modules/cmdlets
if (!(Get-Module "cIBMInstallationManager")) {
    ## Load it nested
    Import-Module "cIBMInstallationManager" -ErrorAction Stop
}

enum WASEdition {
    Base
    ND
    Express
    Developer
    Liberty
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