<#
.SYNOPSIS
    Organization Info
.DESCRIPTION
    Gets information about this github organizations
.LINK
    https://docs.github.com/en/rest/repos/repos#list-organization-repositories
#>
[Reflection.AssemblyMetaData("Order", 1)]
param(
# The GitHub organization.
# This should default to the repository owner.
[string]$Organization = $(
    if ($env:GITHUB_REPOSITORY_OWNER) {
        $env:GITHUB_REPOSITORY_OWNER
    } else {
        'PoshWeb'
    }
)
)

if (-not $script:Cache) {
    $script:Cache = [Ordered]@{}
}


$orgInfoUrl = "https://api.github.com/orgs/$Organization"
if (-not $script:Cache[$orgInfoUrl]) {
    $script:Cache[$orgInfoUrl] = Invoke-RestMethod -Uri "https://api.github.com/orgs/$Organization"
}

$script:Cache[$orgInfoUrl] |
    Add-Member NoteProperty '$type' 'com.github.api.orgs.org' -Force -PassThru
