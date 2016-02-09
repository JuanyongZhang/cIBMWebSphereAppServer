#cIBMWebSphereAppServer

PowerShell CmdLets and Class-Based DSC resources to manage IBM WebSphere Application Server (WAS) on Windows Environments.

To get started using this module just type the command below and the module will be downloaded from [PowerShell Gallery](https://www.powershellgallery.com/packages/cIBMWebSphereAppServer/)
```shell
PS> Install-Module -Name cIBMWebSphereAppServer
```

**Coming Soon:** _Profile generation and WSAdmin CmdLets_ Subscribe to this repo to get notified.

## Resources

* **cIBMWebSphereAppServer** installs IBM WebSphere Application Server on target machine.

### cIBMWebSphereAppServer

* **Ensure**: (Required) Ensures that WAS is Present or Absent on the machine.
* **Version**: (Key) The version of WAS to install
* **WASEdition**: (Key) The edition of WAS to install.  Options: BASE, ND, EXPRESS, DEVELOPER, LIBERTY
* **InstallationDirectory**: Installation path.  Default: C:\IBM\WebSphere\AppServer.
* **IMSharedLocation**: Location of the IBM Installation Manager cache.  Default: C:\IBM\IMShared
* **InstallMediaConfig**: (Optional) Path to the clixml export of the IBMProductMedia object that contains media configuration.
* **ResponseFileTemplate**: (Optional) Path to the response file template to use for the installation.
* **SourcePath**: UNC or local file path to the directory where the IBM installation media resides.
* **SourcePathCredential**: (Optional) Credential to be used to map sourcepath if a remote share is being specified.

_Note_ InstallMediaConfig and ResponseFileTemplate are useful parameters when there's no built-in support for the WAS edition you need to install or when you have special requirements based on how your media is setup or maybe you have unique response file template needs.
If you create your own Response File template it is expected that the template has the variables: **sharedLocation** and **wasInstallLocation**.  See sample response file template before when planning to roll out your own.

## Depedencies
* [cIBMInstallationManager](http://github.com/dennypc/cIBMInstallationManager) DSC Resource/CmdLets for IBM Installation Manager
* [7-Zip](http://www.7-zip.org/ "7-Zip") needs to be installed on the target machine.  You can add 7-Zip to your DSC configuration by using the Package
DSC Resource or by leveraging the [x7Zip DSC Module](https://www.powershellgallery.com/packages/x7Zip/ "x7Zip at PowerShell Gallery")

## Versions

### 1.0.0

* Initial release with the following resources 
    - cIBMWebSphereAppServer

## Testing

The table below outlines the tests that various WAS editions/versions have been verify to date.  As more configurations are tested there should be a corresponding entry for Media Configs and Response File Templates.  Could use help on this, pull requests welcome :-)

| WAS Version | Operating System               | BASE | ND | EXPRESS | DEVELOPER | LIBERTY |
|-------------|--------------------------------|------|----|---------|-----------|---------|
| v8.5.5      |                                |      |    |         |           |         |
|             | Windows 2012 R2 (64bit)        |      |  x |         |           |         |
|             | Windows 10 (64bit)             |      |  x |         |           |         |
|             | Windows 2008 R2 Server (64bit) |      |    |         |           |         |


## Media Files

The installation depents on media files that have already been downloaded.  In order to get the media files please check your IBM Passport Advantage site.

The table below shows the currently supported (i.e. tested) media files.

| WAS Version | WAS Edition | Media Files           |
|-------------|-------------|-----------------------|
| v8.5.5      |             |                       |
|             | ND          | WASND_v8.5.5_1of3.zip |
|             |             | WASND_v8.5.5_2of3.zip |
|             |             | WASND_v8.5.5_3of3.zip |

## Examples

### Install WAS Network Deployment Edition

This configuration will install [7-Zip](http://www.7-zip.org/ "7-Zip") using the DSC Package Resource, install/update IBM Installation Manager
and finally install IBM WebSphere Application Server Network Deployment edition

Note: This requires the following DSC modules:
* xPsDesiredStateConfiguration
* cIBMInstallationManager

```powershell
Configuration WASND
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DSCResource -ModuleName 'cIBMInstallationManager'
    Import-DSCResource -ModuleName 'cIBMWebSphereAppServer'
    Package SevenZip {
        Ensure = 'Present'
        Name = '7-Zip 9.20 (x64 edition)'
        ProductId = '23170F69-40C1-2702-0920-000001000000'
        Path = 'C:\Media\7z920-x64.msi'
    }
    cIBMInstallationManager IIMInstall
    {
        Ensure = 'Present'
        InstallationDirectory = 'C:\IBM\IIM'
        Version = '1.8.3'
        SourcePath = 'C:\Media\agent.installer.win32.win32.x86_1.8.3000.20150606_0047.zip'
        DependsOn= '[Package]SevenZip'
    }
    cIBMWebSphereAppServer WASNDInstall
    {
        Ensure = 'Present'
        WASEdition = 'ND'
        InstallationDirectory = 'C:\IBM\WebSphere\AppServer'
        Version = '8.5.5'
        SourcePath = 'C:\Media\WASND855\'
        DependsOn= '[cIBMInstallationManager]IIMInstall'
    }
}
WASND
Start-DscConfiguration -Wait -Force -Verbose WASND
```