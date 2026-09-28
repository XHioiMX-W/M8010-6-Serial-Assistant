param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M8010Protocol.ps1')

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Message) {
    if ($Actual -ne $Expected) { throw "$Message：实际 [$Actual]，期望 [$Expected]" }
}

function Assert-Near([double]$Actual, [double]$Expected, [double]$Tolerance, [string]$Message) {
    if ([math]::Abs($Actual - $Expected) -gt $Tolerance) { throw "$Message：实际 [$Actual]，期望 [$Expected]" }
}

$sampleSpeed = 1619 * 2 * [math]::PI / 256
$run = ConvertTo-M8010ControlFrame -MotorId 0 -Status 1 -TorqueNm 0 -SpeedRadPerSec $sampleSpeed -PositionRad 0 -Kp 0 -Kd 0.05
$stop = ConvertTo-M8010ControlFrame -MotorId 0 -Status 0 -TorqueNm 0 -SpeedRadPerSec $sampleSpeed -PositionRad 0 -Kp 0 -Kd 0.05
Assert-Equal (ConvertTo-HexString $run) 'FE EE 10 00 00 53 06 00 00 00 00 00 00 40 00 8C 6C' '运行样例报文'
Assert-Equal (ConvertTo-HexString $stop) 'FE EE 00 00 00 53 06 00 00 00 00 00 00 40 00 5C 36' '停止样例报文'

$feedbackBytes = [System.Collections.Generic.List[byte]]::new()
foreach ($value in (0xFD, 0xEE, 0x13, 0x80, 0xFE, 0x01, 0x00, 0x00, 0x80, 0x00, 0x00, 0xFB, 0x2D, 0x1A)) { $feedbackBytes.Add([byte]$value) }
$feedbackCrc = Get-M8010Crc16 ([byte[]]$feedbackBytes)
$feedbackBytes.Add([byte]($feedbackCrc -band 0xFF))
$feedbackBytes.Add([byte](($feedbackCrc -shr 8) -band 0xFF))
$feedback = ConvertFrom-M8010FeedbackFrame ([byte[]]$feedbackBytes)
Assert-Equal $feedback.MotorId 3 '反馈 ID'
Assert-Equal $feedback.Status 1 '反馈 STATUS'
Assert-Near $feedback.TorqueNm -1.5 0.001 '反馈转矩'
Assert-Near $feedback.SpeedRadPerSec (1 * 2 * [math]::PI / 256) 0.001 '反馈速度'
Assert-Near $feedback.PositionRad (2 * [math]::PI) 0.001 '反馈位置'
Assert-Equal $feedback.TemperatureC -5 '反馈温度'
Assert-Equal $feedback.ErrorCode 5 '反馈错误码'
Assert-Equal $feedback.ForceRaw 0x345 '反馈 FORCE'

$noise = [byte[]]@(0x00, 0x55) + [byte[]]$feedbackBytes + [byte[]]$feedbackBytes
$parsed = Find-M8010FeedbackFrames $noise
Assert-Equal $parsed.Frames.Count 2 '连续反馈帧数量'
Assert-Equal $parsed.Remaining.Length 0 '连续反馈帧剩余字节'
$feedbackFrame = [byte[]]$feedbackBytes.ToArray()
$bad = [byte[]]$feedbackFrame.Clone()
$bad[15] = $bad[15] -bxor 0xFF
$badParsed = Find-M8010FeedbackFrames $bad
Assert-Equal $badParsed.Frames.Count 0 'CRC 错误帧数量'
Assert-Equal $badParsed.CrcDrops 1 'CRC 丢弃数量'

Write-Output 'M8010 协议测试通过：控制样例、反馈位域、连续帧同步和 CRC 错误处理均正常。'
