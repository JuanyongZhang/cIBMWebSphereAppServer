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
                        $this.InstallMediaConfig = Join-Path -Path $PSScriptRoot -ChildPath "InstallMediaConfig\$ibmwasEdition-$wasVersion.xml"
                    }
                    if (!($this.ResponseFileTemplate)) {
                        $this.ResponseFileTemplate = Join-Path -Path $PSScriptRoot -ChildPath "ResponseFileTemplates\$ibmwasEdition-$wasVersion-template.xml"
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