<#
.Synopsis
   Creates folders for use by other checks and scripts and will trigger an 
   alert if creating the folders fails or error files are found. Reports a
   count of files in other folders. Also creates a Windows application event
   log source for other scripts to use. Adds system variables to be used by
   other scripts.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Edit $RMMBase to
   change the base folder location.
   
.EXAMPLE
   pccCheck-RMMFolders.ps1
.OUTPUTS
   Creates folders and will genereate output for the dashboard.
.EMAIL
   vand@parseccomputer.com
.VERSION
   1.1
#>
param (
    # Accept -logfile for MaxRM script runner 
    [Parameter(Mandatory=$false)]
    [string]
    $logfile
)

# Set error and warning preferences
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Force output to keep MaxRM from timing out
Write-Host " "

# Create hashtable for output
[hashtable]$Return = @{}

# Start an error counter so MaxRM will correctly error on failure
[int]$ErrorCount = '0'

# Check if NuGet is registered as a package provider and install it if it is not
try {
    $NuGet = Get-PackageProvider | Where-Object Name -EQ NuGet
        if (! $NuGet) {
            Write-Host 'NuGet not installed - Fixing'
            $Return.NuGet = Install-PackageProvider -Name NuGet -Force -Verbose 4>&1
            }
        else {
            $Return.Nuget = $NuGet | Select-Object Name,Version
            }
    }
    catch [EXCEPTION] {
        $Return.Nuget_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
    }

# Check if PSGallery is a repository location and that it is trusted to make installs easier
try {
    $Repository = Get-PSRepository | Where-Object Name -EQ PSGallery
        if (! $Repository) {
            Write-Host 'PSGallery not installed - Fixing'
            $Return.Repository = Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2/ -PublishLocation `
             https://www.powershellgallery.com/api/v2/package/ -ScriptSourceLocation https://www.powershellgallery.com/api/v2/items/psscript/ `
             -ScriptPublishLocation https://www.powershellgallery.com/api/v2/package/ -InstallationPolicy Trusted -PackageManagementProvider NuGet `
             -Verbose 4>&1
            }
        elseif ($Repository.InstallationPolicy -eq "Untrusted") {
            Write-Host 'PSGallery not trusted - Fixing'
            $Return.Repository = Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -Verbose 4>&1
            }
        else {
            $Return.Repository = "PSGallery installed and trusted"
            }
    }
    catch [EXCEPTION] {
        $Return.Repository_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
        }

# Check if Carbon module is installed
try {
    $CarbonInstall = Get-InstalledModule | Where-Object Name -EQ Carbon
        if (! $CarbonInstall) {
            Write-Host 'Carbon module not installed - Fixing'
            $Return.CarbonInstall = Find-Module -Name Carbon | Install-Module -AllowClobber -Force -Verbose 4>&1
        }
    else {
        $Return.CarbonInstall = $CarbonInstall  | Select-Object Name,Version
        }
    }
    catch  [EXCEPTION] {
        $Return.CarbonInstall_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
        }

# Import Carbon module
try {
    Import-Module -Name Carbon -Force 
    $CarbonImport = Get-Module -Name Carbon
    if (! $CarbonImport) {
        $Return.CarbonImport = "Carbon module import failed"
        $ErrorCount = $ErrorCount + 1
    }
    else {
        $Return.CarbonImport = $CarbonImport | Select-Object Name,Version
    }
    }
    catch {
        $Return.CarbonImport_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
    }

# List of folders to check for and create the folders if they don't exist
$RMMBase = $env:SystemDrive + "\Parsec_MSP"
$ErrorPath = $RMMBase + "\Errors"
$LogPath = $RMMBase + "\Logs"
$ReportPath = $RMMBase + "\Reports"
$StagingPath = $RMMBase + "\Staging"
$OptionalFolders = $LogPath,$ReportPath,$StagingPath
$RMMEventSource = "Parsec"

try {
    if (! (Test-Path -Path $RMMBase)) {
        $Return.Parsec_MSP_Create = New-Item $RMMBase -ItemType Directory | ForEach-Object {$_.Attributes="hidden"}
        }

    if (! (Test-Path -Path $ErrorPath)) {
        $Return.RMM_Error_Create = New-Item $ErrorPath -ItemType Directory
        }

    foreach ($item in $OptionalFolders) {
            if (! (Test-Path -Path $item)) {
                $ReturnItem = $item + "_Create"
                $Return.$ReturnItem = New-Item $item -ItemType Directory
            }
        }
    
    if (Test-Path $ErrorPath) {
        $Return.Folder_Check = "Error folder exists"
    }

    else {
        $Return.Folder_Check = "Error folder missing"
        $ErrorCount = $ErrorCount + '1'
    }
    
    if ( [System.Diagnostics.EventLog]::SourceExists( "$RMMEventSource" )) {
        $Return.EventLog = "$RMMEventSource event source exists"
    }

    else {
        $Return.EventLog = "Creating $RMMEventSource event log source"
        [System.Diagnostics.EventLog]::CreateEventSource( $RMMEventSource, "Application" )
        $ErrorCount = $ErrorCount + '1'
    }

}
catch [EXCEPTION] {
    $Return.Folder_Check_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + '1'    
}

# Check for system variables and add them if they don't exist

try {
    if (! ($env:RMMFolder -eq $RMMBase)) {
        $Return.RMMFolder_Envirionment = "Attempting to create RMMFolder"
        Set-EnvironmentVariable -Name 'RMMFolder' -Value $RMMBase -ForComputer -Force
        $ErrorCount = $ErrorCount + 1
    }
    if (! ($env:RMMErrorFolder -eq $ErrorPath)) {
        $Return.RMMErrorFolder_Envirionment = "Attempting to create RMMErrorFolder"
        Set-EnvironmentVariable -Name 'RMMErrorFolder' -Value $ErrorPath -ForComputer -Force
        $ErrorCount = $ErrorCount + 1
    }
}
catch {
    $Return.Environment_Variable_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + '1'
}

# Check to see if an error files exist and write their content
try {
    $ErrorFiles = Get-ChildItem $ErrorPath
    if ($ErrorFiles.Count -ge 1) {
        $Return.Error_Files = "Error files found = " + $ErrorFiles.Count
        Write-Host "Errors Found!"
        foreach ($item in $ErrorFiles) {
            Write-Host " "
            Write-Host "-----------------------------------"
            Write-Host $item.Name
            Get-Content -Path $ErrorPath\$item | Write-Host
            Write-Host "-----------------------------------"
            Write-Host " "
            $ErrorCount = $ErrorCount + '1'
            }
    }
    else {
        $Return.Error_Files = "No error files found"
    }    
}
catch [EXCEPTION] {
    $Return.Error_Files_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + '1'
}

# Return a count of other items for information
try {
    foreach ($item in $OptionalFolders) {
        $myFiles = Get-ChildItem $item
        $Return.$item = "Files found:  " + $myFiles.count
    }
}
catch [EXCEPTION] {
    $Return.Other_Check_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + '1'
}

# Return output and create alert if needed
$Return.Error_Count = $ErrorCount
if ($ErrorCount -eq 0) {
Write-Output @"
 
Check Passed
Troubleshooting info below
_______________________________
 
"@
$Return | Format-List
Exit 0
}
else {
    $Error.Clear() | Out-Null
        [string]$ErrorString = "Check Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
}