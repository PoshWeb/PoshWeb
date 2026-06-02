<#
.SYNOPSIS
    Deploy the site
.DESCRIPTION
    Builds and deploys static website
.NOTES
    All you really need to build a page is a simple script or two.

    Simply make a workflow that calls this script, and let it do the rest.
    
    This is an example of technique, not a tool you have to use.

    Feel free to copy, paste, and modify this as needed.

    Ideally, please modify the notes to what this script does.
    
    ---    

    In this site, we're making some xrpc endpoints to restfully expose data.

    Then, we're making a page for this organization.

    This should work for any GitHub organization.
#>
param()

# Make sure we're in the current location
if ($PSScriptRoot) { Push-Location $psScriptRoot }

# Declare a simple dictionary to store site data
$site = [Ordered]@{}

#region Clock Speed

# First, let's get the clock speed.
# Most sites won't need to know this,
# but part of the point of _this_ site is the speed of deployment.

$cpuSpeed = 
    if ($executionContext.SessionState.PSVariable.Get('IsLinux').Value) {
        Get-Content /proc/cpuinfo -Raw -ErrorAction SilentlyContinue | 
            Select-String "(?<Unit>Mhz|MIPS)\s+\:\s+(?<Value>[\d\.]+)" | 
            Select-Object -First 1 -ExpandProperty Matches |
            ForEach-Object {
                $_.Groups["Value"].Value -as [int]
            }
    } elseif ($executionContext.SessionState.PSVariable.Get('IsMacOS').Value) {
        (sysctl -n hw.cpufrequency) / 1e6 -as [int]
    } else {
        $getCimInstance = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-CimInstance','Cmdlet')
        if ($getCimInstance) {
            & $getCimInstance -Class Win32_Processor |
                Select-Object -ExpandProperty MaxClockSpeed
        }
    }
#endregion Clock Speed

#region eponyms

# To make things relatively easy, we'll treat eponym scripts as an index
# For example, if there's a directory called `/xrpc`, `/xrpc.ps1` should
# generate any content in that directory, and return html.

# We will go thru paths in reverse alphabetical format. 

$eponyms =
    @(foreach (
        $directory in Get-ChildItem -Directory -Recurse |
            Sort-Object FullName -Descending
    ) {
        $eponymPath = Join-Path $directory.FullName "$($directory.Name).ps1"
        if (Test-Path $eponymPath) {
            $ExecutionContext.SessionState.InvokeCommand.GetCommand(
                $eponymPath, 'ExternalScript'
            )
        }
    })

foreach ($eponym in $eponyms) {
    $eponymFile =
        $eponym.Source -replace
            "$([Regex]::Escape($eponym.Name))$",
                "index.html"

    . $eponym > $eponymFile
    Get-Item -Path $eponymFile
}
#endregion run eponyms

#region Copy GitHub workflows to `/workflows`

# This site is a useful living example of how to make sites free of frameworks
# So let's make any workflows we use to build it available on the page.

# First get our workflows
$gitHubWorkflows = Get-ChildItem -Path .github -Force | 
    Where-Object Name -EQ workflows

# and if we had any workflows
if ($gitHubWorkflows) {
    # make a ./workflows directory 
    if (-not (Test-Path './workflows')) {
        New-Item -ItemType Directory -Path ./workflows -Force
    }
    # and copy the workflows to the right place.
    $gitHubWorkflows |Get-ChildItem |
        Copy-Item -Destination ./workflows -PassThru
}

#endregion Copy GitHub workflows to `/workflows`

# Build our index:
. ./index.html.ps1 > ./index.html
# and get the file
Get-Item -Path ./index.html

if ($PSScriptRoot) { Pop-Location }