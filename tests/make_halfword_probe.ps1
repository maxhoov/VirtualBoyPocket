param([Parameter(Mandatory=$true)][string]$RomPath,
      [Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
$sourcePath=(Resolve-Path -LiteralPath $RomPath).Path
$targetPath=[IO.Path]::GetFullPath($OutputPath)
if(Test-Path -LiteralPath $targetPath){throw 'Refusing to overwrite an existing file.'}
$original=[IO.File]::ReadAllBytes($sourcePath)
if($original.Length -lt 16 -or $original.Length%4){throw 'Expected a word-aligned ROM.'}
$probe=New-Object byte[] $original.Length
for($i=0;$i -lt $original.Length;$i+=4) {
    $probe[$i]=$original[$i+2]; $probe[$i+1]=$original[$i+3]
    $probe[$i+2]=$original[$i]; $probe[$i+3]=$original[$i+1]
}
# Verify that the transformation is exactly reversible before writing.
for($i=0;$i -lt $original.Length;$i++) {
    if($probe[$i -bxor 2] -ne $original[$i]) {throw "Transform mismatch at $i"}
}
[IO.File]::WriteAllBytes($targetPath,$probe)
Write-Output 'Diagnostic copy only: 16-bit halfwords swapped within each 32-bit word. Original untouched.'
Get-FileHash -LiteralPath $sourcePath,$targetPath -Algorithm SHA256
