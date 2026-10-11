#!/usr/bin/env bash
# Instala (na primeira vez) e entra no servidor de Doom do @@OWNER@@.
set -euo pipefail

SERVER="@@PUBLIC_ADDR@@"
SERVER="$(curl -fsS -m 5 https://@@SITE_HOST@@/server.txt 2>/dev/null || echo "$SERVER")"
# >>> PASTA DO JOGO: edite a linha abaixo para mudar (ex.: DIR="/mnt/jogos/doom") <<<
DIR="${DOOM_DIR:-$HOME/Jogos/doom}"
ZAN_URL="https://zandronum.com/downloads/zandronum3.2.1-linux-x86_64.tar.bz2"
FD_URL="https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip"

baixar() {  # baixar URL ARQUIVO
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

# o Zandronum traz a libfmod na propria pasta
export LD_LIBRARY_PATH="$DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

FALTAM=$(ldd ./zandronum | awk '/not found/ {print $1}')
if [ -n "$FALTAM" ]; then
  echo "ERRO: faltam bibliotecas no seu sistema:"; echo "$FALTAM"
  echo "Instale-as pelo gerenciador de pacotes da sua distro (procure pelo nome acima) e rode de novo."
  exit 1
fi

echo ">> Instalado em $DIR"
[ "${DOOM_NO_LAUNCH:-0}" = 1 ] && exit 0
echo ">> Entrando em $SERVER ..."
exec ./zandronum -iwad freedoom2.wad +connect "$SERVER"
