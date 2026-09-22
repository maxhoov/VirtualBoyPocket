param([Parameter(Mandatory=$true)][string]$RomPath,
      [Parameter(Mandatory=$true)][ValidatePattern('^(0x)?[0-9a-fA-F]{8}$')][string]$PC,
      [Parameter(Mandatory=$true)][ValidatePattern('^(0x)?[0-9a-fA-F]{8}$')][string]$Instruction)
$ErrorActionPreference='Stop'
$pcValue=[Convert]::ToUInt32(($PC -replace '^0x',''),16)
$iwValue=[Convert]::ToUInt32(($Instruction -replace '^0x',''),16)
if(($pcValue -band 0x07000000) -ne 0x07000000) {
    throw 'PC is outside the cartridge ROM region; inspect RAM/control flow instead.'
}
if($pcValue -band 1) { throw 'Instruction PC must be halfword aligned.' }
$romBytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $RomPath).Path)
if($romBytes.Length -lt 16 -or $romBytes.Length -gt 16777216 -or
    ($romBytes.Length -band ($romBytes.Length-1))) {
    throw 'Expected a power-of-two ROM size between 16 bytes and 16 MiB.'
}
$mask=$romBytes.Length-1
$offset=$pcValue -band $mask
$first=([uint32]$romBytes[($offset+1) -band $mask] -shl 8) -bor $romBytes[$offset]
$second=([uint32]$romBytes[($offset+3) -band $mask] -shl 8) -bor $romBytes[($offset+2) -band $mask]
[PSCustomObject]@{
    PC=('{0:X8}' -f $pcValue)
    FileOffset=('{0:X6}' -f $offset)
    CapturedFirst=('{0:X4}' -f ($iwValue -shr 16))
    ExpectedFirst=('{0:X4}' -f $first)
    FirstMatches=(($iwValue -shr 16) -eq $first)
    CapturedFollowing=('{0:X4}' -f ($iwValue -band 0xffff))
    ExpectedFollowing=('{0:X4}' -f $second)
}
Write-Output 'Only the first halfword necessarily belongs to the illegal instruction.'
