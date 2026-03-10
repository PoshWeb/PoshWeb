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

    For example, this script is _really_ simple.

    In this case we're building a single page site.
    
    This means this script is _very_ short.
#>
param()

if ($PSScriptRoot) { Push-Location $psScriptRoot }

$xrpcData = [Ordered]@{}

foreach ($xrpcIndexFile in 
    Get-ChildItem -Path $psScriptRoot -Filter xrpc | 
    Get-ChildItem -filter *.*.*.ps1 
) {
    $xrpcScript = Get-Command $xrpcIndexFile.FullName
    $xrpcOutput = . $xrpcScript

    $xrpcNsid = $xrpcScript.Name -replace '\.ps1$' 

    $xrpcOutputDirectory = Join-Path $xrpcIndexFile.Directory (
        $xrpcNsid
    )
    
    $xrpcOutputFile = Join-Path $xrpcOutputDirectory "index.json"
    New-Item -ItemType File -Path $xrpcOutputFile -Value (
        $xrpcOutput | ConvertTo-Json -Depth 10
    ) -Force
    
    $xrpcData[$xrpcNsid] = $xrpcOutput
}

# All we need to do is run one file and redirect it's output:
. ./index.html.ps1 > ./index.html
Get-Item -Path ./index.html

if ($PSScriptRoot) { Pop-Location }