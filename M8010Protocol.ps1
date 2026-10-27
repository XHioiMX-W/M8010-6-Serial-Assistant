Set-StrictMode -Version Latest

function ConvertTo-Signed16 {
    param([int]$Value)
    $raw = $Value -band 0xFFFF
    if (($raw -band 0x8000) -ne 0) { return $raw - 0x10000 }
    return $raw
}

function ConvertTo-Signed32 {
    param([long]$Value)
    $raw = $Value -band 0xFFFFFFFFL
    if (($raw -band 0x80000000L) -ne 0) { return $raw - 0x100000000L }
    return $raw
}

function ConvertTo-UInt16Bytes {
    param([int]$Value)
    $raw = $Value -band 0xFFFF
    return [byte[]]@(($raw -band 0xFF), (($raw -shr 8) -band 0xFF))
}

function ConvertTo-UInt32Bytes {
    param([long]$Value)
    $raw = $Value -band 0xFFFFFFFFL
    return [byte[]]@(
        ($raw -band 0xFF),
        (($raw -shr 8) -band 0xFF),
        (($raw -shr 16) -band 0xFF),
        (($raw -shr 24) -band 0xFF)
    )
}

function Get-M8010Crc16 {
    <# CRC16-CCITT, reflected representation used by the M8010 manual. #>
    param([byte[]]$Bytes)
    [int]$crc = 0
    foreach ($value in $Bytes) {
        $crc = $crc -bxor [int]$value
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) {
                $crc = ($crc -shr 1) -bxor 0x8408
            } else {
                $crc = $crc -shr 1
            }
            $crc = $crc -band 0xFFFF
        }
    }
    return $crc
}

function ConvertTo-HexString {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return '' }
    return (($Bytes | ForEach-Object { $_.ToString('X2') }) -join ' ')
}

function ConvertFrom-HexString {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return [byte[]]@() }
    $clean = $Text -replace '(?i)0x', '' -replace '[\s,;]', ''
    if ($clean -notmatch '^[0-9a-fA-F]*$') { throw '十六进制数据包含无效字符。' }
    if (($clean.Length % 2) -ne 0) { throw '十六进制数据必须包含完整的字节。' }
    $result = [byte[]]::new($clean.Length / 2)
    for ($i = 0; $i -lt $result.Length; $i++) {
        $result[$i] = [Convert]::ToByte($clean.Substring($i * 2, 2), 16)
    }
    return $result
}

function ConvertTo-M8010ControlFrame {
    param(
        [ValidateRange(0, 15)][int]$MotorId,
        [ValidateSet(0, 1, 2)][int]$Status,
        [double]$TorqueNm = 0,
        [double]$SpeedRadPerSec = 0,
        [double]$PositionRad = 0,
        [double]$Kp = 0,
        [double]$Kd = 0
    )

    if ([math]::Abs($TorqueNm) -gt 127.99) { throw '目标转矩必须在 -127.99 至 127.99 N·m 范围内。' }
    if ([math]::Abs($SpeedRadPerSec) -gt 804.0) { throw '目标速度必须在 -804 至 804 rad/s 范围内。' }
    if ([math]::Abs($PositionRad) -gt 411774) { throw '目标位置必须在 -411774 至 411774 rad 范围内。' }
    if ($Kp -lt 0 -or $Kp -gt 25.599) { throw 'Kp 必须在 0 至 25.599 范围内。' }
    if ($Kd -lt 0 -or $Kd -gt 25.599) { throw 'Kd 必须在 0 至 25.599 范围内。' }

    $torqueRaw = [int][math]::Round($TorqueNm * 256, [MidpointRounding]::AwayFromZero)
    $speedRaw = [int][math]::Round($SpeedRadPerSec / (2 * [math]::PI) * 256, [MidpointRounding]::AwayFromZero)
    $positionRaw = [long][math]::Round($PositionRad / (2 * [math]::PI) * 32768, [MidpointRounding]::AwayFromZero)
    $kpRaw = [int][math]::Round($Kp * 1280, [MidpointRounding]::AwayFromZero)
    $kdRaw = [int][math]::Round($Kd * 1280, [MidpointRounding]::AwayFromZero)

    $bytes = [System.Collections.Generic.List[byte]]::new()
    $bytes.Add(0xFE)
    $bytes.Add(0xEE)
    # The mode byte follows the manual's bit numbering: ID is the low nibble,
    # STATUS occupies bits 4-6.
    $bytes.Add([byte](($MotorId -band 0x0F) -bor (($Status -band 0x07) -shl 4)))
    foreach ($byte in (ConvertTo-UInt16Bytes $torqueRaw)) { $bytes.Add($byte) }
    foreach ($byte in (ConvertTo-UInt16Bytes $speedRaw)) { $bytes.Add($byte) }
    foreach ($byte in (ConvertTo-UInt32Bytes $positionRaw)) { $bytes.Add($byte) }
    foreach ($byte in (ConvertTo-UInt16Bytes $kpRaw)) { $bytes.Add($byte) }
    foreach ($byte in (ConvertTo-UInt16Bytes $kdRaw)) { $bytes.Add($byte) }

    $crc = Get-M8010Crc16 ([byte[]]$bytes)
    $bytes.Add([byte]($crc -band 0xFF))
    $bytes.Add([byte](($crc -shr 8) -band 0xFF))
    return [byte[]]$bytes
}

function ConvertFrom-M8010FeedbackFrame {
    param([byte[]]$Frame)
    if ($null -eq $Frame -or $Frame.Length -ne 16) { throw '反馈帧必须正好为 16 字节。' }
    if ($Frame[0] -ne 0xFD -or $Frame[1] -ne 0xEE) { throw '反馈帧头错误，应为 FD EE。' }

    $expected = Get-M8010Crc16 ($Frame[0..13])
    $received = [int]$Frame[14] -bor ([int]$Frame[15] -shl 8)
    if ($expected -ne $received) { throw ('CRC 错误：收到 {0:X4}，应为 {1:X4}。' -f $received, $expected) }

    $torqueRaw = [int]$Frame[3] -bor ([int]$Frame[4] -shl 8)
    $speedRaw = [int]$Frame[5] -bor ([int]$Frame[6] -shl 8)
    $positionRaw = [long]$Frame[7] -bor ([long]$Frame[8] -shl 8) -bor ([long]$Frame[9] -shl 16) -bor ([long]$Frame[10] -shl 24)
    $errorAndForce = [int]$Frame[12] -bor ([int]$Frame[13] -shl 8)

    $errorCode = $errorAndForce -band 0x07
    $forceRaw = ($errorAndForce -shr 3) -band 0x0FFF
    $temperature = ConvertTo-Signed16 ([int]$Frame[11])
    if ($temperature -gt 127) { $temperature -= 256 }

    [pscustomobject]@{
        MotorId = $Frame[2] -band 0x0F
        Status = ($Frame[2] -shr 4) -band 0x07
        TorqueNm = (ConvertTo-Signed16 $torqueRaw) / 256.0
        SpeedRadPerSec = (ConvertTo-Signed16 $speedRaw) / 256.0 * 2 * [math]::PI
        PositionRad = (ConvertTo-Signed32 $positionRaw) / 32768.0 * 2 * [math]::PI
        TemperatureC = $temperature
        ErrorCode = $errorCode
        ForceRaw = $forceRaw
        ForcePercent = $forceRaw / 4095.0 * 100.0
        Crc = $received
        Raw = $Frame
    }
}

function Find-M8010FeedbackFrames {
    param([byte[]]$Buffer)
    $frames = [System.Collections.Generic.List[object]]::new()
    $remaining = [System.Collections.Generic.List[byte]]::new()
    $crcDrops = 0
    if ($null -ne $Buffer) { foreach ($byte in $Buffer) { $remaining.Add($byte) } }

    while ($remaining.Count -ge 2) {
        $start = -1
        for ($i = 0; $i -lt ($remaining.Count - 1); $i++) {
            if ($remaining[$i] -eq 0xFD -and $remaining[$i + 1] -eq 0xEE) { $start = $i; break }
        }
        if ($start -lt 0) {
            if ($remaining.Count -gt 1) { $remaining.RemoveRange(0, $remaining.Count - 1) }
            break
        }
        if ($start -gt 0) { $remaining.RemoveRange(0, $start) }
        if ($remaining.Count -lt 16) { break }
        $candidate = [byte[]]$remaining.GetRange(0, 16).ToArray()
        try {
            $frames.Add((ConvertFrom-M8010FeedbackFrame $candidate))
            $remaining.RemoveRange(0, 16)
        } catch {
            $crcDrops++
            $remaining.RemoveAt(0)
        }
    }
    [pscustomobject]@{ Frames = @($frames); Remaining = [byte[]]$remaining.ToArray(); CrcDrops = $crcDrops }
}

# GO-M8010-6 MotorTools v0.2.0 factory protocol. These frames are deliberately
# separate from STATUS 0/1/2 motion commands. See ID-PROTOCOL.md for provenance.
function New-M8010EnterFactoryFrame {
    return [byte[]]@(0xFE, 0xEE, 0x7F, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x6F, 0x9A)
}

function New-M8010FactoryCommand {
    param(
        [ValidateSet('Discover', 'ChangeId', 'PrepareMotor', 'StartMotor')][string]$Command,
        [ValidateRange(0, 15)][int]$MotorId = 0,
        [ValidateRange(0, 14)][int]$NewId = 0
    )
    switch ($Command) {
        'Discover'     { return [byte[]]@(0xFB, 0, 0, 0xBB) }
        'ChangeId'     { return [byte[]]@(0xFB, 1, (($NewId -shl 4) -bor $MotorId), 0xBB) }
        'PrepareMotor' { return [byte[]]@(0xFB, 4, $MotorId, 0xBB) }
        'StartMotor'   { return [byte[]]@(0xFB, 3, $MotorId, 0xBB) }
    }
}

function Find-M8010FactoryReplies {
    param([byte[]]$Buffer)
    $replies = [System.Collections.Generic.List[object]]::new()
    $offset = 0
    while ($offset -lt $Buffer.Length) {
        if ($Buffer[$offset] -ne 0xFC) { $offset++; continue }
        if (($Buffer.Length - $offset) -lt 4) { break }
        # The factory protocol has no CRC. Require both delimiters and a known
        # response command, then verify success with normal CRC-protected frames.
        if ($Buffer[$offset + 3] -eq 0xBB -and $Buffer[$offset + 1] -in 1, 3, 4) {
            $replies.Add([pscustomobject]@{
                Command = [int]$Buffer[$offset + 1]
                MotorId = [int]($Buffer[$offset + 2] -band 0x0F)
                Result = [int]($Buffer[$offset + 2] -shr 4)
            })
            $offset += 4
        } else { $offset++ }
    }
    $remaining = if ($offset -lt $Buffer.Length) { [byte[]]$Buffer[$offset..($Buffer.Length - 1)] } else { [byte[]]@() }
    return [pscustomobject]@{ Replies = @($replies.ToArray()); Remaining = $remaining }
}
