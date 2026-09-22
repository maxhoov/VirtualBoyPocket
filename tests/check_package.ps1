param([string]$PackageRoot = (Join-Path $PSScriptRoot '../release'))
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$core = Join-Path $PackageRoot 'Cores/maxhoov.VirtualBoy'
if (Test-Path -LiteralPath (Join-Path $PackageRoot 'Cores/PocketVB.VirtualBoy')) {
    throw 'Legacy core directory remains in package; migrate it before packaging.'
}
$rbf = [IO.File]::ReadAllBytes((Join-Path $repo 'src/fpga/output_files/ap_core.rbf'))
$packed = [IO.File]::ReadAllBytes((Join-Path $core 'bitstream.rbf_r'))
if ($rbf.Length -ne $packed.Length -or !$rbf.Length) { throw 'Bitstream length mismatch.' }
# Verify every byte using an independent nibble-reversal table.
$reverseNibble = @(0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15)
for ($i = 0; $i -lt $rbf.Length; $i++) {
    $expected = ($reverseNibble[$rbf[$i] -band 15] -shl 4) -bor $reverseNibble[$rbf[$i] -shr 4]
    if ($packed[$i] -ne $expected) { throw "RBF_R conversion mismatch at byte $i." }
}
foreach ($name in @('core.json','audio.json','data.json','input.json','interact.json','variants.json','video.json','info.txt','LICENSE')) {
    $path = Join-Path $core $name
    if ((Get-FileHash -LiteralPath $path).Hash -ne (Get-FileHash -LiteralPath (Join-Path $repo $name)).Hash) {
        throw "Package source mismatch: $name"
    }
    if ($name.EndsWith('.json')) { Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null }
}
$metadata = Get-Content -LiteralPath (Join-Path $core 'core.json') -Raw | ConvertFrom-Json
if ($metadata.core.metadata.author -cne 'maxhoov') { throw 'Wrong core author.' }
foreach ($name in @('README.md','VALIDATION.md','HARDWARE_TEST.md','PORTING.md','DIAGNOSTIC.md')) {
    $path = Join-Path $PackageRoot "Documents/VirtualBoy/$name"
    if ((Get-FileHash -LiteralPath $path).Hash -ne (Get-FileHash -LiteralPath (Join-Path $repo $name)).Hash) {
        throw "Package documentation mismatch: $name"
    }
}
$menu = Get-Content -LiteralPath (Join-Path $core 'interact.json') -Raw | ConvertFrom-Json
if ($menu.interact.variables.Count -gt 16) { throw 'Too many menu entries.' }
foreach ($entry in $menu.interact.variables) {
    if ($entry.name.Length -gt 23) { throw "Menu label too long: $($entry.name)" }
    foreach ($option in $entry.options) {
        if ($option.name.Length -gt 23) { throw "Menu option too long: $($option.name)" }
    }
}
if ($metadata.core.cores[0].filename -ne 'bitstream.rbf_r') { throw 'Wrong bitstream filename.' }
$platform = Join-Path $PackageRoot 'Platforms/virtualboy.json'
$platformMetadata = Get-Content -LiteralPath $platform -Raw | ConvertFrom-Json
if ($platformMetadata.platform.category -cne 'Console') { throw 'Platform category must be Console.' }
if ((Get-FileHash -LiteralPath $platform).Hash -ne
    (Get-FileHash -LiteralPath (Join-Path $repo 'dist/platforms/virtualboy.json')).Hash) {
    throw 'Platform source mismatch.'
}
$platformImage = Join-Path $PackageRoot 'Platforms/_images/virtualboy.bin'
if ((Get-FileHash -LiteralPath $platformImage).Hash -ne
    (Get-FileHash -LiteralPath (Join-Path $repo 'dist/platforms/_images/virtualboy.bin')).Hash) {
    throw 'Platform image source mismatch.'
}
$imageBytes = [IO.File]::ReadAllBytes($platformImage)
if ($imageBytes.Length -ne 521*165*2) { throw 'Wrong platform image dimensions.' }
for ($i=1; $i -lt $imageBytes.Length; $i+=2) {
    if ($imageBytes[$i] -ne 0) { throw 'Platform image low byte must be zero.' }
}
if ((Get-FileHash -LiteralPath $platformImage).Hash -eq
    (Get-FileHash -LiteralPath (Join-Path $repo 'dist/platforms/_images/ex_platform.bin')).Hash) {
    throw 'Platform image is still the template placeholder.'
}
if (!(Test-Path -LiteralPath (Join-Path $PackageRoot 'Assets/virtualboy/common') -PathType Container)) {
    throw 'Missing ROM directory.'
}
Write-Output "PASS: package metadata and all $($rbf.Length) RBF_R bytes verified."
Get-FileHash -LiteralPath (Join-Path $core 'bitstream.rbf_r') -Algorithm SHA256
