<#
.SYNOPSIS
    Organization Public Members
.DESCRIPTION
    Gets the public members in this organization.
.LINK
    https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#list-public-organization-members
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


$orgMembersUrl = "https://api.github.com/orgs/$Organization/public_members?per_page=100"
if (-not $script:Cache[$orgMembersUrl]) {
    $script:Cache[$orgMembersUrl] = Invoke-RestMethod -Uri $orgMembersUrl
}

$script:Cache[$orgMembersUrl] |
    Add-Member NoteProperty '$type' 'com.github.api.org.member' -Force -PassThru
