param([string]$QuestaBin = 'D:\Development\QuartusPrime-25.1\questa_fse\win64')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & (Join-Path $QuestaBin 'vsim.exe') -c -do run.do *> simulation.log
    $result = $LASTEXITCODE
    $log = Get-Content simulation.log -Raw
    if ($result -ne 0 -or $log -match '(?m)^# \*\* (Error|Fatal):' -or
        ([regex]::Matches($log, '(?m)^# PASS:')).Count -ne 9) {
        throw 'Simulation failed or missing PASS markers. See tests/simulation.log.'
    }
    $log -split "`n" | Where-Object { $_ -match '^# PASS:' }
} finally { Pop-Location }
