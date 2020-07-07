
$major = "1"
$minor = "0"
$date_patch = Get-Date -UFormat "%Y%m%d"
$BUILD_COUNT_DAY = $env:CDP_DEFINITION_BUILD_COUNT_DAY
$commit = $env:CDP_COMMIT_ID
$branch = $env:BUILD_SOURCEBRANCHNAME
$build_tag = $env:CDP_BUILD_TAG
$buildId = "$major.$minor.$date_patch.$BUILD_COUNT_DAY.$build_tag.$branch.$commit"
[Environment]::SetEnvironmentVariable("CustomBuildNumber", $buildIdr, "User")  # This will allow you to use it from env var in later steps of the same phase
Write-Host "##vso[build.updatebuildnumber]${buildId}"                         # This will update build ID on your build