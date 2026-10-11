# doom-server — servidor Zandronum (Doom multiplayer)

Servidor de deathmatch do Doom em Docker, com relay UDP (playit.gg), site/tutorial e controle rápido de WAD, mapa e monstros.

## Estrutura
| Arquivo | Para quê |
|---|---|
| `docker-compose.yml` | `sala1` (Zandronum + site) e `playit` (relay UDP). Containers `game-doom-server` e `game-doom-playit` |
| `Dockerfile`, `start.sh`, `httpd.conf` | Imagem do servidor: Zandronum + `busybox httpd` (site na 36921) |
| `sala.sh` | Controle da sala (veja abaixo); instalado como `doom-sala` (symlink em `~/.local/bin`) |
| `site-src/` | Modelo do site (tutorial): `index.html`, `win.ps1`, `linux.sh`, `server.txt`, `cgi-bin/sala` (estado da sala em JSON), com marcadores `@@...@@` |
| `render.sh` | Aplica o `.env`: gera `site/` (fora do git) a partir de `site-src/` e grava `sv_hostname`/`sv_motd` no `sala1.cfg` real |
| `configs/sala1.cfg` | Cópia da config da sala (a real fica em `$DOOM_DADOS/configs/`) |
| `docs/` | Documentação detalhada e guia para jogadores |
| `.env` | `SECRET_KEY` do playit, `DOOM_DADOS` (pasta de dados) e dados públicos do site: `DOOM_SITE_HOST`, `DOOM_PUBLIC_ADDR`, `DOOM_PUBLIC_IP_ADDR`, `DOOM_OWNER`, `DOOM_SALA_NOME`, `DOOM_SALA_MOTD` (nome e mensagem de entrada da sala) (**fora do git**; modelo em `.env.example`) |

## Portas
UDP **36920** (jogo, via relay playit) · TCP **36921** (site, via Cloudflare Tunnel). O endereço público do jogo é o do túnel configurado no playit.

## Controle da sala (`doom-sala`)
```
doom-sala                          # estado atual
doom-sala doom2 MAP07              # WAD + mapa
doom-sala MAP05                    # só o mapa
doom-sala monstros off             # liga/desliga monstros
doom-sala udmx MAP12 monstros off  # combinado
doom-sala --help
```
WADs: `doom doom2 tnt plutonia freedoom1 freedoom2 sigil sigil2 nerve masterlevels` e pacotes de deathmatch `udmx udm1 vodm finalfrg aeondm`. Cada troca recria a sala (derruba os conectados). Escreve `site/sala.txt` com o pacote atual.

## Site
- `https://<seu-domínio>/` — tutorial e **"Sala agora"** (WAD, mapa, monstros e limites em tempo real, via `/cgi-bin/sala`, que lê o processo, o `sala1.cfg` e o log do servidor).
- `https://<seu-domínio>/wad/` — download dos WADs livres (pasta `$DOOM_DADOS/wads-publicos`, montada em `site/wad`). **WADs comerciais não são distribuídos.**

## Dados fora do repositório
`$DOOM_DADOS/`: `wads/` (IWADs/PWADs, incluindo comerciais), `wads-publicos/`, `configs/`, `logs/`. O Zandronum exige o mesmo hash de IWAD no cliente (o `doom2.wad` é o v1.9, MD5 `25e1459ca71d321525f84628f45ca8cd`).

## Acesso externo (playit.gg)
Agente `game-doom-playit` (network_mode host, secret em `.env`). Túnel UDP -> `127.0.0.1:36920`, Proxy Protocol desligado. O Cloudflare Tunnel não leva UDP.

## Instalação rápida
1. `cp .env.example .env` e preencha (`SECRET_KEY` do playit, `DOOM_DADOS` e os dados do site).
2. Coloque `doom2.wad` etc. em `$DOOM_DADOS/wads`, a config em `$DOOM_DADOS/configs/sala1.cfg` (modelo em `configs/`, com `@@SALA_NOME@@`/`@@SALA_MOTD@@`; o `render.sh` preenche) e crie `logs/` (`chmod 777`).
3. `./render.sh && docker compose up -d --build`.
4. Opcional: `ln -s $PWD/sala.sh ~/.local/bin/doom-sala`.
