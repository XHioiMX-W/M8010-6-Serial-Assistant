# All scheduling, port access and WPF updates stay on the UI thread.
$MultiModeCombo = Get-Control 'MultiModeCombo'
$MultiTemplateButton = Get-Control 'MultiTemplateButton'
$MultiSaveButton = Get-Control 'MultiSaveButton'
$MultiLoadButton = Get-Control 'MultiLoadButton'
$MultiOverspeedBox = Get-Control 'MultiOverspeedBox'
$MultiKdBox = Get-Control 'MultiKdBox'
$MultiTimeoutBox = Get-Control 'MultiTimeoutBox'
$MultiRowsGrid = Get-Control 'MultiRowsGrid'
$MultiStartButton = Get-Control 'MultiStartButton'
$MultiStopButton = Get-Control 'MultiStopButton'
$MultiElapsedText = Get-Control 'MultiElapsedText'
$MultiProgress = Get-Control 'MultiProgress'
$MultiStatusText = Get-Control 'MultiStatusText'
$script:MultiBusy = $false
$script:MultiNeedsStop = $false
$script:MultiInternalSend = $false
$script:MultiPhase = 'Idle'
$script:MultiPlan = @()
$script:MultiPending = $null
$script:MultiReason = ''
$script:MultiClock = [Diagnostics.Stopwatch]::new()
$script:MultiRows = @()
$script:MultiSavedControls = @()
$script:MultiTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:MultiTimer.Interval = [TimeSpan]::FromMilliseconds(10)
$script:MultiSettingsPath = Join-Path $PSScriptRoot 'M8010-program.json'

$columnWidths = @(48, 42, 90, 150, 125, 145, 140, 150)
foreach ($width in $columnWidths) {
    $column = New-Object System.Windows.Controls.ColumnDefinition
    $column.Width = [System.Windows.GridLength]::new($width, [System.Windows.GridUnitType]::Star)
    $MultiRowsGrid.ColumnDefinitions.Add($column)
}
function Add-MultiCell($Control, [int]$Row, [int]$Column) {
    [System.Windows.Controls.Grid]::SetRow($Control, $Row)
    [System.Windows.Controls.Grid]::SetColumn($Control, $Column)
    $Control.Margin = [System.Windows.Thickness]::new(4, 2, 8, 2)
    [void]$MultiRowsGrid.Children.Add($Control)
}
$MultiRowsGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
$headers = @('启用', '序号', '电机 ID', '速度 rad/s', '时长 s', '实际 rad/s', '剩余 s', '状态')
for ($i = 0; $i -lt $headers.Count; $i++) {
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $headers[$i]
    $label.Foreground = [System.Windows.Media.Brushes]::LightSkyBlue
    Add-MultiCell $label 0 $i
}
for ($i = 0; $i -lt 8; $i++) {
    $MultiRowsGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $enabled = New-Object System.Windows.Controls.CheckBox
    $enabled.IsChecked = $true
    $enabled.VerticalAlignment = 'Center'
    $number = New-Object System.Windows.Controls.TextBlock
    $number.Text = [string]($i + 1)
    $idBox = New-Object System.Windows.Controls.TextBox
    $multiRowSpeedBox = New-Object System.Windows.Controls.TextBox
    $durationBox = New-Object System.Windows.Controls.TextBox
    $actual = New-Object System.Windows.Controls.TextBlock
    $remaining = New-Object System.Windows.Controls.TextBlock
    $state = New-Object System.Windows.Controls.TextBlock
    $state.TextWrapping = 'Wrap'
    $cells = @($enabled, $number, $idBox, $multiRowSpeedBox, $durationBox, $actual, $remaining, $state)
    for ($j = 0; $j -lt $cells.Count; $j++) { Add-MultiCell $cells[$j] ($i + 1) $j }
    $script:MultiRows += [pscustomobject]@{
        Enabled = $enabled; Id = $idBox; Speed = $multiRowSpeedBox; Duration = $durationBox
        Actual = $actual; Remaining = $remaining; State = $state
    }
}

function Get-MultiNow { return $script:MultiClock.Elapsed.TotalSeconds }

function Assert-MultiMotionAllowed {
    if ($script:MultiBusy) { throw '多电机程序正在执行，请先停止全部电机。' }
    if ($script:MultiNeedsStop) { throw '尚有电机未确认停止，请在“多电机程序”页重试锁定并检查反馈。' }
}

function Set-MultiControls {
    $blocked = $script:MultiBusy -or $script:MultiNeedsStop
    if ($blocked -and $script:MultiSavedControls.Count -eq 0) {
        $controls = @($script:IdMotionControls) + @($ReadMotorIdsButton, $FactoryReadIdsButton,
            $ChangeMotorIdButton, $RecoverMotorModeButton, $UseDetectedIdButton, $OverspeedLimitBox,
            $MultiModeCombo, $MultiTemplateButton, $MultiLoadButton, $MultiSaveButton,
            $MultiOverspeedBox, $MultiKdBox, $MultiTimeoutBox, $MultiStartButton)
        foreach ($row in $script:MultiRows) { $controls += @($row.Enabled, $row.Id, $row.Speed, $row.Duration) }
        $script:MultiSavedControls = @($controls | ForEach-Object {
            [pscustomobject]@{ Control = $_; Enabled = $_.IsEnabled }
        })
    }
    foreach ($entry in $script:MultiSavedControls) {
        $entry.Control.IsEnabled = if ($blocked) { $false } else { $entry.Enabled }
    }
    if (-not $blocked) {
        $script:MultiSavedControls = @()
        Set-IdOperationControls
    }
}

function Reset-MultiTemplate {
    Assert-MultiMotionAllowed
    for ($i = 0; $i -lt 8; $i++) {
        $row = $script:MultiRows[$i]
        $row.Enabled.IsChecked = $true
        $row.Id.Text = [string]($i + 2)
        $row.Speed.Text = '1'
        $row.Duration.Text = '2'
        $row.Actual.Text = '—'
        $row.Remaining.Text = '—'
        $row.State.Text = '待运行'
    }
    $MultiModeCombo.SelectedIndex = 0
    $MultiProgress.Value = 0
    $MultiElapsedText.Text = '已用时 0.0 s'
    $MultiStatusText.Text = '已装载模板：ID 2–9，输出轴 1 rad/s，各运行 2 秒；可修改后顺序或同时执行。'
}

function Read-MultiConfiguration {
    $ratio = Get-GearRatio
    if ([double]::IsNaN($ratio) -or [double]::IsInfinity($ratio)) { throw '减速比必须是有限数值。' }
    $limit = Read-Double $MultiOverspeedBox '多电机反馈超速阈值（请自行填写）'
    if ([double]::IsNaN($limit) -or [double]::IsInfinity($limit) -or $limit -le 0 -or $limit -gt 804) { throw '多电机超速阈值必须为大于 0 且不高于 804 rad/s 的有限数值，请自行设置。' }
    $kd = Read-Double $MultiKdBox '多电机速度增益'
    if ([double]::IsNaN($kd) -or [double]::IsInfinity($kd) -or $kd -le 0 -or $kd -gt 25.599) { throw '速度增益必须大于 0 且不高于 25.599。' }
    $timeout = Read-Int $MultiTimeoutBox '单次反馈超时' 50 5000
    if ($MultiModeCombo.SelectedIndex -notin 0, 1) { throw '请选择运行方式。' }
    $plan = @()
    $ids = @{}
    foreach ($row in $script:MultiRows) {
        if (-not $row.Enabled.IsChecked) { continue }
        $id = Read-Int $row.Id '电机 ID' 0 14
        if ($ids.ContainsKey($id)) { throw "电机 ID $id 重复，请为每一行设置不同的 ID。" }
        $ids[$id] = $true
        $speed = Read-Double $row.Speed "ID $id 的输出轴速度"
        $duration = Read-Double $row.Duration "ID $id 的运行时长"
        if ([double]::IsNaN($speed) -or [double]::IsInfinity($speed) -or [math]::Abs($speed * $ratio) -gt 804) { throw "ID $id 的速度超出转子侧 ±804 rad/s 可编码范围。" }
        if ([double]::IsNaN($duration) -or [double]::IsInfinity($duration) -or $duration -lt 0.1 -or $duration -gt 86400) { throw "ID $id 的时长须为 0.1–86400 秒。" }
        $plan += [pscustomobject]@{
            Id = $id; Speed = $speed; Duration = $duration; Ui = $row
            State = 'Unchecked'; Started = -1.0; LastSent = -1.0; Attempts = 0
        }
    }
    if ($plan.Count -eq 0) { throw '请至少启用一台电机。' }
    return [pscustomobject]@{ Plan = $plan; Ratio = $ratio; Limit = $limit; Kd = $kd; Timeout = $timeout / 1000.0; Parallel = ($MultiModeCombo.SelectedIndex -eq 1) }
}

function Write-MultiFrame([byte[]]$Frame, [string]$Description = '') {
    $script:MultiInternalSend = $true
    try {
        if ($Description) { Send-Bytes $Frame $Description }
        else {
            # Periodic frames do not append to the UI log on every poll.
            $script:SerialPort.Write($Frame, 0, $Frame.Length)
            $LastTxBox.Text = ConvertTo-HexString $Frame
        }
    } finally { $script:MultiInternalSend = $false }
}

function Send-MultiTransaction($Row, [int]$Status) {
    $now = Get-MultiNow
    $frame = if ($Status -eq 1) {
        ConvertTo-M8010ControlFrame -MotorId $Row.Id -Status 1 -SpeedRadPerSec ($Row.Speed * $script:MultiConfig.Ratio) -Kd $script:MultiConfig.Kd
    } else { ConvertTo-M8010ControlFrame -MotorId $Row.Id -Status 0 }
    $script:MultiPending = [pscustomobject]@{ Row = $Row; Status = $Status; Sent = $now }
    if ($Status -eq 1 -and $Row.Started -lt 0) {
        $Row.Started = $now
        $Row.State = 'Running'
        $Row.Ui.State.Text = '运行中'
        Write-Log "自动程序启动 ID $($Row.Id)：输出轴 $($Row.Speed) rad/s，$($Row.Duration) s"
    }
    $Row.LastSent = $now
    Write-MultiFrame $frame
}

function Start-MultiProgram {
    Assert-MultiMotionAllowed
    Assert-IdMotionAllowed
    if ($null -eq $script:SerialPort -or -not $script:SerialPort.IsOpen) { throw '请先打开串口。' }
    if ($script:SerialPort.BaudRate -ne 4000000) { throw '多电机程序需要 4000000 波特率。' }
    if ((Get-Date) -lt $script:CalibrationUntil) { throw '校准期间不能启动自动程序。' }
    $config = Read-MultiConfiguration
    if ($script:CycleTimer.IsEnabled -or $CycleCheck.IsChecked) { Stop-ControlOutput '自动程序前停止单电机控制' }
    $script:PendingPositionStart = $false
    $script:PendingPositionStartMotorId = -1
    $script:SerialPort.DiscardInBuffer()
    $script:RxBuffer.Clear()
    $script:MultiConfig = $config
    $script:MultiPlan = @($config.Plan)
    $script:MultiPending = $null
    $script:MultiReason = ''
    $script:MultiPhase = 'Preflight'
    $script:MultiBusy = $true
    $script:MultiClock.Restart()
    foreach ($row in $script:MultiRows) { $row.State.Text = '不参与'; $row.Actual.Text = '—'; $row.Remaining.Text = '—' }
    foreach ($row in $script:MultiPlan) { $row.Ui.State.Text = '等待预检' }
    $MultiProgress.Maximum = $script:MultiPlan.Count
    $MultiProgress.Value = 0
    $ModeCombo.SelectedIndex = 0
    Set-MultiControls
    $MultiStatusText.Text = '正在逐台读取并确认停止状态，全部预检通过后开始运行……'
    $script:ReceiveTimer.Start()
    $script:MultiTimer.Start()
}

function Complete-MultiProgram {
    $script:MultiTimer.Stop()
    $script:MultiClock.Stop()
    $script:MultiPending = $null
    $script:MultiBusy = $false
    $unconfirmed = @($script:MultiPlan | Where-Object { $_.State -eq 'Unconfirmed' })
    $script:MultiNeedsStop = $unconfirmed.Count -gt 0
    $MultiProgress.Value = @($script:MultiPlan | Where-Object { $_.State -in 'Done','Stopped' }).Count
    $MultiElapsedText.Text = '已用时 {0:0.0} s' -f (Get-MultiNow)
    if ($script:MultiNeedsStop) {
        $ids = ($unconfirmed | ForEach-Object { $_.Id }) -join ', '
        $MultiStatusText.Text = "程序已停止发送速度，但 ID $ids 未确认锁定。已尝试发送停止，请检查供电 / 接线后重试锁定；运动控制保持禁用。$($script:MultiReason)"
    } elseif ($script:MultiReason) { $MultiStatusText.Text = "程序已中止并确认全部锁定：$($script:MultiReason)" }
    else { $MultiStatusText.Text = '程序完成：所有参与电机均已到时，并收到 STATUS 0 锁定反馈。' }
    $script:MultiPhase = 'Idle'
    Set-MultiControls
    Write-Log $MultiStatusText.Text
}

function Stop-MultiProgram([string]$Reason = '手动停止') {
    if ($script:MultiBusy -and $script:MultiPhase -eq 'Stopping') { return }
    if (-not $script:MultiBusy -and -not $script:MultiNeedsStop) { $MultiStatusText.Text = '当前没有运行中的自动程序。'; return }
    $script:MultiReason = $Reason
    $script:MultiPending = $null
    $script:MultiBusy = $true
    $script:MultiPhase = 'Stopping'
    foreach ($row in $script:MultiPlan) {
        $row.State = 'StopPending'; $row.Attempts = 0; $row.Ui.State.Text = '等待锁定'
    }
    Set-MultiControls
    $MultiStatusText.Text = "正在停止全部电机并逐台确认：$Reason"
    # Broadcast lock has no reply and quickly stops the bus before individual
    # verification, so an absent first motor cannot delay stops of the others.
    try { Write-MultiFrame (ConvertTo-M8010ControlFrame -MotorId 15 -Status 0) '自动程序停止：总线广播锁定' }
    catch { Write-Log "广播停止发送失败：$($_.Exception.Message)" }
    $script:MultiTimer.Start()
}

function Accept-MultiFeedback($Feedback) {
    if (-not $script:MultiBusy) { return }
    $row = @($script:MultiPlan | Where-Object { $_.Id -eq $Feedback.MotorId })
    if ($row.Count -ne 1) { return }
    $row = $row[0]
    $row.Ui.Actual.Text = '{0:0.###}' -f $Feedback.SpeedRadPerSec
    if ($script:MultiPhase -ne 'Stopping' -and ($Feedback.ErrorCode -ne 0 -or $Feedback.TemperatureC -ge 90 -or
        [math]::Abs($Feedback.SpeedRadPerSec) -gt $script:MultiConfig.Limit)) {
        Stop-MultiProgram "ID $($row.Id) 反馈异常：错误码 $($Feedback.ErrorCode)，温度 $($Feedback.TemperatureC) °C，速度 $($Feedback.SpeedRadPerSec) rad/s"
        return
    }
    $pending = $script:MultiPending
    if ($null -eq $pending -or $pending.Row.Id -ne $Feedback.MotorId -or $pending.Status -ne $Feedback.Status) { return }
    $script:MultiPending = $null
    if ($script:MultiPhase -eq 'Preflight') { $row.State = 'Ready'; $row.Ui.State.Text = '预检通过' }
    elseif ($pending.Status -eq 0) {
        $row.State = if ($script:MultiPhase -eq 'Stopping') { 'Stopped' } else { 'Done' }
        $row.Ui.State.Text = if ($row.State -eq 'Done') { '完成 / 已锁定' } else { '中止 / 已锁定' }
        $row.Ui.Remaining.Text = '0.0'
    }
}

function Step-MultiProgram {
    if (-not $script:MultiBusy) { return }
    try {
        $now = Get-MultiNow
        $MultiElapsedText.Text = '已用时 {0:0.0} s' -f $now
        foreach ($row in $script:MultiPlan) {
            if ($row.State -eq 'Running') { $row.Ui.Remaining.Text = '{0:0.0}' -f [math]::Max(0, $row.Duration - ($now - $row.Started)) }
        }
        $MultiProgress.Value = @($script:MultiPlan | Where-Object { $_.State -in 'Done','Stopped' }).Count
        if ($null -eq $script:SerialPort -or -not $script:SerialPort.IsOpen) { throw '串口已断开' }
        if ($null -ne $script:MultiPending) {
            # A long user-selected response timeout must not extend a timed
            # movement indefinitely. Allow a small scheduling margin, then lock
            # the bus if another outstanding transaction prevents a due stop.
            if ($script:MultiPhase -eq 'Run') {
                $overdue = @($script:MultiPlan | Where-Object {
                    $_.State -eq 'Running' -and ($now - $_.Started) -ge ($_.Duration + 0.05) -and
                    -not ($script:MultiPending.Status -eq 0 -and $script:MultiPending.Row.Id -eq $_.Id)
                })
                if ($overdue.Count) { Stop-MultiProgram '运行时长已到但反馈仍未返回，停止整组'; return }
            }
            if (($now - $script:MultiPending.Sent) -lt $script:MultiConfig.Timeout) { return }
            $row = $script:MultiPending.Row
            $script:MultiPending = $null
            if ($script:MultiPhase -ne 'Stopping') { Stop-MultiProgram "ID $($row.Id) 反馈超时"; return }
            if ($row.Attempts -ge 3) { $row.State = 'Unconfirmed'; $row.Ui.State.Text = '未确认锁定' }
        }
        if ($script:MultiPhase -eq 'Stopping') {
            $next = @($script:MultiPlan | Where-Object { $_.State -eq 'StopPending' } | Select-Object -First 1)
            if ($next.Count) { $next[0].Attempts++; Send-MultiTransaction $next[0] 0 }
            else { Complete-MultiProgram }
            return
        }
        if ($script:MultiPhase -eq 'Preflight') {
            $next = @($script:MultiPlan | Where-Object { $_.State -eq 'Unchecked' } | Select-Object -First 1)
            if ($next.Count) { Send-MultiTransaction $next[0] 0; return }
            $script:MultiPhase = 'Run'
            $MultiStatusText.Text = if ($script:MultiConfig.Parallel) { '同时执行中：每台电机独立计时，到时分别锁定。' } else { '顺序执行中：上一台到时并确认锁定后，再启动下一台。' }
        }
        $due = @($script:MultiPlan | Where-Object { $_.State -eq 'Running' -and ($now - $_.Started) -ge $_.Duration } | Select-Object -First 1)
        if ($due.Count) { Send-MultiTransaction $due[0] 0; return }
        $active = @($script:MultiPlan | Where-Object { $_.State -eq 'Running' })
        $ready = @($script:MultiPlan | Where-Object { $_.State -eq 'Ready' } | Select-Object -First 1)
        if ($ready.Count -and ($script:MultiConfig.Parallel -or $active.Count -eq 0)) { Send-MultiTransaction $ready[0] 1; return }
        if ($active.Count) {
            $next = @($active | Sort-Object LastSent | Select-Object -First 1)[0]
            if (($now - $next.LastSent) -ge 0.02) { Send-MultiTransaction $next 1 }
        } elseif ($ready.Count -eq 0) { Complete-MultiProgram }
    } catch {
        $errorMessage = $_.Exception.Message
        if ($script:MultiPhase -ne 'Stopping') { Stop-MultiProgram $errorMessage }
        else {
            foreach ($row in $script:MultiPlan) {
                if ($row.State -notin 'Done','Stopped') { $row.State = 'Unconfirmed'; $row.Ui.State.Text = '未确认锁定' }
            }
            $script:MultiReason += "；$errorMessage"
            Complete-MultiProgram
        }
    }
}

function Save-MultiConfiguration {
    Assert-MultiMotionAllowed
    $rows = @($script:MultiRows | ForEach-Object {
        [pscustomobject]@{ Enabled = [bool]$_.Enabled.IsChecked; Id = $_.Id.Text; Speed = $_.Speed.Text; Duration = $_.Duration.Text }
    })
    $data = [pscustomobject]@{ Version = 1; Mode = $MultiModeCombo.SelectedIndex; Limit = $MultiOverspeedBox.Text; Kd = $MultiKdBox.Text; Timeout = $MultiTimeoutBox.Text; Rows = $rows }
    [IO.File]::WriteAllText($script:MultiSettingsPath, ($data | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($true))
    $MultiStatusText.Text = '参数已保存到程序目录的 M8010-program.json。载入不会自动运行。'
}

function Load-MultiConfiguration {
    Assert-MultiMotionAllowed
    $data = [IO.File]::ReadAllText($script:MultiSettingsPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($data.Version -ne 1 -or @($data.Rows).Count -ne 8 -or $data.Mode -notin 0,1) { throw '参数文件格式不正确。' }
    for ($i = 0; $i -lt 8; $i++) {
        $row = $script:MultiRows[$i]; $saved = $data.Rows[$i]
        $row.Enabled.IsChecked = [bool]$saved.Enabled
        $row.Id.Text = [string]$saved.Id; $row.Speed.Text = [string]$saved.Speed; $row.Duration.Text = [string]$saved.Duration
    }
    $MultiModeCombo.SelectedIndex = [int]$data.Mode
    $MultiOverspeedBox.Text = [string]$data.Limit; $MultiKdBox.Text = [string]$data.Kd; $MultiTimeoutBox.Text = [string]$data.Timeout
    $MultiStatusText.Text = '参数已载入。启动时将重新检查范围和重复 ID，不会自动运行。'
}

$MultiTemplateButton.Add_Click({ try { Reset-MultiTemplate } catch { Show-Problem $_.Exception.Message } })
$MultiStartButton.Add_Click({ try { Start-MultiProgram } catch { if ($script:MultiBusy) { Stop-MultiProgram $_.Exception.Message }; Show-Problem $_.Exception.Message } })
$MultiStopButton.Add_Click({ Stop-MultiProgram '手动停止' })
$MultiSaveButton.Add_Click({ try { Save-MultiConfiguration } catch { Show-Problem $_.Exception.Message } })
$MultiLoadButton.Add_Click({ try { Load-MultiConfiguration } catch { Show-Problem $_.Exception.Message } })
$script:MultiTimer.Add_Tick({ Step-MultiProgram })
Reset-MultiTemplate
