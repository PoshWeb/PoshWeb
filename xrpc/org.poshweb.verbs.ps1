<#
.SYNOPSIS
    Gets PowerShell modules
.DESCRIPTION
    Gets a snapshot of PowerShell modules from the gallery
#>
[OutputType('{
    "type": "object",
    "required": ["verb", "description", "group"],
    "properties": {
        "verb": {
            "type": "string",
            "description": "The verb"
        },
        "description": {
            "type": "string",
            "description": "The description"
        },
        "group": {
            "type": "string",
            "description": "The verb group"
        },
        "aliasPrefix": {
            "type": "string",
            "description": "The alias prefix"
        }
    }
}')]
param(
    
)


$myOutputSchema = $MyInvocation.MyCommand.OutputType -match '^{' | ConvertFrom-Json
$myOutputProperties = $myOutputSchema.properties.psobject.properties.name


foreach ($verb in Get-Verb) {
    $outputObject = [Ordered]@{}
    foreach (
        $propertyName in $myOutputProperties
    ) {
        $propertyInfo = $verb.psobject.properties[$propertyName]
        
        if (-not $propertyInfo) { continue }
        $propertyData = $propertyInfo.Value

        if ($propertyData) {
            $outputObject[$propertyName] = $propertyData
        }
    }
    
    [PSCustomObject]$outputObject
}   
