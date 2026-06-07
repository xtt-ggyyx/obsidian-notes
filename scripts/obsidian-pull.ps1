$c=Get-Content (Join-Path $PSScriptRoot "obsidian-config.json") -Raw|ConvertFrom-Json
if(-not (Test-Path $c.vaultPath)){exit 1}
$l=Join-Path $PSScriptRoot "obsidian-pull.log"
function g{param($m);"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m"|Out-File $l -Append -Encoding UTF8}
try{$env:GIT_TERMINAL_PROMPT='0';$env:GCM_INTERACTIVE='Never';Set-Location $c.vaultPath;$r=git pull 2>&1;if($LASTEXITCODE -ne 0){throw ($r -join ' ')};g "Pulled: $r"
if($c.showNotify){try{$n=New-Object System.Windows.Forms.NotifyIcon;$n.Icon=[System.Drawing.SystemIcons]::Information;$n.BalloonTipTitle='Obsidian Sync';$n.BalloonTipText="Sync done
$r";$n.Visible=$true;$n.ShowBalloonTip(5000);Start-Sleep 2;$n.Dispose()}catch{}}}catch{g "ERROR: $_";exit 1}
