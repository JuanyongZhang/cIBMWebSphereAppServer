#requires -Version 5

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
        TempDir = 'C:\IBM\Temp'
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
    cIBMWebSphereAppServerFixpack WASFixpackInstall
    {
        Ensure = 'Present'
        WASEdition = 'ND'
        WebSphereInstallationDirectory = 'C:\IBM\WebSphere\AppServer'
        Version = '8.5.5.6'
        SourcePath = @('C:\Media\WAS855_FP\8.5.5-WS-WAS-FP0000006-part1.zip', 'C:\Media\WAS855_FP\8.5.5-WS-WAS-FP0000006-part2.zip')
        DependsOn= '[cIBMWebSphereAppServer]WASNDInstall'
    }
}
WASND
Start-DscConfiguration -Wait -Force -Verbose WASND