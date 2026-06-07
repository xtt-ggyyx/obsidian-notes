$c=Get-Content (Join-Path $PSScriptRoot "obsidian-config.json") -Raw|ConvertFrom-Json
if(-not (Test-Path $c.vaultPath)){exit 1}
$l=Join-Path $PSScriptRoot "obsidian-backup.log"
function g{param($m);"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m"|Out-File $l -Append -Encoding UTF8}
try{$env:GIT_TERMINAL_PROMPT='0';$env:GCM_INTERACTIVE='Never';Set-Location $c.vaultPath;g "Start"
git add -A 2>&1|Out-Null;if($LASTEXITCODE -ne 0){throw "git add failed"}
$s=git status --porcelain 2>&1
if($s){$t=Get-Date -Format 'yyyy-MM-dd HH:mm:ss';git commit -m "auto backup $t" 2>&1|Out-Null;if($LASTEXITCODE -ne 0){throw "git commit failed"};g "Commit";git push 2>&1|Out-File $l -Append -Encoding UTF8;if($LASTEXITCODE -ne 0){throw "git push failed"};g "Pushed"}else{g "No changes"}
if($c.cleanTemp){Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue;g "User temp cleaned"}}catch{g "ERROR: $_";exit 1}
