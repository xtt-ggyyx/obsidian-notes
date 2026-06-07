param(
    [switch]$NoElevate,
    [ValidateSet('InstallBackupTask','UninstallBackupTask')]
    [string]$AdminAction
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "D:\scripts" }
$configPath = Join-Path $scriptRoot "obsidian-config.json"
$backupScriptPath = Join-Path $scriptRoot "obsidian-backup.ps1"
$pullScriptPath = Join-Path $scriptRoot "obsidian-pull.ps1"
$backupTaskName = "ObsidianAutoBackup"
$pullTaskName = "ObsidianAutoPull"
$periodicTaskName = "ObsidianAutoSync"
$startupLinkPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\ObsidianGitManager.lnk"

# Embedded scripts
$backupScriptContent = @"
`$c=Get-Content (Join-Path `$PSScriptRoot "obsidian-config.json") -Raw|ConvertFrom-Json
if(-not (Test-Path `$c.vaultPath)){exit 1}
`$l=Join-Path `$PSScriptRoot "obsidian-backup.log"
function g{param(`$m);"`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - `$m"|Out-File `$l -Append -Encoding UTF8}
try{`$env:GIT_TERMINAL_PROMPT='0';`$env:GCM_INTERACTIVE='Never';Set-Location `$c.vaultPath;g "Start"
git add -A 2>&1|Out-Null;if(`$LASTEXITCODE -ne 0){throw "git add failed"}
`$s=git status --porcelain 2>&1
if(`$s){`$t=Get-Date -Format 'yyyy-MM-dd HH:mm:ss';git commit -m "auto backup `$t" 2>&1|Out-Null;if(`$LASTEXITCODE -ne 0){throw "git commit failed"};g "Commit";git push 2>&1|Out-File `$l -Append -Encoding UTF8;if(`$LASTEXITCODE -ne 0){throw "git push failed"};g "Pushed"}else{g "No changes"}
if(`$c.cleanTemp){Remove-Item "`$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue;g "User temp cleaned"}}catch{g "ERROR: `$_";exit 1}
"@

$pullScriptContent = @"
`$c=Get-Content (Join-Path `$PSScriptRoot "obsidian-config.json") -Raw|ConvertFrom-Json
if(-not (Test-Path `$c.vaultPath)){exit 1}
`$l=Join-Path `$PSScriptRoot "obsidian-pull.log"
function g{param(`$m);"`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - `$m"|Out-File `$l -Append -Encoding UTF8}
try{`$env:GIT_TERMINAL_PROMPT='0';`$env:GCM_INTERACTIVE='Never';Set-Location `$c.vaultPath;`$r=git pull 2>&1;if(`$LASTEXITCODE -ne 0){throw (`$r -join ' ')};g "Pulled: `$r"
if(`$c.showNotify){try{`$n=New-Object System.Windows.Forms.NotifyIcon;`$n.Icon=[System.Drawing.SystemIcons]::Information;`$n.BalloonTipTitle='Obsidian Sync';`$n.BalloonTipText="Sync done`n`$r";`$n.Visible=`$true;`$n.ShowBalloonTip(5000);Start-Sleep 2;`$n.Dispose()}catch{}}}catch{g "ERROR: `$_";exit 1}
"@

$periodicScriptContent = @"
`$c=Get-Content (Join-Path `$PSScriptRoot "obsidian-config.json") -Raw|ConvertFrom-Json
if(-not (Test-Path `$c.vaultPath)){exit 1}
`$l=Join-Path `$PSScriptRoot "obsidian-sync.log"
function g{param(`$m);"`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - `$m"|Out-File `$l -Append -Encoding UTF8}
try{`$env:GIT_TERMINAL_PROMPT='0';`$env:GCM_INTERACTIVE='Never';Set-Location `$c.vaultPath;g "Start";git add -A 2>&1|Out-Null;if(`$LASTEXITCODE -ne 0){throw "git add failed"};`$s=git status --porcelain 2>&1;if(`$s){git commit -m "auto sync `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1|Out-Null;if(`$LASTEXITCODE -ne 0){throw "git commit failed"};git push 2>&1|Out-File `$l -Append -Encoding UTF8;if(`$LASTEXITCODE -ne 0){throw "git push failed"};g "Pushed"}else{g "No local"};`$r=git pull 2>&1;if(`$LASTEXITCODE -ne 0){throw (`$r -join ' ')};g "Pull done"}catch{g "ERROR: `$_";exit 1}
"@

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$isAdmin = Test-Admin
if (-not $isAdmin -and -not $NoElevate -and -not $AdminAction) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = 'RunAs'
    try { [System.Diagnostics.Process]::Start($psi) | Out-Null }
    catch { [System.Windows.Forms.MessageBox]::Show('需要管理员权限运行。', '提示', 'OK', 'Warning') | Out-Null }
    return
}

function Load-Config {
    if (Test-Path $configPath) {
        $c = Get-Content $configPath -Raw | ConvertFrom-Json
        return [PSCustomObject]@{
            vaultPath = $c.vaultPath
            cleanTemp = if ($null -eq $c.cleanTemp) { $false } else { $c.cleanTemp }
            showNotify = if ($null -eq $c.showNotify) { $false } else { $c.showNotify }
            periodicHours = if ($null -eq $c.periodicHours) { 0 } else { $c.periodicHours }
            gmailPass = if ($null -eq $c.gmailPass) { '' } else { $c.gmailPass }
            sitePass = if ($null -eq $c.sitePass) { '' } else { $c.sitePass }
        }
    }
    return [PSCustomObject]@{ vaultPath = ''; cleanTemp = $false; showNotify = $false; periodicHours = 0; gmailPass = ''; sitePass = '' }
}
function Save-Config {
    param($c)
    $d = Split-Path $configPath -Parent
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    $c | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
}
function Get-TaskStatus {
    param($n)
    $r = schtasks /Query /TN $n 2>&1
    if ($LASTEXITCODE -eq 0) { return 'Installed' }
    if (($r -join "`n") -match 'Access is denied|拒绝访问') { return 'AccessDenied' }
    return 'Missing'
}
function Set-TaskStatusLabel {
    param($Label, [string]$Status)
    if ($Status -eq 'Installed') {
        $Label.Text = '已安装'; $Label.ForeColor = $cs
    } elseif ($Status -eq 'AccessDenied') {
        $Label.Text = '需管理员'; $Label.ForeColor = $cp
    } else {
        $Label.Text = '未安装'; $Label.ForeColor = $cl
    }
}
function Write-Script {
    param($p, $c)
    $d = Split-Path $p -Parent
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    $c | Set-Content $p -Encoding UTF8
}

function Install-BackupTaskElevated {
    Write-Script $backupScriptPath $backupScriptContent
    $x = Join-Path $env:TEMP "obsidian-backup-task.xml"
    $ps = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"$backupScriptPath`""
@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo><Description>Obsidian auto backup on shutdown</Description></RegistrationInfo>
<Triggers><EventTrigger><Enabled>true</Enabled>
<Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[EventID=1074]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
<Delay>PT0S</Delay></EventTrigger>
</Triggers>
<Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
<Settings>
<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
<AllowHardTerminate>true</AllowHardTerminate>
<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
<Enabled>true</Enabled><RunOnlyIfIdle>false</RunOnlyIfIdle>
<UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
<WakeToRun>false</WakeToRun>
<ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
</Settings>
<Actions Context="Author"><Exec><Command>$ps</Command><Arguments>$a</Arguments></Exec></Actions>
</Task>
"@ | Out-File $x -Encoding Unicode
    $r = schtasks /Create /XML $x /TN $backupTaskName /F 2>&1
    Remove-Item $x -Force
    if ($LASTEXITCODE -ne 0) { throw $r }
}

if ($AdminAction) {
    try {
        if ($AdminAction -eq 'InstallBackupTask') { Install-BackupTaskElevated }
        elseif ($AdminAction -eq 'UninstallBackupTask') { schtasks /Delete /TN $backupTaskName /F 2>&1 | Out-Null }
        exit 0
    } catch {
        [System.Windows.Forms.MessageBox]::Show("管理员操作失败：$_", '错误', 'OK', 'Error') | Out-Null
        exit 1
    }
}

function Install-BackupTask {
    if ($isAdmin) {
        Install-BackupTaskElevated
        return
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -AdminAction InstallBackupTask"
    $psi.Verb = 'RunAs'
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) { throw '需要管理员授权才能安装关机自动上传任务' }
}

function Install-PullTask {
    Write-Script $pullScriptPath $pullScriptContent
    $ps = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"$pullScriptPath`""
    $act = New-ScheduledTaskAction -Execute $ps -Argument $a
    $trg = New-ScheduledTaskTrigger -AtLogon
    $pri = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Limited
    Register-ScheduledTask -TaskName $pullTaskName -Action $act -Trigger $trg -Principal $pri -Force -ErrorAction Stop | Out-Null
}

function Install-PeriodicTask {
    param($h)
    $s = Join-Path $scriptRoot "obsidian-periodic.ps1"
    Write-Script $s $periodicScriptContent
    $xmlPath = Join-Path $env:TEMP "obsidian-periodic-task.xml"
    $ps = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"$s`""
@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo><Description>Obsidian periodic sync</Description></RegistrationInfo>
<Triggers>
<CalendarTrigger>
<StartBoundary>2024-01-01T00:00:00</StartBoundary>
<Repetition><Interval>PT$( $h)H</Interval><Duration>P1D</Duration><StopAtDurationEnd>false</StopAtDurationEnd></Repetition>
<Enabled>true</Enabled>
<ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay>
</CalendarTrigger>
</Triggers>
<Principals><Principal id="Author"><UserId>$env:USERDOMAIN\$env:USERNAME</UserId><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
<Settings>
<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
<AllowHardTerminate>true</AllowHardTerminate>
<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
<Enabled>true</Enabled>
<RunOnlyIfIdle>false</RunOnlyIfIdle>
<UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
<WakeToRun>false</WakeToRun>
<ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
</Settings>
<Actions Context="Author"><Exec><Command>$ps</Command><Arguments>$a</Arguments></Exec></Actions>
</Task>
"@ | Out-File $xmlPath -Encoding Unicode
    $r = schtasks /Create /XML $xmlPath /TN $periodicTaskName /F 2>&1
    Remove-Item $xmlPath -Force
    if ($LASTEXITCODE -ne 0) { throw $r }
}

function Uninstall-Task {
    param($n)
    if ($n -eq $backupTaskName -and -not $isAdmin) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -AdminAction UninstallBackupTask"
        $psi.Verb = 'RunAs'
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        if ($proc.ExitCode -ne 0) { throw '需要管理员授权才能卸载关机自动上传任务' }
        return
    }
    schtasks /Delete /TN $n /F 2>&1 | Out-Null
}

function Refresh-GitStatus {
    $vp = $txtPath.Text.Trim()
    if (-not (Test-Path $vp)) { $lblGitStatus.Text = 'Git 状态：路径无效'; return }
    try {
        $loc = (Get-Item $vp).FullName
        $branch = git -C $loc rev-parse --abbrev-ref HEAD 2>$null
        if (-not $?) { $lblGitStatus.Text = 'Git 状态：不是 git 仓库'; return }
        $behind = git -C $loc rev-list --count origin/$branch..HEAD 2>$null
        $ahead = git -C $loc rev-list --count HEAD..origin/$branch 2>$null
        $last = git -C $loc log -1 --format="%ci" 2>$null
        if (-not $last) { $last = 'N/A' } else { $last = $last.Substring(0,16) }
        $s = "Git 状态：[$branch]"
        if ($behind -gt 0) { $s += " 领先 $behind " }
        if ($ahead -gt 0) { $s += " 落后 $ahead " }
        if ($behind -eq 0 -and $ahead -eq 0) { $s += ' 已同步' }
        $s += " | $last"
        $lblGitStatus.Text = $s
    } catch { $lblGitStatus.Text = 'Git 状态：读取失败' }
}

function Refresh-Log {
    param([string]$n)
    if ([string]::IsNullOrWhiteSpace($n)) { $txtLog.Text = '暂无日志'; return }
    $f = Join-Path $scriptRoot $n
    if (Test-Path $f) { $txtLog.Text = (Get-Content $f -Tail 4) -join "`r`n" }
    else { $txtLog.Text = '暂无日志' }
}

function Start-ScriptTest {
    param(
        [string]$ScriptPath,
        [string]$ScriptContent,
        [string]$LogName,
        [string]$Title
    )
    if (-not (Test-Path $configPath)) { [System.Windows.Forms.MessageBox]::Show('请先保存路径。', '提示', 'OK', 'Warning'); return }
    Write-Script $ScriptPath $ScriptContent
    $lblStatus.Text = "$Title 正在后台执行..."; $lblStatus.ForeColor = $cp
    Refresh-Log $LogName

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Tag = [PSCustomObject]@{
        Process = $proc
        StartedAt = Get-Date
        LogName = $LogName
        Title = $Title
    }
    $timer.Add_Tick({
        $state = $this.Tag
        Refresh-Log $state.LogName
        if (-not $state.Process.HasExited -and ((Get-Date) - $state.StartedAt).TotalSeconds -gt 90) {
            try { $state.Process.Kill() } catch {}
            $this.Stop()
            $this.Dispose()
            $lblStatus.Text = "$($state.Title) 超时，已停止"
            $lblStatus.ForeColor = $cd
            $statusTimer.Start()
            return
        }
        if ($state.Process.HasExited) {
            $this.Stop()
            $this.Dispose()
            $lblStatus.Text = "$($state.Title) 完成，退出码 $($state.Process.ExitCode)"
            $lblStatus.ForeColor = if ($state.Process.ExitCode -eq 0) { $cs } else { $cd }
            $statusTimer.Start()
        }
    })
    $timer.Start()
}

function Test-Backup {
    Start-ScriptTest $backupScriptPath $backupScriptContent 'obsidian-backup.log' '上传测试'
}
function Test-Pull {
    Start-ScriptTest $pullScriptPath $pullScriptContent 'obsidian-pull.log' '拉取测试'
}

# ===== C# IMAP 读取器 =====
Add-Type @'
using System;
using System.Globalization;
using System.IO;
using System.Net.Security;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;

public class ImapReader
{
    private TcpClient tcp;
    private SslStream ssl;
    private StreamReader reader;
    private int tag;

    private bool ConnectWithTimeout(string host, int port, int ms)
    {
        tcp = new TcpClient();
        var ar = tcp.BeginConnect(host, port, null, null);
        if (!ar.AsyncWaitHandle.WaitOne(ms, false)) { tcp.Close(); tcp = null; return false; }
        try { tcp.EndConnect(ar); } catch { tcp.Close(); tcp = null; return false; }
        tcp.ReceiveTimeout = ms;
        tcp.SendTimeout = ms;
        return true;
    }

    private bool Send(string cmd)
    {
        try { tag++; byte[] d = Encoding.UTF8.GetBytes("a00" + tag + " " + cmd + "\r\n"); ssl.Write(d, 0, d.Length); ssl.Flush(); return true; }
        catch { return false; }
    }

    private string Read()
    {
        try
        {
            StringBuilder sb = new StringBuilder(); string l;
            while ((l = reader.ReadLine()) != null) { sb.AppendLine(l); if (l.StartsWith("a00" + tag + " ")) break; }
            return sb.ToString();
        }
        catch { return ""; }
    }

    private string Quote(string value)
    {
        if (value == null) value = "";
        return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
    }

    private string SearchCurrentMailbox(string target)
    {
        string since = DateTime.UtcNow.AddDays(-1).ToString("dd-MMM-yyyy", CultureInfo.InvariantCulture);
        if (!Send("SEARCH SINCE " + since)) return "";
        string resp = Read();
        int idx = resp.IndexOf("* SEARCH");
        if (idx < 0) return "";

        string after = resp.Substring(idx + 8).Trim();
        int nl = after.IndexOf('\n');
        if (nl > 0) after = after.Substring(0, nl).Trim();
        string[] nums = after.Split(' ');

        string loweredTarget = (target ?? "").ToLowerInvariant();
        Match suffixMatch = Regex.Match(loweredTarget, "\\+[^@\\s>]+");
        string suffix = suffixMatch.Success ? suffixMatch.Value : "";

        int checkedCount = 0;
        for (int i = nums.Length - 1; i >= 0 && checkedCount < 40; i--)
        {
            string n = nums[i].Trim();
            if (n.Length == 0) continue;
            checkedCount++;

            if (!Send("FETCH " + n + " (BODY.PEEK[HEADER])")) break;
            string hdr = Read();
            if (hdr == "") break;
            string hdrLower = hdr.ToLowerInvariant();
            bool fromToken = hdrLower.Contains("tokenx24");
            bool targetMatch = loweredTarget.Length == 0 || hdrLower.Contains(loweredTarget) || (suffix.Length > 0 && hdrLower.Contains(suffix));
            if (!fromToken && !targetMatch) continue;

            if (!Send("FETCH " + n + " (BODY.PEEK[TEXT])")) break;
            string body = Read();
            string combined = (hdr + "\n" + body).ToLowerInvariant();
            targetMatch = loweredTarget.Length == 0 || combined.Contains(loweredTarget) || (suffix.Length > 0 && combined.Contains(suffix));
            if (!targetMatch) continue;

            Match m = Regex.Match(body, "\\b([0-9]{6})\\b");
            if (m.Success) return m.Groups[1].Value;
        }
        return "";
    }

    public string GetCode(string user, string pass, string target)
    {
        try
        {
            if (!ConnectWithTimeout("imap.gmail.com", 993, 8000)) return "";
            ssl = new SslStream(tcp.GetStream(), false);
            var sslAr = ssl.BeginAuthenticateAsClient("imap.gmail.com", null, null);
            if (!sslAr.AsyncWaitHandle.WaitOne(8000, false)) { return ""; }
            try { ssl.EndAuthenticateAsClient(sslAr); } catch { return ""; }
            reader = new StreamReader(ssl, Encoding.UTF8);
            reader.ReadLine();
            tag = 0;

            string cleanPass = Regex.Replace(pass ?? "", "\\s+", "");
            if (!Send("LOGIN " + Quote(user) + " " + Quote(cleanPass))) return "";
            string loginResp = Read();
            if (loginResp.IndexOf(" OK ", StringComparison.OrdinalIgnoreCase) < 0) return "";

            if (Send("SELECT INBOX"))
            {
                string selectResp = Read();
                if (selectResp.IndexOf(" OK ", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    string code = SearchCurrentMailbox(target);
                    if (code.Length == 6) return code;
                }
            }

            if (Send("SELECT \"[Gmail]/All Mail\""))
            {
                string selectResp = Read();
                if (selectResp.IndexOf(" OK ", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    string code = SearchCurrentMailbox(target);
                    if (code.Length == 6) return code;
                }
            }
            return "";
        }
        catch { return ""; }
        finally { try { if (ssl != null) ssl.Close(); } catch {} try { if (tcp != null) tcp.Close(); } catch {} }
    }
}
'@

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::Expect100Continue = $false

# ===== TokenX24 注册函数 =====
$txCounterFile = Join-Path $scriptRoot "tokenx24-counter.txt"
$txLogFile = Join-Path $scriptRoot "tokenx24-accounts.txt"

function Get-TxCounter {
    if (Test-Path $txCounterFile) {
        $v = [int](Get-Content $txCounterFile -Raw).Trim()
        if ($v -lt 20) { $v = 20; [System.IO.File]::WriteAllText($txCounterFile, "20") }
        return $v
    }
    return 20
}
function Set-TxCounter {
    param($n)
    [System.IO.File]::WriteAllText($txCounterFile, "$n")
}
function Set-TxStartNumber {
    param([int]$n)
    if ($n -lt 1) { $n = 1 }
    Set-TxCounter ($n - 1)
}

function New-TokenX24Account {
    param($gmailUser, $gmailPass, $sitePass, $statusLabel, $form)
    $base = "https://www.tokenx24.com/api/v1"

    function SendReq($url, $json) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $lastError = $null

        for ($try = 1; $try -le 3; $try++) {
            $req = [System.Net.WebRequest]::CreateHttp($url)
            $req.Method = 'POST'
            $req.ContentType = 'application/json'
            $req.Accept = 'application/json, text/plain, */*'
            $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            $req.KeepAlive = $false
            $req.Timeout = 15000
            $req.ReadWriteTimeout = 15000
            $req.ContentLength = $bytes.Length

            $stream = $null
            $resp = $null
            try {
                $stream = $req.GetRequestStream()
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Close()
                $stream = $null

                $resp = $req.GetResponse()
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $body = $reader.ReadToEnd()
                $reader.Close()
                $resp.Close()
                return @{ Success = $true; Body = $body }
            } catch {
                $ex = $_.Exception
                $wex = $ex
                while ($wex.InnerException) { $wex = $wex.InnerException }
                $lastError = $wex.Message

                if ($ex.Response) {
                    $r = New-Object System.IO.StreamReader($ex.Response.GetResponseStream())
                    $errBody = $r.ReadToEnd()
                    $r.Close()
                    $statusCode = [int]$ex.Response.StatusCode
                    return @{ Success = $false; StatusCode = $statusCode; Body = $errBody }
                }

                if ($try -lt 3) { Start-Sleep -Milliseconds (700 * $try) }
            } finally {
                if ($stream) { try { $stream.Close() } catch {} }
                if ($resp) { try { $resp.Close() } catch {} }
            }
        }

        throw $lastError
    }

    $emailBase = $gmailUser -replace '@.*$', ''
    $maxAttempts = 50
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        $attempt++
        $counter = Get-TxCounter
        $counter++
        $email = "${emailBase}+${counter}@gmail.com"
        if ($statusLabel) { $statusLabel.Text = "尝试 +$counter ..."; $statusLabel.ForeColor = "#1E6F9F"; $form.Refresh() }

        $r1 = SendReq "$base/auth/send-verify-code" "{`"email`":`"$email`"}"
        if (-not $r1.Success) {
            $errInfo = if ($r1.Body) { $r1.Body.Substring(0, [Math]::Min(80, $r1.Body.Length)) } else { "HTTP $($r1.StatusCode)" }
            if ($statusLabel) { $statusLabel.Text = "跳过 +$counter ($errInfo)"; $form.Refresh() }
            Start-Sleep 1
            Set-TxCounter $counter
            continue
        }

        if ($statusLabel) { $statusLabel.Text = "验证码已发送到 +$counter，等待中..."; $form.Refresh(); [System.Windows.Forms.Application]::DoEvents() }
        Start-Sleep 3
        $code = $null
        for ($i = 0; $i -lt 15; $i++) {
            if ($statusLabel) { $statusLabel.Text = "读取验证码 +$counter ($($i+1)/15)..."; $form.Refresh(); [System.Windows.Forms.Application]::DoEvents() }
            try { $r = New-Object ImapReader; $code = $r.GetCode($gmailUser, $gmailPass, $email) } catch { if ($statusLabel) { $statusLabel.Text = "IMAP连接失败，重试..."; $form.Refresh(); [System.Windows.Forms.Application]::DoEvents() } }
            if ($code -and $code.Length -eq 6) { break }
            if ($statusLabel) { $statusLabel.Text = "等待验证码 $($i+1)/15..."; $form.Refresh(); [System.Windows.Forms.Application]::DoEvents() }
            Start-Sleep 4
        }
        if (-not $code) {
            if ($statusLabel) { $statusLabel.Text = "IMAP 超时，请手动输入验证码 → 浏览器查看 Gmail"; $form.Refresh(); [System.Windows.Forms.Application]::DoEvents() }
            $manualCode = [Microsoft.VisualBasic.Interaction]::InputBox("IMAP 自动读取失败`n请在浏览器中打开 Gmail 查看 TokenX24 的验证码`n然后输入下方的 6 位数字：", "手动输入验证码 (+$counter)", "")
            if ($manualCode -match '^(\d{6})$') { $code = $matches[1] }
            if (-not $code) { throw "验证码获取失败 (已尝试至 +$counter)" }
        }

        if ($statusLabel) { $statusLabel.Text = "验证码: $code，正在注册..."; $form.Refresh() }
        $r2 = SendReq "$base/auth/register" "{`"email`":`"$email`",`"password`":`"$sitePass`",`"verify_code`":`"$code`"}"
        if (-not $r2.Success) {
            if ($r2.StatusCode -eq 409) {
                Set-TxCounter $counter
                continue
            }
            throw "注册失败: $($r2.Body)"
        }

        Set-TxCounter $counter
        "$email | $sitePass | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $txLogFile -Append -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("注册成功`n邮箱: $email`n密码: $sitePass", 'TokenX24', 'OK', 'Information')
        return @{ Email = $email; Password = $sitePass }
    }
}

function Login-TokenX24 {
    param($email, $password)
    $base = "https://www.tokenx24.com/api/v1"
    $req = [System.Net.WebRequest]::CreateHttp("$base/auth/login")
    $req.Method = 'POST'; $req.ContentType = 'application/json'; $req.UserAgent = 'Mozilla/5.0'
    $req.KeepAlive = $false
    $req.Timeout = 15000
    $req.ReadWriteTimeout = 15000
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("{`"email`":`"$email`",`"password`":`"$password`"}")
    $req.ContentLength = $bytes.Length
    $stream = $null
    $resp = $null
    try {
        $stream = $req.GetRequestStream(); $stream.Write($bytes, 0, $bytes.Length); $stream.Close(); $stream = $null
        $resp = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $body = $reader.ReadToEnd()
        $reader.Close()
        return $body
    } finally {
        if ($stream) { try { $stream.Close() } catch {} }
        if ($resp) { try { $resp.Close() } catch {} }
    }
}

function ConvertTo-JsLiteral {
    param($Value, [int]$Depth = 20)
    if ($null -eq $Value) { return 'null' }
    return ($Value | ConvertTo-Json -Compress -Depth $Depth)
}

function Get-LastTokenX24Account {
    if (-not (Test-Path $txLogFile)) { return $null }
    $last = Get-Content $txLogFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() } | Select-Object -Last 1
    if (-not $last) { return $null }
    $parts = $last -split '\|'
    if ($parts.Count -lt 2) { return $null }
    return [PSCustomObject]@{
        Email = $parts[0].Trim()
        Password = $parts[1].Trim()
    }
}

function Find-BrowserExecutable {
    $candidates = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:LocalAppData\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return $path }
    }
    foreach ($name in @('msedge.exe','chrome.exe')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Invoke-ChromeRuntimeEvaluate {
    param([string]$WebSocketUrl, [string]$Expression)

    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    try {
        $ws.ConnectAsync([Uri]$WebSocketUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        $payload = @{
            id = 1
            method = 'Runtime.evaluate'
            params = @{
                expression = $Expression
                awaitPromise = $true
                returnByValue = $true
            }
        } | ConvertTo-Json -Compress -Depth 8
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()

        $buffer = New-Object byte[] 65536
        $builder = New-Object System.Text.StringBuilder
        do {
            $result = $ws.ReceiveAsync([System.ArraySegment[byte]]::new($buffer), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
            if ($result.Count -gt 0) {
                [void]$builder.Append([System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count))
            }
        } while (-not $result.EndOfMessage)

        $response = $builder.ToString() | ConvertFrom-Json
        if ($response.error) { throw $response.error.message }
        if ($response.result.exceptionDetails) { throw $response.result.exceptionDetails.text }
    } finally {
        try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).GetAwaiter().GetResult() } catch {}
        try { $ws.Dispose() } catch {}
    }
}

function Open-TokenX24LoggedIn {
    param($email, $password, $statusLabel, $form)

    if (-not $email -or -not $password) {
        $last = Get-LastTokenX24Account
        if ($last) { $email = $last.Email; $password = $last.Password }
    }
    if (-not $email -or -not $password) { throw '没有可登录的账号，请先注册一个账号' }

    if ($statusLabel) { $statusLabel.Text = '正在验证账号...'; $statusLabel.ForeColor = $cp; $form.Refresh(); [System.Windows.Forms.Application]::DoEvents() }
    $authRaw = Login-TokenX24 $email $password | ConvertFrom-Json
    $auth = if ($authRaw.data) { $authRaw.data } else { $authRaw }
    if ($auth.requires_2fa) { throw '该账号需要二次验证，不能自动直登' }
    if (-not $auth.access_token) { throw '登录接口没有返回 access_token' }

    $browser = Find-BrowserExecutable
    if (-not $browser) { throw '未找到 Edge 或 Chrome' }

    $port = Get-Random -Minimum 19000 -Maximum 26000
    $profile = Join-Path $env:TEMP ("tokenx24-login-profile-$port")
    New-Item -ItemType Directory -Path $profile -Force | Out-Null

    if ($statusLabel) { $statusLabel.Text = '正在打开已登录窗口...'; $form.Refresh(); [System.Windows.Forms.Application]::DoEvents() }
    $args = @(
        "--remote-debugging-port=$port",
        "--user-data-dir=$profile",
        '--no-first-run',
        '--new-window',
        'https://www.tokenx24.com/login'
    )
    Start-Process -FilePath $browser -ArgumentList $args | Out-Null

    $page = $null
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250
        try {
            $pages = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json" -TimeoutSec 2
            $page = $pages | Where-Object { $_.url -like 'https://www.tokenx24.com/*' } | Select-Object -First 1
            if ($page -and $page.webSocketDebuggerUrl) { break }
        } catch {}
    }
    if (-not $page) { throw '浏览器调试端口未就绪，无法写入登录态' }

    $accessJs = ConvertTo-JsLiteral $auth.access_token
    $refreshJs = ConvertTo-JsLiteral $auth.refresh_token
    $userJs = ConvertTo-JsLiteral $auth.user
    $expires = if ($auth.expires_in) { [int]$auth.expires_in } else { 86400 }
    $expr = @"
localStorage.setItem('auth_token', $accessJs);
if ($refreshJs) localStorage.setItem('refresh_token', $refreshJs);
localStorage.setItem('token_expires_at', String(Date.now() + $expires * 1000));
if ($userJs) localStorage.setItem('auth_user', JSON.stringify($userJs));
location.href = '/';
'ok';
"@
    Invoke-ChromeRuntimeEvaluate $page.webSocketDebuggerUrl $expr
    if ($statusLabel) { $statusLabel.Text = "已登录: $email"; $statusLabel.ForeColor = $cs }
}

function Save-CurrentUiConfig {
    param([string]$VaultPath)
    Save-Config @{
        vaultPath = $VaultPath
        cleanTemp = $chkClean.Checked
        showNotify = $chkNotify.Checked
        periodicHours = if ($chkPeriodic.Checked) { [int]$cmbPeriodic.SelectedItem } else { 0 }
        gmailPass = $txtTxPass.Text
        sitePass = $txtTxSPass.Text
    }
}

# ===== Colors =====
$cp = "#2457A6"; $cs = "#16803C"; $cd = "#B42318"; $ct = "#20242A"; $cl = "#697386"
$bg = "#F6F7F9"; $card = "#FFFFFF"; $line = "#D9DEE7"; $soft = "#EEF4FF"; $warn = "#FFF7E6"

function Set-FlatButton {
    param($Button, [string]$Back = '#FFFFFF', [string]$Fore = $ct, [string]$Border = $line)
    $Button.FlatStyle = 'Flat'
    $Button.BackColor = $Back
    $Button.ForeColor = $Fore
    $Button.FlatAppearance.BorderColor = $Border
    $Button.FlatAppearance.MouseOverBackColor = '#EAF1FF'
}

# ===== Config =====
$config = Load-Config

# ===== Form =====
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Obsidian Git 管理工具'
$form.Size = New-Object System.Drawing.Size(900, 610)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $bg
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$form.AutoScroll = $false

# ===== Header =====
$hdr = New-Object System.Windows.Forms.Panel
$hdr.BackColor = $cp; $hdr.Size = New-Object System.Drawing.Size(900, 48)
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = 'Obsidian Git 同步管理'; $lblTitle.ForeColor = 'White'
$lblTitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(22, 10); $lblTitle.Size = New-Object System.Drawing.Size(310, 28)
$lblVer = New-Object System.Windows.Forms.Label
$lblVer.Text = 'v2.1'; $lblVer.ForeColor = "#D7E7FF"
$lblVer.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
$lblVer.Location = New-Object System.Drawing.Point(238, 16); $lblVer.Size = New-Object System.Drawing.Size(45, 18)
$btnExp = New-Object System.Windows.Forms.Button
$btnFolder = New-Object System.Windows.Forms.Button
$btnFolder.Text = '目录'; Set-FlatButton $btnFolder 'Transparent' 'White' '#5F86CA'
$btnFolder.FlatAppearance.MouseOverBackColor = "#1A5A80"
$btnFolder.Location = New-Object System.Drawing.Point(708, 11); $btnFolder.Size = New-Object System.Drawing.Size(55, 27)
$btnFolder.Add_Click({ Start-Process $scriptRoot })

$btnExp = New-Object System.Windows.Forms.Button
$btnExp.Text = '导出'; Set-FlatButton $btnExp 'Transparent' 'White' '#5F86CA'
$btnExp.FlatAppearance.MouseOverBackColor = "#1A5A80"
$btnExp.Location = New-Object System.Drawing.Point(768, 11); $btnExp.Size = New-Object System.Drawing.Size(55, 27)
$btnExp.Add_Click({ $s = New-Object System.Windows.Forms.SaveFileDialog; $s.Filter = 'JSON|*.json'; $s.FileName = 'obsidian-config.json'; if ($s.ShowDialog() -eq 'OK') { Copy-Item $configPath $s.FileName -Force; $lblStatus.Text = '✓ 已导出'; $statusTimer.Start() } })
$btnImp = New-Object System.Windows.Forms.Button
$btnImp.Text = '导入'; Set-FlatButton $btnImp 'Transparent' 'White' '#5F86CA'
$btnImp.FlatAppearance.MouseOverBackColor = "#1A5A80"
$btnImp.Location = New-Object System.Drawing.Point(828, 11); $btnImp.Size = New-Object System.Drawing.Size(55, 27)
$btnImp.Add_Click({ $o = New-Object System.Windows.Forms.OpenFileDialog; $o.Filter = 'JSON|*.json'; if ($o.ShowDialog() -eq 'OK') { Copy-Item $o.FileName $configPath -Force; [System.Windows.Forms.MessageBox]::Show('已导入，重启工具生效', '完成', 'OK', 'Information') } })
$hdr.Controls.AddRange(@($lblTitle, $lblVer, $btnFolder, $btnExp, $btnImp))

# ===== Path =====
$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = '仓库路径'; $lblPath.Location = New-Object System.Drawing.Point(24, 62); $lblPath.Size = New-Object System.Drawing.Size(65, 22)
$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(92, 59); $txtPath.Size = New-Object System.Drawing.Size(560, 24)
$txtPath.Text = $config.vaultPath; $txtPath.BorderStyle = 'FixedSingle'
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = '选择'; Set-FlatButton $btnBrowse
$btnBrowse.Location = New-Object System.Drawing.Point(660, 58); $btnBrowse.Size = New-Object System.Drawing.Size(58, 27)
$btnBrowse.Add_Click({ $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = '选择仓库'; $f.SelectedPath = $txtPath.Text; if ($f.ShowDialog() -eq 'OK') { $txtPath.Text = $f.SelectedPath } })
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = '保存'; Set-FlatButton $btnSave $cp 'White' $cp
$btnSave.Location = New-Object System.Drawing.Point(724, 58); $btnSave.Size = New-Object System.Drawing.Size(72, 27)
$btnSave.Add_Click({
    $p = $txtPath.Text.Trim()
    if (-not $p) { [System.Windows.Forms.MessageBox]::Show('请输入路径', '提示', 'OK', 'Warning'); return }
    if (-not (Test-Path $p)) { $r = [System.Windows.Forms.MessageBox]::Show('路径不存在，仍然保存？', '确认', 'YesNo', 'Question'); if ($r -eq 'No') { return } }
    Save-CurrentUiConfig $p
    $lblStatus.Text = '✓ 已保存'; $lblStatus.ForeColor = $cs; $statusTimer.Start(); Refresh-GitStatus
})

# ===== One-click =====
$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = '一键安装所有同步任务'; Set-FlatButton $btnAll '#174EA6' 'White' '#174EA6'
$btnAll.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$btnAll.Location = New-Object System.Drawing.Point(24, 95); $btnAll.Size = New-Object System.Drawing.Size(830, 32)
$btnAll.Add_Click({
    $p = $txtPath.Text.Trim()
    if (-not $p) { [System.Windows.Forms.MessageBox]::Show('请先填路径', '提示', 'OK', 'Warning'); return }
    Save-CurrentUiConfig $p
    $installErrors = @()
    try { Install-BackupTask; $lblBVal.Text = '已安装'; $lblBVal.ForeColor = $cs } catch { $installErrors += "关机上传: $_" }
    try { Install-PullTask; $lblPVal.Text = '已安装'; $lblPVal.ForeColor = $cs } catch { $installErrors += "开机拉取: $_" }
    if ($chkPeriodic.Checked) { try { Install-PeriodicTask ([int]$cmbPeriodic.SelectedItem); $lblPerVal.Text = '已安装'; $lblPerVal.ForeColor = $cs } catch { $installErrors += "定时同步: $_" } }
    if ($chkMgrStartup.Checked) {
        $w = New-Object -ComObject WScript.Shell; $s = $w.CreateShortcut($startupLinkPath)
        $s.TargetPath = "powershell.exe"; $s.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""; $s.Save()
    } else { if (Test-Path $startupLinkPath) { Remove-Item $startupLinkPath -Force } }
    if ($installErrors.Count -gt 0) {
        $lblStatus.Text = '部分安装失败'; $lblStatus.ForeColor = $cd; $statusTimer.Start()
        [System.Windows.Forms.MessageBox]::Show(($installErrors -join "`n"), '安装结果', 'OK', 'Warning')
    } else {
        $lblStatus.Text = '✓ 全部安装完成'; $lblStatus.ForeColor = $cs; $statusTimer.Start()
        [System.Windows.Forms.MessageBox]::Show('所有任务已安装！', '完成', 'OK', 'Information')
    }
})

# ===== Separator =====
$s1 = New-Object System.Windows.Forms.Label
$s1.BackColor = $line; $s1.Location = New-Object System.Drawing.Point(24, 139); $s1.Size = New-Object System.Drawing.Size(830, 1)

# ===== Task cards =====
$tt = New-Object System.Windows.Forms.ToolTip; $tt.InitialDelay = 300; $tt.AutoPopDelay = 8000

# Backup card (y=140)
$pb = New-Object System.Windows.Forms.Panel; $pb.BackColor = $card; $pb.BorderStyle = 'FixedSingle'
$pb.Location = New-Object System.Drawing.Point(24, 154); $pb.Size = New-Object System.Drawing.Size(410, 48)
$lb = New-Object System.Windows.Forms.Label
$lb.Text = '关机自动上传'; $lb.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$lb.Location = New-Object System.Drawing.Point(14, 7); $lb.Size = New-Object System.Drawing.Size(135, 22)
$lbd = New-Object System.Windows.Forms.Label
$lbd.Text = '关机时 git push'; $lbd.ForeColor = $cl; $lbd.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
$lbd.Location = New-Object System.Drawing.Point(14, 29); $lbd.Size = New-Object System.Drawing.Size(105, 16)
$lblBVal = New-Object System.Windows.Forms.Label
$lblBVal.Text = '检查中...'; $lblBVal.Location = New-Object System.Drawing.Point(150, 13); $lblBVal.Size = New-Object System.Drawing.Size(68, 22); $lblBVal.ForeColor = $cl
$btnBI = New-Object System.Windows.Forms.Button
$btnBI.Text = '安装'; Set-FlatButton $btnBI $cs 'White' $cs
$btnBI.Location = New-Object System.Drawing.Point(210, 9); $btnBI.Size = New-Object System.Drawing.Size(66, 30)
$tt.SetToolTip($btnBI, '关机时自动 git add/commit/push')
$btnBI.Add_Click({ try { Install-BackupTask; $lblStatus.Text = '✓ 已安装'; $statusTimer.Start() } catch { [System.Windows.Forms.MessageBox]::Show("失败：$_", '错误', 'OK', 'Error') } finally { Set-TaskStatusLabel $lblBVal (Get-TaskStatus $backupTaskName) } })
$btnBU = New-Object System.Windows.Forms.Button
$btnBU.Text = '卸载'; Set-FlatButton $btnBU $cd 'White' $cd
$btnBU.Location = New-Object System.Drawing.Point(280, 9); $btnBU.Size = New-Object System.Drawing.Size(66, 30)
$btnBU.Add_Click({ try { Uninstall-Task $backupTaskName; $lblBVal.Text = '未安装'; $lblBVal.ForeColor = $cl } catch { [System.Windows.Forms.MessageBox]::Show("失败：$_", '错误', 'OK', 'Error') } })
$btnBT = New-Object System.Windows.Forms.Button
$btnBT.Text = '测试'; Set-FlatButton $btnBT
$btnBT.Location = New-Object System.Drawing.Point(350, 9); $btnBT.Size = New-Object System.Drawing.Size(66, 30)
$tt.SetToolTip($btnBT, '立即执行一次')
$btnBT.Add_Click({ Test-Backup })
$pb.Controls.AddRange(@($lb, $lbd, $lblBVal, $btnBI, $btnBU, $btnBT))

# Pull card (y=196)
$pp = New-Object System.Windows.Forms.Panel; $pp.BackColor = $card; $pp.BorderStyle = 'FixedSingle'
$pp.Location = New-Object System.Drawing.Point(24, 210); $pp.Size = New-Object System.Drawing.Size(410, 48)
$lp = New-Object System.Windows.Forms.Label
$lp.Text = '开机自动拉取'; $lp.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$lp.Location = New-Object System.Drawing.Point(14, 7); $lp.Size = New-Object System.Drawing.Size(135, 22)
$lpd = New-Object System.Windows.Forms.Label
$lpd.Text = '登录时 git pull'; $lpd.ForeColor = $cl; $lpd.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
$lpd.Location = New-Object System.Drawing.Point(14, 29); $lpd.Size = New-Object System.Drawing.Size(105, 16)
$lblPVal = New-Object System.Windows.Forms.Label
$lblPVal.Text = '检查中...'; $lblPVal.Location = New-Object System.Drawing.Point(150, 13); $lblPVal.Size = New-Object System.Drawing.Size(68, 22); $lblPVal.ForeColor = $cl
$btnPI = New-Object System.Windows.Forms.Button
$btnPI.Text = '安装'; Set-FlatButton $btnPI $cs 'White' $cs
$btnPI.Location = New-Object System.Drawing.Point(210, 9); $btnPI.Size = New-Object System.Drawing.Size(66, 30)
$tt.SetToolTip($btnPI, '登录 Windows 时自动 git pull')
$btnPI.Add_Click({ try { Install-PullTask; $lblPVal.Text = '已安装'; $lblPVal.ForeColor = $cs } catch { [System.Windows.Forms.MessageBox]::Show("失败：$_", '错误', 'OK', 'Error') } })
$btnPU = New-Object System.Windows.Forms.Button
$btnPU.Text = '卸载'; Set-FlatButton $btnPU $cd 'White' $cd
$btnPU.Location = New-Object System.Drawing.Point(280, 9); $btnPU.Size = New-Object System.Drawing.Size(66, 30)
$btnPU.Add_Click({ Uninstall-Task $pullTaskName; $lblPVal.Text = '未安装'; $lblPVal.ForeColor = $cl })
$btnPT = New-Object System.Windows.Forms.Button
$btnPT.Text = '测试'; Set-FlatButton $btnPT
$btnPT.Location = New-Object System.Drawing.Point(350, 9); $btnPT.Size = New-Object System.Drawing.Size(66, 30)
$tt.SetToolTip($btnPT, '立即执行一次')
$btnPT.Add_Click({ Test-Pull })
$pp.Controls.AddRange(@($lp, $lpd, $lblPVal, $btnPI, $btnPU, $btnPT))

# Periodic card (y=252)
$pper = New-Object System.Windows.Forms.Panel; $pper.BackColor = $card; $pper.BorderStyle = 'FixedSingle'
$pper.Location = New-Object System.Drawing.Point(24, 266); $pper.Size = New-Object System.Drawing.Size(410, 48)
$lper = New-Object System.Windows.Forms.Label
$lper.Text = '定时同步'; $lper.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$lper.Location = New-Object System.Drawing.Point(14, 7); $lper.Size = New-Object System.Drawing.Size(90, 22)
$cmbPeriodic = New-Object System.Windows.Forms.ComboBox
$cmbPeriodic.DropDownStyle = 'DropDownList'; $cmbPeriodic.FlatStyle = 'Flat'
'1','2','3','4','6','8','12' | ForEach-Object { $cmbPeriodic.Items.Add($_) | Out-Null }
$cmbPeriodic.SelectedItem = if ($config.periodicHours -gt 0) { "$($config.periodicHours)" } else { '2' }
$cmbPeriodic.Location = New-Object System.Drawing.Point(14, 28); $cmbPeriodic.Size = New-Object System.Drawing.Size(56, 22)
$lperu = New-Object System.Windows.Forms.Label
$lperu.Text = '小时'; $lperu.ForeColor = $cl; $lperu.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
$lperu.Location = New-Object System.Drawing.Point(74, 30); $lperu.Size = New-Object System.Drawing.Size(34, 16)
$lblPerVal = New-Object System.Windows.Forms.Label
$lblPerVal.Text = '检查中...'; $lblPerVal.Location = New-Object System.Drawing.Point(150, 13); $lblPerVal.Size = New-Object System.Drawing.Size(68, 22); $lblPerVal.ForeColor = $cl
$chkPeriodic = New-Object System.Windows.Forms.CheckBox
$chkPeriodic.Text = '启用'; $chkPeriodic.Location = New-Object System.Drawing.Point(106, 27); $chkPeriodic.Size = New-Object System.Drawing.Size(52, 22)
$chkPeriodic.Checked = ($config.periodicHours -gt 0)
$btnPerI = New-Object System.Windows.Forms.Button
$btnPerI.Text = '安装'; Set-FlatButton $btnPerI $cs 'White' $cs
$btnPerI.Location = New-Object System.Drawing.Point(210, 9); $btnPerI.Size = New-Object System.Drawing.Size(66, 30)
$tt.SetToolTip($btnPerI, '按间隔自动同步')
$btnPerI.Add_Click({ try { Install-PeriodicTask ([int]$cmbPeriodic.SelectedItem); $lblPerVal.Text = '已安装'; $lblPerVal.ForeColor = $cs; $chkPeriodic.Checked = $true } catch { [System.Windows.Forms.MessageBox]::Show("失败：$_", '错误', 'OK', 'Error') } })
$btnPerU = New-Object System.Windows.Forms.Button
$btnPerU.Text = '卸载'; Set-FlatButton $btnPerU $cd 'White' $cd
$btnPerU.Location = New-Object System.Drawing.Point(280, 9); $btnPerU.Size = New-Object System.Drawing.Size(66, 30)
$btnPerU.Add_Click({ Uninstall-Task $periodicTaskName; $lblPerVal.Text = '未安装'; $lblPerVal.ForeColor = $cl; $chkPeriodic.Checked = $false })
$pper.Controls.AddRange(@($lper, $cmbPeriodic, $lperu, $lblPerVal, $chkPeriodic, $btnPerI, $btnPerU))

# ===== Settings (y=308) =====
$pset = New-Object System.Windows.Forms.Panel; $pset.BackColor = $card; $pset.BorderStyle = 'FixedSingle'
$pset.Location = New-Object System.Drawing.Point(24, 322); $pset.Size = New-Object System.Drawing.Size(410, 38)
$chkClean = New-Object System.Windows.Forms.CheckBox
$chkClean.Text = '关机清理临时文件'; $chkClean.Location = New-Object System.Drawing.Point(14, 9); $chkClean.Size = New-Object System.Drawing.Size(132, 22)
$chkClean.Checked = $config.cleanTemp
$tt.SetToolTip($chkClean, '关机时删除 C:\Windows\Temp')
$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text = '立即清理'; Set-FlatButton $btnClean
$btnClean.Location = New-Object System.Drawing.Point(148, 5); $btnClean.Size = New-Object System.Drawing.Size(76, 27)
$btnClean.Add_Click({ $p1="$env:SystemRoot\Temp\*";$p2="$env:TEMP\*";$c=(Get-ChildItem $p1 -Force -EA 0|Measure-Object).Count+(Get-ChildItem $p2 -Force -EA 0|Measure-Object).Count;Remove-Item $p1 -Recurse -Force -EA 0;Remove-Item $p2 -Recurse -Force -EA 0;[System.Windows.Forms.MessageBox]::Show("清理 $c 项`n$env:SystemRoot\Temp`n$env:TEMP", '结果', 'OK','Information') })
$chkNotify = New-Object System.Windows.Forms.CheckBox
$chkNotify.Text = '弹窗通知'; $chkNotify.Location = New-Object System.Drawing.Point(238, 8); $chkNotify.Size = New-Object System.Drawing.Size(82, 22)
$chkNotify.Checked = $config.showNotify
$tt.SetToolTip($chkNotify, '拉取完成后右下角弹窗')
$chkMgrStartup = New-Object System.Windows.Forms.CheckBox
$chkMgrStartup.Text = '自启管理器'; $chkMgrStartup.Location = New-Object System.Drawing.Point(318, 8); $chkMgrStartup.Size = New-Object System.Drawing.Size(92, 22)
$chkMgrStartup.Checked = (Test-Path $startupLinkPath)
$tt.SetToolTip($chkMgrStartup, '开机自动打开本工具')
$pset.Controls.AddRange(@($chkClean, $btnClean, $chkNotify, $chkMgrStartup))

# ===== Git status (y=352) =====
$pgit = New-Object System.Windows.Forms.Panel; $pgit.BackColor = $soft; $pgit.BorderStyle = 'FixedSingle'
$pgit.Location = New-Object System.Drawing.Point(24, 370); $pgit.Size = New-Object System.Drawing.Size(410, 30)
$lblGitStatus = New-Object System.Windows.Forms.Label
$lblGitStatus.Text = 'Git 状态：读取中...'; $lblGitStatus.ForeColor = $ct
$lblGitStatus.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
$lblGitStatus.Location = New-Object System.Drawing.Point(10, 6); $lblGitStatus.Size = New-Object System.Drawing.Size(330, 20)
$btnRefGit = New-Object System.Windows.Forms.Button
$btnRefGit.Text = '刷新'; Set-FlatButton $btnRefGit
$btnRefGit.Location = New-Object System.Drawing.Point(350, 3); $btnRefGit.Size = New-Object System.Drawing.Size(54, 24)
$btnRefGit.Add_Click({ Refresh-GitStatus })
$pgit.Controls.AddRange(@($lblGitStatus, $btnRefGit))

# ===== Log viewer (y=386) =====
$plog = New-Object System.Windows.Forms.Panel; $plog.BackColor = $card; $plog.BorderStyle = 'FixedSingle'
$plog.Location = New-Object System.Drawing.Point(24, 410); $plog.Size = New-Object System.Drawing.Size(410, 112)
$llog = New-Object System.Windows.Forms.Label
$llog.Text = '最近日志'; $llog.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
$llog.Location = New-Object System.Drawing.Point(10, 7); $llog.Size = New-Object System.Drawing.Size(70, 20)
$cmbLog = New-Object System.Windows.Forms.ComboBox
$cmbLog.DropDownStyle = 'DropDownList'; $cmbLog.FlatStyle = 'Flat'
$cmbLog.Items.AddRange(@('上传日志','拉取日志','定时日志'))
$cmbLog.SelectedIndex = 0; $cmbLog.Location = New-Object System.Drawing.Point(82, 6); $cmbLog.Size = New-Object System.Drawing.Size(96, 22)
$cmbLog.Add_SelectedIndexChanged({ Refresh-Log @('obsidian-backup.log','obsidian-pull.log','obsidian-sync.log')[$cmbLog.SelectedIndex] })
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(10, 32); $txtLog.Size = New-Object System.Drawing.Size(390, 72)
$txtLog.Multiline = $true; $txtLog.ReadOnly = $true; $txtLog.BackColor = 'White'
$txtLog.BorderStyle = 'FixedSingle'; $txtLog.Font = New-Object System.Drawing.Font('Consolas', 8); $txtLog.ScrollBars = 'None'
$plog.Controls.AddRange(@($llog, $cmbLog, $txtLog))

# ===== Help (y=482) =====
$phlp = New-Object System.Windows.Forms.Panel; $phlp.BackColor = $warn; $phlp.BorderStyle = 'FixedSingle'
$phlp.Location = New-Object System.Drawing.Point(455, 154); $phlp.Size = New-Object System.Drawing.Size(410, 48)
$lhlp = New-Object System.Windows.Forms.Label
$lhlp.Text = '工具会以管理员方式启动，计划任务状态和关机上传安装更稳定。换电脑时复制整个 scripts 文件夹，再选择仓库路径。'
$lhlp.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8); $lhlp.ForeColor = "#795548"
$lhlp.Location = New-Object System.Drawing.Point(10, 8); $lhlp.Size = New-Object System.Drawing.Size(390, 40)
$phlp.Controls.Add($lhlp)

# ===== TokenX24 面板 =====
$s2 = New-Object System.Windows.Forms.Label
$s2.BackColor = $line; $s2.Location = New-Object System.Drawing.Point(455, 210); $s2.Size = New-Object System.Drawing.Size(410, 1)

$lblTxTitle = New-Object System.Windows.Forms.Label
$lblTxTitle.Text = 'TokenX24 账号'; $lblTxTitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$lblTxTitle.Location = New-Object System.Drawing.Point(455, 226); $lblTxTitle.Size = New-Object System.Drawing.Size(140, 22)

$lblTxCounter = New-Object System.Windows.Forms.Label
$lblTxCounter.Text = "当前: +$(Get-TxCounter)"; $lblTxCounter.ForeColor = $cl
$lblTxCounter.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
$lblTxCounter.Location = New-Object System.Drawing.Point(565, 229); $lblTxCounter.Size = New-Object System.Drawing.Size(90, 18)

$lblTxStart = New-Object System.Windows.Forms.Label
$lblTxStart.Text = '下次编号 +'; $lblTxStart.Location = New-Object System.Drawing.Point(455, 259); $lblTxStart.Size = New-Object System.Drawing.Size(72, 22)

$numTxStart = New-Object System.Windows.Forms.NumericUpDown
$numTxStart.Minimum = 1; $numTxStart.Maximum = 999999; $numTxStart.Value = [Math]::Max(1, (Get-TxCounter) + 1)
$numTxStart.Location = New-Object System.Drawing.Point(528, 256); $numTxStart.Size = New-Object System.Drawing.Size(110, 24)
$numTxStart.BorderStyle = 'FixedSingle'
$numTxStart.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$numTxStart.TextAlign = 'Center'

$btnTxSetStart = New-Object System.Windows.Forms.Button
$btnTxSetStart.Text = '设为起点'; Set-FlatButton $btnTxSetStart
$btnTxSetStart.Location = New-Object System.Drawing.Point(646, 255); $btnTxSetStart.Size = New-Object System.Drawing.Size(82, 27)
$tt.SetToolTip($btnTxSetStart, '设置下一次注册使用的 Gmail +编号')
$btnTxSetStart.Add_Click({
    Set-TxStartNumber ([int]$numTxStart.Value)
    $lblTxCounter.Text = "当前: +$(Get-TxCounter)"
    $lblTxResult.Text = "下一次从 +$([int]$numTxStart.Value) 开始"
    $lblTxResult.ForeColor = $cs
})

$lblTxMail = New-Object System.Windows.Forms.Label
$lblTxMail.Text = 'Gmail'; $lblTxMail.Location = New-Object System.Drawing.Point(455, 296); $lblTxMail.Size = New-Object System.Drawing.Size(50, 22)
$txtTxMail = New-Object System.Windows.Forms.TextBox
$txtTxMail.Text = "xttt1316@gmail.com"; $txtTxMail.ReadOnly = $true; $txtTxMail.BackColor = "#F1F3F6"; $txtTxMail.Location = New-Object System.Drawing.Point(515, 293); $txtTxMail.Size = New-Object System.Drawing.Size(190, 24); $txtTxMail.BorderStyle = 'FixedSingle'

$lblTxPass = New-Object System.Windows.Forms.Label
$lblTxPass.Text = '授权码'; $lblTxPass.Location = New-Object System.Drawing.Point(715, 296); $lblTxPass.Size = New-Object System.Drawing.Size(52, 22)
$txtTxPass = New-Object System.Windows.Forms.TextBox
$txtTxPass.ReadOnly = $true; $txtTxPass.BackColor = "#F1F3F6"; $txtTxPass.UseSystemPasswordChar = $true; $txtTxPass.Text = "bxmt kzxq ngoo pbak"; $txtTxPass.Location = New-Object System.Drawing.Point(772, 293); $txtTxPass.Size = New-Object System.Drawing.Size(88, 24); $txtTxPass.BorderStyle = 'FixedSingle'

$lblTxSPass = New-Object System.Windows.Forms.Label
$lblTxSPass.Text = '站点密码'; $lblTxSPass.Location = New-Object System.Drawing.Point(455, 332); $lblTxSPass.Size = New-Object System.Drawing.Size(60, 22)
$txtTxSPass = New-Object System.Windows.Forms.TextBox
$txtTxSPass.Text = "Test123456"; $txtTxSPass.Location = New-Object System.Drawing.Point(515, 329); $txtTxSPass.Size = New-Object System.Drawing.Size(110, 24); $txtTxSPass.BorderStyle = 'FixedSingle'

$btnTxReg = New-Object System.Windows.Forms.Button
$btnTxReg.Text = '注册新账号'; Set-FlatButton $btnTxReg '#174EA6' 'White' '#174EA6'
$btnTxReg.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$btnTxReg.Location = New-Object System.Drawing.Point(455, 370); $btnTxReg.Size = New-Object System.Drawing.Size(148, 32)
$tt.SetToolTip($btnTxReg, '自动注册 Gmail + 别名账号并保存')
$btnTxReg.Add_Click({
    $btnTxReg.Enabled = $false; $btnTxLogin.Enabled = $false; $btnTxReg.Text = '注册中...'
    $lblTxResult.Text = '正在执行...'; $lblTxResult.ForeColor = $cp
    $form.Refresh()
    try {
        $r = New-TokenX24Account $txtTxMail.Text $txtTxPass.Text $txtTxSPass.Text $lblTxResult $form
        $script:lastTxEmail = $r.Email
        $script:lastTxPassword = $r.Password
        $lblTxResult.Text = "账号: $($r.Email)  已保存到 tokenx24-accounts.txt"
        $lblTxCounter.Text = "当前: +$(Get-TxCounter)"
        $numTxStart.Value = [Math]::Min($numTxStart.Maximum, [Math]::Max($numTxStart.Minimum, (Get-TxCounter) + 1))
        $lblTxResult.ForeColor = $cs
        $btnTxLogin.Enabled = $true
        [System.Windows.Forms.Clipboard]::SetText($r.Email)
        Save-CurrentUiConfig $txtPath.Text.Trim()
    } catch {
        $lblTxResult.Text = "失败: $_"
        $lblTxResult.ForeColor = $cd
    } finally {
        $btnTxReg.Enabled = $true; $btnTxLogin.Enabled = $true; $btnTxReg.Text = '注册新账号'
    }
})

$btnTxLogin = New-Object System.Windows.Forms.Button
$btnTxLogin.Text = '直接登录'; Set-FlatButton $btnTxLogin $cs 'White' $cs
$btnTxLogin.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
$btnTxLogin.Location = New-Object System.Drawing.Point(615, 370); $btnTxLogin.Size = New-Object System.Drawing.Size(120, 32)
$tt.SetToolTip($btnTxLogin, '使用刚注册或最后保存的 TokenX24 账号打开已登录窗口')
$btnTxLogin.Add_Click({
    $btnTxLogin.Enabled = $false
    try {
        $email = $script:lastTxEmail
        $password = $script:lastTxPassword
        if (-not $password) { $password = $txtTxSPass.Text }
        Open-TokenX24LoggedIn $email $password $lblTxResult $form
    } catch {
        $lblTxResult.Text = "登录失败: $_"
        $lblTxResult.ForeColor = $cd
    } finally {
        $btnTxLogin.Enabled = $true
    }
})

$lblTxResult = New-Object System.Windows.Forms.Label
$lblTxResult.Text = '点击上方按钮注册'; $lblTxResult.ForeColor = $cl; $lblTxResult.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 8)
$lblTxResult.Location = New-Object System.Drawing.Point(455, 414); $lblTxResult.Size = New-Object System.Drawing.Size(410, 58)

$btnTxOpen = New-Object System.Windows.Forms.Button
$btnTxOpen.Text = '打开网站'; Set-FlatButton $btnTxOpen
$btnTxOpen.Location = New-Object System.Drawing.Point(792, 226); $btnTxOpen.Size = New-Object System.Drawing.Size(74, 25)
$btnTxOpen.Add_Click({ Start-Process "https://www.tokenx24.com/login" })

# ===== Footer =====
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = '就绪'; $lblStatus.Location = New-Object System.Drawing.Point(24, 538)
$lblStatus.Size = New-Object System.Drawing.Size(830, 22); $lblStatus.ForeColor = $cl
$statusTimer = New-Object System.Windows.Forms.Timer
$statusTimer.Interval = 4000
$statusTimer.Add_Tick({ $lblStatus.Text = '就绪'; $lblStatus.ForeColor = $cl; $statusTimer.Stop() })

# ===== Assemble =====
$form.Controls.AddRange(@($hdr, $lblPath, $txtPath, $btnBrowse, $btnSave, $btnAll, $s1, $pb, $pp, $pper, $pset, $pgit, $plog, $phlp, $s2, $lblTxTitle, $lblTxCounter, $lblTxStart, $numTxStart, $btnTxSetStart, $lblTxMail, $txtTxMail, $lblTxPass, $txtTxPass, $lblTxSPass, $txtTxSPass, $btnTxReg, $btnTxLogin, $lblTxResult, $btnTxOpen, $lblStatus))

$form.Add_Shown({
    $s1 = Get-TaskStatus $backupTaskName; $s2 = Get-TaskStatus $pullTaskName; $s3 = Get-TaskStatus $periodicTaskName
    Set-TaskStatusLabel $lblBVal $s1
    Set-TaskStatusLabel $lblPVal $s2
    Set-TaskStatusLabel $lblPerVal $s3
    Refresh-GitStatus; Refresh-Log 'obsidian-backup.log'
    $c = Load-Config
    if ($c.gmailPass) { $txtTxPass.Text = $c.gmailPass }
    if ($c.sitePass) { $txtTxSPass.Text = $c.sitePass }
    $form.AutoScrollMinSize = New-Object System.Drawing.Size(0, 0)
})

[void]$form.ShowDialog()


