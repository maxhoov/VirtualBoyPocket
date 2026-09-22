param([string]$QuartusBin = 'D:\Development\QuartusPrime-25.1\quartus\bin64',
      [switch]$PackageOnly)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'src/fpga'
Push-Location $project
try {
    $buildStarted = Get-Date
    if (!$PackageOnly) {
        & (Join-Path $QuartusBin 'quartus_sh.exe') --flow compile ap_core
        if ($LASTEXITCODE -ne 0) { throw 'Quartus compilation failed; no package generated.' }
    } else {
        # Only allow packaging results newer than every synthesis input.
        $inputs = @(Get-ChildItem core, apf -Recurse -File |
            Where-Object { $_.Extension -in '.v','.sv','.vhd','.sdc','.qip','.mif' })
        $inputs += Get-Item ap_core.qsf
        $buildStarted = ($inputs | Sort-Object LastWriteTime -Descending |
            Select-Object -First 1).LastWriteTime
    }
    foreach ($report in @('output_files/ap_core.fit.summary','output_files/ap_core.sta.summary')) {
        if (!(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTime -lt $buildStarted) {
            throw "Missing or stale report: $report"
        }
    }
    $fit = Get-Content 'output_files/ap_core.fit.summary' -Raw
    if ($fit -notmatch 'Fitter Status\s*:\s*Successful') { throw 'Fitter did not succeed.' }
    $timing = Get-Content 'output_files/ap_core.sta.summary' -Raw
    if ($timing -match '(?im)^Slack\s*:\s*-') {
        throw 'Timing violations remain; no package generated. Inspect ap_core.sta.rpt.'
    }
    if ($timing -notmatch '(?im)^Slack\s*:') { throw 'No timing slack found; inspect timing report.' }
    $rbf = Join-Path $project 'output_files/ap_core.rbf'
    if (!(Test-Path $rbf)) { throw 'Quartus did not produce ap_core.rbf.' }
    if ((Get-Item -LiteralPath $rbf).LastWriteTime -lt $buildStarted) {
        throw 'RBF is stale (possibly the template example); no package generated.'
    }
    $package = Join-Path $PSScriptRoot 'release'
    $core = Join-Path $package 'Cores/maxhoov.VirtualBoy'
    $platforms = Join-Path $package 'Platforms'
    New-Item -ItemType Directory -Force $core, $platforms, (Join-Path $package 'Assets/virtualboy/common') | Out-Null
    foreach ($name in @('core.json','audio.json','data.json','input.json','interact.json','variants.json','video.json','info.txt','LICENSE')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $core
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'dist/platforms/virtualboy.json') -Destination $platforms
    $platformImages = Join-Path $platforms '_images'
    New-Item -ItemType Directory -Force $platformImages | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'dist/platforms/_images/virtualboy.bin') -Destination $platformImages
    $docs = Join-Path $package 'Documents/VirtualBoy'
    New-Item -ItemType Directory -Force $docs | Out-Null
    foreach ($name in @('README.md','VALIDATION.md','HARDWARE_TEST.md','PORTING.md','DIAGNOSTIC.md')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $docs
    }
    # RBF_R reverses bits inside every byte, not byte order.
    $bytes = [IO.File]::ReadAllBytes($rbf)
    $lookup = New-Object byte[] 256
    for ($i = 0; $i -lt 256; $i++) {
        $v = $i; $r = 0
        for ($j = 0; $j -lt 8; $j++) { $r = ($r -shl 1) -bor ($v -band 1); $v = $v -shr 1 }
        $lookup[$i] = $r
    }
    for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = $lookup[$bytes[$i]] }
    [IO.File]::WriteAllBytes((Join-Path $core 'bitstream.rbf_r'), $bytes)
    Write-Host "Package ready: $package (hardware validation still required)."
} finally { Pop-Location }
