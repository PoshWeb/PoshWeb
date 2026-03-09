<#
.SYNOPSIS
    Gets lexicons 
.DESCRIPTION
    Gets the lexicons supported by this server.
.NOTES
    In this server's case, all lexicon contents are dynamic static.

    Each time the site is built, the lexicons will be refreshed.
#>
[OutputType('{
    "type": "object",
    "required": ["lexicon"],
    "properties": {                        
        "lexicon": {
            "type": "object",
            "description": "The lexicon"
        }
    }
}')]
param()

filter toLexicon {
    $lexiconScript = $_
    $lexiconHelp = Get-Help $lexiconScript.Source

    $lexiconOutputSchema = @($lexiconScript.OutputType.Name) -match '^\{' | ConvertFrom-Json

    [Ordered]@{
        lexicon = 1
        id = $lexiconScript.Name -replace '\.ps1$'
        defs = [Ordered]@{
            main = [Ordered]@{
                type = "query"
                description = $lexiconHelp.description.text -join [Environment]::NewLine
                parameters = [Ordered]@{}
                output = if ($lexiconOutputSchema) {
                    [Ordered]@{
                        encoding = 'application/json'
                        schema = $lexiconOutputSchema
                    }
                } else {
                    [Ordered]@{
                        encoding = 'application/json'
                    }
                }
            }
        }
    }
}

$lexiconScripts = Get-ChildItem -Path $PSScriptRoot -Filter *.*.*.ps1 | Get-Command { $_.FullName}
foreach ($lexiconScript in $lexiconScripts) {
    [PSCustomObject]@{
        PSTypeName = 'org.poshweb.lexicon'
        '$type' = 'org.poshweb.lexicon'
        lexicon = $lexiconScript | toLexicon
    }
}



