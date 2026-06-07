param([switch]$NoElevate)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = "D:\scripts" }
$configPath = Join-Path $scriptDir "obsidian-config.json"
$backupScript = Join-Path $scriptDir "obsidian-backup.ps1"
$pullScript = Join-Path $scriptDir "obsidian-pull.ps1"
$backupTaskName = "ObsidianAutoBackup"
$pullTaskName = "ObsidianAutoPull"

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $id
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin) -and -not $NoElevate) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -NoElevate"
    $psi.Verb = "RunAs"
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show("需要管理员权限才能管理定时任务。`n请右键以管理员身份运行。", "权限不足", "OK", "Warning")
    }
    return
}

function Load-Config {
    if (Test-Path $configPath) {
        $c = Get-Content $configPath -Raw | ConvertFrom-Json
        return $c
    }
    return @{ vaultPath = "" }
}

function Save-Config {
    param($Config)
    $dir = Split-Path $configPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Config | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
}

function Get-TaskStatus {
    param($TaskName)
    $r = schtasks /Query /TN $TaskName /FO CSV /V 2>&1
    if ($LASTEXITCODE -eq 0) {
        $lines = $r -split "`r`n|`n" | Where-Object { $_ -match "^`"" }
        if ($lines) {
            $parts = $lines[0] -split '","' -replace '"',''
            if ($parts.Count -ge 8) { return $parts[7] }
            return "已安装"
        }
    }
    return "未安装"
}

function Install-BackupTask {
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Auto backup Obsidian to GitHub before shutdown</Description></RegistrationInfo>
  <Triggers>
    <EventTrigger><Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[EventID=1074]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
      <Delay>PT0S</Delay>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -File "$backupScript"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    $xmlPath = Join-Path $env:TEMP "obsidian-backup-task.xml"
    $xml | Out-File $xmlPath -Encoding Unicode
    $r = schtasks /Create /XML $xmlPath /TN $backupTaskName /F 2>&1
    Remove-Item $xmlPath -Force
    return $r
}

function Install-PullTask {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$pullScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogon -User "$env:USERDOMAIN\$env:USERNAME"
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Limited -LogonType InteractiveToken
    Register-ScheduledTask -TaskName $pullTaskName -Action $action -Trigger $trigger -Principal $principal -Force -ErrorAction Stop | Out-Null
}

function Uninstall-Task {
    param($TaskName)
    schtasks /Delete /TN $TaskName /F 2>&1 | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Obsidian Git 管理工具"
$form.Size = New-Object System.Drawing.Size(600, 470)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("powershell.exe")

$config = Load-Config

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Obsidian 仓库路径："
$lblPath.Location = New-Object System.Drawing.Point(15, 20)
$lblPath.Size = New-Object System.Drawing.Size(560, 20)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(15, 45)
$txtPath.Size = New-Object System.Drawing.Size(480, 23)
$txtPath.Text = $config.vaultPath

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "浏览..."
$btnBrowse.Location = New-Object System.Drawing.Point(500, 44)
$btnBrowse.Size = New-Object System.Drawing.Size(75, 25)
$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "选择 Obsidian 仓库文件夹"
    $fbd.SelectedPath = $txtPath.Text
    if ($fbd.ShowDialog() -eq "OK") { $txtPath.Text = $fbd.SelectedPath }
})

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "保存路径"
$btnSave.Location = New-Object System.Drawing.Point(15, 78)
$btnSave.Size = New-Object System.Drawing.Size(90, 28)
$btnSave.Add_Click({
    if (-not $txtPath.Text.Trim()) {
        [System.Windows.Forms.MessageBox]::Show("请输入仓库路径", "提示", "OK", "Warning")
        return
    }
    if (-not (Test-Path $txtPath.Text.Trim())) {
        $r = [System.Windows.Forms.MessageBox]::Show("路径不存在，是否仍然保存？", "确认", "YesNo", "Question")
        if ($r -eq "No") { return }
    }
    Save-Config @{ vaultPath = $txtPath.Text.Trim() }
    $lblStatus.Text = "✓ 配置已保存"
    $statusTimer.Start()
})

$groupTasks = New-Object System.Windows.Forms.GroupBox
$groupTasks.Text = "定时任务管理"
$groupTasks.Location = New-Object System.Drawing.Point(15, 120)
$groupTasks.Size = New-Object System.Drawing.Size(560, 240)

$lblBackupStat = New-Object System.Windows.Forms.Label
$lblBackupStat.Text = "关机自动推送 (git push)："
$lblBackupStat.Location = New-Object System.Drawing.Point(15, 30)
$lblBackupStat.Size = New-Object System.Drawing.Size(210, 22)

$lblBackupVal = New-Object System.Windows.Forms.Label
$lblBackupVal.Text = "检查中..."
$lblBackupVal.Location = New-Object System.Drawing.Point(230, 30)
$lblBackupVal.Size = New-Object System.Drawing.Size(130, 22)
$lblBackupVal.ForeColor = "Gray"

$btnBackupInstall = New-Object System.Windows.Forms.Button
$btnBackupInstall.Text = "安装"
$btnBackupInstall.Location = New-Object System.Drawing.Point(370, 28)
$btnBackupInstall.Size = New-Object System.Drawing.Size(75, 28)
$btnBackupInstall.Add_Click({
    if (-not (Test-Path $backupScript)) {
        [System.Windows.Forms.MessageBox]::Show("备份脚本不存在：$backupScript", "错误", "OK", "Error")
        return
    }
    try {
        Install-BackupTask
        $lblBackupVal.Text = Get-TaskStatus $backupTaskName
        $lblBackupVal.ForeColor = "Green"
        $lblStatus.Text = "✓ 关机备份任务已安装"
        $statusTimer.Start()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("安装失败：$_", "错误", "OK", "Error")
    }
})

$btnBackupUninstall = New-Object System.Windows.Forms.Button
$btnBackupUninstall.Text = "卸载"
$btnBackupUninstall.Location = New-Object System.Drawing.Point(455, 28)
$btnBackupUninstall.Size = New-Object System.Drawing.Size(75, 28)
$btnBackupUninstall.Add_Click({
    try {
        Uninstall-Task $backupTaskName
        $lblBackupVal.Text = Get-TaskStatus $backupTaskName
        $lblBackupVal.ForeColor = "Gray"
        $lblStatus.Text = "✓ 关机备份任务已卸载"
        $statusTimer.Start()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("卸载失败：$_", "错误", "OK", "Error")
    }
})

$lblPullStat = New-Object System.Windows.Forms.Label
$lblPullStat.Text = "开机自动拉取 (git pull)："
$lblPullStat.Location = New-Object System.Drawing.Point(15, 75)
$lblPullStat.Size = New-Object System.Drawing.Size(210, 22)

$lblPullVal = New-Object System.Windows.Forms.Label
$lblPullVal.Text = "检查中..."
$lblPullVal.Location = New-Object System.Drawing.Point(230, 75)
$lblPullVal.Size = New-Object System.Drawing.Size(130, 22)
$lblPullVal.ForeColor = "Gray"

$btnPullInstall = New-Object System.Windows.Forms.Button
$btnPullInstall.Text = "安装"
$btnPullInstall.Location = New-Object System.Drawing.Point(370, 73)
$btnPullInstall.Size = New-Object System.Drawing.Size(75, 28)
$btnPullInstall.Add_Click({
    if (-not (Test-Path $pullScript)) {
        [System.Windows.Forms.MessageBox]::Show("拉取脚本不存在：$pullScript", "错误", "OK", "Error")
        return
    }
    try {
        Install-PullTask
        $lblPullVal.Text = Get-TaskStatus $pullTaskName
        $lblPullVal.ForeColor = "Green"
        $lblStatus.Text = "✓ 开机拉取任务已安装"
        $statusTimer.Start()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("安装失败：$_", "错误", "OK", "Error")
    }
})

$btnPullUninstall = New-Object System.Windows.Forms.Button
$btnPullUninstall.Text = "卸载"
$btnPullUninstall.Location = New-Object System.Drawing.Point(455, 73)
$btnPullUninstall.Size = New-Object System.Drawing.Size(75, 28)
$btnPullUninstall.Add_Click({
    try {
        Uninstall-Task $pullTaskName
        $lblPullVal.Text = Get-TaskStatus $pullTaskName
        $lblPullVal.ForeColor = "Gray"
        $lblStatus.Text = "✓ 开机拉取任务已卸载"
        $statusTimer.Start()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("卸载失败：$_", "错误", "OK", "Error")
    }
})

$lblTip = New-Object System.Windows.Forms.Label
$lblTip.Text = "提示：安装开关机任务需要管理员权限，请以管理员身份运行此工具"
$lblTip.Location = New-Object System.Drawing.Point(15, 160)
$lblTip.Size = New-Object System.Drawing.Size(530, 30)
$lblTip.ForeColor = "Gray"
$lblTip.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9, [System.Drawing.FontStyle]::Italic)

$groupTasks.Controls.AddRange(@($lblBackupStat, $lblBackupVal, $btnBackupInstall, $btnBackupUninstall,
                                   $lblPullStat, $lblPullVal, $btnPullInstall, $btnPullUninstall, $lblTip))

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "就绪"
$lblStatus.Location = New-Object System.Drawing.Point(15, 390)
$lblStatus.Size = New-Object System.Drawing.Size(400, 22)
$lblStatus.ForeColor = "Gray"

$statusTimer = New-Object System.Windows.Forms.Timer
$statusTimer.Interval = 4000
$statusTimer.Add_Tick({ $lblStatus.Text = "就绪"; $statusTimer.Stop() })

$form.Controls.AddRange(@($lblPath, $txtPath, $btnBrowse, $btnSave, $groupTasks, $lblStatus))

$form.Add_Shown({
    $lblBackupVal.Text = Get-TaskStatus $backupTaskName
    $lblPullVal.Text = Get-TaskStatus $pullTaskName
    if ($lblBackupVal.Text -ne "未安装") { $lblBackupVal.ForeColor = "Green" }
    if ($lblPullVal.Text -ne "未安装") { $lblPullVal.ForeColor = "Green" }
})

[void]$form.ShowDialog()
