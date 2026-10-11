**English** · [Português](doom-como-entrar.pt-BR.md)

# 🎮 How to play Doom online on the server owner's server (copy and paste)

_Created 2026-10-10. Links checked 2026-10-10. **Windows tested and working** (PowerShell without admin, 2026-10-10). The Linux script had its download/extraction tested (Debian 13); the game itself on Linux was not tested._

You just **copy and paste** the block for your system. It downloads the game and joins the server. The second time you paste it, it only opens the game (it does not download again).

## 📍 Server details
```
Address:  <endereço-público>
Alternative IP:  <ip-público>:<porta>
Room:      Frendner - Sala 1 (test)       Players: up to 16      Password: none
```
You do not need to open ports or touch the router.

---

# 🪟 WINDOWS — copy and paste

1. Press the **Windows** key, type **PowerShell** and open it (it does not need to be administrator).
2. **Copy the whole block below**, paste it into the blue window (right-click to paste) and press **Enter**.

```powershell
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$Server = '<endereço-público>'
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
```

The game is installed in `C:\Users\<your user>\Doom`. **Different folder?** Download https://<seu-domínio>/win.ps1, edit the `$Dir = …` line and run `powershell -ExecutionPolicy Bypass -File "$HOME\Downloads\win.ps1"`. To play again later, paste the same block.

**If PowerShell complains that "script execution is disabled":** this does not happen when pasting directly into the terminal. If it does, close PowerShell and open it again.

**Manual (no script):**
1. Download Zandronum 3.2.1: [installer](https://zandronum.com/downloads/zandronum3.2.1-win64-installer.exe) or [zip](https://zandronum.com/downloads/zandronum3.2.1-win64-base.zip) (zip: extract into a folder).
2. Download [Freedoom 0.13.0](https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip), extract it and copy `freedoom2.wad` into the Zandronum folder (where `zandronum.exe` is).
3. Open Zandronum (choose `freedoom2.wad` if asked), press `'` or `~` and type `connect <endereço-público>`.

---

# 🐧 LINUX — copy and paste

### Step 0 — libraries (important)
Zandronum for Linux needs two old libraries: **libSDL-1.2** and **libjpeg.so.8**. The script warns you if they are missing.

| Your distro | Command |
|---|---|
| **Ubuntu / Linux Mint** | `sudo apt install libsdl1.2debian libjpeg-turbo8` |
| **Debian 13** | `sudo apt install libsdl1.2debian` — `libjpeg.so.8` **does not exist** on Debian 13; use Ubuntu/Mint, Windows, or see "Debian" below |
| **Arch / Manjaro** | `zandronum` package in the AUR (brings everything) instead of the script |
| **Fedora** | look for `SDL` 1.2 (`sdl12-compat`) and `libjpeg-turbo`; if `.so.8` is missing, the script will show it |

### Step 1 — copy and paste
Open the **Terminal**, copy the whole block, paste it and press **Enter**:

```bash
cat > ~/doom.sh <<'FIM'
#!/usr/bin/env bash
set -euo pipefail

SERVER="<endereço-público>"
# >>> PASTA DO JOGO: edite a linha abaixo para mudar (ex.: DIR="/mnt/jogos/doom") <<<
DIR="${DOOM_DIR:-$HOME/Jogos/doom}"
ZAN_URL="https://zandronum.com/downloads/zandronum3.2.1-linux-x86_64.tar.bz2"
FD_URL="https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip"

baixar() {
  if command -v curl >/dev/null; then curl -fL --progress-bar -o "$2" "$1"
  elif command -v wget >/dev/null; then wget -O "$2" "$1"
  else echo "ERRO: instale curl ou wget."; exit 1; fi
}

mkdir -p "$DIR"; cd "$DIR"

if [ ! -x ./zandronum ]; then
  echo ">> Baixando o Zandronum..."
  baixar "$ZAN_URL" zandronum.tar.bz2
  tar -xjf zandronum.tar.bz2 && rm -f zandronum.tar.bz2
  chmod +x zandronum
fi

if [ ! -f freedoom2.wad ]; then
  echo ">> Baixando o Freedoom..."
  baixar "$FD_URL" freedoom.zip
  if command -v unzip >/dev/null; then unzip -oj -q freedoom.zip '*/freedoom2.wad'
  else python3 -c "import zipfile,shutil;z=zipfile.ZipFile('freedoom.zip');n=[x for x in z.namelist() if x.endswith('/freedoom2.wad')][0];shutil.copyfileobj(z.open(n),open('freedoom2.wad','wb'))"
  fi
  rm -f freedoom.zip
fi

export LD_LIBRARY_PATH="$DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

FALTAM=$(ldd ./zandronum | awk '/not found/ {print $1}')
if [ -n "$FALTAM" ]; then
  echo "ERRO: faltam bibliotecas no seu sistema:"; echo "$FALTAM"
  echo "Veja o 'Passo 0' do guia e rode de novo: bash ~/doom.sh"
  exit 1
fi

echo ">> Entrando em $SERVER ..."
exec ./zandronum -iwad freedoom2.wad +connect "$SERVER"
FIM
bash ~/doom.sh
```

To play again: `bash ~/doom.sh`. **Different folder?** Download https://<seu-domínio>/linux.sh, edit the `DIR=…` line and run `bash ~/Downloads/linux.sh` (or `DOOM_DIR=/other/folder bash linux.sh`). The game is installed in `~/Jogos/doom`.

**Manual (no script):**
1. Download [Zandronum 3.2.1 Linux](https://zandronum.com/downloads/zandronum3.2.1-linux-x86_64.tar.bz2) and extract it: `mkdir -p ~/Jogos/doom && tar -xjf zandronum3.2.1-linux-x86_64.tar.bz2 -C ~/Jogos/doom`
2. Download [Freedoom 0.13.0](https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip), extract it and copy `freedoom2.wad` to `~/Jogos/doom`.
3. Run: `cd ~/Jogos/doom && LD_LIBRARY_PATH=. ./zandronum -iwad freedoom2.wad +connect <endereço-público>`

### Debian
If the script fails with `libjpeg.so.8`, the simplest way is to run Zandronum in an Ubuntu container (for example with `distrobox`) or use a machine running Ubuntu/Mint/Windows. I could not validate a native alternative on Debian 13.

---

## 🕹️ Playing
| Action | How |
|---|---|
| Open the console (text bar) | `'` or `~` key |
| Join manually (if the script did not connect) | in the console: `connect <endereço-público>` |
| Leave the server | in the console: `disconnect` |
| Chat | `T` key |
| Change controls (mouse/WASD) | menu **Options → Customize Controls** |

## 🆘 Having trouble?
| What you see | What to do |
|---|---|
| Stays on "Connecting..." and then errors | Try the IP in the console: `connect <ip-público>:<porta>`. If that fails, let the server owner know (the server may be down) |
| "Version mismatch" | You are not on **3.2.1**. Delete the game folder and paste the block again |
| "Couldn't find IWAD" | `freedoom2.wad` is missing from the game folder. Delete the folder and paste the block again |
| Library error (Linux) | See Step 0 |
| Lagging / skipping | Use a network cable or move closer to the Wi-Fi |
| Cannot find the console | ABNT keyboard: try `'` and `~`, or **Customize Controls → Console** |

> Use version **3.2.1** (stable); the "testing 3.3" builds are not accepted on this server. Optional: [Doomseeker](https://doomseeker.drdteam.org) (server browser).

---
_For the owner: technical details in `doom-zandronum.md`. If you change the room's IWAD or the playit address, update `SERVER`/`freedoom2` in both blocks._
