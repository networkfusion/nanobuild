[System.Net.WebClient]$webClient = New-Object System.Net.WebClient
$webClient.UseDefaultCredentials = $true

function DownloadVsixFile($fileUrl, $downloadFileName)
{
    Write-Host "Download VSIX file from $fileUrl to $downloadFileName"
    $webClient.DownloadFile($fileUrl,$downloadFileName)
}

$tempDir = $($Env:RUNNER_TEMP)
Write-Host "TempDir is: $tempDir"

# Get nanoFramework VS extension information from Open VSIX Gallery feed
$vsixFeedXml = Join-Path $tempDir "vs-extension-feed.xml"
$webClient.DownloadFile("http://vsixgallery.com/feed/author/nanoframework", $vsixFeedXml)
[xml]$feedDetails = Get-Content $vsixFeedXml

# Find which entry corresponds to which VS version
for ($i = 0; $i -lt $feedDetails.feed.entry.Count; $i++) {

    if($feedDetails.feed.entry[$i].id -eq '455f2be5-bb07-451e-b351-a9faf3018dc9')
    {
#         Write-Host "VS2019->$i"
        $idVS2019 = $i
    }
    elseif($feedDetails.feed.entry[$i].id -eq 'bf694e17-fa5f-4877-9317-6d3664b2689a')
    {
#         Write-Host "VS2022->$i"
        $idVS2022 = $i
    }
    elseif($feedDetails.feed.entry[$i].id -eq '47973986-ed3c-4b64-ba40-a9da73b44ef7')
    {
#         Write-Host "VS2017->$i"
        $idVS2017 = $i
    }
    else {
#         Write-Host "?????[$i]"
    }
}

# Find which VS version is installed
$VsWherePath = "${env:PROGRAMFILES(X86)}\Microsoft Visual Studio\Installer\vswhere.exe"

Write-Host "VsWherePath is: $VsWherePath"

$VsInstance = $(&$VSWherePath -latest -property displayName)

Write-Host "Latest found VS instance is: $VsInstance"

# Get extension details according to VS version, starting from VS2022 down to VS2017
if($vsInstance.Contains('2022'))
{
    $extensionUrl = $feedDetails.feed.entry[$idVS2022].content.src
    $vsixDownloadPath = Join-Path  $tempDir "nanoFramework.Tools.VS2022.Extension.zip"
    $extensionVersion = $feedDetails.feed.entry[$idVS2022].Vsix.Version
}
elseif($vsInstance.Contains('2019'))
{
    $extensionUrl = $feedDetails.feed.entry[$idVS2019].content.src
    $vsixDownloadPath = Join-Path  $tempDir "nanoFramework.Tools.VS2019.Extension.zip"
    $extensionVersion = $feedDetails.feed.entry[$idVS2019].Vsix.Version
}
elseif($vsInstance.Contains('2017'))
{
    $extensionUrl = $feedDetails.feed.entry[$idVS2017].content.src
    $vsixDownloadPath = Join-Path  $tempDir "nanoFramework.Tools.VS2017.Extension.zip"
    $extensionVersion = $feedDetails.feed.entry[$idVS2017].Vsix.Version
}

# Download VS extension
DownloadVsixFile $extensionUrl $vsixDownloadPath

# Unzip extension --- TODO: lets use 7zip here for expected results?!
Write-Host "Unzipping nF VS extension package"
Expand-Archive -LiteralPath $vsixDownloadPath -DestinationPath $tempDir\nf-extension\ | Write-Host

$tempCheckDir = Get-ChildItem -Path "$tempDir\nf-extension\"
Write-Host $tempCheckDir

# Copy build files to msbuild location
$VsPath = $(&$VsWherePath -latest -property installationPath)

Write-Host "Copying build files to msbuild location"
$msbuildPath = Join-Path -Path $VsPath -ChildPath "\MSBuild"
Write-Host "tempExt Path: $tempDir\nf-extension\`$MSBuild\nanoFramework"
Write-Host "msbuildPath: $msbuildPath"

Copy-Item -Path "$tempDir\nf-extension\`$MSBuild\nanoFramework" -Destination $msbuildPath -Recurse

Write-Output "Installed VS extension v$extensionVersion"
