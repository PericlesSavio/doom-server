#!/bin/bash
# Controle rapido da sala de Doom: WAD, mapa e monstros. Recria a sala (derruba os conectados).
#   ./sala.sh -h | --help | ajuda  ajuda detalhada em portugues
#   ./sala.sh                    mostra o estado e os WADs
#   ./sala.sh doom2              troca o WAD (mapa inicial automatico)
#   ./sala.sh doom2 MAP07        WAD + mapa
#   ./sala.sh MAP07              so o mapa (E1M3 tambem vale)
#   ./sala.sh monstros off|on    desliga/liga monstros (tambem: sem-monstros / com-monstros)
#   ./sala.sh sigil sem-monstros E5M2   argumentos podem ser combinados, em qualquer ordem
cd "$(dirname "$(readlink -f "$0")")" || exit 1
DADOS="${DOOM_DADOS:-$HOME/Servidor/Dados/doom}"
WADS="$DADOS/wads"
CFG="$DADOS/configs/sala1.cfg"

# WAD -> "iwad|pwad|mapa inicial". PWADs (sigil, nerve...) precisam de um IWAD base.
perfil() {
  case "$1" in
    doom|doom2|tnt|plutonia|freedoom1|freedoom2)
      case "$1" in doom|freedoom1) m=E1M1;; *) m=MAP01;; esac; echo "$1.wad||$m";;
    sigil)        echo "doom.wad|sigil.wad|E5M1";;
    sigil2)       echo "doom.wad|sigil2.wad|E6M1";;
    nerve)        echo "doom2.wad|nerve.wad|MAP01";;
    masterlevels) echo "doom2.wad|masterlevels.wad|MAP01";;
    # pacotes de deathmatch (baixados do idgames em 11/10/2026)
    udmx|udm1|vodm|finalfrg) echo "doom2.wad|$1.wad|MAP01";;
    aeondm)       echo "doom2.wad|aeondm.pk3|AEON01";;
    *) return 1;;
  esac
}
nome_atual() {  # descobre o nome "amigavel" a partir do compose
  local i p; i=$(grep -oE '\-iwad /data/\S+' docker-compose.yml | sed 's|.*/data/||;s|\.wad||')
  p=$(grep -oE '\-file /data/\S+' docker-compose.yml | sed 's|.*/data/||;s|\.wad||')
  echo "${p:-$i}"
}
mapa_atual()     { grep -oE '^\s+\+map \S+' docker-compose.yml | awk '{print $2}'; }
monstros_atual() { grep -qE '^sv_nomonsters\s+1' "$CFG" && echo "DESLIGADOS" || echo "ligados"; }

ajuda() {
  cat <<'H'
doom-sala - controla a sala de Doom (WAD, mapa e monstros)

USO
  doom-sala                          mostra o estado atual e os WADs
  doom-sala <wad>                    troca o WAD (mapa inicial automatico)
  doom-sala <wad> <mapa>             troca WAD e mapa
  doom-sala <mapa>                   troca so o mapa (MAP01..MAP32 ou E1M1..)
  doom-sala monstros on|off          liga/desliga os monstros
  doom-sala sem-monstros             atalho para "monstros off"
  doom-sala com-monstros             atalho para "monstros on"
  doom-sala -h | --help | ajuda      mostra esta ajuda
Os argumentos podem ser combinados, em qualquer ordem.

WADS
  jogo base:  doom doom2 tnt plutonia freedoom1 freedoom2 sigil sigil2 nerve masterlevels
  deathmatch: udmx (32 mapas) udm1 (16) vodm (23) finalfrg (32) aeondm (33, mapas AEON01..AEON33)

EXEMPLOS
  doom-sala doom2 MAP07              Doom 2 no mapa 7
  doom-sala MAP05                    muda so o mapa
  doom-sala monstros off             sem monstros (no mapa atual)
  doom-sala sigil sem-monstros E5M2  Sigil, sem monstros, mapa E5M2
  doom-sala udmx MAP12 monstros off  UDMX, mapa 12, sem monstros
  doom-sala aeondm AEON05            AeonDM no mapa 5

ATENCAO: cada troca recria a sala e derruba quem esta conectado.
H
}

status() {
  echo "WAD:      $(nome_atual)"
  echo "Mapa:     $(mapa_atual)"
  echo "Monstros: $(monstros_atual)"
}

case "$1" in -h|--help|ajuda|help) ajuda; exit 0;; esac
if [ $# -eq 0 ]; then
  status; echo; echo "(use: doom-sala --help para ver os comandos)"; exit 0
fi

wad=; mapa=; mons=
while [ $# -gt 0 ]; do
  a=$(echo "$1" | tr '[:upper:]' '[:lower:]'); a=${a%.wad}; shift
  case "$a" in
    monstros|monsters) b=$(echo "$1" | tr '[:upper:]' '[:lower:]'); shift
      case "$b" in on|sim|1) mons=0;; off|nao|não|0) mons=1;; *) echo "Use: monstros on|off"; exit 1;; esac;;
    sem-monstros|semmonstros) mons=1;;
    com-monstros|commonstros) mons=0;;
    map[0-9][0-9]|aeon[0-9][0-9]|e[0-9]m[0-9]*) mapa=$(echo "$a" | tr '[:lower:]' '[:upper:]');;
    *) perfil "$a" >/dev/null || { echo "Argumento invalido: $a"; exit 1; }; wad=$a;;
  esac
done

if [ -n "$wad" ]; then
  IFS='|' read -r iwad pwad m0 <<< "$(perfil "$wad")"
  for f in "$iwad" $pwad; do [ -f "$WADS/$f" ] || { echo "Nao existe: $WADS/$f"; exit 1; }; done
  [ -n "$mapa" ] || mapa=$m0
else  # mantem o WAD atual
  iwad=$(grep -oE '\-iwad /data/\S+' docker-compose.yml | sed 's|.*/data/||')
  pwad=$(grep -oE '\-file /data/\S+' docker-compose.yml | sed 's|.*/data/||')
  [ -n "$mapa" ] || mapa=$(mapa_atual)
fi

# reescreve o bloco "command" da sala1 no compose
{
  echo "      -port 36920"
  echo "      -iwad /data/$iwad"
  [ -n "$pwad" ] && echo "      -file /data/$pwad"
  echo "      +logfile /logs/sala.log"
  echo "      +exec /configs/sala1.cfg"
  echo "      +map $mapa"
} > .cmd.tmp
awk -v blk="$(cat .cmd.tmp)" '
  /^    command: >/ && !done {print; print blk; skip=1; done=1; next}
  skip && /^    volumes:/ {skip=0}
  !skip {print}' docker-compose.yml > .compose.tmp && mv .compose.tmp docker-compose.yml; rm -f .cmd.tmp

if [ -n "$mons" ]; then
  if grep -qE '^sv_nomonsters' "$CFG"; then sed -i -E "s/^sv_nomonsters.*/sv_nomonsters $mons/" "$CFG"
  else printf '\nsv_nomonsters %s\n' "$mons" >> "$CFG"; fi
fi

docker compose up -d sala1 >/dev/null 2>&1 && nome_atual > site/sala.txt && echo "Sala1 recriada:" && status
