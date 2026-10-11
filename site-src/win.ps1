$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$Server = '@@PUBLIC_ADDR@@'
try { $Server = (Invoke-RestMethod 'https://@@SITE_HOST@@/server.txt').ToString().Trim() } catch {}
# >>> PASTA DO JOGO: edite a linha abaixo para mudar (ex.: $Dir = "D:\Jogos\Doom") <<<
$Dir = "$env:USERPROFILE\Doom"
New-Item -ItemType Directory -Force $Dir | Out-Null

if (-not (Test-Path "$Dir\zandronum.exe")) {
  Write-Host '>> Baixando o Zandronum...'
  # o site do Zandronum bloqueia o User-Agent padrao do PowerShell (anti-bot), entao usamos um neutro
  Invoke-WebRequest 'https://zandronum.com/downloads/zandronum3.2.1-win64-base.zip' -OutFile "$Dir\z.zip" -UserAgent 'curl/8.4.0'
  if ([System.IO.File]::ReadAllBytes("$Dir\z.zip")[0..1] -join ',' -ne '80,75') { Remove-Item "$Dir\z.zip"; throw 'O download do Zandronum nao veio como zip (site bloqueou?). Baixe na mao: https://zandronum.com/download' }
  Expand-Archive "$Dir\z.zip" $Dir -Force
  Remove-Item "$Dir\z.zip"
}
if (-not (Test-Path "$Dir\freedoom2.wad")) {
  Write-Host '>> Baixando o Freedoom...'
  Invoke-WebRequest 'https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip' -OutFile "$Dir\f.zip"
  Expand-Archive "$Dir\f.zip" "$Dir\fd" -Force
  Copy-Item (Get-ChildItem "$Dir\fd" -Recurse -Filter freedoom2.wad).FullName "$Dir\freedoom2.wad"
  Remove-Item "$Dir\f.zip", "$Dir\fd" -Recurse -Force
}
Write-Host ">> Entrando em $Server ..."
Start-Process "$Dir\zandronum.exe" -ArgumentList '-iwad','freedoom2.wad','+connect',$Server -WorkingDirectory $Dir
