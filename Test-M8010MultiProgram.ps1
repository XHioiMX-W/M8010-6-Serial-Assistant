# Run only through the application's -SmokeTest. No real port is opened.
$savedMultiNowFunction = ${function:Get-MultiNow}
function Get-MultiNow { return $script:MultiTestTime }
$script:MultiTestTime = 0.0

function Assert-MultiTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function New-MultiTestPort {
    $port = [pscustomobject]@{
        IsOpen = $true; BaudRate = 4000000
        Input = [System.Collections.Generic.Queue[byte]]::new()
        Writes = [System.Collections.Generic.List[object]]::new()
    }
    $port | Add-Member ScriptProperty BytesToRead { return $this.Input.Count }
    $port | Add-Member ScriptMethod DiscardInBuffer { $this.Input.Clear() }
    $port | Add-Member ScriptMethod Write {
        param([byte[]]$Bytes, [int]$Offset, [int]$Count)
        $this.Writes.Add([pscustomobject]@{ Bytes = [byte[]]$Bytes.Clone(); Time = Get-MultiNow })
    }
    $port | Add-Member ScriptMethod Read {
        param([byte[]]$Buffer, [int]$Offset, [int]$Count)
        $read = [math]::Min($Count, $this.Input.Count)
        for ($i = 0; $i -lt $read; $i++) { $Buffer[$Offset + $i] = $this.Input.Dequeue() }
        return $read
    }
    return $port
}
function New-MultiTestFeedback([int]$Id, [int]$Status, [double]$Speed = 0, [int]$ErrorCode = 0, [int]$Temperature = 25) {
    $speedBytes = ConvertTo-UInt16Bytes ([int][math]::Round($Speed * 256 / (2 * [math]::PI)))
    $data = [byte[]]@(0xFD,0xEE,(($Status -shl 4) -bor $Id),0,0,$speedBytes[0],$speedBytes[1],0,0,0,0,$Temperature,$ErrorCode,0)
    $crc = Get-M8010Crc16 $data
    return [byte[]]($data + [byte[]]@(($crc -band 255),($crc -shr 8)))
}
function Feed-MultiTest([byte[]]$Bytes) {
    foreach ($b in $Bytes) { $script:SerialPort.Input.Enqueue($b) }
    Receive-SerialData
}
function Advance-MultiTest([bool]$Reply = $true) {
    $script:MultiTestTime += 0.05
    if ($Reply -and $null -ne $script:MultiPending) {
        $p = $script:MultiPending
        $speed = if ($p.Status -eq 1) { $p.Row.Speed } else { 0 }
        Feed-MultiTest (New-MultiTestFeedback $p.Row.Id $p.Status $speed)
    }
    Step-MultiProgram
}
function Drive-MultiTest([bool]$Reply = $true) {
    for ($tick = 0; $tick -lt 1500 -and $script:MultiBusy; $tick++) { Advance-MultiTest $Reply }
    Assert-MultiTest (-not $script:MultiBusy) '多电机模拟超过步数。'
}
function Reset-MultiTest {
    Assert-MultiTest (-not $script:MultiBusy -and -not $script:MultiNeedsStop) '测试前仍有运行或未确认停止的电机。'
    Reset-MultiTemplate
    $MultiOverspeedBox.Text = '12'
    $MultiTimeoutBox.Text = '200'
    $script:MultiTestTime = 0.0
    $script:SerialPort = New-MultiTestPort
    $script:PendingPositionStart = $false
    $script:CycleTimer.Stop()
}

try {
    Assert-MultiTest ([string]::IsNullOrWhiteSpace($MultiOverspeedBox.Text)) '多电机阈值不应预设。'
    Reset-MultiTest
    $MultiOverspeedBox.Text = ''
    $rejected = $false
    try { Start-MultiProgram } catch { $rejected = $true }
    Assert-MultiTest ($rejected -and $script:SerialPort.Writes.Count -eq 0) '空阈值没有在发帧前被拒绝。'
    $MultiOverspeedBox.Text = '12'
    $script:MultiRows[1].Id.Text = '2'
    $rejected = $false
    try { Start-MultiProgram } catch { $rejected = $true }
    Assert-MultiTest ($rejected -and $script:SerialPort.Writes.Count -eq 0) '重复 ID 没有在发帧前被拒绝。'
    $script:MultiRows[1].Id.Text = '15'
    $rejected = $false
    try { Start-MultiProgram } catch { $rejected = $true }
    Assert-MultiTest $rejected '接受了广播 ID。'
    $script:MultiRows[1].Id.Text = '3'
    foreach ($invalid in @('NaN','Infinity','-Infinity','999')) {
        $script:MultiRows[0].Speed.Text = $invalid
        $rejected = $false
        try { Start-MultiProgram } catch { $rejected = $true }
        Assert-MultiTest $rejected "接受了非法速度 $invalid。"
    }

    Reset-MultiTest
    Start-MultiProgram
    Assert-MultiTest (-not $StartFocButton.IsEnabled -and -not $ChangeMotorIdButton.IsEnabled -and -not $RawSendButton.IsEnabled) '多电机执行时控制入口没有锁定。'
    $blocked = $false
    try { Start-IdOperation Read } catch { $blocked = $true }
    Assert-MultiTest $blocked '运行期间允许 ID 操作。'
    $blocked = $false
    try { Send-Bytes (ConvertTo-M8010ControlFrame -MotorId 0 -Status 1) '测试禁止的帧' } catch { $blocked = $true }
    Assert-MultiTest $blocked '运行期间允许外部控制帧。'
    Drive-MultiTest
    Assert-MultiTest ($MultiStatusText.Text -like '程序完成*' -and -not $script:MultiNeedsStop) '顺序程序没有完成并确认锁定。'
    $events = @($script:SerialPort.Writes)
    $starts = @()
    $lastStop = -1.0
    foreach ($id in 2..9) {
        $start = @($events | Where-Object { $_.Bytes[2] -eq (0x10 + $id) } | Select-Object -First 1)[0]
        $stop = @($events | Where-Object { $_.Bytes[2] -eq $id -and $_.Time -gt $start.Time } | Select-Object -First 1)[0]
        Assert-MultiTest ($start.Time -gt $lastStop) '顺序程序在上一电机锁定之前启动了下一台。'
        Assert-MultiTest (($stop.Time - $start.Time) -ge 2 -and ($stop.Time - $start.Time) -lt 2.11) '顺序模板未按每台 2 秒停止。'
        $rotorSpeedRaw = ConvertTo-Signed16 ([int]$start.Bytes[5] -bor ([int]$start.Bytes[6] -shl 8))
        Assert-MultiTest ([math]::Abs($rotorSpeedRaw / 256.0 * 2 * [math]::PI - 6.33) -lt 0.02) '目标 1 rad/s 没有按输出轴单位换算。'
        $lastStop = $stop.Time
        $starts += $start
    }
    Assert-MultiTest ($starts.Count -eq 8) '顺序程序没有运行八台电机。'

    Reset-MultiTest
    $MultiModeCombo.SelectedIndex = 1
    for ($i = 0; $i -lt 8; $i++) {
        $script:MultiRows[$i].Speed.Text = if ($i % 2) { '-1' } else { '2' }
        $script:MultiRows[$i].Duration.Text = (1.0 + $i * 0.2).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
    }
    Start-MultiProgram
    Drive-MultiTest
    Assert-MultiTest ($MultiStatusText.Text -like '程序完成*') '同时程序没有正常完成。'
    $events = @($script:SerialPort.Writes)
    $startTimes = @()
    foreach ($row in $script:MultiPlan) {
        $id = $row.Id
        $start = @($events | Where-Object { $_.Bytes[2] -eq (0x10 + $id) } | Select-Object -First 1)[0]
        $stop = @($events | Where-Object { $_.Bytes[2] -eq $id -and $_.Time -gt $start.Time } | Select-Object -First 1)[0]
        $startTimes += $start.Time
        Assert-MultiTest (($stop.Time - $start.Time) -ge $row.Duration -and ($stop.Time - $start.Time) -lt $row.Duration + 0.11) '同时程序没有独立计时停止。'
        $raw = ConvertTo-Signed16 ([int]$start.Bytes[5] -bor ([int]$start.Bytes[6] -shl 8))
        Assert-MultiTest (($raw -lt 0) -eq ($row.Speed -lt 0)) '负速度方向编码错误。'
    }
    Assert-MultiTest ((($startTimes | Measure-Object -Maximum).Maximum - ($startTimes | Measure-Object -Minimum).Minimum) -lt 0.5) '同时程序变成了顺序执行。'

    Reset-MultiTest
    Start-MultiProgram
    Step-MultiProgram
    $pending = $script:MultiPending
    $corrupt = New-MultiTestFeedback $pending.Row.Id 0
    $corrupt[15] = $corrupt[15] -bxor 1
    Feed-MultiTest $corrupt
    Feed-MultiTest (New-MultiTestFeedback 14 0)
    Assert-MultiTest ($null -ne $script:MultiPending) '错误 CRC 或错误 ID 被用作预检确认。'
    Drive-MultiTest $false
    Assert-MultiTest ($script:MultiNeedsStop -and -not $StartFocButton.IsEnabled) '失联未保留停止锁。'
    Assert-MultiTest (@($script:SerialPort.Writes | Where-Object { ($_.Bytes[2] -shr 4) -eq 1 }).Count -eq 0) '预检失败仍发送了运动帧。'
    Stop-MultiProgram '恢复连接后重试'
    Drive-MultiTest
    Assert-MultiTest (-not $script:MultiNeedsStop -and $StartFocButton.IsEnabled) '重新确认停止后没有解除控制锁。'

    foreach ($failure in @('overspeed','error','temperature','manual','close','window','disconnect')) {
        Reset-MultiTest
        $MultiModeCombo.SelectedIndex = 1
        Start-MultiProgram
        for ($i = 0; $i -lt 12; $i++) { Advance-MultiTest }
        Assert-MultiTest ($script:MultiPhase -eq 'Run') '故障测试未进入运行。'
        switch ($failure) {
            'overspeed' { Feed-MultiTest (New-MultiTestFeedback 9 1 20) }
            'error' { Feed-MultiTest (New-MultiTestFeedback 9 1 0 1) }
            'temperature' { Feed-MultiTest (New-MultiTestFeedback 9 1 0 0 90) }
            'manual' { Stop-ControlOutput '测试急停' }
            'close' { Close-Serial; Assert-MultiTest $script:SerialPort.IsOpen '关闭串口未先等待整组停止。' }
            'window' {
                $closingArgs = [ComponentModel.CancelEventArgs]::new()
                $onClosing = [System.Windows.Window].GetMethod('OnClosing', [Reflection.BindingFlags]'Instance,NonPublic')
                [void]$onClosing.Invoke($window, [object[]]@($closingArgs))
                Assert-MultiTest $closingArgs.Cancel '关闭窗口未等待整组停止。'
            }
            'disconnect' { $script:SerialPort.IsOpen = $false; Step-MultiProgram }
        }
        if ($failure -eq 'disconnect') {
            Step-MultiProgram
            Assert-MultiTest $script:MultiNeedsStop '断线未保留停止锁。'
            $script:SerialPort = New-MultiTestPort
            Stop-MultiProgram '重连后重试'
        }
        Assert-MultiTest ($script:MultiPhase -eq 'Stopping') "故障 $failure 未停止整组。"
        $writesBefore = $script:SerialPort.Writes.Count
        Drive-MultiTest
        Assert-MultiTest (-not $script:MultiNeedsStop) "故障 $failure 后未验证锁定。"
        $later = @($script:SerialPort.Writes | Select-Object -Skip $writesBefore)
        Assert-MultiTest (@($later | Where-Object { ($_.Bytes[2] -shr 4) -eq 1 }).Count -eq 0) '停止后仍发送了速度帧。'
    }

    Reset-MultiTest
    foreach ($row in $script:MultiRows) { $row.Enabled.IsChecked = $false }
    $script:MultiRows[0].Enabled.IsChecked = $true
    $script:MultiRows[0].Duration.Text = '0.2'
    $MultiTimeoutBox.Text = '5000'
    Start-MultiProgram
    Advance-MultiTest
    Advance-MultiTest
    Assert-MultiTest ($script:MultiPhase -eq 'Run') '长超时测试没有开始运行。'
    for ($i = 0; $i -lt 7; $i++) { Advance-MultiTest $false }
    Assert-MultiTest ($script:MultiPhase -eq 'Stopping') '长反馈超时延长了已到时的运动。'
    Drive-MultiTest
    Assert-MultiTest (-not $script:MultiNeedsStop) '到时保护未确认锁定。'

    Reset-MultiTest
    $script:MultiRows[2].Enabled.IsChecked = $false
    $savedSettingsPath = $script:MultiSettingsPath
    $script:MultiSettingsPath = Join-Path ([IO.Path]::GetTempPath()) ('M8010-program-test-' + [guid]::NewGuid() + '.json')
    try {
        Save-MultiConfiguration
        Reset-MultiTemplate
        Load-MultiConfiguration
        Assert-MultiTest (-not $script:MultiRows[2].Enabled.IsChecked -and -not $script:MultiBusy) '保存 / 载入没有保持启用状态，或自动启动了程序。'
    } finally {
        Remove-Item -LiteralPath $script:MultiSettingsPath -ErrorAction SilentlyContinue
        $script:MultiSettingsPath = $savedSettingsPath
    }
    Write-Output 'M8010 multi-program passed: 8 sequential motors, independent parallel durations, signed speed/gear ratio, interlocks, CRC, timeout, group fault stops, disconnect recovery and settings.'
} finally {
    $script:MultiTimer.Stop()
    $script:ReceiveTimer.Stop()
    $script:SerialPort = $null
    ${function:Get-MultiNow} = $savedMultiNowFunction
}
