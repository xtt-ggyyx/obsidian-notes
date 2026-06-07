$c=Get-Content (Join-Path $PSScriptRoot "obsidian-config.json") -Raw|ConvertFrom-Json
if(-not (Test-Path $c.vaultPath)){exit 1}
$l=Join-Path $PSScriptRoot "obsidian-sync.log"
function g{param($m);"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m"|Out-File $l -Append -Encoding UTF8}
try{Set-Location $c.vaultPath;g "Start";git add -A;$s=git status --porcelain;if($s){git commit -m "auto sync $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')";git push;g "Pushed"}else{g "No local"};git pull;g "Pull done"}catch{g "ERROR: $_"}
