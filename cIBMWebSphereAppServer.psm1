# Import IBM WebSphere App Server Utils Module
Import-Module $PSScriptRoot\cIBMWebSphereAppServerUtils.psm1 -ErrorAction Stop

enum Ensure {
    Absent
    Present
}

enum WASEdition {
    Base
    ND
    Express
    Developer
    Liberty
}

enum ProfileType {
	Cell
	Default
	Dmgr
	Managed
	Management
	Secureproxy
}

<#
   DSC resource to manage the installation of IBM WebSphere Application Server.
   Key features: 
    - Install IBM WebSphere Application Server for the first time
    - Can use media on the local drive as well as from a network share which may require specifying credentials
#>

[DscResource()]
class cIBMWebSphereAppServer {
    
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Key)]
    [WASEdition] $WASEdition
    
    [DscProperty(Key)]
    [String] $Version
    
    [DscProperty()]
    [String] $InstallationDirectory = "C:\IBM\WebSphere"
    
    [DscProperty()]
    [String] $IMSharedLocation = "C:\IBM\IMShared"
    
    [DscProperty()]
    [String] $InstallMediaConfig
    
    [DscProperty()]
    [String] $ResponseFileTemplate

    [DscProperty()]
    [String] $SourcePath
    
    [DscProperty()]
    [bool] $PlusJava7 = $false
    
    [DscProperty()]
    [System.Management.Automation.PSCredential] $SourcePathCredential

    <#
        Installs IBM WebSphere Application Server
    #>
    [void] Set () {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                Write-Verbose -Message "Starting installation of IBM WebSphere Application Server"
                $sevenZipExe = Get-SevenZipExecutable
                if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
                    $ibmwasEdition = $this.WASEdition.ToString()
                    $wasVersion = $this.Version
                    if (!($this.InstallMediaConfig)) {
                        if ($this.PlusJava7) {
                            $this.InstallMediaConfig = Join-Path -Path $PSScriptRoot -ChildPath "InstallMediaConfig\$ibmwasEdition-$wasVersion-plus-JAVA7.xml"
                        } else {
                            $this.InstallMediaConfig = Join-Path -Path $PSScriptRoot -ChildPath "InstallMediaConfig\$ibmwasEdition-$wasVersion.xml"
                        }
                        
                    }
                    if (!($this.ResponseFileTemplate)) {
                        if ($this.PlusJava7) {
                            $this.ResponseFileTemplate = Join-Path -Path $PSScriptRoot -ChildPath "ResponseFileTemplates\$ibmwasEdition-$wasVersion-template-plus-JAVA7.xml"
                        } else {
                            $this.ResponseFileTemplate = Join-Path -Path $PSScriptRoot -ChildPath "ResponseFileTemplates\$ibmwasEdition-$wasVersion-template.xml"
                        }
                    }
                    
                    $installed = Install-IBMWebSphereAppServer -InstallMediaConfig $this.InstallMediaConfig `
                        -ResponseFileTemplate $this.ResponseFileTemplate -InstallationDirectory $this.InstallationDirectory `
                        -IMSharedLocation $this.IMSharedLocation -SourcePath $this.SourcePath -SourcePathCredential $this.SourcePathCredential
                    if ($installed) {
                        Write-Verbose "IBM WebSphere Application Server Installed Successfully"
                    } else {
                        Write-Error "Unable to install IBM WebSphere Application Server, please check installation logs for more information"
                    }
                } else {
                    Write-Error "IBM WebSphere Application Server installation depends on 7-Zip, please ensure 7-Zip is installed first"
                }
            } else {
                Write-Verbose "Uninstalling IBM Application Server (Not Yet Implemented)"
            }
        } catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }

    <#
        Performs test to check if WAS is in the desired state, includes 
        validation of installation directory and version
    #>
    [bool] Test () {
        Write-Verbose "Checking for IBM WebSphere Application Server installation"
        $wasConfiguredCorrectly = $false
        $wasRsrc = $this.Get()
        
        if (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Present)) {
            $sameVersion = ($wasRsrc.Version -eq $this.Version)
            if (!($sameVersion)) {
                $currVersionObj = (New-Object -TypeName System.Version -ArgumentList $wasRsrc.Version)
                $newVersionObj = (New-Object -TypeName System.Version -ArgumentList $this.Version)
                $sameVersion = (($currVersionObj.ToString(3)) -eq ($newVersionObj.ToString(3)))
            }
            if ($sameVersion) {
                if (((Get-Item($wasRsrc.InstallationDirectory)).Name -eq 
                    (Get-Item($this.InstallationDirectory)).Name) -and (
                    (Get-Item($wasRsrc.InstallationDirectory)).Parent.FullName -eq 
                    (Get-Item($this.InstallationDirectory)).Parent.FullName)) {
                    if ($wasRsrc.WASEdition -eq $this.WASEdition) {
                        Write-Verbose "IBM WebSphere Application Server is installed and configured correctly"
                        $wasConfiguredCorrectly = $true
                    }
                }
            }
        } elseif (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Absent)) {
            $wasConfiguredCorrectly = $true
        }

        if (!($wasConfiguredCorrectly)) {
            Write-Verbose "IBM WebSphere Application Server not configured correctly"
        }
        
        return $wasConfiguredCorrectly
    }

    <#
        Leverages the information stored in the registry to populate the properties of an existing
        installation of WAS
    #>
    [cIBMWebSphereAppServer] Get () {
        $RetEnsure = [Ensure]::Absent
        $RetVersion = $null
        $RetWASEdition = $this.WASEdition
        
        $versionObj = (New-Object -TypeName System.Version -ArgumentList $this.Version)
        $RetInsDir = Get-IBMWebSphereAppServerInstallLocation $this.WASEdition $versionObj
        
        if($RetInsDir -and (Test-Path($RetInsDir))) {
            $VersionInfo = Get-IBMWebSphereProductVersionInfo $RetInsDir
            $ibmwasEdition = $this.WASEdition.ToString()
            if($VersionInfo -and ($VersionInfo.Products) -and ($VersionInfo.Products[$ibmwasEdition])) {
                Write-Verbose "IBM WebSphere Application Server is Present"
                $RetEnsure = [Ensure]::Present
                $RetVersion = $VersionInfo.Products[$ibmwasEdition].Version
            } else {
                Write-Warning "Unable to retrieve version information from the IBM WebSphere Application Server installed"
            }
        } else {
            Write-Verbose "IBM WebSphere Application Server is NOT Present"
        }

        $returnValue = @{
            InstallationDirectory = $RetInsDir
            Version = $RetVersion
            WASEdition = $RetWASEdition
            Ensure = $RetEnsure
        }

        return $returnValue
    }
}

[DscResource()]
class cIBMWebSphereAppServerFixpack {
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Key)]
    [WASEdition] $WASEdition
    
    [DscProperty(Key)]
    [String] $Version
    
    [DscProperty()]
    [String] $WebSphereInstallationDirectory = "C:\IBM\WebSphere\"
    
    [DscProperty()]
    [String[]] $SourcePath
    
    [DscProperty()]
    [System.Management.Automation.PSCredential] $SourcePathCredential

    <#
        Installs IBM WebSphere Application Server Fixpack
    #>
    [void] Set () {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                Write-Verbose -Message "Starting installation of IBM WAS Fixpack"
                $sevenZipExe = Get-SevenZipExecutable
                if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
                    $versionObj = (New-Object -TypeName System.Version -ArgumentList $this.Version)
                    $installed = Install-IBMWebSphereAppServerFixpack -Version $versionObj `
                        -WASEdition $this.WASEdition -WebSphereInstallationDirectory $this.WebSphereInstallationDirectory `
                        -SourcePath $this.SourcePath -SourcePathCredential $this.SourcePathCredential
                    if ($installed) {
                        Write-Verbose ("IBM WAS Fixpack " + $this.Version + "Installed Successfully")
                    } else {
                        Write-Error "Unable to install the IBM WAS Fixpack, please check installation logs for more information"
                    }
                } else {
                    Write-Error "IBM WAS Fixpack installation depends on 7-Zip, please ensure 7-Zip is installed first"
                }
            } else {
                Write-Verbose "Uninstalling IBM WAS Fixpack (Not Yet Implemented)"
            }
        } catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }

    <#
        Performs test to check if WAS fixpack is alreay installed
    #>
    [bool] Test () {
        Write-Verbose "Checking for IBM WAS Fixpack installation"
        $wasConfiguredCorrectly = $false
        $wasRsrc = $this.Get()
        
        if (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Present)) {
            if ($wasRsrc.Version -eq $this.Version) {
                if (((Get-Item($wasRsrc.WebSphereInstallationDirectory)).Name -eq 
                    (Get-Item($this.WebSphereInstallationDirectory)).Name) -and (
                    (Get-Item($wasRsrc.WebSphereInstallationDirectory)).Parent.FullName -eq 
                    (Get-Item($this.WebSphereInstallationDirectory)).Parent.FullName)) {
                    if ($wasRsrc.WASEdition -eq $this.WASEdition) {
                        Write-Verbose "IBM WAS Fixpack is installed"
                        $wasConfiguredCorrectly = $true
                    }
                }
            }
        } elseif (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Absent)) {
            $wasConfiguredCorrectly = $true
        }

        if (!($wasConfiguredCorrectly)) {
            Write-Verbose "IBM WAS Fixpack not configured correctly"
        }
        
        return $wasConfiguredCorrectly
    }

    <#
        Leverages versionInfo.bat to get installed fixpack
    #>
    [cIBMWebSphereAppServerFixpack] Get () {
        $RetEnsure = [Ensure]::Absent
        $RetVersion = $null
        $RetWASEdition = $this.WASEdition
        
        $versionObj = (New-Object -TypeName System.Version -ArgumentList $this.Version)
        $RetInsDir = Get-IBMWebSphereAppServerInstallLocation $this.WASEdition $versionObj
        
        if($RetInsDir -and (Test-Path($RetInsDir))) {
            $VersionInfo = Get-IBMWebSphereProductVersionInfo $RetInsDir
            $ibmwasEdition = $this.WASEdition.ToString()
            if($VersionInfo -and ($VersionInfo.Products) -and ($VersionInfo.Products[$ibmwasEdition])) {
                $RetEnsure = [Ensure]::Present
                $RetVersion = $VersionInfo.Products[$ibmwasEdition].Version
            } else {
                Write-Warning "Unable to retrieve version information from the IBM WebSphere Application Server installed"
            }
        } else {
            Write-Verbose "IBM WebSphere Application Server is NOT Present"
        }

        $returnValue = @{
            WebSphereInstallationDirectory = $RetInsDir
            Version = $RetVersion
            WASEdition = $RetWASEdition
            Ensure = $RetEnsure
        }

        return $returnValue
    }
}

[DscResource()]
class cIBMWebSphereAppServerProfile {
    
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Key)]
    [string] $ProfileName
    
    [DscProperty()]
    [string] $ProfilePath
    
    [DscProperty(NotConfigurable)]
    [String] $WASAppServerHome = $null
    
    [DscProperty(Mandatory)]
    [String] $NodeName
    
    [DscProperty()]
    [String] $CellName
    
    [DscProperty()]
    [String] $HostName
    
    [DscProperty()]
    [String] $TemplatePath
    
    [DscProperty()]
    [Bool] $EnableSecurity = $true
    
    [DscProperty()]
    [String] $ServerName = "server1"
    
    [DscProperty()]
    [ProfileType] $ProfileType = [ProfileType]::Default
    
    [DscProperty()]
    [System.Management.Automation.PSCredential] $AdminCredential
    
    [DscProperty()]
    [String] $DmgrHost
    
    [DscProperty()]
    [Int] $DmgrPort
    
    # Sets the desired state of the resource.
    [void] Set() {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                Write-Verbose -Message ("Creating WebSphere Profile: " + $this.ProfileName)
                [bool] $created = $false
                
                $isMgmt = ($this.ProfileType -eq [ProfileType]::Management)
                if ($isMgmt) {
                	$this.ServerName = "dmgr"
                }
                
                $appServerDir = Get-IBMWebSphereAppServerInstallLocation ND
                if (!$this.TemplatePath) {
                	$this.TemplatePath = Join-Path -Path $appServerDir -ChildPath ("profileTemplates\" + $this.ProfileType) 
                }
                
                Write-Verbose -Message ("Creating WebSphere Profile using template: " + $this.TemplatePath)
				
                $created = New-IBMWebSphereProfile `
                				-ProfileName $this.ProfileName `
                				-ProfilePath $this.ProfilePath `
                                -NodeName $this.NodeName `
                                -CellName $this.CellName `
                                -HostName $this.HostName `
                                -TemplatePath $this.TemplatePath `
                                -AdminCredential $this.AdminCredential `
                                -EnableSecurity $this.EnableSecurity `
                                -DmgrHost $this.DmgrHost `
				                -DmgrPort $this.DmgrPort `
				                -ServerName $this.ServerName `
                                -isMgmt $isMgmt `
                                -ErrorAction Stop

                # If the profiles are default/management a server will be created, go ahead and create a windows service for it and start it
				if ($created -and (($this.ProfileType -eq [ProfileType]::Default) -or ($this.ProfileType -eq [ProfileType]::Management))) {
					$created = $false
					
					if (!$this.ProfilePath) {
						$this.ProfilePath = Get-IBMWASProfilePath $this.ProfileName ND
					}
                    
                    if (!(Test-Path $this.ProfilePath)) {
                        Write-Error "Invalid profile directory, it does not exist"
                    }
					
					$wasWinSvcName = New-IBMWebSphereAppServerWindowsService `
										-ProfilePath $this.ProfilePath `
										-ServerName $this.ServerName `
										-WebSphereAdministratorCredential $this.AdminCredential `
										-WASEdition ND -StartupType Automatic
					Write-Verbose -Message ("New-IBMWebSphereAppServerWindowsService created: $wasWinSvcName")
					
                    if ($wasWinSvcName -and (Get-Service -DisplayName $wasWinSvcName)) {
                        Write-Verbose "IBM WebSphere Windows Service [$wasWinSvcName] configured successfully, starting it"
                        if($isMgmt){
	                        Start-WebSphereDmgr -DmgrProfileDir $this.ProfilePath `
	                        	-WebSphereAdministratorCredential $this.AdminCredential
                        } else {
                        	Start-WebSphereServer -ServerName $this.ServerName
                        }
                        $created = $true
                    } else {
                        Write-Warning "IBM WebSphere Profile was not installed correctly (Windows Service Does Not Exists).  Please check the installation logs"
                    }
				}
                if ($created) {
                    Write-Verbose ("WebSphere profile " + $this.ProfileName + " created/configured successfully")
                } else {
                    Write-Error "Unable to create the WebSphere Profile, please check WAS logs for more information"
                }
            } else {
                Write-Verbose "Uninstalling WebSphere Profile (Not Yet Implemented)"
            }
        } catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }
    
    # Tests if the resource is in the desired state.
    [bool] Test() {
        Write-Verbose "Checking WebSphere Profile configuration"
        $profileConfiguredCorrectly = $false
        $wasRsrc = $this.Get()
        
        if (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Present)) {
            if ($wasRsrc.ProfileName -eq $this.ProfileName) {
                if ((!$this.ProfilePath) -or (((Get-Item($wasRsrc.ProfilePath)).Name -eq 
                    (Get-Item($this.ProfilePath)).Name) -and (
                    (Get-Item($wasRsrc.ProfilePath)).Parent.FullName -eq 
                    (Get-Item($this.ProfilePath)).Parent.FullName))) {
                    Write-Verbose "WebSphere profile is configured correctly"
                    $profileConfiguredCorrectly = $true
                }
            }
        } elseif (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Absent)) {
            $profileConfiguredCorrectly = $true
        }

        if (!($profileConfiguredCorrectly)) {
            Write-Verbose "WebSphere profile not configured correctly"
        }
        
        return $profileConfiguredCorrectly
    }
    
     # Gets the resource's current state.
    [cIBMWebSphereAppServerProfile] Get() {
        $RetEnsure = [Ensure]::Absent
        $RetProfileName = $null
        $RetProfilePath = $null
        
        $RetInsDir = Get-IBMWebSphereAppServerInstallLocation ND
        Write-Verbose "WAS is installed at: $RetInsDir"
        if($RetInsDir -and (Test-Path($RetInsDir))) {
        	$RetProfilePath = Get-IBMWASProfilePath $this.ProfileName ND
            if ($RetProfilePath -and (Test-Path $RetProfilePath)) {
            	$RetProfileName = $this.ProfileName
            	$RetEnsure = [Ensure]::Present
            	Write-Verbose "Found Existing Profile $RetProfileName at $RetProfilePath"
            } else {
                Write-Verbose "No profiles found : $RetProfileName"
            }
        } else {
            Write-Verbose "IBM WebSphere Application Server is NOT Present"
        }
        
        $returnValue = @{
            WASAppServerHome = $RetInsDir
            ProfileName = $RetProfileName
            ProfilePath = $RetProfilePath
            Ensure = $RetEnsure
        }

        return $returnValue
    }
}