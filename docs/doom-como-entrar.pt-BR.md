[English](doom-como-entrar.md) · **Português**

# 🎮 Como jogar Doom online no servidor do dono (copiar e colar)

_Criado em 10/10/2026. Links conferidos em 10/10/2026. **Windows testado e funcionando** (PowerShell sem admin, 10/10/2026). O script de Linux teve download/extração testados (Debian 13); o jogo em si no Linux não foi testado._

Você só **copia e cola** o bloco do seu sistema. Ele baixa o jogo e entra no servidor. Na segunda vez que colar, ele só abre o jogo (não baixa de novo).

## 📍 Dados do servidor
```
Endereço:  <endereço-público>
IP alternativo:  <ip-público>:<porta>
Sala:      Frendner - Sala 1 (teste)       Jogadores: até 16      Senha: nenhuma
```
Não precisa abrir portas nem mexer no roteador.

---

# 🪟 WINDOWS — copiar e colar

1. Aperte a tecla **Windows**, digite **PowerShell** e abra (não precisa ser administrador).
2. **Copie o bloco inteiro abaixo**, cole na janela azul (clique com o botão direito para colar) e aperte **Enter**.

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

O jogo fica em `C:\Users\<seu usuário>\Doom`. **Outra pasta?** Baixe https://<seu-domínio>/win.ps1, edite a linha `$Dir = …` e rode `powershell -ExecutionPolicy Bypass -File "$HOME\Downloads\win.ps1"`. Para jogar de novo depois, cole o mesmo bloco.

**Se o PowerShell reclamar de "execução de scripts desabilitada":** isso não acontece com colar direto no terminal. Se acontecer, feche e abra o PowerShell de novo.

**Manual (sem script):**
1. Baixe o Zandronum 3.2.1: [instalador](https://zandronum.com/downloads/zandronum3.2.1-win64-installer.exe) ou [zip](https://zandronum.com/downloads/zandronum3.2.1-win64-base.zip) (zip: extraia numa pasta).
2. Baixe o [Freedoom 0.13.0](https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip), extraia e copie o `freedoom2.wad` para a pasta do Zandronum (onde está o `zandronum.exe`).
3. Abra o Zandronum (escolha `freedoom2.wad` se perguntar), aperte `'` ou `~` e digite `connect <endereço-público>`.

---

# 🐧 LINUX — copiar e colar

### Passo 0 — bibliotecas (importante)
O Zandronum para Linux precisa de duas bibliotecas antigas: **libSDL-1.2** e **libjpeg.so.8**. O script avisa se faltarem.

| Sua distro | Comando |
|---|---|
| **Ubuntu / Linux Mint** | `sudo apt install libsdl1.2debian libjpeg-turbo8` |
| **Debian 13** | `sudo apt install libsdl1.2debian` — a `libjpeg.so.8` **não existe** no Debian 13; use o Ubuntu/Mint, o Windows, ou veja "Debian" mais abaixo |
| **Arch / Manjaro** | pacote `zandronum` no AUR (traz tudo) em vez do script |
| **Fedora** | procure `SDL` 1.2 (`sdl12-compat`) e `libjpeg-turbo`; se faltar a `.so.8`, o script mostra |

### Passo 1 — copiar e colar
Abra o **Terminal**, copie o bloco inteiro, cole e aperte **Enter**:

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

Para jogar de novo: `bash ~/doom.sh`. **Outra pasta?** Baixe https://<seu-domínio>/linux.sh, edite a linha `DIR=…` e rode `bash ~/Downloads/linux.sh` (ou `DOOM_DIR=/outra/pasta bash linux.sh`). O jogo fica em `~/Jogos/doom`.

**Manual (sem script):**
1. Baixe o [Zandronum 3.2.1 Linux](https://zandronum.com/downloads/zandronum3.2.1-linux-x86_64.tar.bz2) e extraia: `mkdir -p ~/Jogos/doom && tar -xjf zandronum3.2.1-linux-x86_64.tar.bz2 -C ~/Jogos/doom`
2. Baixe o [Freedoom 0.13.0](https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip), extraia e copie o `freedoom2.wad` para `~/Jogos/doom`.
3. Rode: `cd ~/Jogos/doom && LD_LIBRARY_PATH=. ./zandronum -iwad freedoom2.wad +connect <endereço-público>`

### Debian
Se o script falhar com `libjpeg.so.8`, o jeito mais simples é rodar o Zandronum num container Ubuntu (por exemplo com `distrobox`) ou usar uma máquina com Ubuntu/Mint/Windows. Não consegui validar uma alternativa nativa no Debian 13.

---

## 🕹️ Jogando
| Ação | Como |
|---|---|
| Abrir o console (barra de texto) | tecla `'` ou `~` |
| Entrar na mão (se o script não entrou) | no console: `connect <endereço-público>` |
| Sair do servidor | no console: `disconnect` |
| Conversar | tecla `T` |
| Mudar controles (mouse/WASD) | menu **Options → Customize Controls** |

## 🆘 Deu problema?
| O que apareceu | O que fazer |
|---|---|
| Fica "Connecting..." e dá erro | Tente o IP no console: `connect <ip-público>:<porta>`. Se não for, avise o o dono do servidor (servidor pode estar desligado) |
| "Version mismatch" | Você não está com a **3.2.1**. Apague a pasta do jogo e cole o bloco de novo |
| "Couldn't find IWAD" | Falta o `freedoom2.wad` na pasta do jogo. Apague a pasta e cole o bloco de novo |
| Erro de biblioteca (Linux) | Veja o Passo 0 |
| Travando / pulando | Use cabo de rede ou chegue mais perto do Wi-Fi |
| Não acho o console | Teclado ABNT: tente `'` e `~`, ou **Customize Controls → Console** |

> Use a versão **3.2.1** (estável); as "testing 3.3" não entram neste servidor. Opcional: [Doomseeker](https://doomseeker.drdteam.org) (lista de servidores).

---
_Para o dono: detalhes técnicos em `doom-zandronum.md`. Se mudar o IWAD da sala ou o endereço do playit, atualizar `SERVER`/`freedoom2` nos dois blocos._
