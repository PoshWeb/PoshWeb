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

$indexDataTypes = [string], [bool], [int], [datetime], [float], [double], [timespan]
$xrpcData = [Ordered]@{}

$xrpcDb = [Data.DataSet]::new()

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

    foreach ($xrpcObject in $xrpcOutput) {
        $xrpcType = $xrpcObject.'$type'
        if (-not $xrpcType) { continue }
        if (-not $xrpcdb.Tables[$xrpcType]) {
            $xrpcTable = $xrpcdb.Tables.Add($xrpcType)            
            $xrpcTable.Columns.AddRange(@(
                [Data.DataColumn]::new('record', [object], '', 'Hidden')
            ))
        }

        $newRow = $xrpcdb.Tables[$xrpcType].NewRow()
        $newRow.Record = $xrpcObject

        foreach ($property in $xrpcObject.psobject.properties) {
            if (-not $property.value.getType) { continue }
            $propertyType = $property.value.GetType()
            if ($propertyType -in $indexDataTypes) {
                if (-not $xrpcdb.Tables[$xrpcType].Columns[$property.Name]) {
                    $xrpcdb.Tables[$xrpcType].Columns.AddRange(@(
                        [Data.DataColumn]::new($property.name, $propertyType, '', 'Attribute')
                    ))
                }
            }  else {
                if (-not $xrpcdb.Tables[$xrpcType].Columns[$property.Name]) {
                    $xrpcdb.Tables[$xrpcType].Columns.AddRange(@(
                        [Data.DataColumn]::new($property.name, [object], '', 'Hidden')
                    ))
                }
            }
            $newRow.($property.Name) = $property.Value            
        }

        $xrpcdb.Tables[$xrpcType].Rows.Add($newRow)
    }
}

# All we need to do is run one file and redirect it's output:
. ./index.html.ps1 > ./index.html
Get-Item -Path ./index.html

if ($PSScriptRoot) { Pop-Location }