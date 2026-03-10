<#
.SYNOPSIS
    Gets stargazers 
.DESCRIPTION
    Gets stargazers for repositories in this organization.
#>
[OutputType('{"type": "object"}')]
param(
[string[]]
$StargazerCacheUrl = @(
    "https://poshweb.org/xrpc/org.poshweb.stargazers",
    "https://poshweb.org/PoshWeb.stargazers.json"    
)
)

if ($psScriptRoot) { Push-Location $psScriptRoot } 

$stargazersCache = foreach ($stargazerUrl in $StargazerCacheUrl) {
    try {
        Invoke-RestMethod $stargazerUrl -ErrorAction Stop
    } catch {
        continue
    }
}

$stargazers = [Ordered]@{
    PSTypeName='org.poshweb.stargazers'
    '$type' = 'org.poshweb.stargazers'
}
foreach ($property in $stargazersCache.psobject.properties) {    
    $stargazers[$property.Name] = @($property.Value)
}

$orgRepos = . ./com.github.api.orgs.org.repos.ps1

foreach ($repoInfo in $orgRepos) {
    if ($repoInfo.stargazers_count -ne 
        @($stargazers[$repoInfo.name] | ? { $_ }).count
    ) {
        # stargazer count has changed
        Write-Verbose "Getting Stargazers for $($repoInfo.Name)" -Verbose
        try {
            $repoStargazers = Invoke-RestMethod "$($repoInfo.stargazers_url)?per_page=100"
            if (-not $stargazers[$repoInfo.name]) {
                $stargazers[$repoInfo.name] = @()
            }
            $currentStargazers = $stargazers[$repoInfo.name].login
            $newStargazers = @(
                $repoStargazers |                    
                    Select-Object login, id, html_url, avatar_url |
                    Where-Object login -NotIn $currentStargazers
            )            
            
            if ($newStargazers) {
                Write-Verbose "New Stargazers for $($repoInfo.Name): $($newStargazers.login)" -Verbose
                $stargazers[$repoInfo.name] = 
                    @($newStargazers + $stargazers[$repoInfo.name])
            }            
        } catch {
            Write-Warning "Could not get stargazers for $($repoInfo.Name): $_"
        }
    }
}

[PSCustomObject]$stargazers

if ($psScriptRoot) { Pop-Location } 

