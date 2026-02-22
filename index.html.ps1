<#
.SYNOPSIS
    GitHub Organization Summary
.DESCRIPTION
    Builds a page that shows a GitHub organization's summary
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
),

# The location of a list of color palettes.
[uri]
$PaletteListSource = 'https://4bitcss.com/Palette-List.json',

# The Palette CDN.  This is the root URL of all palettes.
[uri]
$PaletteCDN = 'https://cdn.jsdelivr.net/gh/2bitdesigns/4bitcss@latest/css/',

# The identifier for the palette `<select>`.
[string]
$SelectPaletteId = 'SelectPalette',

# The identifier for the stylesheet.  By default, palette.
[string]
$PaletteId = 'palette',

[string]
$DefaultPalette = $(
    if ($page.Palette) {
        $page.Palette
    } elseif ($site.Palette) {
        $site.Palette
    }
    else {
        'Konsolas'
    }
),

# If set, will not render the build time.
[switch]
$NoBuildTime,

# If set, will not highlight content.
[switch]
$NoHighlight
)

#region Collect Information

# We need to collect a few pieces of information to build this page.
# To be polite, we want to cache results.
# To get an accurate sense of timing the build itself, 
# we want to collect all RESTful information first.

if (-not $script:orgInfo) {
    $script:orgInfo = Invoke-RestMethod -Uri "https://api.github.com/orgs/$Organization"
}

if (-not $script:orgProjects) {
    $script:OrgProjects = Invoke-RestMethod -Uri "https://api.github.com/orgs/$Organization/repos?per_page=100" |
        Where-Object Name -notmatch '^.github'
}

if (-not $script:paletteList) {
    $script:paletteList = Invoke-RestMethod -Uri $PaletteListSource
}

#endregion Collect Information
Push-Location $PSScriptRoot


#region Clock Speed
$cpuSpeed = 
    if ($executionContext.SessionState.PSVariable.Get('IsLinux').Value) {
        Get-Content /proc/cpuinfo -Raw -ErrorAction SilentlyContinue | 
            Select-String "(?<Unit>Mhz|MIPS)\s+\:\s+(?<Value>[\d\.]+)" | 
            Select-Object -First 1 -ExpandProperty Matches |
            ForEach-Object {
                $_.Groups["Value"].Value -as [int]
            }
    } elseif ($executionContext.SessionState.PSVariable.Get('IsMacOS').Value) {
        (sysctl -n hw.cpufrequency) / 1e6 -as [int]
    } else {
        $getCimInstance = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-CimInstance','Cmdlet')
        if ($getCimInstance) {
            & $getCimInstance -Class Win32_Processor |
                Select-Object -ExpandProperty MaxClockSpeed
        }
    }
#endregion Clock Speed

$start = [DateTime]::UtcNow

#region Define Controls

# We can make any single page application by combining controls.

# You don't have to declare them in order, but it certainly helps.

#region OrgInfo
$ShowOrgInfo = @{
    html = @(
        "<h1>$([Web.HttpUtility]::HtmlEncode($Organization))</h1>"
        if ($orgInfo.description) {
            "<h2>$([Web.HttpUtility]::HtmlEncode($orgInfo.description))</h2>"    
        }
    )
}
#endregion OrgInfo

#region Select-Palette
$selectPalette = @{
    js = @"
function SetPalette() {
    var palette = document.getElementById('$PaletteId')
    if (! palette) {
        palette = document.createElement('link')
        palette.rel = 'stylesheet'
        palette.id = '$PaletteId'
        document.head.appendChild(palette)
    }
    var selectedPalette = document.getElementById('$SelectPaletteId').value
    palette.href = '$PaletteCDN' + selectedPalette + '.css'        
}
"@
    css = @"
.Select-Palette {
    text-align: center;
}
"@

    html = @"
<section class='Select-Palette'>
    <label for='$SelectPaletteId'>Palette</label>
    <br/>    
    <select id='$SelectPaletteId' onchange='SetPalette()'>
$(
    if (-not $script:PaletteList) {
        $script:PaletteList = Invoke-RestMethod $PaletteListSource
    }
    foreach ($paletteName in $script:PaletteList) {
        $selectedPalette = if ($defaultPalette -and $defaultPalette -eq $paletteName) { " selected='true'"} else { '' }
        "<option value='$([Web.HttpUtility]::HtmlAttributeEncode($paletteName))'$selectedPalette>$([Web.HttpUtility]::HtmlEncode($paletteName))</option>"
    }
)
</select>
</section>
"@
}
#endregion Select-Palette

#region Get-RandomPalette
$GetRandomPalette = @{
    JavaScript = @"   
function GetRandomPalette() {
    var SelectPalette = document.getElementById('$SelectPaletteId')
    if (SelectPalette) {
        var randomNumber = Math.floor(Math.random() * SelectPalette.length);
        SelectPalette.selectedIndex = randomNumber
        SetPalette()
    }    
}
"@
    CSS = @"
.Get-RandomPalette { text-align: center }
"@
    HTML = @"
<section class='Get-RandomPalette'>
    <button onclick='GetRandomPalette()'>Random Palette</button>
</section>
"@

}
#endregion Get-RandomPalette

#region Repository Grid
$RepoGrid = [Ordered]@{
    css = @"
.github-repos {
    display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2.5em; margin: 2.5em
}

.github-repo-sorter {
    font-size: 1.5em; text-align: center
}

.repo-thumbnail { max-width: 100%; height: auto; }
"@
    html = @(
@"
<h4>Repositories</h4>
<div class='github-repo-sorter'>
Sort by:
<select id='sort-repos'>
    <option value='repoRandom'>Random</option>
    <option value='repoStars' selected>Stars</option>
    <option value='repoUpdatedAt'>Updated At</option>
    <option value='repoCreatedAt'>Created At</option>
    <option value='repoOpenIssues'>Open Issues</option>
    <option value='repoForks'>Forks</option>
    <option value='repoName'>Name</option>
    <option value='repoWatchers'>Watchers</option>
</select>
</div>
"@

"<div class='github-repos'>"
foreach ($repoInfo in $script:OrgProjects | Sort-Object stargazers_count -Descending) {
    $attributes = [Ordered]@{
        'class' = 'github-repo'
        'data-repo-name' = $repoInfo.Name
        'data-repo-url' = $repoInfo.html_url
        'data-repo-stars' = $repoInfo.stargazers_count
        'data-repo-forks' = $repoInfo.forks_count
        'data-repo-watchers' = $repoInfo.watchers_count
        'data-repo-open-issues' = $repoInfo.open_issues_count
        'data-repo-created-at' = $repoInfo.created_at.ToString('o')
        'data-repo-updated-at' = $repoInfo.updated_at.ToString('o')
    }
    $attributeString = @(
        foreach ($attributeName in $attributes.Keys) {
            "$attributeName='$($attributes[$attributeName])'"
        }
    ) -join ' '
    "<div $attributeString>"
        "<h2><a href='$($repoInfo.html_url)'>$($repoInfo.Name)</a></h2>"
        "<p>$([Web.HttpUtility]::HtmlEncode($repoInfo.Description))</p>"
        "<p>★ $($repoInfo.stargazers_count) | ⑃ forks: $($repoInfo.forks_count) | ☑ issues: $($repoInfo.open_issues_count)</p>"
        "<p>Created: $($repoInfo.created_at.ToString('yyyy-MM-dd')) | Updated: $($repoInfo.updated_at.ToString('yyyy-MM-dd'))</p>"
    "</div>"
}
"</div>"
)
    js = @"
document.getElementById('sort-repos').addEventListener('change', function(event) {
    const sortBy = event.target.value;
    const container = document.querySelector('.github-repos')
    const repos = Array.from(container.children)
    repos.sort((a, b) => {
        if (sortBy === 'repoStars') {
            return parseInt(b.dataset.repoStars) - parseInt(a.dataset.repoStars)
        } else if (sortBy === 'repoForks') {
            return parseInt(b.dataset.repoForks) - parseInt(a.dataset.repoForks)
        } else if (sortBy === 'repoOpenIssues') {
            return parseInt(b.dataset.repoOpenIssues) - parseInt(a.dataset.repoOpenIssues);
        } else if (sortBy === 'repoName') {
            return a.dataset.repoName.localeCompare(b.dataset.repoName)
        } else if (sortBy === 'repoWatchers') {
            return parseInt(b.dataset.repoWatchers) - parseInt(a.dataset.repoWatchers)
        } else if (sortBy === 'repoCreatedAt') {
            return new Date(b.dataset.repoCreatedAt) - new Date(a.dataset.repoCreatedAt)
        } else if (sortBy === 'repoUpdatedAt') { 
            return new Date(b.dataset.repoUpdatedAt) - new Date(a.dataset.repoUpdatedAt);
        } else if (sortBy === 'repoRandom') {
            return Math.random() - 0.5;
        }
    })
    for (let i = 0; i < repos.length; i++) {
        repos[i].style.order = i + 1;
    }   
});
"@
}
#endregion Repository Grid

#region View Source
$ViewSource = @{
    html= @"
<details>
<summary>View Source</summary>
<pre><code class='language-powershell'>$([Web.HttpUtility]::HtmlEncode($MyInvocation.MyCommand.ScriptBlock))</code></pre>
</details>
"@
}
#endregion View Source


#region ShowBuildTime
$ShowBuildTime = @{
    html = "<h4>Last built in `$buildTime at $([DateTime]::UtcNow.ToString("s")) running @ $cpuSpeed Mhz</h4>"
}

#endregion ShowBuildTime
# Put all of the controls in the order we want them to appear
$Controls = 
    @(
        $ShowOrgInfo        
        $selectPalette
        $GetRandomPalette
        $RepoGrid
        $ViewSource
        if (-not $NoBuildTime) { $ShowBuildTime }
    )    

#endregion Define Controls


# Create the base style for the page
$style = @(

@'
body { height: 100vh; max-width: 100vw; margin:0 }

h1, h2, h3,h4 { text-align: center; }
'@

)


# To create the index (or any page, all we need to do is join parts together)

$index = @(

    "<html>"    
    "<head>"
    
    "<title>$([Web.HttpUtility]::HtmlEncode($Organization))</title>"
    
    # Make sure we set the viewport so things work on mobile.
    "<meta name='viewport' content='width=device-width, initial-scale=1, minimum-scale=1.0' />"
    

    # Propagate the title, description, and image into OpenGraph attributes

    "<meta property='og:title' content='$([Web.HttpUtility]::HtmlAttributeEncode($orgInfo.name))' />"
    if ($orgInfo.description) {
        "<meta property='og:description' content='$([Web.HttpUtility]::HtmlAttributeEncode($orgInfo.description))' />"
    }    
    if ($orgInfo.avatar_url) {
        "<meta property='og:image' content='$($orgInfo.avatar_url)' />"
    }
    

    if ($DefaultPalette) {
        "<link rel='stylesheet' id='palette' href='$("$PaletteCDN" + $DefaultPalette + '.css')'> "
    }

    if (-not $NoHighlight) {
        "<script src='https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@latest/build/highlight.min.js'></script>"
        "<script src='https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@latest/build/powershell.min.js'></script>"
    }

    # Declare any styles in the header
    "<style>"
    # start with the base style
    $style 
    # and then include the css for each of the controls.
    foreach ($control in $controls) {
        if ($control.css) { $control.css}
    }
    "</style>"
    
    "</head>"

    "<body>"        
    
    # Include any control html
    foreach ($control in $controls) {
        $control.html
    }
    
    # Then include any javascript from controls
    "<script>"
    # (this way, any html elements already exist and we do not need to wait for the document to load)
    foreach ($control in $controls) {
        if ($control.js) {
            $control.js
        } elseif ($control.JavaScript) {
            $control.JavaScript
        }                
    }
    "</script>"
    
    if (-not $NoHighlight) { "<script>hljs.highlightAll();</script>" }
    
    # Close out the page.
    "</body>"
    "</html>"
)

$end = [DateTime]::UtcNow

# One last trick:
# We can replace any variables with a little regex
# In this case, let's make our build time a <time> element.
$index -replace '\$buildTime', 
    "<time datetime='$(
        [Xml.XmlConvert]::ToString($end - $start)
    )'>$(
        ($end - $start)
    )</time>"

Pop-Location
