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

#region index data in `/xrpc/`

# We want to run any script in `/xrpc/`.

# Fun fact: this becomes our site data.

# We'll call each script that generates xrpc an "indexer"
# (because it generates an index of the content)
# Any `*.*.*.ps1` beneath /xrpc/ will be conisdered an indexer.
foreach ($xrpcIndexFile in 
    Get-ChildItem -Path $psScriptRoot -Filter xrpc | 
    Get-ChildItem -filter *.*.*.ps1 
) {
    # Let's get the script
    $xrpcScript = Get-Command $xrpcIndexFile.FullName

    # and run it in the current scope.
    $xrpcOutput = . $xrpcScript

    # To get the NSID, we just need to remove the extension.
    $xrpcNsid = $xrpcScript.Name -replace '\.ps1$'
    
    # Once we know the NSID, we can start to construct the directory.
    $xrpcOutputDirectory = Join-Path $xrpcIndexFile.Directory (
        $xrpcNsid
    )
    
    # Fun fact number #2:
    # We can use an index.json file to return static json.
    # This eliminates most of the server side load. 
    $xrpcOutputFile = Join-Path $xrpcOutputDirectory "index.json"

    # All we have to do is cache our results into a json file
    # and now our site can serve them up.
    New-Item -ItemType File -Path $xrpcOutputFile -Value (
        $xrpcOutput | ConvertTo-Json -Depth 10
    ) -Force
    
    # Before we move onto the next indexer,
    # let's save our site data.
    $site[$xrpcNsid] = $xrpcOutput
}

#endregion index data in `/xrpc/`

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