if (-not $Site) { $site = [Ordered]@{} }
# We want to run any script in `/xrpc/`.

# Fun fact: this becomes our site data.

# We'll call each script that generates xrpc an "indexer"
# (because it generates an index of the content)
# Any `*.*.*.ps1` beneath /xrpc/ will be conisdered an indexer.

$nsidList = @()

$xrpcFiles = foreach ($xrpcIndexFile in 
    Get-ChildItem -Path $psScriptRoot -filter *.*.*.ps1 
) {
    # Let's get the script
    $xrpcScript = Get-Command $xrpcIndexFile.FullName

    # and run it in the current scope.
    $xrpcOutput = . $xrpcScript

    # To get the NSID, we just need to remove the extension.
    $xrpcNsid = $xrpcScript.Name -replace '\.ps1$'

    $nsidList += $xrpcNsid
    
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



@"
# xrpc

This website supports [xrpc](https://atproto.com/specs/xrpc).

Some of the data that drives this website is freely available with an easy lexical json api.

The following lexicons are supported:

$(
    @(
        foreach ($xrpcNsid in $nsidList) {
            "* [$xrpcNsid](/xrpc/$xrpcNsid)"
        }
    ) -join [Environment]::NewLine
)
"@ |
    ConvertFrom-Markdown |
        Select-Object -ExpandProperty Html
