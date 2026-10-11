#!/usr/bin/env bash
# Aplica o .env: (1) gera site/ (servido pelo container) a partir de site-src/, trocando os @@PLACEHOLDERS@@;
# (2) grava sv_hostname e sv_motd no sala1.cfg real ($DOOM_DADOS/configs). Rode depois de editar site-src/ ou o .env.
# O site nao precisa de restart; mudar nome/mensagem da sala exige 'docker compose restart sala1' (derruba os conectados).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
set -a; . ./.env; set +a
: "${DOOM_SITE_HOST:?defina no .env}" "${DOOM_PUBLIC_ADDR:?}" "${DOOM_PUBLIC_IP_ADDR:?}" "${DOOM_OWNER:?}" "${DOOM_DADOS:?}" "${DOOM_SALA_NOME:?}" "${DOOM_SALA_MOTD:?}"
mkdir -p site/wad
# copia tudo, preservando o que e gerado em runtime (sala.txt) e o ponto de montagem de wad/
find site -mindepth 1 -maxdepth 1 ! -name wad ! -name sala.txt -exec rm -rf {} +
cp -a site-src/. site/
find site -type f \( -name '*.html' -o -name '*.sh' -o -name '*.ps1' -o -name '*.txt' \) ! -path 'site/cgi-bin/*' -exec sed -i \
  -e "s|@@SITE_HOST@@|${DOOM_SITE_HOST}|g" \
  -e "s|@@PUBLIC_ADDR@@|${DOOM_PUBLIC_ADDR}|g" \
  -e "s|@@PUBLIC_IP_ADDR@@|${DOOM_PUBLIC_IP_ADDR}|g" \
  -e "s|@@OWNER@@|${DOOM_OWNER}|g" \
  -e "s|@@SALA_NOME@@|${DOOM_SALA_NOME}|g" {} +
echo "site/ gerado de site-src/"
# nome e mensagem da sala no cfg real (so essas linhas; o resto do cfg, como monstros/exit, e mantido)
cfg="$DOOM_DADOS/configs/sala1.cfg"
sed -i -e "s|^sv_hostname .*|sv_hostname \"${DOOM_SALA_NOME}\"|" -e "s|^sv_motd .*|sv_motd \"${DOOM_SALA_MOTD}\"|" "$cfg"
echo "sala1.cfg: $(grep -E '^sv_(hostname|motd)' "$cfg" | tr '\n' ' ')"
