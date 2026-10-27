param(
    [switch]$TestProtocol,
    [switch]$SmokeTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$protocolPath = Join-Path $PSScriptRoot 'M8010Protocol.ps1'
. $protocolPath

if ($TestProtocol) {
    $sampleSpeed = 1619 * 2 * [math]::PI / 256
    $run = ConvertTo-M8010ControlFrame -MotorId 0 -Status 1 -TorqueNm 0 -SpeedRadPerSec $sampleSpeed -PositionRad 0 -Kp 0 -Kd 0.05
    $stop = ConvertTo-M8010ControlFrame -MotorId 0 -Status 0 -TorqueNm 0 -SpeedRadPerSec $sampleSpeed -PositionRad 0 -Kp 0 -Kd 0.05
    $runHex = ConvertTo-HexString $run
    $stopHex = ConvertTo-HexString $stop
    [pscustomobject]@{
        RunFrame = $runHex
        StopFrame = $stopHex
        RunMatchesReadme = ($runHex -eq 'FE EE 10 00 00 53 06 00 00 00 00 00 00 40 00 8C 6C')
        StopMatchesReadme = ($stopHex -eq 'FE EE 00 00 00 53 06 00 00 00 00 00 00 40 00 5C 36')
    } | ConvertTo-Json -Compress
    exit 0
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="M8010-6 串口助手" Width="1360" Height="860" MinWidth="1120" MinHeight="700"
        WindowStartupLocation="CenterScreen" Background="#0B1220" Foreground="#E5EEF8"
        FontFamily="Microsoft YaHei UI" FontSize="13" ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="#D8E2F0"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style TargetType="Label">
      <Setter Property="Foreground" Value="#A9BAD0"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Padding" Value="0,2,8,2"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Foreground" Value="#EAF2FB"/>
      <Setter Property="Background" Value="#111D30"/>
      <Setter Property="BorderBrush" Value="#2B3D55"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="8,4"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="MinHeight" Value="30"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Foreground" Value="#EAF2FB"/>
      <Setter Property="Background" Value="#111D30"/>
      <Setter Property="BorderBrush" Value="#2B3D55"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="7,4"/>
      <Setter Property="MinHeight" Value="30"/>
      <Setter Property="ItemContainerStyle">
        <Setter.Value>
          <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="#EAF2FB"/>
            <Setter Property="Background" Value="#16243A"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="OverridesDefaultStyle" Value="True"/>
            <Setter Property="Template">
              <Setter.Value>
                <ControlTemplate TargetType="ComboBoxItem">
                  <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                    <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                  </Border>
                </ControlTemplate>
              </Setter.Value>
            </Setter>
            <Style.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter Property="Foreground" Value="#FFFFFF"/>
                <Setter Property="Background" Value="#1E5A7A"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter Property="Foreground" Value="#FFFFFF"/>
                <Setter Property="Background" Value="#155E75"/>
              </Trigger>
              <MultiTrigger>
                <MultiTrigger.Conditions>
                  <Condition Property="IsSelected" Value="True"/>
                  <Condition Property="IsHighlighted" Value="True"/>
                </MultiTrigger.Conditions>
                <Setter Property="Foreground" Value="#FFFFFF"/>
                <Setter Property="Background" Value="#087E8B"/>
              </MultiTrigger>
            </Style.Triggers>
          </Style>
        </Setter.Value>
      </Setter>
      <Setter Property="OverridesDefaultStyle" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid SnapsToDevicePixels="True">
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="32"/></Grid.ColumnDefinitions>
              <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="2"/>
              <ContentPresenter x:Name="ContentSite" Margin="8,0,34,0" VerticalAlignment="Center"
                                HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                ContentStringFormat="{TemplateBinding SelectionBoxItemStringFormat}"/>
              <TextBox x:Name="PART_EditableTextBox" Visibility="Collapsed" Margin="8,0,34,0"
                       Background="Transparent" BorderThickness="0" Foreground="{TemplateBinding Foreground}"
                       VerticalContentAlignment="Center" Padding="0"
                       Text="{Binding Text, RelativeSource={RelativeSource TemplatedParent}, UpdateSourceTrigger=PropertyChanged}"
                       IsReadOnly="{TemplateBinding IsReadOnly}"/>
              <ToggleButton x:Name="ToggleButton" Grid.Column="1" Focusable="False" ClickMode="Press"
                            IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}}"
                            HorizontalAlignment="Right" Width="32" Background="Transparent" BorderThickness="0">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border Background="{TemplateBinding Background}" BorderThickness="0">
                      <Path Width="9" Height="6" HorizontalAlignment="Center" VerticalAlignment="Center"
                            Fill="#9DB1C7" Stretch="Fill" Data="M 0 0 L 9 0 L 4.5 6 Z"/>
                    </Border>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <Popup x:Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                <Border Background="#16243A" BorderBrush="#3A5876" BorderThickness="1" Padding="2"
                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}">
                  <ScrollViewer MaxHeight="{TemplateBinding MaxDropDownHeight}" CanContentScroll="True">
                    <ItemsPresenter SnapsToDevicePixels="True"/>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEditable" Value="True">
                <Setter TargetName="ContentSite" Property="Visibility" Value="Collapsed"/>
                <Setter TargetName="PART_EditableTextBox" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.55"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TabControl">
      <Setter Property="Background" Value="#0B1220"/>
      <Setter Property="BorderBrush" Value="#263A54"/>
      <Setter Property="BorderThickness" Value="1"/>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#A9BAD0"/>
      <Setter Property="Background" Value="#101D31"/>
      <Setter Property="Padding" Value="22,10"/>
      <Setter Property="Margin" Value="0,0,4,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="TabSurface" Background="{TemplateBinding Background}" BorderBrush="#263A54" BorderThickness="1,1,1,0" CornerRadius="4,4,0,0" Padding="{TemplateBinding Padding}">
              <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="TabSurface" Property="Background" Value="#155E75"/>
                <Setter TargetName="TabSurface" Property="BorderBrush" Value="#38BDF8"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="TabSurface" Property="Background" Value="#1A3852"/>
              </Trigger>
              <MultiTrigger>
                <MultiTrigger.Conditions>
                  <Condition Property="IsSelected" Value="True"/>
                  <Condition Property="IsMouseOver" Value="True"/>
                </MultiTrigger.Conditions>
                <Setter TargetName="TabSurface" Property="Background" Value="#087E8B"/>
              </MultiTrigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#EAF2FB"/>
      <Setter Property="Background" Value="#1B304B"/>
      <Setter Property="BorderBrush" Value="#355273"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12,6"/>
      <Setter Property="Margin" Value="0,0,6,6"/>
      <Setter Property="MinHeight" Value="32"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style TargetType="GroupBox">
      <Setter Property="Foreground" Value="#8ED8FF"/>
      <Setter Property="BorderBrush" Value="#263A54"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#D8E2F0"/>
      <Setter Property="Margin" Value="0,4,12,4"/>
    </Style>
    <Style TargetType="Separator">
      <Setter Property="Background" Value="#263A54"/>
      <Setter Property="Margin" Value="0,8"/>
    </Style>
  </Window.Resources>
  <Grid Margin="18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#101D31" BorderBrush="#243A55" BorderThickness="1" Padding="18,14" CornerRadius="6">
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock Text="M8010-6  MOTOR CONTROL" FontSize="22" FontWeight="SemiBold" Foreground="#F5FAFF"/>
          <TextBlock Text="宇树 M8010-6 · FE EE 控制帧 / FD EE 反馈帧" FontSize="12" Foreground="#8FA6BF" Margin="0,4,0,0"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <Image x:Name="DesignWordmark" Width="184" Height="44" Stretch="Uniform" Margin="0,0,18,0" RenderOptions.BitmapScalingMode="HighQuality"/>
          <Border Background="#F8FAFC" BorderBrush="#DCE4EC" BorderThickness="1" CornerRadius="3" Padding="6,4" Margin="0,0,20,0">
            <Image x:Name="BrandLogo" Width="150" Height="36" Stretch="Uniform"/>
          </Border>
          <Ellipse x:Name="ConnectionDot" Width="11" Height="11" Fill="#64748B" Margin="0,0,8,0"/>
          <TextBlock x:Name="ConnectionState" Text="未连接" Foreground="#A9BAD0" FontSize="14"/>
        </StackPanel>
      </Grid>
    </Border>

    <TabControl Grid.Row="1" Margin="0,14,0,2" x:Name="MainTabs">
      <TabItem Header="连接与安全">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="18">
            <GroupBox Header="串口连接">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <Grid.ColumnDefinitions><ColumnDefinition Width="90"/><ColumnDefinition Width="260"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Label Grid.Row="0" Grid.Column="0" Content="端口"/><ComboBox x:Name="PortCombo" Grid.Row="0" Grid.Column="1"/>
                <Label Grid.Row="1" Grid.Column="0" Content="波特率"/><ComboBox x:Name="BaudCombo" Grid.Row="1" Grid.Column="1" IsEditable="True" Text="4000000"/>
                <Label Grid.Row="2" Grid.Column="0" Content="数据位"/><ComboBox x:Name="DataBitsCombo" Grid.Row="2" Grid.Column="1" SelectedIndex="0"><ComboBoxItem Content="8"/></ComboBox>
                <Label Grid.Row="3" Grid.Column="0" Content="校验"/><ComboBox x:Name="ParityCombo" Grid.Row="3" Grid.Column="1" SelectedIndex="0"><ComboBoxItem Content="None"/><ComboBoxItem Content="Even"/><ComboBoxItem Content="Odd"/></ComboBox>
                <Label Grid.Row="4" Grid.Column="0" Content="停止位"/><ComboBox x:Name="StopBitsCombo" Grid.Row="4" Grid.Column="1" SelectedIndex="0"><ComboBoxItem Content="1"/><ComboBoxItem Content="2"/></ComboBox>
                <TextBlock Grid.Row="0" Grid.Column="2" Grid.RowSpan="5" Text="GO-M8010-6 固定通信参数：RS-485、4 Mbps、8-N-1。连接后先在“控制”页选择目标电机并启动连续控制。" TextWrapping="Wrap" Foreground="#A9BAD0" Margin="28,4,0,4" VerticalAlignment="Center"/>
                <StackPanel Grid.Row="5" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,12,0,0">
                  <Button x:Name="RefreshPortsButton" Content="刷新端口"/>
                  <Button x:Name="OpenButton" Content="打开串口" Background="#146C62" BorderBrush="#2B9A8C"/>
                  <Button x:Name="CloseButton" Content="关闭" IsEnabled="False"/>
                </StackPanel>
              </Grid>
            </GroupBox>
            <GroupBox Header="目标电机与单位">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <Grid.ColumnDefinitions><ColumnDefinition Width="90"/><ColumnDefinition Width="190"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Label Grid.Row="0" Grid.Column="0" Content="电机 ID"/><TextBox x:Name="MotorIdBox" Grid.Row="0" Grid.Column="1" Text="0"/>
                <CheckBox x:Name="BroadcastCheck" Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" Content="广播 ID 15（无反馈）"/>
                <Label Grid.Row="0" Grid.Column="2" Content="减速比" Margin="28,0,0,0"/><TextBox x:Name="GearRatioBox" Grid.Row="0" Grid.Column="2" Text="6.33" Margin="88,0,0,0"/>
                <CheckBox x:Name="OutputUnitsCheck" Grid.Row="1" Grid.Column="2" Content="目标按输出轴单位输入" IsChecked="True" Margin="28,4,0,4"/>
                <TextBlock Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3" Text="单电机 ID 为 0–14，默认按手册示例使用 ID 0；必须与电机实际 ID 一致。勾选输出轴单位后，程序自动按 6.33 换算。" TextWrapping="Wrap" Foreground="#7D91A8" FontSize="11" Margin="0,7,0,0"/>
              </Grid>
            </GroupBox>
            <GroupBox Header="反馈超速保护">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="180"/><ColumnDefinition Width="120"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Label Grid.Column="0" Content="自动锁定阈值"/>
                <TextBox x:Name="OverspeedLimitBox" Grid.Column="1" Text=""/>
                <TextBlock Grid.Column="2" Text="输出轴 rad/s，需自行填写；必须大于 0 且不超过 804。数据手册标注 24 V 最大转速 30 rad/s，仅供参考。运行期间固定。" TextWrapping="Wrap" Foreground="#A9BAD0" Margin="14,4,0,4" VerticalAlignment="Center"/>
              </Grid>
            </GroupBox>
            <GroupBox Header="安全动作">
              <StackPanel>
                <WrapPanel>
                  <Button x:Name="StopButton" Content="■  停止 / 锁定" Background="#8A2E3A" BorderBrush="#C45A67"/>
                  <Button x:Name="EmergencyButton" Content="急停" Background="#B42318" BorderBrush="#F97066" FontWeight="SemiBold"/>
                  <Button x:Name="CalibrationButton" Content="开始编码器校准" Background="#624A1E" BorderBrush="#B88A38"/>
                </WrapPanel>
                <TextBlock Text="急停和关闭串口前会发送 STATUS 0 锁定。编码器校准开始后，5 秒内所有发送动作会被锁定。" TextWrapping="Wrap" Foreground="#F1B5A9" FontSize="11"/>
              </StackPanel>
            </GroupBox>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="电机 ID">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="18">
            <Border Background="#12344A" BorderBrush="#2E8DB2" BorderThickness="1" Padding="16" CornerRadius="5" Margin="0,0,0,12">
              <StackPanel>
                <TextBlock Text="读取与修改电机 ID" FontSize="18" FontWeight="SemiBold"/>
                <TextBlock Text="先打开串口。普通读取不进入工厂模式；修改 ID 会自动进入工厂模式、写入、恢复电机模式并验证反馈。" TextWrapping="Wrap" Foreground="#B8D9E8" Margin="0,7,0,0"/>
              </StackPanel>
            </Border>
            <GroupBox Header="读取 ID">
              <StackPanel>
                <WrapPanel>
                  <Button x:Name="ReadMotorIdsButton" Content="扫描 / 读取 ID" Background="#146C62" BorderBrush="#42C5AE"/>
                  <Button x:Name="UseDetectedIdButton" Content="将选中 ID 用于控制"/>
                </WrapPanel>
                <TextBlock Text="按顺序查询 ID 0–14，扫描期间发送 STATUS 0 停止输出。正常反馈需通过 CRC；扫描不能区分使用相同 ID 的多台电机。" Foreground="#A9BAD0" TextWrapping="Wrap" Margin="0,6,0,8"/>
                <ComboBox x:Name="DetectedIdsCombo" MinWidth="220" HorizontalAlignment="Left"/>
                <TextBlock x:Name="IdReadStatusText" Text="尚未读取。打开串口后点击扫描。" TextWrapping="Wrap" Foreground="#8ED8FF" Margin="0,10,0,0"/>
              </StackPanel>
            </GroupBox>
            <GroupBox Header="修改 ID（单电机配置）">
              <StackPanel>
                <CheckBox x:Name="SingleMotorIdCheck" Content="已确认总线只接一台电机，且没有其他主机发送数据"/>
                <TextBlock Text="厂家要求单电机操作。未分配 ID 15 或处于工厂模式时，请先用“工厂读取”。重新上电不能代替“恢复电机模式”。" TextWrapping="Wrap" Foreground="#F1B5A9" Margin="0,6,0,12"/>
                <WrapPanel>
                  <Label Content="当前 ID（0–15）"/><TextBox x:Name="CurrentMotorIdBox" Text="0" Width="80"/>
                  <Label Content="新 ID（0–14）" Margin="18,0,0,0"/><TextBox x:Name="NewMotorIdBox" Text="1" Width="80"/>
                </WrapPanel>
                <WrapPanel Margin="0,12,0,0">
                  <Button x:Name="FactoryReadIdsButton" Content="工厂读取（含 ID 15）"/>
                  <Button x:Name="ChangeMotorIdButton" Content="修改 ID 并验证" Background="#14532D" BorderBrush="#4ADE80"/>
                  <Button x:Name="RecoverMotorModeButton" Content="恢复电机模式"/>
                  <Button x:Name="CancelIdOperationButton" Content="取消 / 恢复" IsEnabled="False"/>
                </WrapPanel>
                <TextBlock x:Name="IdOperationStatusText" Text="就绪。操作期间禁止运动控制；验证失败会显示具体阶段。" TextWrapping="Wrap" Foreground="#8ED8FF" Margin="0,10,0,0"/>
              </StackPanel>
            </GroupBox>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="FOC 控制">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="18">
            <Border Background="#12344A" BorderBrush="#2E8DB2" BorderThickness="1" Padding="16" CornerRadius="5" Margin="0,0,0,12">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="FOC 连续控制" FontSize="18" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                  <TextBlock x:Name="ModeHint" Text="选择策略只会装载参数；检查目标后再启动。默认速度 0.5 rad/s（输出轴）。" Foreground="#B8D9E8" Margin="0,5,0,0" TextWrapping="Wrap"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                  <Button x:Name="RefreshStateButton" Content="安全读取状态" Background="#334155" BorderBrush="#64748B" Padding="14,10"/>
                  <Button x:Name="StartFocButton" Content="启动 FOC" Background="#146C62" BorderBrush="#42C5AE" FontWeight="SemiBold" Padding="20,10"/>
                  <Button x:Name="SendButton" Content="发送一次" Background="#1D4ED8" BorderBrush="#60A5FA" Padding="16,10"/>
                </StackPanel>
              </Grid>
            </Border>
            <GroupBox Header="底层状态">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="180"/><ColumnDefinition Width="300"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Label Grid.Column="0" Content="STATUS"/><ComboBox x:Name="ModeCombo" Grid.Column="1" SelectedIndex="1">
                  <ComboBoxItem Content="锁定 / 默认（STATUS 0）" Tag="0"/>
                  <ComboBoxItem Content="FOC 闭环（STATUS 1）" Tag="1"/>
                  <ComboBoxItem Content="编码器校准（STATUS 2，约 5 秒）" Tag="2"/>
                </ComboBox>
                <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="24,0,0,0" VerticalAlignment="Center">
                  <CheckBox x:Name="CycleCheck" Content="连续发送"/>
                  <Label Content="周期 ms"/><TextBox x:Name="CycleIntervalBox" Text="20" Width="70"/>
                </StackPanel>
              </Grid>
            </GroupBox>
            <GroupBox Header="FOC 策略">
              <StackPanel>
                <UniformGrid Columns="3" Rows="3">
                  <Button x:Name="PositionModeButton" Content="当前位置保持" Background="#174E63" BorderBrush="#38BDF8"/>
                  <Button x:Name="SpeedModeButton" Content="速度控制 · 缓速启动" Background="#174E63" BorderBrush="#38BDF8"/>
                  <Button x:Name="DirectSpeedModeButton" Content="速度控制 · 直接到达" Background="#14532D" BorderBrush="#4ADE80"/>
                  <Button x:Name="DampingModeButton" Content="阻尼模式" Background="#174E63" BorderBrush="#38BDF8"/>
                  <Button x:Name="TorqueModeButton" Content="恒力矩" Background="#5B3B1B" BorderBrush="#D39A47"/>
                  <Button x:Name="ZeroTorqueModeButton" Content="零力矩" Background="#334155" BorderBrush="#64748B"/>
                  <Button x:Name="HybridModeButton" Content="力位混合" Background="#1D4ED8" BorderBrush="#60A5FA"/>
                </UniformGrid>
                <TextBlock x:Name="StrategyStatusText" Text="策略仅装载参数，不会自动启动。请确认电机周围安全后再启动。" Foreground="#8ED8FF" FontSize="12" Margin="0,8,0,0"/>
              </StackPanel>
            </GroupBox>
            <GroupBox Header="目标参数">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <Grid.ColumnDefinitions><ColumnDefinition Width="180"/><ColumnDefinition Width="150"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Label Grid.Row="0" Grid.Column="0" Content="目标转矩 τset"/><TextBox x:Name="TorqueBox" Grid.Row="0" Grid.Column="1" Text="0"/><TextBlock x:Name="TorqueUnitHint" Grid.Row="0" Grid.Column="2" Text="N·m（输出轴估算）" Foreground="#7D91A8" Margin="12,0,0,0"/>
                <Label Grid.Row="1" Grid.Column="0" Content="目标速度 ωset"/><TextBox x:Name="SpeedBox" Grid.Row="1" Grid.Column="1" Text="0.5"/><TextBlock x:Name="SpeedUnitHint" Grid.Row="1" Grid.Column="2" Text="输出轴 rad/s" Foreground="#7D91A8" Margin="12,0,0,0"/>
                <Label Grid.Row="2" Grid.Column="0" Content="目标位置 θset"/><TextBox x:Name="PositionBox" Grid.Row="2" Grid.Column="1" Text="0"/><TextBlock x:Name="PositionUnitHint" Grid.Row="2" Grid.Column="2" Text="输出轴 rad，多圈位置" Foreground="#7D91A8" Margin="12,0,0,0"/>
                <Label Grid.Row="3" Grid.Column="0" Content="位置增益 Kpos"/><TextBox x:Name="KpBox" Grid.Row="3" Grid.Column="1" Text="0"/><TextBlock Grid.Row="3" Grid.Column="2" Text="0–25.599" Foreground="#7D91A8" Margin="12,0,0,0"/>
                <Label Grid.Row="4" Grid.Column="0" Content="速度增益 Kspd"/><TextBox x:Name="KdBox" Grid.Row="4" Grid.Column="1" Text="0.02"/><TextBlock Grid.Row="4" Grid.Column="2" Text="0–25.599" Foreground="#7D91A8" Margin="12,0,0,0"/>
                <StackPanel Grid.Row="5" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,12,0,0">
                  <Button x:Name="ForwardButton" Content="↻  正转" Background="#155E75" BorderBrush="#38BDF8"/>
                  <Button x:Name="ReverseButton" Content="↺  反转" Background="#155E75" BorderBrush="#38BDF8"/>
                  <Button x:Name="SpeedDownButton" Content="−  减速"/>
                  <Button x:Name="SpeedUpButton" Content="＋  加速"/>
                  <Label Content="步长" Margin="8,0,0,0"/><TextBox x:Name="SpeedStepBox" Text="0.1" Width="70"/>
                </StackPanel>
              </Grid>
            </GroupBox>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="多电机程序">
        <Grid>
          <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="18,12,18,8">
            <Border Background="#12344A" BorderBrush="#2E8DB2" BorderThickness="1" Padding="10" CornerRadius="5" Margin="0,0,0,6">
              <StackPanel>
                <TextBlock Text="8 电机 · 自动速度程序" FontSize="16" FontWeight="SemiBold"/>
                <TextBlock Text="模板：ID 2–9，以输出轴 1 rad/s 各运行 2 秒。正速度正转、负速度反转；顺序逐台切换，同时分别计时。" TextWrapping="Wrap" Foreground="#B8D9E8" Margin="0,4,0,0"/>
              </StackPanel>
            </Border>
            <GroupBox Header="执行设置" Padding="8" Margin="0,0,0,6">
              <StackPanel>
                <WrapPanel>
                  <Label Content="运行方式"/><ComboBox x:Name="MultiModeCombo" Width="150" SelectedIndex="0"><ComboBoxItem Content="顺序执行"/><ComboBoxItem Content="同时执行"/></ComboBox>
                  <Label Content="超速阈值 rad/s（自行填写）" Margin="18,0,0,0"/><TextBox x:Name="MultiOverspeedBox" Width="85" Text=""/>
                  <Button x:Name="MultiTemplateButton" Content="恢复 ID 2–9 模板" Margin="18,0,6,0"/>
                  <Button x:Name="MultiSaveButton" Content="保存参数"/><Button x:Name="MultiLoadButton" Content="载入参数"/>
                </WrapPanel>
                <Expander Header="高级设置 · 速度增益与反馈超时" Foreground="#A9BAD0" Margin="0,4,0,0">
                  <StackPanel Margin="0,8,0,0">
                    <WrapPanel>
                      <Label Content="速度增益 Kspd"/><TextBox x:Name="MultiKdBox" Width="75" Text="0.02"/>
                      <Label Content="单次反馈超时 ms" Margin="18,0,0,0"/><TextBox x:Name="MultiTimeoutBox" Width="75" Text="200"/>
                    </WrapPanel>
                    <TextBlock Text="采用直接速度控制，按连接页减速比换算输出轴目标；运行时参数锁定。" TextWrapping="Wrap" Margin="0,6,0,0"/>
                  </StackPanel>
                </Expander>
              </StackPanel>
            </GroupBox>
            <GroupBox Header="电机参数与实时状态" Padding="8" Margin="0,0,0,6">
              <StackPanel>
                <Grid x:Name="MultiRowsGrid"/>
                <TextBlock Text="可取消勾选不参与的电机；ID 必须互不相同且为 0–14。运行前逐台确认反馈；任何电机失联、报错、过热或超速会停止整组。" Foreground="#A9BAD0" TextWrapping="Wrap" Margin="0,10,0,0"/>
              </StackPanel>
            </GroupBox>
            <TextBlock Text="同时执行通过共享 RS-485 总线逐台轮询，存在通信和 Windows 调度延迟，不是硬件同步触发。时长从首条速度指令开始计时，不包含预检。手动 / 异常停止会广播锁定总线上的全部电机，再逐台验证。" TextWrapping="Wrap" Foreground="#7D91A8" Margin="8,0,8,0"/>
          </StackPanel>
        </ScrollViewer>
            <Border Grid.Row="1" Margin="18,8,18,16" Background="#101D31" BorderBrush="#263A54" BorderThickness="1" Padding="10" CornerRadius="4">
              <StackPanel>
                <WrapPanel>
                  <Button x:Name="MultiStartButton" Content="▶  启动程序" Background="#146C62" BorderBrush="#42C5AE" FontWeight="SemiBold"/>
                  <Button x:Name="MultiStopButton" Content="■  停止全部 / 重试锁定" Background="#8A2E3A" BorderBrush="#F97066"/>
                  <TextBlock x:Name="MultiElapsedText" Text="已用时 0.0 s" Foreground="#8ED8FF" Margin="18,0,0,0"/>
                </WrapPanel>
                <ProgressBar x:Name="MultiProgress" Minimum="0" Maximum="8" Value="0" Height="5" Margin="0,6,0,6" Foreground="#42C5AE" Background="#1E293B"/>
                <TextBlock x:Name="MultiStatusText" Text="就绪。连接串口、填写阈值并检查参数后启动。" TextWrapping="Wrap" Foreground="#8ED8FF"/>
              </StackPanel>
            </Border>
        </Grid>
      </TabItem>

      <TabItem Header="状态监视">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="18">
            <GroupBox Header="连接状态">
              <StackPanel Orientation="Horizontal">
                <Ellipse x:Name="MonitorConnectionDot" Width="12" Height="12" Fill="#64748B" Margin="0,0,8,0"/>
                <TextBlock x:Name="MonitorConnectionState" Text="未连接" FontSize="16" Foreground="#A9BAD0"/>
              </StackPanel>
            </GroupBox>
            <GroupBox Header="电机反馈">
              <Grid>
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <Grid.ColumnDefinitions><ColumnDefinition Width="180"/><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Label Grid.Row="0" Grid.Column="0" Content="状态"/><TextBlock x:Name="FeedbackStatusText" Grid.Row="0" Grid.Column="1" Text="等待反馈" Foreground="#8ED8FF" FontWeight="SemiBold"/><TextBlock x:Name="FeedbackIdText" Grid.Row="0" Grid.Column="2" Text="ID —" Foreground="#7D91A8"/>
                <Label Grid.Row="1" Grid.Column="0" Content="实际转矩"/><TextBlock x:Name="FeedbackTorqueText" Grid.Row="1" Grid.Column="1" Text="—"/><TextBlock Grid.Row="1" Grid.Column="2" Text="N·m" Foreground="#7D91A8"/>
                <Label Grid.Row="2" Grid.Column="0" Content="实际速度（输出轴）"/><TextBlock x:Name="FeedbackSpeedText" Grid.Row="2" Grid.Column="1" Text="—"/><TextBlock Grid.Row="2" Grid.Column="2" Text="rad/s" Foreground="#7D91A8"/>
                <Label Grid.Row="3" Grid.Column="0" Content="实际位置"/><TextBlock x:Name="FeedbackPositionText" Grid.Row="3" Grid.Column="1" Text="—"/><TextBlock Grid.Row="3" Grid.Column="2" Text="rad" Foreground="#7D91A8"/>
                <Label Grid.Row="4" Grid.Column="0" Content="温度"/><TextBlock x:Name="FeedbackTempText" Grid.Row="4" Grid.Column="1" Text="—"/><TextBlock Grid.Row="4" Grid.Column="2" Text="°C" Foreground="#7D91A8"/>
                <Label Grid.Row="5" Grid.Column="0" Content="足端力 FORCE"/><TextBlock x:Name="FeedbackForceText" Grid.Row="5" Grid.Column="1" Text="—"/><TextBlock Grid.Row="5" Grid.Column="2" Text="raw / 4095" Foreground="#7D91A8"/>
              </Grid>
            </GroupBox>
            <Border Background="#101D31" BorderBrush="#243A55" BorderThickness="1" Padding="18" Margin="0,0,0,12">
              <StackPanel>
                <TextBlock Text="诊断" Foreground="#8ED8FF" FontWeight="SemiBold" Margin="0,0,0,10"/>
                <TextBlock x:Name="ErrorText" Text="等待电机反馈。" TextWrapping="Wrap" Foreground="#A9BAD0"/>
                <Separator/>
                <TextBlock Text="协议状态" Foreground="#8FA6BF" FontSize="11"/>
                <TextBlock x:Name="ProtocolStatsText" Text="接收帧 0 · CRC 丢弃 0" Foreground="#D8E2F0" Margin="0,4,0,0"/>
                <TextBlock Text="状态说明" Foreground="#8FA6BF" FontSize="11" Margin="0,14,0,0"/>
                <TextBlock Text="温度达到 90 °C 会触发保护；反馈错误码非 0 时应立即停止控制并检查电机。" TextWrapping="Wrap" Foreground="#A9BAD0" FontSize="11" Margin="0,4,0,0"/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="诊断">
        <Grid Margin="18">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <GroupBox Header="高级原始帧（仅诊断）" Grid.Row="0">
            <StackPanel>
              <TextBlock Text="正常控制无需填写十六进制。此处只用于抓包、校验和故障定位。" Foreground="#F1B5A9" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,8"/>
              <TextBox x:Name="RawSendBox" Text="FE EE 10 00 00 53 06 00 00 00 00 00 00 00 40 8C 6C" MinHeight="54" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
              <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                <Button x:Name="RawSendButton" Content="发送原始帧" Background="#334155"/>
                <TextBlock Text="空格、逗号或 0x 前缀均可" Foreground="#7D91A8" VerticalAlignment="Center"/>
              </StackPanel>
            </StackPanel>
          </GroupBox>
          <GroupBox Header="最近报文" Grid.Row="1">
            <Grid>
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
              <Label Grid.Row="0" Content="最后发送"/><TextBox x:Name="LastTxBox" Grid.Row="0" Margin="90,0,0,4" IsReadOnly="True"/>
              <Label Grid.Row="1" Content="最后接收"/><TextBox x:Name="LastRxBox" Grid.Row="1" Margin="90,0,0,4" IsReadOnly="True"/>
              <TextBlock Grid.Row="2" Text="控制帧 17 字节，反馈帧 16 字节；CRC 低字节先发送。" Foreground="#7D91A8" FontSize="11" TextWrapping="Wrap" Margin="0,5,0,0"/>
            </Grid>
          </GroupBox>
          <Grid Grid.Row="2" Margin="0,12,0,0">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <TextBlock Text="通信日志" Foreground="#8ED8FF" FontWeight="SemiBold" VerticalAlignment="Center"/>
            <Button x:Name="ClearLogButton" Grid.Column="1" Content="清空" Padding="12,4"/>
            <TextBox x:Name="LogBox" Grid.Row="1" Grid.ColumnSpan="2" Background="#08101D" BorderBrush="#243A55" Foreground="#B8C7D9" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11" Padding="10" Margin="0,8,0,0"/>
          </Grid>
        </Grid>
      </TabItem>
    </TabControl>
    <Border Grid.Row="2" Background="#101D31" BorderBrush="#243A55" BorderThickness="1" Padding="12,8">
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <TextBlock Text="M8010-6 · CRC16-CCITT reflected · 17B TX / 16B RX" Foreground="#7D91A8" FontSize="11"/>
        <TextBlock Grid.Column="1" Text="USB-RS485 · 4000000 baud · 8-N-1" Foreground="#8ED8FF" FontSize="11"/>
      </Grid>
    </Border>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

function Get-Control([string]$Name) { return $window.FindName($Name) }

$PortCombo = Get-Control 'PortCombo'
$BaudCombo = Get-Control 'BaudCombo'
$DataBitsCombo = Get-Control 'DataBitsCombo'
$ParityCombo = Get-Control 'ParityCombo'
$StopBitsCombo = Get-Control 'StopBitsCombo'
$RefreshPortsButton = Get-Control 'RefreshPortsButton'
$OpenButton = Get-Control 'OpenButton'
$CloseButton = Get-Control 'CloseButton'
$StartFocButton = Get-Control 'StartFocButton'
$MotorIdBox = Get-Control 'MotorIdBox'
$BroadcastCheck = Get-Control 'BroadcastCheck'
$GearRatioBox = Get-Control 'GearRatioBox'
$OutputUnitsCheck = Get-Control 'OutputUnitsCheck'
$OverspeedLimitBox = Get-Control 'OverspeedLimitBox'
$ModeCombo = Get-Control 'ModeCombo'
$ModeHint = Get-Control 'ModeHint'
$CycleCheck = Get-Control 'CycleCheck'
$CycleIntervalBox = Get-Control 'CycleIntervalBox'
$RefreshStateButton = Get-Control 'RefreshStateButton'
$StopButton = Get-Control 'StopButton'
$EmergencyButton = Get-Control 'EmergencyButton'
$CalibrationButton = Get-Control 'CalibrationButton'
$TorqueBox = Get-Control 'TorqueBox'
$TorqueUnitHint = Get-Control 'TorqueUnitHint'
$SpeedBox = Get-Control 'SpeedBox'
$SpeedUnitHint = Get-Control 'SpeedUnitHint'
$PositionBox = Get-Control 'PositionBox'
$PositionUnitHint = Get-Control 'PositionUnitHint'
$KpBox = Get-Control 'KpBox'
$KdBox = Get-Control 'KdBox'
$ForwardButton = Get-Control 'ForwardButton'
$ReverseButton = Get-Control 'ReverseButton'
$SendButton = Get-Control 'SendButton'
$PositionModeButton = Get-Control 'PositionModeButton'
$SpeedModeButton = Get-Control 'SpeedModeButton'
$DirectSpeedModeButton = Get-Control 'DirectSpeedModeButton'
$DampingModeButton = Get-Control 'DampingModeButton'
$TorqueModeButton = Get-Control 'TorqueModeButton'
$ZeroTorqueModeButton = Get-Control 'ZeroTorqueModeButton'
$HybridModeButton = Get-Control 'HybridModeButton'
$StrategyStatusText = Get-Control 'StrategyStatusText'
$SpeedStepBox = Get-Control 'SpeedStepBox'
$SpeedDownButton = Get-Control 'SpeedDownButton'
$SpeedUpButton = Get-Control 'SpeedUpButton'
$RawSendBox = Get-Control 'RawSendBox'
$RawSendButton = Get-Control 'RawSendButton'
$LastTxBox = Get-Control 'LastTxBox'
$LastRxBox = Get-Control 'LastRxBox'
$ConnectionDot = Get-Control 'ConnectionDot'
$ConnectionState = Get-Control 'ConnectionState'
$BrandLogo = Get-Control 'BrandLogo'
$MonitorConnectionDot = Get-Control 'MonitorConnectionDot'
$MonitorConnectionState = Get-Control 'MonitorConnectionState'
$FeedbackStatusText = Get-Control 'FeedbackStatusText'
$FeedbackIdText = Get-Control 'FeedbackIdText'
$FeedbackTorqueText = Get-Control 'FeedbackTorqueText'
$FeedbackSpeedText = Get-Control 'FeedbackSpeedText'
$FeedbackPositionText = Get-Control 'FeedbackPositionText'
$FeedbackTempText = Get-Control 'FeedbackTempText'
$FeedbackForceText = Get-Control 'FeedbackForceText'
$ErrorText = Get-Control 'ErrorText'
$ProtocolStatsText = Get-Control 'ProtocolStatsText'
$ClearLogButton = Get-Control 'ClearLogButton'
$LogBox = Get-Control 'LogBox'

$script:SerialPort = $null
$script:IsClosing = $false
$script:IsClosed = $false
$script:RxBuffer = [System.Collections.Generic.List[byte]]::new()
$script:RxFrames = 0
$script:RxCrcDrops = 0
$script:LastFeedback = $null
$script:LastFeedbackAt = [DateTime]::MinValue
$script:PendingPositionStart = $false
$script:PendingPositionStartMotorId = -1
$script:PendingPositionStartUntil = [DateTime]::MinValue
$script:LastRxLogAt = [DateTime]::MinValue
$script:ErrorLogPath = Join-Path $PSScriptRoot 'M8010SerialAssistant-errors.log'
$script:SelectedStrategy = 'Speed'
$script:PositionCommandRad = 0.0
$script:PositionTargetRad = 0.0
$script:SpeedCommandRadPerSec = 0.0
$script:TorqueCommandNm = 0.0
$script:SuppressCycleUncheckedLock = $false
$script:PositionRampOutputRadPerSec = 0.5
$script:SpeedRampOutputRadPerSec2 = 1.0
$script:TorqueRampOutputNmPerSec = 0.1
$script:MaxProtocolSpeedRadPerSec = 804.0
$script:MaxFeedbackSpeedOutputRadPerSec = [double]::NaN
$script:InputValuesAreOutputUnits = $true
$script:CycleTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:CycleTimer.Interval = [TimeSpan]::FromMilliseconds(20)
$script:ReceiveTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ReceiveTimer.Interval = [TimeSpan]::FromMilliseconds(10)
$script:CalibrationUntil = [DateTime]::MinValue
$script:CalibrationTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:CalibrationTimer.Interval = [TimeSpan]::FromMilliseconds(100)

foreach ($asset in @(
    @{ Control = 'BrandLogo'; File = '北京建筑大学-01.png' },
    @{ Control = 'DesignWordmark'; File = 'assets/design-wordmark.jpg' }
)) {
    $assetPath = Join-Path $PSScriptRoot $asset.File
    if (Test-Path -LiteralPath $assetPath) {
        $assetImage = New-Object System.Windows.Media.Imaging.BitmapImage
        $assetImage.BeginInit()
        $assetImage.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $assetImage.UriSource = [Uri]::new($assetPath, [UriKind]::Absolute)
        $assetImage.EndInit()
        $assetImage.Freeze()
        (Get-Control $asset.Control).Source = $assetImage
    }
}

$statusNames = @{
    0 = '锁定 / 默认'
    1 = 'FOC 闭环'
    2 = '编码器校准'
}
$errorNames = @{
    0 = '正常'
    1 = '过热'
    2 = '过流'
    3 = '过压'
    4 = '编码器故障'
}

function Write-Log {
    param([string]$Message, [string]$Color = '')
    if ($script:IsClosed -or $null -eq $LogBox) { return }
    $stamp = (Get-Date).ToString('HH:mm:ss.fff')
    try {
        $LogBox.AppendText("[$stamp] $Message`r`n")
        # Feedback can arrive continuously at 4 Mbps. Keep the visual log bounded
        # so the TextBox does not grow until WPF runs out of memory.
        $maxLogChars = 120000
        if ($LogBox.Text.Length -gt $maxLogChars) {
            $keepFrom = $LogBox.Text.Length - 100000
            $lineStart = $LogBox.Text.IndexOf("`n", $keepFrom)
            if ($lineStart -ge 0 -and ($lineStart + 1) -lt $LogBox.Text.Length) {
                $LogBox.Text = $LogBox.Text.Substring($lineStart + 1)
            } else {
                $LogBox.Text = $LogBox.Text.Substring($keepFrom)
            }
        }
        $LogBox.ScrollToEnd()
    } catch {
        # The dispatcher can tear down while a serial callback is still unwinding.
    }
}

function Write-ErrorLog([string]$Context, [object]$Exception) {
    try {
        $detail = if ($null -eq $Exception) { '' } else { $Exception.ToString() }
        Add-Content -LiteralPath $script:ErrorLogPath -Value ("[{0}] {1}`r`n{2}`r`n" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff'), $Context, $detail) -Encoding UTF8
    } catch {
        # Error logging must never affect motor control or window shutdown.
    }
}

function Show-Problem([string]$Message) {
    if ($script:IsClosing -or $script:IsClosed) { return }
    Write-Log "错误：$Message"
    try {
        if (-not $window.Dispatcher.HasShutdownStarted -and -not $window.Dispatcher.HasShutdownFinished) {
            [System.Windows.MessageBox]::Show($window, $Message, 'M8010 串口助手', 'OK', 'Warning') | Out-Null
        }
    } catch {
        Write-Log "提示框显示失败：$($_.Exception.Message)"
    }
}

function Set-ConnectionState([bool]$Connected, [string]$Text) {
    $ConnectionState.Text = $Text
    $MonitorConnectionState.Text = $Text
    if ($Connected) {
        $ConnectionDot.Fill = [System.Windows.Media.Brushes]::LimeGreen
        $MonitorConnectionDot.Fill = [System.Windows.Media.Brushes]::LimeGreen
        $ConnectionState.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $MonitorConnectionState.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $OpenButton.IsEnabled = $false
        $CloseButton.IsEnabled = $true
    } else {
        $ConnectionDot.Fill = [System.Windows.Media.Brushes]::SlateGray
        $MonitorConnectionDot.Fill = [System.Windows.Media.Brushes]::SlateGray
        $ConnectionState.Foreground = [System.Windows.Media.Brushes]::LightGray
        $MonitorConnectionState.Foreground = [System.Windows.Media.Brushes]::LightGray
        $OpenButton.IsEnabled = $true
        $CloseButton.IsEnabled = $false
    }
}

function Refresh-Ports {
    $selected = [string]$PortCombo.Text
    $PortCombo.Items.Clear()
    try {
        $ports = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object { [int]($_ -replace '\D', '') })
    } catch {
        $ports = @()
    }
    foreach ($port in $ports) { [void]$PortCombo.Items.Add($port) }
    if ($ports -contains $selected) { $PortCombo.SelectedItem = $selected }
    elseif ($PortCombo.Items.Count -gt 0) { $PortCombo.SelectedIndex = 0 }
    if ($ports.Count -gt 0) { Write-Log "发现端口：$($ports -join ', ')" }
    else { Write-Log '未发现串口，请连接 USB-RS485 后刷新。' }
}

function Read-Double([object]$Box, [string]$Name) {
    $value = 0.0
    $ok = [double]::TryParse($Box.Text.Trim(), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)
    if (-not $ok) { throw "$Name 不是有效数字。" }
    return $value
}

function Read-Int([object]$Box, [string]$Name, [int]$Min, [int]$Max) {
    $value = 0
    $ok = [int]::TryParse($Box.Text.Trim(), [Globalization.NumberStyles]::Integer, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)
    if (-not $ok -or $value -lt $Min -or $value -gt $Max) { throw "$Name 必须是 $Min 至 $Max 的整数。" }
    return $value
}

function Get-TargetId {
    if ($BroadcastCheck.IsChecked) { return 15 }
    return Read-Int $MotorIdBox '电机 ID' 0 14
}

function Test-FeedbackSpeedSafe($Feedback) {
    if ($null -eq $Feedback) { return $true }
    $targetId = Get-TargetId
    if ($targetId -ne 15 -and $Feedback.MotorId -ne $targetId) { return $true }
    return [math]::Abs([double]$Feedback.SpeedRadPerSec) -le $script:MaxFeedbackSpeedOutputRadPerSec
}

function Read-OverspeedLimit {
    if ([string]::IsNullOrWhiteSpace($OverspeedLimitBox.Text)) {
        throw '请在“连接与安全”页自行填写反馈超速保护阈值后再启动 FOC。'
    }
    $limit = Read-Double $OverspeedLimitBox '反馈超速保护阈值'
    if ([double]::IsNaN($limit) -or [double]::IsInfinity($limit) -or $limit -le 0 -or $limit -gt $script:MaxProtocolSpeedRadPerSec) {
        throw ('反馈超速保护阈值必须是大于 0 且不高于 {0:0.###} rad/s 的有限数值。' -f $script:MaxProtocolSpeedRadPerSec)
    }
    return $limit
}

function Get-SelectedStatus {
    return [int]$ModeCombo.SelectedItem.Tag
}

function Get-GearRatio {
    $ratio = Read-Double $GearRatioBox '减速比'
    if ($ratio -lt 1 -or $ratio -gt 100) { throw '减速比必须在 1 至 100 之间。' }
    return $ratio
}

function Assert-SpeedTargetWithinProtocolRange([double]$InputSpeed) {
    $rotorSpeed = if ($OutputUnitsCheck.IsChecked) { $InputSpeed * (Get-GearRatio) } else { $InputSpeed }
    if ([math]::Abs($rotorSpeed) -gt $script:MaxProtocolSpeedRadPerSec) {
        throw ('目标速度超出协议可编码范围：转子侧必须在 ±{0:0.###} rad/s 内。' -f $script:MaxProtocolSpeedRadPerSec)
    }
}

function Set-TextValue([object]$Box, [double]$Value) {
    $Box.Text = $Value.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
}

function Update-UnitHints {
    if ($OutputUnitsCheck.IsChecked) {
        $TorqueUnitHint.Text = 'N·m（输出轴估算）'
        $SpeedUnitHint.Text = '输出轴 rad/s'
        $PositionUnitHint.Text = '输出轴 rad，多圈位置'
    } else {
        $TorqueUnitHint.Text = 'N·m（转子侧）'
        $SpeedUnitHint.Text = '转子 rad/s'
        $PositionUnitHint.Text = '转子 rad，多圈位置'
    }
}

function Convert-ControlInputUnits([bool]$ToOutputUnits) {
    if ($script:InputValuesAreOutputUnits -eq $ToOutputUnits) { Update-UnitHints; return }
    try {
        $ratio = Get-GearRatio
        $torque = Read-Double $TorqueBox '目标转矩'
        $speed = Read-Double $SpeedBox '目标速度'
        $position = Read-Double $PositionBox '目标位置'
        $step = Read-Double $SpeedStepBox '调整步长'
        if ($ToOutputUnits) {
            $torque *= $ratio
            $speed /= $ratio
            $position /= $ratio
            $step /= $ratio
        } else {
            $torque /= $ratio
            $speed *= $ratio
            $position *= $ratio
            $step *= $ratio
        }
        Set-TextValue $TorqueBox $torque
        Set-TextValue $SpeedBox $speed
        Set-TextValue $PositionBox $position
        Set-TextValue $SpeedStepBox $step
        $script:InputValuesAreOutputUnits = $ToOutputUnits
        Update-UnitHints
    } catch {
        $OutputUnitsCheck.IsChecked = $script:InputValuesAreOutputUnits
        Show-Problem "单位切换失败，原输入值已保留：$($_.Exception.Message)"
    }
}

function Move-Toward([double]$Current, [double]$Target, [double]$MaxStep) {
    if ($MaxStep -lt 0) { throw '斜坡步长不能为负数。' }
    $delta = $Target - $Current
    return $Current + [Math]::Max(-$MaxStep, [Math]::Min($MaxStep, $delta))
}

function Update-TorqueCommand([double]$Target, [double]$IntervalSeconds) {
    $gearRatio = Get-GearRatio
    $targetRotorTorque = if ($OutputUnitsCheck.IsChecked) { $Target / $gearRatio } else { $Target }
    if ([math]::Abs($targetRotorTorque) -gt 127.99) { throw '目标转矩超出协议范围。' }
    $unitScale = if ($OutputUnitsCheck.IsChecked) { 1.0 } else { 1.0 / $gearRatio }
    $maxStep = $script:TorqueRampOutputNmPerSec * $unitScale * [Math]::Max(0.001, $IntervalSeconds)
    $script:TorqueCommandNm = Move-Toward $script:TorqueCommandNm $Target $maxStep
    return $script:TorqueCommandNm
}

function Apply-Strategy([string]$Strategy) {
    Assert-MultiMotionAllowed
    Assert-IdMotionAllowed
    if ((Get-Date) -lt $script:CalibrationUntil) { Show-Problem '编码器校准进行中，5 秒内禁止发送任何数据包。'; return }
    if ($script:CycleTimer.IsEnabled) {
        Stop-ControlOutput '切换策略'
        Write-Log '策略切换时已先发送 STATUS 0 锁定。'
    }
    $script:SelectedStrategy = $Strategy
    $ModeCombo.SelectedIndex = 1
    switch ($Strategy) {
        'Position' {
            Set-TextValue $TorqueBox 0
            Set-TextValue $SpeedBox 0
            $hasFreshPosition = $null -ne $script:LastFeedback -and $script:LastFeedback.MotorId -eq (Get-TargetId) -and
                ((Get-Date) - $script:LastFeedbackAt).TotalSeconds -le 1.0
            if ($hasFreshPosition) {
                $holdPosition = [double]$script:LastFeedback.PositionRad
                if (-not $OutputUnitsCheck.IsChecked) { $holdPosition *= (Get-GearRatio) }
                Set-TextValue $PositionBox $holdPosition
            }
            Set-TextValue $KpBox 0.02
            Set-TextValue $KdBox 0
            $StrategyStatusText.Text = if ($hasFreshPosition) {
                ('当前位置 {0:0.###} rad（输出轴）；启动时会刷新反馈并锁定当时位置。' -f $script:LastFeedback.PositionRad)
            } else { '已选择当前位置保持；启动时会自动读取反馈并锁定当时位置。' }
            $description = '当前位置保持参数已装载'
        }
        'Speed' {
            Set-TextValue $TorqueBox 0
            Set-TextValue $PositionBox 0
            Set-TextValue $KpBox 0
            Set-TextValue $KdBox 0.02
            $requestedSpeed = Read-Double $SpeedBox '目标速度'
            $StrategyStatusText.Text = ('已装载低速控制：目标速度 {0:0.###} rad/s（输出轴）。请先确认速度再启动。' -f $requestedSpeed)
            $description = '低速控制参数已装载'
        }
        'SpeedDirect' {
            Set-TextValue $TorqueBox 0
            Set-TextValue $PositionBox 0
            Set-TextValue $KpBox 0
            Set-TextValue $KdBox 0.02
            $requestedSpeed = Read-Double $SpeedBox '目标速度'
            $StrategyStatusText.Text = ('已装载直接速度控制：目标 {0:0.###} rad/s，启动时直接到达设定值。' -f $requestedSpeed)
            $description = '直接目标速度参数已装载'
        }
        'Damping' {
            Set-TextValue $TorqueBox 0
            Set-TextValue $SpeedBox 0
            Set-TextValue $PositionBox 0
            Set-TextValue $KpBox 0
            Set-TextValue $KdBox 0.02
            $StrategyStatusText.Text = '已装载阻尼模式（W=0，Kp=0，Kw=0.02）。点击启动后会抵抗外力运动。'
            $description = '阻尼模式参数已装载'
        }
        'Torque' {
            Set-TextValue $SpeedBox 0
            Set-TextValue $PositionBox 0
            Set-TextValue $KpBox 0
            Set-TextValue $KdBox 0
            $currentTorque = Read-Double $TorqueBox '目标转矩'
            $StrategyStatusText.Text = ('已装载恒力矩：{0:0.###} N·m，启动后按 0.1 N·m/s 缓升。空载仍会持续加速，仅在负载和安全措施已确认时启动。' -f $currentTorque)
            $description = '恒力矩参数已装载'
        }
        'ZeroTorque' {
            Set-TextValue $TorqueBox 0
            Set-TextValue $SpeedBox 0
            Set-TextValue $PositionBox 0
            Set-TextValue $KpBox 0
            Set-TextValue $KdBox 0
            $StrategyStatusText.Text = '已装载零力矩（所有目标为 0）。启动后电机仍处于 FOC 主动控制。'
            $description = '零力矩参数已装载'
        }
        'Hybrid' {
            $StrategyStatusText.Text = '已选择力位混合；当前 T / W / Pos / Kp / Kw 均保留，转矩、速度和位置目标会缓升，请逐项检查后再启动。'
            $description = '力位混合参数已保留'
        }
    }
    Write-Log "已应用策略：$description；策略选择不会自动发送。"
}

function Set-CalibrationLockout {
    $script:CalibrationUntil = (Get-Date).AddSeconds(5)
    $script:CalibrationTimer.Start()
    $CycleCheck.IsChecked = $false
    $CycleCheck.IsEnabled = $false
    $ModeCombo.IsEnabled = $false
    $CalibrationButton.IsEnabled = $false
    $StartFocButton.IsEnabled = $false
    $SendButton.IsEnabled = $false
    $ForwardButton.IsEnabled = $false
    $ReverseButton.IsEnabled = $false
    $SpeedUpButton.IsEnabled = $false
    $SpeedDownButton.IsEnabled = $false
    $StopButton.IsEnabled = $false
    $EmergencyButton.IsEnabled = $false
    $PositionModeButton.IsEnabled = $false
    $SpeedModeButton.IsEnabled = $false
    $DirectSpeedModeButton.IsEnabled = $false
    $DampingModeButton.IsEnabled = $false
    $TorqueModeButton.IsEnabled = $false
    $ZeroTorqueModeButton.IsEnabled = $false
    $HybridModeButton.IsEnabled = $false
    $RefreshStateButton.IsEnabled = $false
    $RawSendButton.IsEnabled = $false
    $RawSendBox.IsEnabled = $false
    $ModeHint.Text = '编码器校准进行中：剩余 5.0 秒，手册要求期间禁止发送任何数据包。'
    Write-Log '编码器校准已开始，5 秒内锁定所有通信动作。'
}

function Clear-CalibrationLockout {
    $script:CalibrationUntil = [DateTime]::MinValue
    $script:CalibrationTimer.Stop()
    $CycleCheck.IsEnabled = $true
    $ModeCombo.IsEnabled = $true
    $CalibrationButton.IsEnabled = $true
    $StartFocButton.IsEnabled = $true
    $SendButton.IsEnabled = $true
    $ForwardButton.IsEnabled = $true
    $ReverseButton.IsEnabled = $true
    $SpeedUpButton.IsEnabled = $true
    $SpeedDownButton.IsEnabled = $true
    $StopButton.IsEnabled = $true
    $EmergencyButton.IsEnabled = $true
    $PositionModeButton.IsEnabled = $true
    $SpeedModeButton.IsEnabled = $true
    $DirectSpeedModeButton.IsEnabled = $true
    $DampingModeButton.IsEnabled = $true
    $TorqueModeButton.IsEnabled = $true
    $ZeroTorqueModeButton.IsEnabled = $true
    $HybridModeButton.IsEnabled = $true
    $RefreshStateButton.IsEnabled = $true
    $rawAllowed = (Get-SelectedStatus) -ne 2
    $RawSendButton.IsEnabled = $rawAllowed
    $RawSendBox.IsEnabled = $rawAllowed
    $ModeHint.Text = '编码器校准完成，可以重新选择控制模式。'
    Write-Log '编码器校准等待结束，通信动作已恢复。'
    Set-IdOperationControls
    if ($script:MultiBusy -or $script:MultiNeedsStop) { Set-MultiControls }
}

function New-CurrentFrame(
    [int]$StatusOverride = -1,
    [bool]$ZeroMotion = $false,
    [double]$TorqueOverride = [double]::NaN,
    [double]$SpeedOverride = [double]::NaN,
    [double]$PositionOverride = [double]::NaN
) {
    $id = Get-TargetId
    $status = if ($StatusOverride -ge 0) { $StatusOverride } else { Get-SelectedStatus }
    $zero = $ZeroMotion -or $status -eq 0 -or $status -eq 2
    $torque = if ($zero) { 0 } elseif (-not [double]::IsNaN($TorqueOverride)) { $TorqueOverride } else { Read-Double $TorqueBox '目标转矩' }
    $speed = if ($zero) { 0 } elseif (-not [double]::IsNaN($SpeedOverride)) { $SpeedOverride } else { Read-Double $SpeedBox '目标速度' }
    $position = if ($zero) { 0 } elseif (-not [double]::IsNaN($PositionOverride)) { $PositionOverride } else { Read-Double $PositionBox '目标位置' }
    $kp = if ($zero) { 0 } else { Read-Double $KpBox 'Kpos' }
    $kd = if ($zero) { 0 } else { Read-Double $KdBox 'Kspd' }
    if ($OutputUnitsCheck.IsChecked -and -not $zero) {
        $ratio = Get-GearRatio
        $torque /= $ratio
        $speed *= $ratio
        $position *= $ratio
    }
    return ConvertTo-M8010ControlFrame -MotorId $id -Status $status -TorqueNm $torque -SpeedRadPerSec $speed -PositionRad $position -Kp $kp -Kd $kd
}

function Send-Bytes([byte[]]$Bytes, [string]$Description) {
    if (-not $script:MultiInternalSend) { Assert-MultiMotionAllowed }
    if (-not $script:IdInternalSend) { Assert-IdMotionAllowed }
    if ($null -eq $script:SerialPort -or -not $script:SerialPort.IsOpen) { throw '串口尚未打开。' }
    $script:SerialPort.Write($Bytes, 0, $Bytes.Length)
    $hex = ConvertTo-HexString $Bytes
    $LastTxBox.Text = $hex
    Write-Log "TX  $hex  [$Description]"
}

function Send-Control([int]$StatusOverride = -1, [bool]$ZeroMotion = $false, [string]$Description = '控制帧') {
    try {
        if ((Get-Date) -lt $script:CalibrationUntil) { throw '编码器校准进行中，5 秒内禁止发送任何数据包。' }
        $selectedStatus = if ($StatusOverride -ge 0) { $StatusOverride } else { Get-SelectedStatus }
        $frame = New-CurrentFrame $StatusOverride $ZeroMotion
        Send-Bytes $frame $Description
        if ($selectedStatus -eq 2) { Set-CalibrationLockout }
    } catch { Show-Problem $_.Exception.Message }
}

function Request-SafeFeedback {
    try {
        if ($null -eq $script:SerialPort -or -not $script:SerialPort.IsOpen) { throw '请先打开串口。' }
        if ($script:CycleTimer.IsEnabled) { throw '请先停止当前控制，再安全读取当前位置。' }
        if ((Get-Date) -lt $script:CalibrationUntil) { throw '编码器校准期间禁止发送任何数据包。' }
        $frame = ConvertTo-M8010ControlFrame -MotorId (Get-TargetId) -Status 0 -TorqueNm 0 -SpeedRadPerSec 0 -PositionRad 0 -Kp 0 -Kd 0
        $ModeCombo.SelectedIndex = 0
        Send-Bytes $frame '安全读取状态（STATUS 0 锁定）'
        $ModeHint.Text = '已发送 STATUS 0 锁定状态请求，等待反馈更新；选择当前位置保持后再明确启动。'
    } catch { Show-Problem $_.Exception.Message }
}

function Start-FocLoop([bool]$FromPositionFeedback = $false) {
    try {
        Assert-MultiMotionAllowed
        Assert-IdMotionAllowed
        if ($script:PendingPositionStart -and (Get-Date) -gt $script:PendingPositionStartUntil) {
            $script:PendingPositionStart = $false
            $script:PendingPositionStartMotorId = -1
        }
        if ($script:PendingPositionStart -and -not $FromPositionFeedback) { return }
        if ($null -eq $script:SerialPort -or -not $script:SerialPort.IsOpen) { throw '请先在“连接与安全”页打开串口。' }
        if ((Get-Date) -lt $script:CalibrationUntil) { throw '编码器校准进行中，5 秒内禁止发送任何数据包。' }
        $script:MaxFeedbackSpeedOutputRadPerSec = Read-OverspeedLimit
        $ModeCombo.SelectedIndex = 1
        $interval = Read-Int $CycleIntervalBox '周期' 5 1000
        $targetId = Get-TargetId
        $speed = Read-Double $SpeedBox '目标速度'
        $torqueOverride = [double]::NaN
        $positionOverride = [double]::NaN
        $speedOverride = [double]::NaN

        if ($script:SelectedStrategy -eq 'Position') {
            if ($null -eq $script:LastFeedback -or $script:LastFeedback.MotorId -ne $targetId -or
                ((Get-Date) - $script:LastFeedbackAt).TotalSeconds -gt 1.0) {
                if ($targetId -eq 15) { throw '当前位置保持不支持广播 ID；请指定一台电机。' }
                $script:PendingPositionStart = $true
                $script:PendingPositionStartMotorId = $targetId
                $script:PendingPositionStartUntil = (Get-Date).AddSeconds(2.0)
                if ($CycleCheck.IsChecked) {
                    $script:SuppressCycleUncheckedLock = $true
                    try { $CycleCheck.IsChecked = $false } finally { $script:SuppressCycleUncheckedLock = $false }
                }
                $ModeCombo.SelectedIndex = 0
                $queryFrame = ConvertTo-M8010ControlFrame -MotorId $targetId -Status 0 -TorqueNm 0 -SpeedRadPerSec 0 -PositionRad 0 -Kp 0 -Kd 0
                Send-Bytes $queryFrame '位置保持前读取当前位置'
                $ModeHint.Text = '正在读取目标电机当前位置，收到反馈后会自动锁定当前位置并启动。'
                return
            }
            $ratio = Get-GearRatio
            $script:PositionCommandRad = [double]$script:LastFeedback.PositionRad
            if (-not $OutputUnitsCheck.IsChecked) { $script:PositionCommandRad *= $ratio }
            $script:PositionTargetRad = [double]$script:LastFeedback.PositionRad
            if (-not $OutputUnitsCheck.IsChecked) { $script:PositionTargetRad *= $ratio }
            Set-TextValue $PositionBox $script:PositionTargetRad
            $positionScale = if ($OutputUnitsCheck.IsChecked) { $ratio } else { 1.0 }
            if ([math]::Abs($script:PositionTargetRad * $positionScale) -gt 411774) {
                throw '目标位置超出协议范围，请缩小目标或切换为转子侧单位。'
            }
            $positionOverride = $script:PositionCommandRad
        } elseif ($script:SelectedStrategy -in 'Speed', 'SpeedDirect') {
            Assert-SpeedTargetWithinProtocolRange $speed
            $speedScale = if ($OutputUnitsCheck.IsChecked) { 1.0 } else { (Get-GearRatio) }
            if ($null -ne $script:LastFeedback -and $script:LastFeedback.MotorId -eq $targetId -and
                ((Get-Date) - $script:LastFeedbackAt).TotalSeconds -le 1.0) {
                $script:SpeedCommandRadPerSec = [double]$script:LastFeedback.SpeedRadPerSec
                if (-not $OutputUnitsCheck.IsChecked) { $script:SpeedCommandRadPerSec *= $speedScale }
            } else { $script:SpeedCommandRadPerSec = 0.0 }
            if ($script:SelectedStrategy -eq 'SpeedDirect') {
                $script:SpeedCommandRadPerSec = $speed
                $speedOverride = $speed
            } else {
                $speedOverride = $script:SpeedCommandRadPerSec
            }
        } elseif ($script:SelectedStrategy -eq 'Torque') {
            if ($null -eq $script:LastFeedback -or $script:LastFeedback.MotorId -ne $targetId -or
                ((Get-Date) - $script:LastFeedbackAt).TotalSeconds -gt 1.0) {
                throw '恒力矩启动需要目标电机 1 秒内的反馈作为软启动起点。'
            }
            $script:TorqueCommandNm = [double]$script:LastFeedback.TorqueNm
            if (-not $OutputUnitsCheck.IsChecked) { $script:TorqueCommandNm /= (Get-GearRatio) }
            $torqueOverride = $script:TorqueCommandNm
            $targetTorque = Read-Double $TorqueBox '目标转矩'
            $torqueScale = if ($OutputUnitsCheck.IsChecked) { 1.0 / (Get-GearRatio) } else { 1.0 }
            if ([math]::Abs($targetTorque * $torqueScale) -gt 127.99) {
                throw '目标转矩超出协议范围，请缩小目标或切换为输出轴单位。'
            }
            if ([math]::Abs($targetTorque) -lt 0.000001) {
                throw '恒力矩为 0 时不会产生恒力矩效果。请输入一个小的、明确的非零目标值。'
            }
            $answer = [System.Windows.MessageBox]::Show($window, '恒力矩空载时会持续加速。确认电机有负载、机构安全且目标转矩已检查？', '恒力矩安全确认', 'YesNo', 'Warning')
            if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
                if ($CycleCheck.IsChecked) { $CycleCheck.IsChecked = $false }
                return
            }
        } elseif ($script:SelectedStrategy -eq 'Hybrid') {
            if ($null -eq $script:LastFeedback -or $script:LastFeedback.MotorId -ne $targetId -or
                ((Get-Date) - $script:LastFeedbackAt).TotalSeconds -gt 1.0) {
                throw '力位混合需要目标电机 1 秒内的反馈作为软启动起点。'
            }
            $ratio = Get-GearRatio
            $script:PositionCommandRad = [double]$script:LastFeedback.PositionRad
            $script:SpeedCommandRadPerSec = [double]$script:LastFeedback.SpeedRadPerSec
            $script:TorqueCommandNm = [double]$script:LastFeedback.TorqueNm
            if (-not $OutputUnitsCheck.IsChecked) {
                $script:PositionCommandRad *= $ratio
                $script:SpeedCommandRadPerSec *= $ratio
                $script:TorqueCommandNm /= $ratio
            }
            $positionOverride = $script:PositionCommandRad
            $speedOverride = $script:SpeedCommandRadPerSec
            $torqueOverride = $script:TorqueCommandNm
            $positionScale = if ($OutputUnitsCheck.IsChecked) { $ratio } else { 1.0 }
            if ([math]::Abs((Read-Double $PositionBox '目标位置') * $positionScale) -gt 411774) {
                throw '力位混合目标位置超出协议范围。'
            }
            Assert-SpeedTargetWithinProtocolRange $speed
            $targetTorque = Read-Double $TorqueBox '目标转矩'
            $torqueScale = if ($OutputUnitsCheck.IsChecked) { 1.0 / $ratio } else { 1.0 }
            if ([math]::Abs($targetTorque * $torqueScale) -gt 127.99) {
                throw '力位混合目标转矩超出协议范围。'
            }
            if ([math]::Abs($targetTorque) -gt 0.000001) {
                $answer = [System.Windows.MessageBox]::Show($window, '力位混合包含非零前馈转矩。确认当前转矩、位置、速度目标均已检查？', '力位混合安全确认', 'YesNo', 'Warning')
                if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }
            }
        }
        $script:CycleTimer.Interval = [TimeSpan]::FromMilliseconds($interval)
        $frame = New-CurrentFrame -TorqueOverride $torqueOverride -SpeedOverride $speedOverride -PositionOverride $positionOverride
        Send-Bytes $frame '启动 FOC'
        $script:CycleTimer.Start()
        $OutputUnitsCheck.IsEnabled = $false
        $OverspeedLimitBox.IsEnabled = $false
        $CycleCheck.IsChecked = $true
        $StrategyStatusText.Text = switch ($script:SelectedStrategy) {
            'Position' { '运行中：当前位置保持，目标位置限速跟随' }
            'Speed' { '运行中：速度目标正按加速度限制缓升' }
            'SpeedDirect' { '运行中：速度目标直接到达设定值' }
            'Torque' { '运行中：转矩目标以 0.1 N·m/s 缓升；空载可能持续加速' }
            'Hybrid' { '运行中：转矩、速度和位置目标均按斜坡更新' }
            'Damping' { '运行中：阻尼控制' }
            'ZeroTorque' { '运行中：零力矩 FOC' }
            default { '运行中：FOC 连续控制已启动' }
        }
        $ModeHint.Text = "FOC 正在运行：每 $interval ms 发送一次控制帧。停止或取消连续发送会发送 STATUS 0 锁定。"
        Write-Log "FOC 连续控制已启动：周期 $interval ms"
    } catch {
        $script:CycleTimer.Stop()
        $script:PendingPositionStart = $false
        $script:PendingPositionStartMotorId = -1
        if ($CycleCheck.IsChecked) { $CycleCheck.IsChecked = $false }
        Show-Problem $_.Exception.Message
    }
}

function Stop-ControlOutput([string]$Description = '停止 / 锁定') {
    if ($script:MultiBusy -or $script:MultiNeedsStop) { Stop-MultiProgram $Description; return }
    if ($script:IdBusy -or $script:IdNeedsRecovery) { Cancel-IdOperation; return }
    $script:CycleTimer.Stop()
    $OutputUnitsCheck.IsEnabled = $true
    $OverspeedLimitBox.IsEnabled = $true
    $script:SuppressCycleUncheckedLock = $true
    try { $CycleCheck.IsChecked = $false } finally { $script:SuppressCycleUncheckedLock = $false }
    if ($ModeCombo.SelectedIndex -ne 0) { $ModeCombo.SelectedIndex = 0 }
    Send-Control -StatusOverride 0 -ZeroMotion $true -Description $Description
    $StrategyStatusText.Text = "$Description：已停止连续发送并锁定电机"
    $ModeHint.Text = '电机已发送 STATUS 0 锁定。重新控制请先选择策略并检查目标。'
}

function Update-Stats {
    $ProtocolStatsText.Text = "接收帧 $($script:RxFrames) · CRC 丢弃 $($script:RxCrcDrops)"
}

function Update-Feedback($feedback) {
    $script:LastFeedback = $feedback
    $script:LastFeedbackAt = Get-Date
    $rawHex = ConvertTo-HexString $feedback.Raw
    $LastRxBox.Text = $rawHex
    $FeedbackIdText.Text = "ID $($feedback.MotorId)"
    $FeedbackStatusText.Text = if ($statusNames.ContainsKey([int]$feedback.Status)) { $statusNames[[int]$feedback.Status] } else { "保留 ($($feedback.Status))" }
    $FeedbackTorqueText.Text = ('{0,8:0.000}' -f $feedback.TorqueNm)
    $FeedbackSpeedText.Text = ('{0,8:0.000}' -f $feedback.SpeedRadPerSec)
    $FeedbackPositionText.Text = ('{0,8:0.000}' -f $feedback.PositionRad)
    $FeedbackTempText.Text = ('{0} °C' -f $feedback.TemperatureC)
    $FeedbackForceText.Text = ('{0} / 4095' -f $feedback.ForceRaw)
    $FeedbackTempText.Foreground = if ($feedback.TemperatureC -ge 90) { [System.Windows.Media.Brushes]::Tomato } elseif ($feedback.TemperatureC -ge 70) { [System.Windows.Media.Brushes]::Orange } else { [System.Windows.Media.Brushes]::LightGreen }
    $errorName = if ($errorNames.ContainsKey([int]$feedback.ErrorCode)) { $errorNames[[int]$feedback.ErrorCode] } else { "保留错误码 $($feedback.ErrorCode)" }
    $ErrorText.Text = if ($feedback.ErrorCode -eq 0) { "正常 · 温度 $($feedback.TemperatureC) °C · FORCE $($feedback.ForceRaw)" } else { "错误：$errorName · 温度 $($feedback.TemperatureC) °C · 请停止输出并检查电机" }
    $ErrorText.Foreground = if ($feedback.ErrorCode -eq 0) { [System.Windows.Media.Brushes]::LightGreen } else { [System.Windows.Media.Brushes]::Tomato }
    $overSpeed = $false
    if ($script:CycleTimer.IsEnabled) { $overSpeed = -not (Test-FeedbackSpeedSafe $feedback) }
    if (($feedback.ErrorCode -ne 0 -or $feedback.TemperatureC -ge 90 -or $overSpeed) -and $script:CycleTimer.IsEnabled) {
        $script:CycleTimer.Stop()
        $CycleCheck.IsChecked = $false
        $OutputUnitsCheck.IsEnabled = $true
        $OverspeedLimitBox.IsEnabled = $true
        $ModeCombo.SelectedIndex = 0
        if ($overSpeed) {
            $StrategyStatusText.Text = ('已触发超速保护：反馈速度 {0:0.###} rad/s 超过 ±{1:0.###} rad/s，控制已锁定' -f $feedback.SpeedRadPerSec, $script:MaxFeedbackSpeedOutputRadPerSec)
            Write-Log "超速保护已锁定电机：反馈速度 $($feedback.SpeedRadPerSec) rad/s"
        } else {
            $StrategyStatusText.Text = '已自动停止：电机反馈错误或温度达到保护阈值'
            Write-Log "周期发送已自动停止：错误码 $($feedback.ErrorCode)，温度 $($feedback.TemperatureC) °C"
        }
    }
    $now = Get-Date
    if (($now - $script:LastRxLogAt).TotalSeconds -ge 1) {
        Write-Log "RX  $rawHex  [$($FeedbackStatusText.Text), $errorName]"
        $script:LastRxLogAt = $now
    }
    Update-Stats
    if ($script:PendingPositionStart) {
        if ((Get-Date) -gt $script:PendingPositionStartUntil) {
            $script:PendingPositionStart = $false
            $script:PendingPositionStartMotorId = -1
            $ModeHint.Text = '当前位置读取超时；请检查电机 ID 与串口反馈后重试。'
        } elseif ($feedback.MotorId -eq $script:PendingPositionStartMotorId) {
            $script:PendingPositionStart = $false
            $targetPosition = [double]$feedback.PositionRad
            if (-not $OutputUnitsCheck.IsChecked) { $targetPosition *= (Get-GearRatio) }
            Set-TextValue $PositionBox $targetPosition
            Start-FocLoop $true
        }
    }
}

function Receive-SerialData {
    if ($script:IsClosing -or $script:IsClosed) { return }
    $port = $script:SerialPort
    if ($null -eq $port -or -not $port.IsOpen) { return }
    if ($script:IdBusy) { Receive-IdSerialData; return }

    try {
        # SerialPort.DataReceived invokes a PowerShell script block on a driver
        # thread. Windows PowerShell can terminate when that callback has no
        # script context. Polling here keeps all serial and WPF work on the UI
        # thread instead.
        $budget = 65536
        $latestFeedback = $null
        $faultFeedback = $null
        $receivedFrames = 0
        $crcDrops = 0

        while ($budget -gt 0) {
            $available = $port.BytesToRead
            if ($available -le 0) { break }
            $count = [Math]::Min([Math]::Min($available, $budget), 16384)
            $incoming = [byte[]]::new($count)
            $read = $port.Read($incoming, 0, $count)
            if ($read -le 0) { break }
            $budget -= $read

            for ($index = 0; $index -lt $read; $index++) { $script:RxBuffer.Add($incoming[$index]) }
            $parsed = Find-M8010FeedbackFrames ([byte[]]$script:RxBuffer.ToArray())
            $script:RxBuffer.Clear()
            foreach ($byte in $parsed.Remaining) { $script:RxBuffer.Add($byte) }
            $crcDrops += $parsed.CrcDrops

            foreach ($frame in $parsed.Frames) {
                $receivedFrames++
                if ($script:MultiBusy) { Accept-MultiFeedback $frame }
                $latestFeedback = $frame
                if ($frame.ErrorCode -ne 0 -or $frame.TemperatureC -ge 90) { $faultFeedback = $frame }
            }
        }

        if ($crcDrops -gt 0) { $script:RxCrcDrops += $crcDrops }
        if ($receivedFrames -gt 0) {
            $script:RxFrames += $receivedFrames
            # Render one state per poll. This prevents high-rate feedback from
            # flooding the WPF dispatcher and makes a reported fault visible.
            if ($null -ne $faultFeedback) { Update-Feedback $faultFeedback }
            else { Update-Feedback $latestFeedback }
        } elseif ($crcDrops -gt 0) {
            Update-Stats
        }
    } catch [System.TimeoutException] {
        # BytesToRead can change between the availability check and Read().
    } catch {
        $script:ReceiveTimer.Stop()
        if ($script:MultiBusy) { Stop-MultiProgram "串口接收异常：$($_.Exception.Message)" }
        $script:CycleTimer.Stop()
        $CycleCheck.IsChecked = $false
        $StrategyStatusText.Text = '接收已停止：串口读取异常'
        Write-Log "串口接收异常，已停止控制：$($_.Exception.Message)"
    }
}

function Open-Serial {
    $port = $null
    try {
        if ([string]::IsNullOrWhiteSpace($PortCombo.Text)) { throw '请选择一个串口。' }
        $baud = Read-Int $BaudCombo '波特率' 1200 10000000
        $dataBits = [int]$DataBitsCombo.Text
        $parity = [System.IO.Ports.Parity]::$($ParityCombo.Text)
        $stopBits = if ($StopBitsCombo.Text -eq '2') { [System.IO.Ports.StopBits]::Two } else { [System.IO.Ports.StopBits]::One }
        $port = New-Object System.IO.Ports.SerialPort($PortCombo.Text, $baud, $parity, $dataBits, $stopBits)
        $port.ReadTimeout = 100
        $port.WriteTimeout = 100
        $port.ReadBufferSize = 65536
        $port.Handshake = [System.IO.Ports.Handshake]::None
        $port.DtrEnable = $false
        $port.RtsEnable = $false
        $script:LastFeedback = $null
        $script:LastFeedbackAt = [DateTime]::MinValue
        $script:RxBuffer.Clear()
        $script:SerialPort = $port
        $port.Open()
        $script:ReceiveTimer.Start()
        Set-ConnectionState $true "已连接 $($PortCombo.Text)"
        Write-Log "串口已打开：$($PortCombo.Text), $baud, $dataBits-$($ParityCombo.Text)-$($StopBitsCombo.Text)"
    } catch {
        if ($null -ne $port) {
            try {
                if ($port.IsOpen) { $port.Close() }
                $port.Dispose()
            } catch { }
        }
        $script:ReceiveTimer.Stop()
        $script:SerialPort = $null
        Set-ConnectionState $false '未连接'
        Show-Problem $_.Exception.Message
    }
}

function Close-Serial {
    if ($script:IsClosed -and $null -eq $script:SerialPort) { return }
    if ($script:MultiBusy) {
        Stop-MultiProgram '关闭串口前停止程序'
        Write-Log '正在逐台停止并验证，请结束后再次关闭串口。'
        return
    }
    if ($script:IdBusy) {
        Cancel-IdOperation
        Write-Log 'ID 操作正在取消 / 恢复，请完成后再次关闭串口。'
        return
    }
    $script:CycleTimer.Stop()
    $script:ReceiveTimer.Stop()
    $script:CalibrationTimer.Stop()
    $currentPort = $script:SerialPort
    $script:SerialPort = $null
    $script:RxBuffer.Clear()
    try {
        $CycleCheck.IsChecked = $false
        if ($null -ne $currentPort) {
            if ($currentPort.IsOpen) {
                if ((Get-Date) -ge $script:CalibrationUntil -and -not $script:IdNeedsRecovery) {
                    try {
                        $safeFrame = New-CurrentFrame -StatusOverride 0 -ZeroMotion $true
                        $currentPort.Write($safeFrame, 0, $safeFrame.Length)
                        Write-Log "TX  $(ConvertTo-HexString $safeFrame)  [关闭前锁定]"
                    } catch { Write-Log "关闭前锁定发送失败：$($_.Exception.Message)" }
                } else { Write-Log '编码器校准进行中，按手册要求关闭前不发送额外数据包。' }
                $currentPort.Close()
            }
            $currentPort.Dispose()
        }
    } catch { Write-Log "关闭异常：$($_.Exception.Message)" }
    if ($script:IsClosing) { return }
    Clear-CalibrationLockout
    Set-ConnectionState $false '未连接'
    Write-Log '串口已关闭。'
}

function Send-Raw {
    try {
        if ((Get-SelectedStatus) -eq 2) { throw 'STATUS 2 编码器校准期间禁止发送原始数据包。' }
        if ((Get-Date) -lt $script:CalibrationUntil) { throw '编码器校准进行中，5 秒内禁止发送任何数据包。' }
        $bytes = ConvertFrom-HexString $RawSendBox.Text
        if ($bytes.Length -eq 0) { throw '请输入十六进制数据。' }
        Send-Bytes $bytes '原始帧'
        if ($bytes.Length -eq 17 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xEE -and ((($bytes[2] -shr 4) -band 0x07) -eq 2)) { Set-CalibrationLockout }
    } catch { Show-Problem $_.Exception.Message }
}

. (Join-Path $PSScriptRoot 'M8010IdManager.ps1')
. (Join-Path $PSScriptRoot 'M8010MultiProgram.ps1')

$RefreshPortsButton.Add_Click({ Refresh-Ports })
$OpenButton.Add_Click({ Open-Serial })
$CloseButton.Add_Click({ Close-Serial })
$RawSendButton.Add_Click({ Send-Raw })
$SendButton.Add_Click({
    if ((Get-SelectedStatus) -eq 1) {
        Show-Problem 'FOC 策略请通过“启动 FOC”运行，避免单帧位置/速度目标跳变。'
        return
    }
    Send-Control -Description '当前模式'
})
$StartFocButton.Add_Click({ Start-FocLoop })
$PositionModeButton.Add_Click({ try { Apply-Strategy 'Position' } catch { Show-Problem $_.Exception.Message } })
$SpeedModeButton.Add_Click({ try { Apply-Strategy 'Speed' } catch { Show-Problem $_.Exception.Message } })
$DirectSpeedModeButton.Add_Click({ try { Apply-Strategy 'SpeedDirect' } catch { Show-Problem $_.Exception.Message } })
$DampingModeButton.Add_Click({ try { Apply-Strategy 'Damping' } catch { Show-Problem $_.Exception.Message } })
$TorqueModeButton.Add_Click({ try { Apply-Strategy 'Torque' } catch { Show-Problem $_.Exception.Message } })
$ZeroTorqueModeButton.Add_Click({ try { Apply-Strategy 'ZeroTorque' } catch { Show-Problem $_.Exception.Message } })
$HybridModeButton.Add_Click({ try { Apply-Strategy 'Hybrid' } catch { Show-Problem $_.Exception.Message } })
$ForwardButton.Add_Click({
    try {
        if ((Get-SelectedStatus) -ne 1) { throw '正转按钮仅适用于 FOC 闭环模式，请先选择 STATUS 1。' }
        $value = [math]::Abs((Read-Double $SpeedBox '目标速度'))
        if ($value -lt 0.000001) { $value = 0.5 }
        $SpeedBox.Text = $value.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
        if ($script:SelectedStrategy -notin 'Speed', 'SpeedDirect') { Apply-Strategy 'Speed' }
        $ModeHint.Text = if ($script:CycleTimer.IsEnabled -and $script:SelectedStrategy -eq 'SpeedDirect') { '正转目标已更新，控制器会立即应用新速度。' } elseif ($script:CycleTimer.IsEnabled) { '正转目标已更新，将按加速度限制缓升。' } else { '正转目标已设置，请检查安全后点击启动 FOC。' }
    } catch { Show-Problem $_.Exception.Message }
})
$ReverseButton.Add_Click({
    try {
        if ((Get-SelectedStatus) -ne 1) { throw '反转按钮仅适用于 FOC 闭环模式，请先选择 STATUS 1。' }
        $value = [math]::Abs((Read-Double $SpeedBox '目标速度'))
        if ($value -lt 0.000001) { $value = 0.5 }
        $SpeedBox.Text = (-$value).ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
        if ($script:SelectedStrategy -notin 'Speed', 'SpeedDirect') { Apply-Strategy 'Speed' }
        $ModeHint.Text = if ($script:CycleTimer.IsEnabled -and $script:SelectedStrategy -eq 'SpeedDirect') { '反转目标已更新，控制器会立即应用新速度。' } elseif ($script:CycleTimer.IsEnabled) { '反转目标已更新，将按加速度限制缓升。' } else { '反转目标已设置，请检查安全后点击启动 FOC。' }
    } catch { Show-Problem $_.Exception.Message }
})
$SpeedUpButton.Add_Click({
    try {
        $step = Read-Double $SpeedStepBox '调整步长'; $current = Read-Double $SpeedBox '目标速度'; $SpeedBox.Text = ($current + $step).ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
        if ($script:SelectedStrategy -notin 'Speed', 'SpeedDirect') { Apply-Strategy 'Speed' }
        $ModeHint.Text = if ($script:CycleTimer.IsEnabled -and $script:SelectedStrategy -eq 'SpeedDirect') { '速度目标已更新，控制器会立即应用新速度。' } elseif ($script:CycleTimer.IsEnabled) { '速度目标已更新，将按加速度限制缓升。' } else { '速度目标已更新，请检查安全后点击启动 FOC。' }
    } catch { Show-Problem $_.Exception.Message }
})
$SpeedDownButton.Add_Click({
    try {
        $step = Read-Double $SpeedStepBox '调整步长'; $current = Read-Double $SpeedBox '目标速度'; $SpeedBox.Text = ($current - $step).ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
        if ($script:SelectedStrategy -notin 'Speed', 'SpeedDirect') { Apply-Strategy 'Speed' }
        $ModeHint.Text = if ($script:CycleTimer.IsEnabled -and $script:SelectedStrategy -eq 'SpeedDirect') { '速度目标已更新，控制器会立即应用新速度。' } elseif ($script:CycleTimer.IsEnabled) { '速度目标已更新，将按加速度限制缓降。' } else { '速度目标已更新，请检查安全后点击启动 FOC。' }
    } catch { Show-Problem $_.Exception.Message }
})
$StopButton.Add_Click({ Stop-ControlOutput '停止 / 锁定' })
$EmergencyButton.Add_Click({ Stop-ControlOutput '急停' })
$RefreshStateButton.Add_Click({ Request-SafeFeedback })
$CalibrationButton.Add_Click({
    $ModeCombo.SelectedIndex = 2
    Send-Control -StatusOverride 2 -ZeroMotion $true -Description '编码器校准'
})
$ClearLogButton.Add_Click({ $LogBox.Clear() })
$BroadcastCheck.Add_Checked({ $MotorIdBox.IsEnabled = $false })
$BroadcastCheck.Add_Unchecked({ $MotorIdBox.IsEnabled = $true })
$OutputUnitsCheck.Add_Checked({ Convert-ControlInputUnits $true })
$OutputUnitsCheck.Add_Unchecked({ Convert-ControlInputUnits $false })
$script:InputValuesAreOutputUnits = [bool]$OutputUnitsCheck.IsChecked
Update-UnitHints
$ModeCombo.Add_SelectionChanged({
    if ($null -eq $ModeCombo.SelectedItem) { return }
    $status = [int]$ModeCombo.SelectedItem.Tag
    $ModeHint.Text = switch ($status) {
        0 { '锁定模式：电机默认关闭输出。' }
        1 { 'FOC 模式：按当前目标转矩、速度、位置和增益运行。' }
        2 { '编码器校准：约 5 秒，校准期间不要连续发送 FOC 目标。' }
    }
    if ($status -ne 1 -and $CycleCheck.IsChecked) { $CycleCheck.IsChecked = $false }
    if ($status -eq 2) {
        $RawSendButton.IsEnabled = $false
        $RawSendBox.IsEnabled = $false
    } elseif ((Get-Date) -ge $script:CalibrationUntil) {
        $RawSendButton.IsEnabled = $true
        $RawSendBox.IsEnabled = $true
    }
    if ($script:MultiBusy -or $script:MultiNeedsStop) { Set-MultiControls }
})
$CycleCheck.Add_Checked({
    if ($script:CycleTimer.IsEnabled) { return }
    Start-FocLoop
})
$CycleCheck.Add_Unchecked({
    $script:CycleTimer.Stop()
    $OutputUnitsCheck.IsEnabled = $true
    $OverspeedLimitBox.IsEnabled = $true
    Write-Log '周期发送已停止。'
    if (-not $script:SuppressCycleUncheckedLock -and (Get-SelectedStatus) -ne 2 -and
        (Get-Date) -ge $script:CalibrationUntil -and $null -ne $script:SerialPort -and $script:SerialPort.IsOpen) {
        Send-Control -StatusOverride 0 -ZeroMotion $true -Description '取消连续发送后的锁定'
        $ModeCombo.SelectedIndex = 0
        $ModeHint.Text = '已取消连续发送，并发送 STATUS 0 锁定。'
    }
})
$script:CalibrationTimer.Add_Tick({
    if ($script:IsClosing -or $script:IsClosed) { return }
    try {
        $remaining = ($script:CalibrationUntil - (Get-Date)).TotalSeconds
        if ($remaining -le 0) { Clear-CalibrationLockout }
        else { $ModeHint.Text = ('编码器校准进行中：剩余 {0:0.0} 秒，手册要求期间禁止发送任何数据包。' -f $remaining) }
    } catch {
        $script:CalibrationTimer.Stop()
        Write-Log "校准状态更新异常：$($_.Exception.Message)"
    }
})
$script:ReceiveTimer.Add_Tick({
    Receive-SerialData
})
$script:CycleTimer.Add_Tick({
    if ($script:IsClosing -or $script:IsClosed) { return }
    if ($null -eq $script:SerialPort -or -not $script:SerialPort.IsOpen) { return }
    try {
        $speedOverride = [double]::NaN
        $positionOverride = [double]::NaN
        $torqueOverride = [double]::NaN
        $intervalSeconds = [Math]::Max(0.001, $script:CycleTimer.Interval.TotalSeconds)
        if ($script:SelectedStrategy -in 'Speed', 'SpeedDirect', 'Hybrid') {
            $targetSpeed = Read-Double $SpeedBox '目标速度'
            Assert-SpeedTargetWithinProtocolRange $targetSpeed
            $speedScale = if ($OutputUnitsCheck.IsChecked) { 1.0 } else { Get-GearRatio }
            if ($script:SelectedStrategy -eq 'Speed') {
                $maxSpeedStep = $script:SpeedRampOutputRadPerSec2 * $speedScale * $intervalSeconds
                $script:SpeedCommandRadPerSec = Move-Toward $script:SpeedCommandRadPerSec $targetSpeed $maxSpeedStep
            } else {
                $script:SpeedCommandRadPerSec = $targetSpeed
            }
            $speedOverride = $script:SpeedCommandRadPerSec
        }
        if ($script:SelectedStrategy -in 'Position', 'Hybrid') {
            $script:PositionTargetRad = Read-Double $PositionBox '目标位置'
            $positionScale = if ($OutputUnitsCheck.IsChecked) { 1.0 } else { Get-GearRatio }
            $positionProtocolScale = if ($OutputUnitsCheck.IsChecked) { Get-GearRatio } else { 1.0 }
            if ([math]::Abs($script:PositionTargetRad * $positionProtocolScale) -gt 411774) { throw '目标位置超出协议范围。' }
            $maxPositionStep = $script:PositionRampOutputRadPerSec * $positionScale * $intervalSeconds
            $script:PositionCommandRad = Move-Toward $script:PositionCommandRad $script:PositionTargetRad $maxPositionStep
            $positionOverride = $script:PositionCommandRad
        }
        if ($script:SelectedStrategy -in 'Torque', 'Hybrid') {
            $targetTorque = Read-Double $TorqueBox '目标转矩'
            $torqueOverride = Update-TorqueCommand $targetTorque $intervalSeconds
        }
        $frame = New-CurrentFrame -TorqueOverride $torqueOverride -SpeedOverride $speedOverride -PositionOverride $positionOverride
        $script:SerialPort.Write($frame, 0, $frame.Length)
        $LastTxBox.Text = ConvertTo-HexString $frame
    } catch {
        $CycleCheck.IsChecked = $false
        Show-Problem "周期发送已停止：$($_.Exception.Message)"
    }
})
$window.Dispatcher.Add_UnhandledException({
    param($sender, $eventArgs)
    # Stop output first so a partially handled UI event cannot keep sending commands.
    try {
        if ($script:MultiBusy) { Stop-MultiProgram '界面异常，停止自动程序' }
        if ($script:IdBusy) { Complete-IdOperation '界面发生异常，ID 操作已中止；若进入过工厂模式，请重新连接后恢复电机模式。' }
        $script:CycleTimer.Stop()
        $script:ReceiveTimer.Stop()
        if ($null -ne $CycleCheck) { $CycleCheck.IsChecked = $false }
        $exception = $eventArgs.Exception
        Write-Log "界面事件异常：$($exception.Message)"
        Write-ErrorLog 'WPF Dispatcher 未处理异常' $exception
        $eventArgs.Handled = $true
    } catch { }
})
$window.Add_Closing({
    param($sender, $eventArgs)
    if ($script:MultiBusy) {
        $eventArgs.Cancel = $true
        Stop-MultiProgram '关闭窗口前停止程序'
        return
    }
    $script:MultiTimer.Stop()
    if ($script:IdBusy) {
        $eventArgs.Cancel = $true
        Cancel-IdOperation
        return
    }
    $script:IdTimer.Stop()
    $script:IsClosing = $true
    $script:CycleTimer.Stop()
    $script:ReceiveTimer.Stop()
    $script:CalibrationTimer.Stop()
})
$window.Add_Closed({
    Close-Serial
    $script:IsClosed = $true
})

Refresh-Ports
Set-ConnectionState $false '未连接'
Write-Log '就绪。请确认 RS-485 适配器、终端电阻和 4 Mbps 通信质量。'
if ($SmokeTest) {
    $null = Read-Int $BaudCombo '波特率' 1200 10000000
    if ($null -eq $DirectSpeedModeButton) { throw '直接目标速度策略按钮没有加载。' }
    if ($null -eq $BrandLogo.Source) { throw '北京建筑大学 Logo 没有成功加载。' }
    $initialSpeed = Read-Double $SpeedBox '目标速度'
    $script:LastFeedback = [pscustomobject]@{ MotorId = 0; PositionRad = 1.25; SpeedRadPerSec = 0.0; ErrorCode = 0; TemperatureC = 25; Raw = [byte[]]@(0xFD, 0xEE) }
    $script:LastFeedbackAt = Get-Date
    $script:LastFeedback = $null
    Apply-Strategy 'Position'
    if ($script:SelectedStrategy -ne 'Position') { throw '当前位置保持没有反馈时仍无法选择。' }
    $script:LastFeedback = [pscustomobject]@{ MotorId = 0; PositionRad = 1.25; SpeedRadPerSec = 0.0; ErrorCode = 0; TemperatureC = 25; Raw = [byte[]]@(0xFD, 0xEE) }
    $script:LastFeedbackAt = (Get-Date).AddSeconds(-2)
    if ($null -eq $script:LastFeedback -or ((Get-Date) - $script:LastFeedbackAt).TotalSeconds -le 1.0) { throw '位置保持过期反馈测试前置条件错误。' }
    $script:LastFeedbackAt = Get-Date
    if ([math]::Abs((Move-Toward 0 1 0.01) - 0.01) -gt 0.000001) { throw '正向斜坡步长限幅错误。' }
    if ([math]::Abs((Move-Toward 0 -1 0.01) + 0.01) -gt 0.000001) { throw '反向斜坡步长限幅错误。' }
    if ([math]::Abs((Move-Toward 0 1 ($script:TorqueRampOutputNmPerSec * 0.02)) - 0.002) -gt 0.000001) { throw '输出轴转矩软启动斜率错误。' }
    if (-not [string]::IsNullOrWhiteSpace($OverspeedLimitBox.Text)) { throw '反馈超速保护阈值不应预先设置。' }
    $invalidOverspeedRejected = $false
    try { $null = Read-OverspeedLimit } catch { $invalidOverspeedRejected = $true }
    if (-not $invalidOverspeedRejected) { throw '未填写反馈超速阈值时未阻止启动。' }
    $OverspeedLimitBox.Text = '30'
    $script:MaxFeedbackSpeedOutputRadPerSec = Read-OverspeedLimit
    if (-not (Test-FeedbackSpeedSafe $script:LastFeedback)) { throw '安全速度检查拒绝了限值内的反馈。' }
    $overspeedFeedback = [pscustomobject]@{ MotorId = 0; SpeedRadPerSec = $script:MaxFeedbackSpeedOutputRadPerSec + 0.01 }
    if (Test-FeedbackSpeedSafe $overspeedFeedback) { throw '安全速度检查未识别超速反馈。' }
    $otherMotorFeedback = [pscustomobject]@{ MotorId = 1; SpeedRadPerSec = $script:MaxFeedbackSpeedOutputRadPerSec + 1 }
    if (-not (Test-FeedbackSpeedSafe $otherMotorFeedback)) { throw '安全速度检查误判了其他电机的反馈。' }
    $BroadcastCheck.IsChecked = $true
    if (Test-FeedbackSpeedSafe $otherMotorFeedback) { throw '广播控制下的超速反馈没有触发保护。' }
    $BroadcastCheck.IsChecked = $false
    $OverspeedLimitBox.Text = '12.5'
    if ([math]::Abs((Read-OverspeedLimit) - 12.5) -gt 0.001) { throw '反馈超速保护阈值不可调低。' }
    $OverspeedLimitBox.Text = '0'
    $invalidOverspeedRejected = $false
    try { $null = Read-OverspeedLimit } catch { $invalidOverspeedRejected = $true }
    if (-not $invalidOverspeedRejected) { throw '反馈超速保护阈值接受了零。' }
    $OverspeedLimitBox.Text = '804.1'
    $invalidOverspeedRejected = $false
    try { $null = Read-OverspeedLimit } catch { $invalidOverspeedRejected = $true }
    if (-not $invalidOverspeedRejected) { throw '反馈超速保护阈值没有限制在反馈协议范围内。' }
    $OverspeedLimitBox.Text = 'NaN'
    $invalidOverspeedRejected = $false
    try { $null = Read-OverspeedLimit } catch { $invalidOverspeedRejected = $true }
    if (-not $invalidOverspeedRejected) { throw '反馈超速保护阈值接受了非有限值。' }
    $OverspeedLimitBox.Text = ''
    $script:MaxFeedbackSpeedOutputRadPerSec = [double]::NaN
    foreach ($index in 0, 1, 2) {
        $ModeCombo.SelectedIndex = $index
        $frame = New-CurrentFrame
        if ($frame.Length -ne 17) { throw "STATUS $index 控制帧长度错误。" }
        if ($frame[2] -ne ($index -shl 4)) { throw "STATUS $index 模式位域错误。" }
    }
    foreach ($strategy in 'Position', 'Speed', 'SpeedDirect', 'Damping', 'Torque', 'ZeroTorque', 'Hybrid') { Apply-Strategy $strategy }
    Apply-Strategy 'SpeedDirect'
    Set-TextValue $SpeedBox 10
    $directSpeedFrame = New-CurrentFrame -SpeedOverride 10
    $directRotorSpeedRaw = [int]$directSpeedFrame[5] -bor ([int]$directSpeedFrame[6] -shl 8)
    $expectedDirectRotorRaw = [int][math]::Round((10 * 6.33) / (2 * [math]::PI) * 256, [MidpointRounding]::AwayFromZero)
    if ($directRotorSpeedRaw -ne $expectedDirectRotorRaw) { throw '直接速度模式没有将目标速度立即换算写入控制帧。' }
    Apply-Strategy 'Torque'
    if ([math]::Abs((Read-Double $TorqueBox '目标转矩')) -gt 0.000001) { throw '恒力矩策略自动注入了非零转矩。' }
    Apply-Strategy 'Position'
    if ([math]::Abs((Read-Double $PositionBox '位置') - 1.25) -gt 0.001) { throw '当前位置保持没有锁存反馈位置。' }
    if ([math]::Abs((Read-Double $KdBox 'Kspd')) -gt 0.0001) { throw '位置保持没有按手册将速度目标和阻尼增益设为 0。' }
    if ([math]::Abs($initialSpeed - 0.5) -gt 0.001) { throw '默认速度目标不再是低速设置。' }
    if ($script:CycleTimer.IsEnabled) { throw '选择控制策略时不应自动启动连续输出。' }
    $OutputUnitsCheck.IsChecked = $true
    Assert-SpeedTargetWithinProtocolRange 10
    $invalidSpeedRejected = $false
    try { Assert-SpeedTargetWithinProtocolRange 127.2 } catch { $invalidSpeedRejected = $true }
    if (-not $invalidSpeedRejected) { throw '目标速度超过协议转子侧范围时未拒绝。' }
    $OutputUnitsCheck.IsChecked = $false
    Assert-SpeedTargetWithinProtocolRange 804
    $invalidSpeedRejected = $false
    try { Assert-SpeedTargetWithinProtocolRange 804.1 } catch { $invalidSpeedRejected = $true }
    if (-not $invalidSpeedRejected) { throw '转子侧目标速度超过协议范围时未拒绝。' }
    $OutputUnitsCheck.IsChecked = $true
    Set-TextValue $SpeedBox 1
    $frame = New-CurrentFrame
    if ($frame.Length -ne 17) { throw '输出轴单位换算控制帧长度错误。' }
    if ($frame[5] -ne 0x02 -or $frame[6] -ne 0x01) { throw '输出轴速度换算结果错误。' }
    $rawPosition = [long]$frame[7] -bor ([long]$frame[8] -shl 8) -bor ([long]$frame[9] -shl 16) -bor ([long]$frame[10] -shl 24)
    $expectedPosition = [long][math]::Round((1.25 * 6.33) / (2 * [math]::PI) * 32768, [MidpointRounding]::AwayFromZero)
    if ($rawPosition -ne $expectedPosition) { throw '当前位置保持目标的位置单位换算错误。' }
    $OutputUnitsCheck.IsChecked = $false
    if ([math]::Abs((Read-Double $SpeedBox '速度') - 6.33) -gt 0.01) { throw '切换到转子单位时速度没有保持物理值。' }
    if ([math]::Abs((Read-Double $PositionBox '位置') - (1.25 * 6.33)) -gt 0.01) { throw '切换到转子单位时位置没有保持物理值。' }
    $OutputUnitsCheck.IsChecked = $true
    if ([math]::Abs((Read-Double $SpeedBox '速度') - 1.0) -gt 0.001) { throw '切回输出轴单位时速度换算错误。' }
    if ([math]::Abs((Read-Double $PositionBox '位置') - 1.25) -gt 0.001) { throw '切回输出轴单位时位置换算错误。' }
    $script:TorqueCommandNm = 0
    if ([math]::Abs((Update-TorqueCommand 1 0.02) - 0.002) -gt 0.000001) { throw '输出轴转矩软启动单位换算错误。' }
    $OutputUnitsCheck.IsChecked = $false
    $script:TorqueCommandNm = 0
    $expectedRotorTorqueStep = $script:TorqueRampOutputNmPerSec * 0.02 / (Get-GearRatio)
    if ([math]::Abs((Update-TorqueCommand 1 0.02) - $expectedRotorTorqueStep) -gt 0.000001) { throw '转子侧转矩软启动单位换算错误。' }
    $OutputUnitsCheck.IsChecked = $true
    Set-TextValue $TorqueBox 2
    $frame = New-CurrentFrame -TorqueOverride 0.5
    $rawTorque = [int]$frame[3] -bor ([int]$frame[4] -shl 8)
    $expectedTorque = [int][math]::Round((0.5 / 6.33) * 256, [MidpointRounding]::AwayFromZero)
    if ($rawTorque -ne $expectedTorque) { throw '周期转矩斜坡没有将缓升目标写入控制帧。' }

    $mockPort = [pscustomobject]@{ IsOpen = $true; LastWrite = $null }
    $mockPort | Add-Member -MemberType ScriptMethod -Name Write -Value {
        param([byte[]]$Bytes, [int]$Offset, [int]$Count)
        $this.LastWrite = [byte[]]$Bytes
    }
    $script:SerialPort = $mockPort
    $OverspeedLimitBox.Text = '30'
    $script:LastFeedbackAt = (Get-Date).AddSeconds(-2)
    Apply-Strategy 'Position'
    Start-FocLoop
    if (-not $script:PendingPositionStart) { throw '位置反馈过期后没有进入自动读取流程。' }
    if ($mockPort.LastWrite[2] -ne 0x00) { throw '位置保持自动读取没有先发送 STATUS 0。' }
    $positionFeedback = [pscustomobject]@{
        MotorId = 0; Status = 0; TorqueNm = 0.1; SpeedRadPerSec = 0.2; PositionRad = 1.75
        TemperatureC = 25; ErrorCode = 0; ForceRaw = 0; Raw = [byte[]]@(0xFD, 0xEE)
    }
    Update-Feedback $positionFeedback
    if ($script:PendingPositionStart) { throw '匹配位置反馈到达后没有清除等待状态。' }
    if (-not $script:CycleTimer.IsEnabled) { throw '收到位置反馈后没有自动启动 FOC 周期控制。' }
    if ([math]::Abs((Read-Double $PositionBox '位置') - 1.75) -gt 0.001) { throw '位置保持没有锁定刚收到的当前位置。' }
    if ($mockPort.LastWrite[2] -ne 0x10) { throw '收到位置反馈后没有发送 FOC 闭环控制帧。' }
    if ($mockPort.LastWrite[3] -ne 0 -or $mockPort.LastWrite[4] -ne 0 -or $mockPort.LastWrite[5] -ne 0 -or $mockPort.LastWrite[6] -ne 0) { throw '位置保持启动帧的前馈转矩或速度目标不为 0。' }
    if ($mockPort.LastWrite[11] -ne 0x1A -or $mockPort.LastWrite[12] -ne 0 -or $mockPort.LastWrite[13] -ne 0 -or $mockPort.LastWrite[14] -ne 0) { throw '位置保持启动帧未使用手册推荐的 Kpos=0.02、Kspd=0。' }
    $script:CycleTimer.Stop()
    $script:SuppressCycleUncheckedLock = $true
    try { $CycleCheck.IsChecked = $false } finally { $script:SuppressCycleUncheckedLock = $false }
    $script:SerialPort = $null
    $OverspeedLimitBox.Text = ''
    $script:MaxFeedbackSpeedOutputRadPerSec = [double]::NaN
    . (Join-Path $PSScriptRoot 'Test-M8010IdWorkflow.ps1')
    . (Join-Path $PSScriptRoot 'Test-M8010MultiProgram.ps1')
    Write-Output 'M8010 UI smoke test passed: XAML, direct speed strategy, position feedback start flow, ID workflow, multi-motor programs and all three mode frames were verified.'
    exit 0
}
[void]$window.ShowDialog()
