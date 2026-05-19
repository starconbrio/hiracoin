param(
    [string]$Timestamp = "Hiracoin genesis 2026-05-10 HTMLCOIN-based hybrid PoW/PoS chain",
    [uint32]$Time = 1778400000,
    [uint32]$Bits = 0x1f00ffff,
    [uint32]$StartNonce = 0,
    [string]$PubKey = "04e67225ab32299deaf6312b5b77f0cd2a5264f3757c9663f8dc401ff8b3ad8b012fde713be690ab819f977f84eaef078767168aeb1cb1287941b6319b76d8e582",
    [UInt64]$RewardSatoshis = 10000000,
    [string]$PowPrefix = "0000"
)

$ErrorActionPreference = "Stop"

function Join-Bytes {
    param([Parameter(ValueFromRemainingArguments = $true)][byte[][]]$Parts)
    $len = 0
    foreach ($part in $Parts) { $len += $part.Length }
    $result = New-Object byte[] $len
    $offset = 0
    foreach ($part in $Parts) {
        [Array]::Copy($part, 0, $result, $offset, $part.Length)
        $offset += $part.Length
    }
    return $result
}

function UInt32-Le([UInt32]$Value) {
    return [BitConverter]::GetBytes($Value)
}

function Int32-Le([int]$Value) {
    return [BitConverter]::GetBytes($Value)
}

function UInt64-Le([UInt64]$Value) {
    return [BitConverter]::GetBytes($Value)
}

function VarInt([UInt64]$Value) {
    if ($Value -lt 0xfd) { return [byte[]]@([byte]$Value) }
    if ($Value -le 0xffff) {
        return Join-Bytes ([byte[]]@(0xfd)) ([BitConverter]::GetBytes([UInt16]$Value))
    }
    if ($Value -le 0xffffffff) {
        return Join-Bytes ([byte[]]@(0xfe)) ([BitConverter]::GetBytes([UInt32]$Value))
    }
    return Join-Bytes ([byte[]]@(0xff)) ([BitConverter]::GetBytes([UInt64]$Value))
}

function Hex-ToBytes([string]$Hex) {
    $clean = $Hex -replace '^0x', ''
    $bytes = New-Object byte[] ($clean.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($clean.Substring($i * 2, 2), 16)
    }
    return $bytes
}

function Bytes-ToHex([byte[]]$Bytes) {
    return ([BitConverter]::ToString($Bytes) -replace '-', '').ToLowerInvariant()
}

function Reverse-Bytes([byte[]]$Bytes) {
    $copy = [byte[]]$Bytes.Clone()
    [Array]::Reverse($copy)
    return $copy
}

function DisplayHash([byte[]]$InternalHash) {
    return Bytes-ToHex (Reverse-Bytes $InternalHash)
}

function DoubleSha256([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return $sha.ComputeHash($sha.ComputeHash($Bytes))
}

function ScriptNum([Int64]$Value) {
    if ($Value -eq 0) { return [byte[]]@() }
    $negative = $Value -lt 0
    [UInt64]$abs = if ($negative) { [UInt64](-$Value) } else { [UInt64]$Value }
    $result = New-Object System.Collections.Generic.List[byte]
    while ($abs -gt 0) {
        $result.Add([byte]($abs -band 0xff))
        $abs = $abs -shr 8
    }
    $last = $result.Count - 1
    if (($result[$last] -band 0x80) -ne 0) {
        $result.Add([byte](if ($negative) { 0x80 } else { 0x00 }))
    } elseif ($negative) {
        $result[$last] = [byte]($result[$last] -bor 0x80)
    }
    return $result.ToArray()
}

function Push-Data([byte[]]$Data) {
    if ($Data.Length -lt 0x4c) {
        return Join-Bytes ([byte[]]@([byte]$Data.Length)) $Data
    }
    if ($Data.Length -le 0xff) {
        return Join-Bytes ([byte[]]@(0x4c, [byte]$Data.Length)) $Data
    }
    throw "Push-Data only supports payloads up to 255 bytes for this genesis helper."
}

function Genesis-Tx([string]$Text, [string]$OutputPubKey, [UInt64]$Reward) {
    $scriptSig = Join-Bytes `
        ([byte[]]@(0x00)) `
        (Push-Data (ScriptNum 488804799)) `
        (Push-Data (ScriptNum 4)) `
        (Push-Data ([Text.Encoding]::ASCII.GetBytes($Text)))

    $scriptPubKey = Join-Bytes `
        (Push-Data (Hex-ToBytes $OutputPubKey)) `
        ([byte[]]@(0xac))

    return Join-Bytes `
        (Int32-Le 1) `
        (VarInt 1) `
        (New-Object byte[] 32) `
        (UInt32-Le ([uint32]::MaxValue)) `
        (VarInt $scriptSig.Length) `
        $scriptSig `
        (UInt32-Le ([uint32]::MaxValue)) `
        (VarInt 1) `
        (UInt64-Le $Reward) `
        (VarInt $scriptPubKey.Length) `
        $scriptPubKey `
        (UInt32-Le 0)
}

function Header-Bytes([string]$MerkleDisplayHash, [uint32]$HeaderTime, [uint32]$HeaderBits, [uint32]$HeaderNonce) {
    $stateRoot = "e965ffd002cd6ad0e2dc402b8044de833e06b23127ea8c3d80aec91410771495"
    $utxoRoot = "1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"
    return Join-Bytes `
        (Int32-Le 1) `
        (New-Object byte[] 32) `
        (Reverse-Bytes (Hex-ToBytes $MerkleDisplayHash)) `
        (UInt32-Le $HeaderTime) `
        (UInt32-Le $HeaderBits) `
        (UInt32-Le $HeaderNonce) `
        (Hex-ToBytes $stateRoot) `
        (Hex-ToBytes $utxoRoot) `
        (New-Object byte[] 32) `
        (UInt32-Le ([uint32]::MaxValue)) `
        (VarInt 0)
}

$tx = Genesis-Tx $Timestamp $PubKey $RewardSatoshis
$merkle = DisplayHash (DoubleSha256 $tx)

$nonce = $StartNonce
while ($true) {
    $hash = DisplayHash (DoubleSha256 (Header-Bytes $merkle $Time $Bits $nonce))
    if ($PowPrefix -eq "any" -or $hash.StartsWith($PowPrefix)) {
        [pscustomobject]@{
            timestamp = $Timestamp
            time = $Time
            bits = ("0x{0:x8}" -f $Bits)
            nonce = $nonce
            merkleRoot = $merkle
            genesisHash = $hash
            rewardSatoshis = $RewardSatoshis
        } | Format-List
        break
    }
    $nonce++
}
