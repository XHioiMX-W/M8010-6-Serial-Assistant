# Invoked by M8010SerialAssistant.ps1 -SmokeTest with a fully loaded WPF UI.
# Never opens a real serial port or sends commands to attached hardware.
function New-IdTestFeedback([int]$Id) {
    $data = [byte[]]@(0xFD,0xEE,$Id,0,0,0,0,0,0,0,0,25,0,0)
    $crc = Get-M8010Crc16 $data
    return [byte[]]($data + [byte[]]@(($crc -band 255), ($crc -shr 8)))
}

function New-IdTestPort {
    $port = [pscustomobject]@{
        IsOpen = $true; BaudRate = 4000000
        Writes = [System.Collections.Generic.List[object]]::new()
    }
    $port | Add-Member ScriptMethod Write {
        param([byte[]]$Bytes, [int]$Offset, [int]$Count)
        $this.Writes.Add([byte[]]$Bytes.Clone())
    }
    $port | Add-Member ScriptMethod DiscardInBuffer { }
    return $port
}

function Advance-IdTest {
    $script:IdDue = [DateTime]::MinValue
    Step-IdOperation
}

function Drive-IdTest([int[]]$MotorIds, [int]$FactoryId = 0, [bool]$Acknowledge = $true) {
    for ($tick = 0; $tick -lt 150 -and $script:IdBusy; $tick++) {
        switch ($script:IdPhase) {
            { $_ -in 'DiscoverWait','DiscoverAgainWait' } { Accept-IdInput ([byte[]]@($FactoryId)) }
            'ChangeWait' {
                if ($Acknowledge) {
                    Accept-IdInput ([byte[]]@(0xFC,1))
                    Accept-IdInput ([byte[]]@($script:IdNew,0xBB))
                }
            }
            'ScanWait' {
                if ($script:IdScanIndex -in $MotorIds) {
                    $data = New-IdTestFeedback $script:IdScanIndex
                    Accept-IdInput $data[0..6]
                    Accept-IdInput $data[7..15]
                }
            }
        }
        Advance-IdTest
    }
    if ($script:IdBusy) { throw "ID 测试超过步数：$($script:IdPhase)" }
}

function Assert-IdTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$script:SerialPort = New-IdTestPort
$script:IdNeedsRecovery = $false
$script:CycleTimer.Stop()
$script:PendingPositionStart = $true
$ModeCombo.SelectedIndex = 1
Start-IdOperation Read
Assert-IdTest (-not $script:PendingPositionStart) '扫描未取消旧的位置保持自动启动。'
Assert-IdTest (-not $RawSendButton.IsEnabled -and -not $RawSendBox.IsEnabled) '切换锁定模式后重新启用了原始帧控件。'
$blocked = $false
try { Send-Bytes (ConvertTo-M8010ControlFrame -MotorId 0 -Status 1) '禁止的运动帧' } catch { $blocked = $true }
Assert-IdTest $blocked '扫描期间没有阻止运动帧。'
# Wrong IDs and bad CRCs must not enter discovery results.
Accept-IdInput (New-IdTestFeedback 12)
$corrupt = New-IdTestFeedback 0
$corrupt[15] = $corrupt[15] -bxor 1
Accept-IdInput $corrupt
Assert-IdTest ($script:IdFound.Count -eq 0) '扫描接受了错误 ID 或 CRC。'
Drive-IdTest @(0,3,14)
Assert-IdTest ($script:IdFound.Count -eq 3) '扫描遗漏了电机 ID。'
Assert-IdTest ($DetectedIdsCombo.Items.Count -eq 3) '界面没有列出扫描结果。'
Assert-IdTest (-not $script:CycleTimer.IsEnabled) '扫描后自动启动了运动。'
Assert-IdTest ($script:SerialPort.Writes.Count -eq 31) '扫描未完成两轮 0–14 查询。'

$script:SerialPort = New-IdTestPort
$SingleMotorIdCheck.IsChecked = $false
$blocked = $false
try { Start-IdOperation Change } catch { $blocked = $true }
Assert-IdTest ($blocked -and $script:SerialPort.Writes.Count -eq 0) '未确认单电机时仍发送了配置指令。'
$SingleMotorIdCheck.IsChecked = $true
$CurrentMotorIdBox.Text = '0'
$NewMotorIdBox.Text = '2'
Start-IdOperation Change
Drive-IdTest @(2) 0
Assert-IdTest ($IdOperationStatusText.Text -like '修改成功*') '修改成功未通过完整恢复和验证流程。'
Assert-IdTest ($MotorIdBox.Text -eq '2' -and -not $script:IdNeedsRecovery) '成功后没有同步控制目标或解除恢复锁。'
$commands = @($script:SerialPort.Writes | ForEach-Object { ConvertTo-HexString $_ })
Assert-IdTest ($commands -contains 'FB 01 20 BB') '没有发送正确的 ID 修改指令。'
Assert-IdTest ($commands -contains 'FB 04 0F BB' -and $commands -contains 'FB 03 0F BB') '恢复流程没有覆盖未分配 ID 15。'
foreach ($bytes in $script:SerialPort.Writes) {
    if ($bytes.Length -eq 17) { Assert-IdTest ($bytes[2] -eq 0x7F -or $bytes[2] -le 15) '配置流程意外发送了运动或校准指令。' }
}

$script:SerialPort = New-IdTestPort
$CurrentMotorIdBox.Text = '2'
$NewMotorIdBox.Text = '4'
Start-IdOperation Change
Drive-IdTest @(2) 3
Assert-IdTest (-not $script:IdChangeSent) '实际 ID 不匹配时仍修改了 ID。'
Assert-IdTest ($IdOperationStatusText.Text -notlike '修改成功*') 'ID 不匹配时误报成功。'

$script:SerialPort = New-IdTestPort
$CurrentMotorIdBox.Text = '2'
Start-IdOperation Change
Drive-IdTest @(4) 2 $false
Assert-IdTest ($IdOperationStatusText.Text -like '修改未确认*') '没有写入确认时误报修改成功。'
Assert-IdTest ($MotorIdBox.Text -eq '2') '没有写入确认时自动更改了控制目标。'

$script:SerialPort = New-IdTestPort
Start-IdOperation FactoryRead
Drive-IdTest @() 15
Assert-IdTest ($CurrentMotorIdBox.Text -eq '15' -and $script:IdNeedsRecovery) '工厂读取 ID 15 没有显示结果并保留验证锁。'

$script:SerialPort = New-IdTestPort
$CurrentMotorIdBox.Text = '15'
$NewMotorIdBox.Text = '1'
Start-IdOperation Change
Drive-IdTest @(1) 15
Assert-IdTest ($IdOperationStatusText.Text -like '修改成功*') '未分配 ID 15 无法配置。'

$script:SerialPort = New-IdTestPort
Start-IdOperation FactoryRead
Advance-IdTest
Accept-IdInput ([byte[]]@(1,1))
Advance-IdTest
Assert-IdTest ($script:IdPhase -like 'Restore*') '重复 / 多电机工厂回复没有触发恢复。'
Drive-IdTest @(1) 1
Assert-IdTest (-not $script:IdChangeSent) '工厂读取意外修改了 ID。'

$script:SerialPort = New-IdTestPort
Start-IdOperation FactoryRead
Cancel-IdOperation
Drive-IdTest @(1) 1
Assert-IdTest (-not $script:IdNeedsRecovery) '取消后未恢复电机模式。'

$script:SerialPort = New-IdTestPort
Start-IdOperation FactoryRead
$script:SerialPort.IsOpen = $false
Advance-IdTest
Assert-IdTest (-not $script:IdBusy -and $script:IdNeedsRecovery) '断线后没有保留恢复锁。'
Assert-IdTest (-not $StartFocButton.IsEnabled) '工厂模式断线后 FOC 按钮仍可用。'
$script:SerialPort = New-IdTestPort
Start-IdOperation Recover
Drive-IdTest @(1) 1
Assert-IdTest (-not $script:IdNeedsRecovery -and $StartFocButton.IsEnabled) '重连恢复并验证后未解除控制锁。'

$script:SerialPort = New-IdTestPort
Start-IdOperation Read
Drive-IdTest @()
Assert-IdTest ($DetectedIdsCombo.Items.Count -eq 0) '无反馈时保留了上次扫描的过期结果。'
$script:SerialPort = $null
$script:IdTimer.Stop()
$SingleMotorIdCheck.IsChecked = $false
$MotorIdBox.Text = '0'
Write-Output 'M8010 ID workflow passed: scan, split frames, write/restore/verify, ID 15, mismatch, missing ACK, cancel and disconnect recovery.'
