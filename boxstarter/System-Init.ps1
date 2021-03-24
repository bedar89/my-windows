#1. Install Chocolatey
<#
Set-ExecutionPolicy RemoteSigned -Force

# Create empty profile (so profile-integration scripts have something to append to)
if (-not (Test-Path $PROFILE)) {
    $directory = [IO.Path]::GetDirectoryName($PROFILE)
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory $directory | Out-Null
    }
    
    "# Profile" > $PROFILE
}

iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco feature enable -n=allowGlobalConfirmation
choco feature enable -n=useRememberedArgumentsForUpgrades

# Copy chocolatey.license.xml to C:\ProgramData\chocolatey\license

cinst chocolatey.extension
cinst boxstarter

#>
# 2. Run with this:
<#
$cred=Get-Credential domain\username
Install-BoxstarterPackage -PackageName https://raw.githubusercontent.com/bedar89/my-windows/master/boxstarter/System-Init.ps1 -Credential $cred
#>

# https://github.com/mwrock/boxstarter/issues/241#issuecomment-336028348
New-Item -Path "c:\temp" -ItemType directory -Force | Out-Null

Update-ExecutionPolicy RemoteSigned
Set-WindowsExplorerOptions -EnableShowFileExtensions -EnableExpandToOpenFolder

# No SMB1 - https://blogs.technet.microsoft.com/filecab/2016/09/16/stop-using-smb1/
Disable-WindowsOptionalFeature -Online -FeatureName smb1protocol

Enable-RemoteDesktop

# NuGet package provider. Do this early as reboots are required

if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Install-PackageProvider"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    
    # Exit equivalent
    Invoke-Reboot
}


# Install initial version of PowerShellGet
if (-not (Get-InstalledModule -Name PowerShellGet -ErrorAction SilentlyContinue)) {
    Write-Host "Install-Module PowerShellGet"
    Install-Module -Name "PowerShellGet" -AllowClobber -Force

    # Exit equivalent
    Invoke-Reboot
}

# Upgrade to latest version (> 2.2)
if (Get-InstalledModule -Name PowerShellGet | Where-Object { $_.Version -le 2.2 } ) {
    #Write-Host "Update-Module PowerShellGet"
    
    # Unload this first to avoid 
    #Write-Host "Removing in-use modules"
    #Remove-Module PowerShellGet -Force
    #Remove-Module PackageManagement -Force
    
    # This fails due to "module 'PackageManagement' is currently in use" error. Don't think there's a way around this.
    #PowerShellGet\Update-Module -Name PowerShellGet -Force

    # Exit equivalent
    #Invoke-Reboot
}

# Windows features
cinst NetFx3 TelnetClient Microsoft-Hyper-V-All IIS-WebServerRole IIS-NetFxExtensibility45 IIS-HttpCompressionDynamic IIS-WindowsAuthentication IIS-ASPNET45 IIS-IIS6ManagementCompatibility Containers -source windowsfeatures --cacheLocation="c:\temp"

#--- Uninstall unwanted default apps ---
$applicationList = @(	
    "Microsoft.3DBuilder"
    "Microsoft.CommsPhone"
    "Microsoft.Getstarted"
    "*MarchofEmpires*"
    "Microsoft.GetHelp"
    "Microsoft.Messaging"
    "*Minecraft*"
    "Microsoft.MicrosoftOfficeHub"
    # "Microsoft.WindowsPhone"
    "*Solitaire*"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.Office.Sway"
    # "Microsoft.XboxApp"
    # "Microsoft.XboxIdentityProvider"
    "Microsoft.NetworkSpeedTest"
    "Microsoft.Print3D"

    #Non-Microsoft
    "*Autodesk*"
    "*BubbleWitch*"
    "king.com.CandyCrush*"
    "*Dell*"
    "*Dropbox*"
    "*Facebook*"
    "*Keeper*"
    # "*Plex*"
    "*.Duolingo-LearnLanguagesforFree"
    "*.EclipseManager"
    "ActiproSoftwareLLC.562882FEEB491" # Code Writer
    "*.AdobePhotoshopExpress");

foreach ($app in $applicationList) {
    Remove-App $app
}


############################################
#                                          #
# SYSTEM INIT SCRIPT                       #
#                                          #
# Author: Nikita Tchayka (@nickseagull)    #
#                                          #
# Run with Install-BoxstarterPackage       #
#  Install-BoxStarterPackage -PackageName  #
#  <this script> -DisableReboots           #
############################################
Checkpoint-Computer -Description "Clean install" -RestorePointType "MODIFY_SETTINGS" # Create a restore point
Set-ExecutionPolicy RemoteSigned
Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowProtectedOSFiles -EnableShowFileExtensions

############################################
#                                          #
# U T I L I T Y   F U N C T I O N S        #
#                                          #
############################################

############################################
#                                          #
# S E T U P   D I R E C T O R I E S        #
#                                          #
############################################
mkdir $env:USERPROFILE\Projects

############################################
#                                          #
# P A C K A G E S   L I S T                #
#                                          #
############################################
cinst autohotkey
cinst vscode
cinst microsoft-windows-terminal
cinst LinkShellExtension
cinst slack
#cinst spotify
cinst discord
cinst windowsfirewallcontrol
cinst git
cinst powershell-core
cinst vcxsrv
cinst obs-studio
cinst screentogif
cinst vlc

# # Command line tools
# cinst awscli
# cinst bat
# cinst RunInBash
# cinst bottom
# cinst fzf
# cinst fd
# cinst ripgrep
# cinst sd

############################################
#                                          #
# D E F E N D E R   E X C L U S I O N S    #
#                                          #
############################################

# Folder exclusions
@(

  "$env:USERPROFILE\Projects"

) | ForEach-Object {
  Add-MpPreference -ExclusionPath $_
}

# Process exclusions
@(

  "emacs",
  "npm",
  "node",
  "yarn",
  "git",
  "stack",
  "ghc",
  "nix"

) | ForEach-Object {
  Add-MpPreference -ExclusionProcess $_
}

# Add WSL paths to exclusions
$wslPaths = (Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | ForEach-Object { Get-ItemProperty $_.PSPath }).BasePath
$currentExclusions = $(Get-MpPreference).ExclusionPath
if (!$currentExclusions) {
  $currentExclusions = ''
}
$exclusionsToAdd = ((Compare-Object $wslPaths $currentExclusions) | Where-Object SideIndicator -eq "<=").InputObject
$dirs = @("\bin", "\sbin", "\usr\bin", "\usr\sbin", "\usr\local\bin", "\usr\local\go\bin")
if ($exclusionsToAdd.Length -gt 0) {
  $exclusionsToAdd | ForEach-Object {
    Add-MpPreference -ExclusionPath $_
    Write-Output "Added exclusion for $_"
    $rootfs = $_ + "\rootfs"
    $dirs | ForEach-Object {
      $exclusion = $rootfs + $_ + "\*"
      Add-MpPreference -ExclusionProcess $exclusion
      Write-Output "Added exclusion for $exclusion"
    }
  }
}

############################################
#                                          #
# S E T U P   MYWINDOWS   S E T T I N G S  #
#                                          #
############################################
git clone https://github.com/bedar89/my-windows $env:USERPROFILE\Projects\my-windows
