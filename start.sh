#!/usr/bin/env bash
# Sobe o site (porta 36921, usuario sem privilegio) e entrega o controle ao entrypoint do Zandronum.
# o log do servidor (/logs/sala.log__*.log) alimenta o endpoint /cgi-bin/sala (mapa atual); limpo a cada boot.
rm -f /logs/sala.log*   # o Zandronum cria sala.log__<data>.log a cada boot; limpa os anteriores
busybox httpd -p 36921 -h /srv/site -c /etc/httpd.conf -u nobody
exec /entrypoint.sh "$@"
