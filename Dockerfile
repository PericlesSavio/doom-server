FROM rcdailey/zandronum-server:official-latest
# Site de tutorial (busybox httpd, leve) + servidor Zandronum no mesmo container.
RUN apt-get update && apt-get install -y --no-install-recommends busybox-static \
    && rm -rf /var/lib/apt/lists/*
COPY httpd.conf /etc/httpd.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh
ENTRYPOINT ["tini", "--", "/start.sh"]
