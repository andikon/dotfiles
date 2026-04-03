function touch { param($f) "" | Out-File $f -Encoding ASCII }
function mkcd  { param($d) mkdir $d -Force; Set-Location $d }

function docs  { Set-Location ([Environment]::GetFolderPath("MyDocuments")) }
function desk  { Set-Location ([Environment]::GetFolderPath("Desktop")) }
function home  { Set-Location $HOME }

function la    { Get-ChildItem | Format-Table -AutoSize }
function ll    { Get-ChildItem -Force | Format-Table -AutoSize }

Export-ModuleMember -Function *
