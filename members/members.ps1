if ($site -isnot [Collections.IDictionary]) {
    return
}
if (-not $site['com.github.api.orgs.org.publicMembers']) {
    return
}

"<style>"
"
.member-grid {
    display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2.5em; margin: 2.5em
    text-align: center;
}
"
"</style>"
"<div class='member-grid'>"
foreach ($orgMember in $site['com.github.api.orgs.org.publicMembers']) {
    "<section>"
        "<a href='$($orgMember.html_url)'>"
            "<img src='$($orgMember.avatar_url)' />"
            "<h3>$([Web.HttpUtility]::HtmlEncode($orgMember.login))</h3>"
        "</a>"
    "</section>"
}
"</div>"
