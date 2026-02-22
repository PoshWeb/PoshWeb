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

# All we need to do is run one file and redirect it's output:
./index.html.ps1 > ./index.html