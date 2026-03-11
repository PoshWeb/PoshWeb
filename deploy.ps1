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

# We'll cache our xrpc data first
# Fun fact: this becomes our site data.
$site = [Ordered]@{}

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

# All we need to do is run one file and redirect it's output:
. ./index.html.ps1 > ./index.html
Get-Item -Path ./index.html

# This site is a useful living example of how to make sites free of frameworks
# So let's make any workflows we use to build it available on the page.

# First get our workflows
$gitHubWorkflows = Get-ChildItem -Path .github -Force | 
    Where-Object Name -EQ workflows

# and if we had any
if ($gitHubWorkflows) {
    # make a ./workflows directory if we need to
    if (-not (Test-Path './workflows')) {
        New-Item -ItemType Directory -Path ./workflows -Force
    }
    # copy them to ./workflows.
    $gitHubWorkflows | Copy-Item -Destination ./workflows -PassThru
}

if ($PSScriptRoot) { Pop-Location }