$major = "1"
$minor = "0"
# $date_patch = Get-Date -UFormat "%Y%m%d"
$patch = $env:CDP_PATCH_NUMBER
# $BUILD_COUNT_DAY = $env:CDP_DEFINITION_BUILD_COUNT_DAY
$branch_name = $env:BUILD_SOURCEBRANCHNAME
$commit = $env:CDP_COMMIT_ID

$buildId = "$major.$minor.$patch.$branch_name.$commit"
[Environment]::SetEnvironmentVariable("CustomBuildNumber", $buildIdr, "User")  # This will allow you to use it from env var in later steps of the same phase
Write-Host "##vso[build.updatebuildnumber]${buildId}"                         # This will update build ID on your build