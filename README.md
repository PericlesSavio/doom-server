**English** · [Português](README.pt-BR.md)

# doom-server — Zandronum server (multiplayer Doom)

A Doom deathmatch server in Docker, with a UDP relay (playit.gg), a tutorial website and quick control of WAD, map and monsters.

## Layout
| File | Purpose |
|---|---|
| `docker-compose.yml` | `sala1` (Zandronum + website) and `playit` (UDP relay). Containers `game-doom-server` and `game-doom-playit` |
| `Dockerfile`, `start.sh`, `httpd.conf` | Server image: Zandronum + `busybox httpd` (website on 36921) |
| `sala.sh` | Room control (see below); installed as `doom-sala` (symlink in `~/.local/bin`) |
| `site-src/` | Website template (tutorial): `index.html`, `win.ps1`, `linux.sh`, `server.txt`, `cgi-bin/sala` (room state as JSON), with `@@...@@` placeholders |
| `render.sh` | Applies `.env`: builds `site/` (not in git) from `site-src/` and writes `sv_hostname`/`sv_motd` into the real `sala1.cfg` |
| `configs/sala1.cfg` | Copy of the room config (the real one lives in `$DOOM_DADOS/configs/`; template with `@@SALA_NOME@@`/`@@SALA_MOTD@@`, filled by `render.sh`) |
| `docs/` | Full documentation and a player guide, in English (`*.md`) and Portuguese (`*.pt-BR.md`) |
| `.env` | playit `SECRET_KEY`, `DOOM_DADOS` (data folder), website values `DOOM_SITE_HOST`, `DOOM_PUBLIC_ADDR`, `DOOM_PUBLIC_IP_ADDR`, `DOOM_OWNER`, and the room name/welcome message `DOOM_SALA_NOME`, `DOOM_SALA_MOTD` (**not in git**; template in `.env.example`) |

## Ports
UDP **36920** (game, through the playit relay) · TCP **36921** (website, through a Cloudflare Tunnel). The public game address is the one of the tunnel configured in playit.

## Room control (`doom-sala`)
```
doom-sala                          # current state
doom-sala doom2 MAP07              # WAD + map
doom-sala MAP05                    # map only
doom-sala monstros off             # monsters on/off ("monstros" = monsters)
doom-sala udmx MAP12 monstros off  # combined
doom-sala --help                   # help (in Portuguese)
```
WADs: `doom doom2 tnt plutonia freedoom1 freedoom2 sigil sigil2 nerve masterlevels` and the deathmatch packs `udmx udm1 vodm finalfrg aeondm`. Every change recreates the room (connected players are dropped). It writes `site/sala.txt` with the current pack.

## Website
- `https://<your-domain>/` — tutorial and **"Sala agora"** (current WAD, map, monsters and limits in real time, through `/cgi-bin/sala`, which reads the process, `sala1.cfg` and the server log).
- `https://<your-domain>/wad/` — download of the freely distributable WADs (`$DOOM_DADOS/wads-publicos`, mounted at `site/wad`). **Commercial WADs are not distributed.**

The website text is in Portuguese.

## Data outside the repository
`$DOOM_DADOS/`: `wads/` (IWADs/PWADs, including commercial ones), `wads-publicos/`, `configs/`, `logs/`. Zandronum requires the same IWAD hash on the client (`doom2.wad` is v1.9, MD5 `25e1459ca71d321525f84628f45ca8cd`).

## External access (playit.gg)
`game-doom-playit` agent (host networking, secret in `.env`). UDP tunnel -> `127.0.0.1:36920`, Proxy Protocol off. A Cloudflare Tunnel cannot carry UDP.

## Quick start
1. `cp .env.example .env` and fill it in (playit `SECRET_KEY`, `DOOM_DADOS` and the website values).
2. Put `doom2.wad` etc. in `$DOOM_DADOS/wads`, the config in `$DOOM_DADOS/configs/sala1.cfg` (template in `configs/`) and create `logs/` (`chmod 777`).
3. `./render.sh && docker compose up -d --build`.
4. Optional: `ln -s $PWD/sala.sh ~/.local/bin/doom-sala`.
