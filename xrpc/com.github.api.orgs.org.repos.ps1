<#
.SYNOPSIS
    Organization Repos
.DESCRIPTION
    Gets the public repos in this organization
#>
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


$projectsUrl = "https://api.github.com/orgs/$Organization/repos?per_page=100"



if (-not $script:Cache[$projectsUrl]) {
    $script:Cache[$projectsUrl] = Invoke-RestMethod -Uri $projectsUrl |
        Where-Object Name -notmatch '^.github'
}

$script:orgInfo = $script:Cache[$projectsUrl]

$script:orgInfo |
    Add-Member NoteProperty '$type' 'com.github.api.org.repo' -Force -PassThru
