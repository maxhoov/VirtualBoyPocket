param([Parameter(Mandatory=$true)][string]$RomPath,
      [ValidateRange(1,2000)][int]$RunMs=10,
      [switch]$IdealReadOrder,
      [switch]$MenuPause,
      [string]$QuestaBin='D:\Development\QuartusPrime-25.1\questa_fse\win64')
$ErrorActionPreference='Stop'
$resolvedRom=(Resolve-Path -LiteralPath $RomPath).Path
$priorRom=$env:VB_TEST_ROM
$priorMs=$env:VB_TEST_MS
$priorIdeal=$env:VB_TEST_IDEAL
$priorMenu=$env:VB_TEST_MENU
Push-Location $PSScriptRoot
try {
    $env:VB_TEST_ROM=$resolvedRom
    $env:VB_TEST_MS="$RunMs"
    $env:VB_TEST_IDEAL=if($IdealReadOrder){'1'}else{'0'}
    $env:VB_TEST_MENU=if($MenuPause){'1'}else{'0'}
    & (Join-Path $QuestaBin 'vsim.exe') -c -do top_boot.do *> game.log
    $result=$LASTEXITCODE
    $log=Get-Content game.log -Raw
    $log -split "`n" | Where-Object { $_ -match '^# (GAME:|TRACE|\*\* (Fatal|Error):)' }
    if($result -ne 0 -or $log -match '# \*\* (Fatal|Error):' -or $log -notmatch 'GAME: completed' -or
       ($MenuPause -and $log -notmatch 'GAME: menu pause/resume checks passed')) {
        throw 'Game diagnostic failed. See tests/game.log.'
    }
} finally {
    $env:VB_TEST_ROM=$priorRom
    $env:VB_TEST_MS=$priorMs
    $env:VB_TEST_IDEAL=$priorIdeal
    $env:VB_TEST_MENU=$priorMenu
    Pop-Location
}
