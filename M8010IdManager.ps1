# UI-thread-only ID workflow. No driver-thread PowerShell callbacks or blocking waits.
$ReadMotorIdsButton = Get-Control 'ReadMotorIdsButton'
$UseDetectedIdButton = Get-Control 'UseDetectedIdButton'
$DetectedIdsCombo = Get-Control 'DetectedIdsCombo'
$IdReadStatusText = Get-Control 'IdReadStatusText'
$SingleMotorIdCheck = Get-Control 'SingleMotorIdCheck'
$CurrentMotorIdBox = Get-Control 'CurrentMotorIdBox'
$NewMotorIdBox = Get-Control 'NewMotorIdBox'
$FactoryReadIdsButton = Get-Control 'FactoryReadIdsButton'
$ChangeMotorIdButton = Get-Control 'ChangeMotorIdButton'
$RecoverMotorModeButton = Get-Control 'RecoverMotorModeButton'
$CancelIdOperationButton = Get-Control 'CancelIdOperationButton'
$IdOperationStatusText = Get-Control 'IdOperationStatusText'

$script:IdBusy = $false
$script:IdNeedsRecovery = $false
$script:IdInternalSend = $false
$script:IdPhase = 'Idle'
$script:IdPurpose = ''
$script:IdDue = [DateTime]::MinValue
$script:IdRx = [System.Collections.Generic.List[byte]]::new()
$script:IdDiscovery = [System.Collections.Generic.List[byte]]::new()
$script:IdFirstDiscovery = [byte[]]@()
$script:IdFound = @{}
$script:IdOld = 0
$script:IdNew = 0
$script:IdFactoryFound = -1
$script:IdScanIndex = 0
$script:IdScanPass = 0
$script:IdRestoreIndex = 0
$script:IdFailure = ''
$script:IdChangeAcknowledged = $false
$script:IdChangeSent = $false
$script:IdVerifyStarted = $false
$script:IdMotionSaved = @{}
$script:IdMotionControls = @($StartFocButton, $SendButton, $CycleCheck, $ModeCombo,
    $ForwardButton, $ReverseButton, $SpeedUpButton, $SpeedDownButton, $CalibrationButton,
    $PositionModeButton, $SpeedModeButton, $DirectSpeedModeButton, $DampingModeButton,
    $TorqueModeButton, $ZeroTorqueModeButton, $HybridModeButton, $RefreshStateButton,
    $RawSendButton, $RawSendBox, $MotorIdBox, $BroadcastCheck, $GearRatioBox, $OutputUnitsCheck)
$script:IdTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:IdTimer.Interval = [TimeSpan]::FromMilliseconds(20)

function Assert-IdMotionAllowed {
    if ($script:IdBusy) { throw '电机 ID 操作进行中，请等待完成，或在“电机 ID”页取消 / 恢复。' }
    if ($script:IdNeedsRecovery) { throw '尚未验证已恢复电机模式；请到“电机 ID”页恢复或重新扫描后再控制。' }
}

function Set-IdOperationControls {
    $blocked = $script:IdBusy -or $script:IdNeedsRecovery
    foreach ($control in $script:IdMotionControls) {
        if ($blocked) {
            if (-not $script:IdMotionSaved.ContainsKey($control.Name)) {
                $script:IdMotionSaved[$control.Name] = $control.IsEnabled
            }
            $control.IsEnabled = $false
        } elseif ($script:IdMotionSaved.ContainsKey($control.Name)) {
            $control.IsEnabled = $script:IdMotionSaved[$control.Name]
        }
    }
    if (-not $blocked) {
        $script:IdMotionSaved.Clear()
        $MotorIdBox.IsEnabled = -not $BroadcastCheck.IsChecked
    }
    foreach ($control in @($ReadMotorIdsButton, $FactoryReadIdsButton, $ChangeMotorIdButton,
        $RecoverMotorModeButton, $UseDetectedIdButton, $SingleMotorIdCheck,
        $CurrentMotorIdBox, $NewMotorIdBox, $DetectedIdsCombo)) {
        $control.IsEnabled = -not $script:IdBusy
    }
    $CancelIdOperationButton.IsEnabled = $script:IdBusy
}

function Set-IdPhase([string]$Phase, [int]$WaitMs, [string]$Message = '') {
    $script:IdPhase = $Phase
    $script:IdDue = (Get-Date).AddMilliseconds($WaitMs)
    if ($Message) { $IdOperationStatusText.Text = $Message }
}

function Send-IdBytes([byte[]]$Bytes, [string]$Description) {
    $script:IdInternalSend = $true
    try { Send-Bytes $Bytes $Description } finally { $script:IdInternalSend = $false }
}

function Clear-IdInput {
    $script:SerialPort.DiscardInBuffer()
    $script:RxBuffer.Clear()
    $script:IdRx.Clear()
    $script:IdDiscovery.Clear()
}

function Complete-IdOperation([string]$Message) {
    $script:IdTimer.Stop()
    $script:IdBusy = $false
    $script:IdPhase = 'Idle'
    $script:IdRx.Clear()
    $script:IdDiscovery.Clear()
    Set-IdOperationControls
    $IdOperationStatusText.Text = $Message
    Write-Log $Message
}

function Publish-IdResults {
    $DetectedIdsCombo.Items.Clear()
    foreach ($id in @($script:IdFound.Keys | Sort-Object)) { [void]$DetectedIdsCombo.Items.Add([int]$id) }
    if ($DetectedIdsCombo.Items.Count -gt 0) { $DetectedIdsCombo.SelectedIndex = 0 }
    if ($script:IdFound.Count -eq 1) { $CurrentMotorIdBox.Text = [string]@($script:IdFound.Keys)[0] }
    $ids = @($script:IdFound.Keys | Sort-Object) -join ', '
    $IdReadStatusText.Text = if ($script:IdFound.Count) {
        "已收到有效反馈的 ID：$ids。相同 ID 的多台电机无法通过扫描区分。"
    } else { '未收到 ID 0–14 的有效反馈。请检查供电、4 Mbps 串口、接线；工厂模式或 ID 15 请用单电机工厂读取 / 恢复。' }
}

function Send-IdScanQuery {
    Clear-IdInput
    $id = $script:IdScanIndex
    $frame = ConvertTo-M8010ControlFrame -MotorId $id -Status 0
    Send-IdBytes $frame "读取电机 ID $id（第 $($script:IdScanPass + 1) 轮）"
    Set-IdPhase 'ScanWait' 200 "正在读取 ID $id / 14（第 $($script:IdScanPass + 1) / 2 轮）……"
}

function Start-IdScan {
    $script:IdFound = @{}
    $script:IdScanIndex = 0
    $script:IdScanPass = 0
    $script:IdVerifyStarted = $true
    Send-IdScanQuery
}

function Start-IdRestore {
    # Target every possible factory ID, including unassigned 15. This also
    # recovers after a write whose acknowledgement was lost (old/new ID unknown).
    $script:IdNeedsRecovery = $true
    $script:IdRestoreIndex = 0
    Clear-IdInput
    Send-IdBytes (New-M8010FactoryCommand -Command PrepareMotor -MotorId 0) '准备恢复电机模式 ID 0'
    Set-IdPhase 'RestorePrepareWait' 100 '正在恢复电机模式，请勿断开串口……'
}

function Start-IdOperation([ValidateSet('Read', 'FactoryRead', 'Change', 'Recover')][string]$Purpose) {
    Assert-MultiMotionAllowed
    if ($script:IdBusy) { throw '已有 ID 操作正在进行。' }
    if ($null -eq $script:SerialPort -or -not $script:SerialPort.IsOpen) { throw '请先在“连接与安全”页打开串口。' }
    if ((Get-Date) -lt $script:CalibrationUntil) { throw '编码器校准期间禁止 ID 操作。' }
    if ($script:SerialPort.BaudRate -ne 4000000) { throw 'GO-M8010-6 的 ID 操作需要 4000000 波特率，请重新设置并打开串口。' }
    if ($Purpose -ne 'Read' -and -not $SingleMotorIdCheck.IsChecked) { throw '工厂配置前请只连接一台电机、停止其他主机发送，并勾选单电机确认。' }
    if ($Purpose -eq 'Change') {
        $old = Read-Int $CurrentMotorIdBox '当前 ID' 0 15
        $new = Read-Int $NewMotorIdBox '新 ID' 0 14
        if ($old -eq $new) { throw '新 ID 与当前 ID 相同，无需修改。' }
        $script:IdOld = $old
        $script:IdNew = $new
    }
    # Stop any pending position auto-start before taking ownership of the port.
    $script:PendingPositionStart = $false
    $script:PendingPositionStartMotorId = -1
    if ($script:CycleTimer.IsEnabled -or $CycleCheck.IsChecked) { Stop-ControlOutput 'ID 操作前停止' }
    $script:IdBusy = $true
    $script:IdPurpose = $Purpose
    $script:IdFailure = ''
    $script:IdChangeSent = $false
    $script:IdChangeAcknowledged = $false
    $script:IdFactoryFound = -1
    $script:IdVerifyStarted = $false
    $script:IdFound = @{}
    $script:LastFeedback = $null
    $script:LastFeedbackAt = [DateTime]::MinValue
    Set-IdOperationControls
    $script:IdTimer.Start()
    try {
        Clear-IdInput
        if ($Purpose -eq 'Recover') { Start-IdRestore; return }
        if (-not $script:IdNeedsRecovery) {
            Send-IdBytes (ConvertTo-M8010ControlFrame -MotorId 15 -Status 0) 'ID 操作前停止总线输出'
        }
        $ModeCombo.SelectedIndex = 0
        # Mode selection updates raw-frame controls; retain ID port ownership.
        Set-IdOperationControls
        if ($Purpose -eq 'Read') { Start-IdScan; return }
        $script:IdNeedsRecovery = $true
        Send-IdBytes (New-M8010EnterFactoryFrame) '进入工厂模式（MotorTools）'
        Set-IdPhase 'BootWait' 1000 '正在进入工厂模式（电机绿灯应快速闪烁）……'
    } catch { Fail-IdOperation $_.Exception.Message }
}

function Fail-IdOperation([string]$Message) {
    $script:IdFailure = $Message
    Write-Log "ID 操作异常：$Message"
    if ($script:IdNeedsRecovery -and $script:IdPhase -notlike 'Restore*' -and -not $script:IdVerifyStarted -and
        $null -ne $script:SerialPort -and $script:SerialPort.IsOpen) {
        try { Start-IdRestore; return } catch { $Message += "；恢复发送失败：$($_.Exception.Message)" }
    }
    Complete-IdOperation "操作未完成：$Message。若仍在工厂模式，请单电机连接后点击恢复电机模式。"
}

function Cancel-IdOperation {
    if ($script:IdBusy -and $script:IdPhase -like 'Restore*') { return }
    if ($script:IdBusy -or $script:IdNeedsRecovery) {
        $script:IdFailure = '用户取消，未声明修改成功'
        if ($script:IdNeedsRecovery -and $null -ne $script:SerialPort -and $script:SerialPort.IsOpen) {
            $script:IdBusy = $true
            $script:IdTimer.Start()
            Set-IdOperationControls
            try { Start-IdRestore } catch { Fail-IdOperation $_.Exception.Message }
        } else { Complete-IdOperation 'ID 读取已取消，电机保持停止。' }
    }
}

function Receive-IdSerialData {
    try {
        $port = $script:SerialPort
        $budget = 65536
        while ($port.BytesToRead -gt 0 -and $budget -gt 0) {
            $count = [Math]::Min($port.BytesToRead, [Math]::Min($budget, 16384))
            $bytes = [byte[]]::new($count)
            $read = $port.Read($bytes, 0, $count)
            $budget -= $read
            if ($read -le 0) { break }
            Accept-IdInput ([byte[]]$bytes[0..($read - 1)])
        }
    } catch [System.TimeoutException] { } catch { Fail-IdOperation $_.Exception.Message }
}

function Accept-IdInput([byte[]]$Bytes) {
    if ($script:IdPhase -in 'DiscoverWait', 'DiscoverAgainWait') {
        # swboot returns raw one-byte IDs, not normal FD EE feedback. Do not
        # interpret arbitrary bytes as a successful write or a verified motor.
        foreach ($b in $Bytes) {
            if ($script:IdDiscovery.Count -ge 64) { throw '工厂回复过长，可能有回显或其他主机干扰。' }
            $script:IdDiscovery.Add($b)
        }
        return
    }
    foreach ($b in $Bytes) { $script:IdRx.Add($b) }
    if ($script:IdPhase -eq 'ScanWait') {
        $parsed = Find-M8010FeedbackFrames ([byte[]]$script:IdRx.ToArray())
        $script:IdRx.Clear()
        foreach ($b in $parsed.Remaining) { $script:IdRx.Add($b) }
        $script:RxCrcDrops += $parsed.CrcDrops
        foreach ($feedback in $parsed.Frames) {
            $script:RxFrames++
            if ($feedback.MotorId -eq $script:IdScanIndex) {
                $script:IdFound[[int]$feedback.MotorId] = $feedback
                Update-Feedback $feedback
            }
        }
        return
    }
    $parsed = Find-M8010FactoryReplies ([byte[]]$script:IdRx.ToArray())
    $script:IdRx.Clear()
    foreach ($b in $parsed.Remaining) { $script:IdRx.Add($b) }
    foreach ($reply in $parsed.Replies) {
        if ($script:IdPhase -eq 'ChangeWait' -and $reply.Command -eq 1 -and
            $reply.MotorId -eq $script:IdNew -and $reply.Result -eq 0) {
            $script:IdChangeAcknowledged = $true
        }
        if ($reply.Command -eq 3 -and $reply.Result -in 12, 14) {
            $script:IdFailure = "电机 ID $($reply.MotorId) 的工厂回复报告固件缺失或固件校验错误（$($reply.Result)）"
        }
    }
}

function Finish-IdVerification {
    Publish-IdResults
    if ($script:IdPurpose -eq 'Change') {
        $verified = $script:IdChangeAcknowledged -and $script:IdFound.Count -eq 1 -and
            $script:IdFound.ContainsKey($script:IdNew) -and -not $script:IdFailure
        if ($verified) {
            $script:IdNeedsRecovery = $false
            $BroadcastCheck.IsChecked = $false
            $MotorIdBox.Text = [string]$script:IdNew
            $CurrentMotorIdBox.Text = [string]$script:IdNew
            Complete-IdOperation "修改成功：ID $($script:IdOld) → $($script:IdNew)。已恢复电机模式，并收到新 ID 的 CRC 正确反馈；控制目标已同步。"
        } else {
            # Normal feedback proves a motor is running again, but cannot by
            # itself prove the requested write was acknowledged and committed.
            if ($script:IdFound.Count -gt 0) { $script:IdNeedsRecovery = $false }
            $reason = if ($script:IdFailure) { $script:IdFailure } elseif (-not $script:IdChangeAcknowledged) { '未收到匹配的新 ID 写入确认' } else { '新 ID 验证失败或收到多个 ID' }
            Complete-IdOperation "修改未确认：$reason。请核对读取结果后重试；不要按修改成功使用。"
        }
    } else {
        if ($script:IdFound.Count -gt 0) { $script:IdNeedsRecovery = $false }
        if ($script:IdPurpose -eq 'FactoryRead' -and $script:IdFactoryFound -eq 15) {
            $CurrentMotorIdBox.Text = '15'
            Complete-IdOperation '工厂读取到未分配 ID 15。已发送恢复指令，但广播地址不返回普通反馈；请将其修改为 0–14 并验证。'
        } elseif ($script:IdFailure) {
            Complete-IdOperation "已尝试恢复电机模式；$($script:IdFailure)。请查看读取结果。"
        } elseif ($script:IdFound.Count) {
            Complete-IdOperation ('读取完成：ID {0}。电机保持停止。' -f (@($script:IdFound.Keys | Sort-Object) -join ', '))
        } else {
            Complete-IdOperation '未收到有效反馈；不能确认连接或电机模式。请检查接线 / 供电，必要时单电机恢复。'
        }
    }
}

function Step-IdOperation {
    if (-not $script:IdBusy -or (Get-Date) -lt $script:IdDue) { return }
    if ($null -eq $script:SerialPort -or -not $script:SerialPort.IsOpen) { Fail-IdOperation '串口已断开'; return }
    try {
        switch ($script:IdPhase) {
            'BootWait' {
                Clear-IdInput
                Send-IdBytes (New-M8010FactoryCommand -Command Discover) '工厂读取 ID（第一次）'
                Set-IdPhase 'DiscoverWait' 1500 '正在读取工厂 ID……'
            }
            'DiscoverWait' {
                if ($script:IdDiscovery.Count -ne 1 -or $script:IdDiscovery[0] -gt 15) {
                    throw '未识别到唯一工厂 ID；可能无反馈、重复 ID、多台电机或串口回显。未发送修改指令。'
                }
                $script:IdFirstDiscovery = [byte[]]$script:IdDiscovery.ToArray()
                Clear-IdInput
                Send-IdBytes (New-M8010FactoryCommand -Command Discover) '工厂读取 ID（再次核对）'
                Set-IdPhase 'DiscoverAgainWait' 1500 '正在再次核对单电机 ID……'
            }
            'DiscoverAgainWait' {
                if ($script:IdDiscovery.Count -ne 1 -or $script:IdDiscovery[0] -ne $script:IdFirstDiscovery[0]) {
                    throw '两次工厂 ID 读取不一致，未发送修改指令。'
                }
                $script:IdFactoryFound = [int]$script:IdDiscovery[0]
                $CurrentMotorIdBox.Text = [string]$script:IdFactoryFound
                if ($script:IdPurpose -eq 'Change') {
                    if ($script:IdFactoryFound -ne $script:IdOld) { throw "实际 ID 为 $($script:IdFactoryFound)，与输入的原 ID $($script:IdOld) 不符，未发送修改指令。" }
                    Clear-IdInput
                    $script:IdChangeSent = $true
                    Send-IdBytes (New-M8010FactoryCommand -Command ChangeId -MotorId $script:IdOld -NewId $script:IdNew) '修改电机 ID'
                    Set-IdPhase 'ChangeWait' 1500 '已发送 ID 修改，正在等待电机确认……'
                } else { Start-IdRestore }
            }
            'ChangeWait' {
                if (-not $script:IdChangeAcknowledged) { $script:IdFailure = 'ID 修改未收到匹配确认，结果未知' }
                Start-IdRestore
            }
            'RestorePrepareWait' {
                Send-IdBytes (New-M8010FactoryCommand -Command StartMotor -MotorId $script:IdRestoreIndex) "恢复电机模式 ID $($script:IdRestoreIndex)"
                Set-IdPhase 'RestoreStartWait' 100
            }
            'RestoreStartWait' {
                $script:IdRestoreIndex++
                if ($script:IdRestoreIndex -le 15) {
                    Send-IdBytes (New-M8010FactoryCommand -Command PrepareMotor -MotorId $script:IdRestoreIndex) "准备恢复 ID $($script:IdRestoreIndex)"
                    Set-IdPhase 'RestorePrepareWait' 100
                } else { Set-IdPhase 'RestoreSettle' 1000 '已发送恢复指令，等待电机启动并验证……' }
            }
            'RestoreSettle' { Start-IdScan }
            'ScanWait' {
                $script:IdScanIndex++
                if ($script:IdScanIndex -ge 15) {
                    $script:IdScanIndex = 0
                    $script:IdScanPass++
                }
                if ($script:IdScanPass -ge 2) { Finish-IdVerification }
                else { Send-IdScanQuery }
            }
        }
    } catch { Fail-IdOperation $_.Exception.Message }
}

$ReadMotorIdsButton.Add_Click({ try { Start-IdOperation 'Read' } catch { Show-Problem $_.Exception.Message } })
$FactoryReadIdsButton.Add_Click({ try { Start-IdOperation 'FactoryRead' } catch { Show-Problem $_.Exception.Message } })
$ChangeMotorIdButton.Add_Click({ try { Start-IdOperation 'Change' } catch { Show-Problem $_.Exception.Message } })
$RecoverMotorModeButton.Add_Click({ try { Start-IdOperation 'Recover' } catch { Show-Problem $_.Exception.Message } })
$CancelIdOperationButton.Add_Click({ Cancel-IdOperation })
$UseDetectedIdButton.Add_Click({
    try {
        Assert-IdMotionAllowed
        if ($null -eq $DetectedIdsCombo.SelectedItem) { throw '请先读取并选择一个有效电机 ID。' }
        $BroadcastCheck.IsChecked = $false
        $MotorIdBox.Text = [string]$DetectedIdsCombo.SelectedItem
        $CurrentMotorIdBox.Text = $MotorIdBox.Text
        $script:PendingPositionStart = $false
        $IdOperationStatusText.Text = "已将 ID $($MotorIdBox.Text) 设为控制目标；尚未启动输出。"
    } catch { Show-Problem $_.Exception.Message }
})
$script:IdTimer.Add_Tick({ Step-IdOperation })
