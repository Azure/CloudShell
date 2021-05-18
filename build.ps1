[CmdletBinding()]
param(
    [ValidateSet("Tools", "Base", "All")]
    [string]$image = "Tools",

    [switch]$NoCache
)

$ErrorActionPreference = "Stop"

$args = ""
if ($NoCache) {
    $args = "--no-cache"
}

$base = & docker images base_cloudshell
$buildbase = $false
if (! $base) {
    Write-Verbose "Base_cloudshell image not found, need to build it"
    $buildbase = $true
}
else {
    Write-Verbose "Base image found`n$base"
}

if ($image -eq "base" -or $image -eq "all") {
    $buildbase = $true
}

if ($buildbase) {
    Write-Verbose "Building Base image"
    & docker build -t base_cloudshell $args -f linux/base.Dockerfile .
    Write-Verbose "Finished building base image"
}

if ($image -eq "tools" -or $image -eq "all") {
    Write-verbose "Building tools image"
    & docker build -t tools_cloudshell $args --build-arg IMAGE_LOCATION=base_cloudshell -f linux/tools.Dockerfile . 
    Write-Verbose "Finished building tools image"
}