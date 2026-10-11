**English** · [Português](doom-zandronum.pt-BR.md)

# Doom Server (Zandronum) — Docker + playit.gg relay

_Created 2026-10-10, revised 2026-10-11. Repository: `este repositório` (this repository; copy of this doc in `docs/`). Real state: `docker ps`, `~/Servidor/36xxx/doom/docker-compose.yml`. This doc is history/explanation._

## Summary
Multiplayer Doom (Zandronum) server in a container, for rooms of up to 16 players with community WADs (ZDaemon style from the 2000s). The game uses **UDP**, which the Cloudflare Tunnel (`<tunel>`) does not carry; external access goes through an **outbound UDP relay (playit.gg)**, with no Tailscale and no router changes.

## Architecture
```
jogador --UDP--> <endereço-público> (playit, free network, Brazil region)
              --> agente game-doom-playit (host) --> 127.0.0.1:36920 --> container game-doom-server
```
(jogador = player; agente = agent)

| Piece | Detail |
|---|---|
| Project | `~/Servidor/36xxx/doom/` (compose, Dockerfile, `sala.sh`, `site/`, README, `.env`, `.env.example`, `.gitignore`); git repo `este repositório` (branch `main`) |
| Data | `~/Servidor/Dados/doom/wads/` (IWADs/PWADs, ro), `.../configs/<sala>.cfg` (ro), `.../wads-publicos/` (free WADs served at `/wad`, ro) and `.../logs/` (server log, rw) |
| Room 1 (test) | container `game-doom-server`, image `rcdailey/zandronum-server:official-latest` (Zandronum 3.2.1), UDP **36920** |
| Relay | container `game-doom-playit`, image `ghcr.io/playit-cloud/playit-agent:1.0`, `network_mode: host` |
| Limits | sala1: 256 MB / 0.5 CPU; playit: 128 MB / 0.25 CPU (actual use ~22 MB and ~15 MB) |
| Dashboard | "Doom (Zandronum)" card in the Jogos (Games) group (`services.json`, port 36921, public `<seu-domínio>`) |
| Hostname in the Cloudflare tunnel | `<seu-domínio>` -> 36921 (site only; the game is UDP and does not pass through) |

(sala = room)

## Room 1 — current config (2026-10-11)
`doom2.wad` v1.9 + `udmx` package (switch with `doom-sala`), deathmatch, 16 players, timelimit 10 / fraglimit 30, no password, `sv_hostname "Frendner - Sala 1 (teste)"`, `sv_updatemaster 1`, `sv_noexit 1` (anyone who tries to exit the map dies) and monsters on (`sv_nomonsters 0`). What counts is the compose `command` + `sala1.cfg`; real-time state is at `https://<seu-domínio>/cgi-bin/sala`.

## Operation
- Start/apply changes: `cd ~/Servidor/36xxx/doom && docker compose up -d` (recreates the room and drops connected players).
- Logs: `docker logs game-doom-server`, `docker logs game-doom-playit` (the agent should show `tunnel_count=1`, `account_status="verified"`).
- **Change WAD / map / monsters (quick):** `~/Servidor/36xxx/doom/sala.sh` (merge of the former `mapa.sh` and `iwad.sh`, 2026-10-11; both were removed). With no arguments it shows the state. Examples: `./sala.sh doom2 MAP07`, `./sala.sh MAP05`, `./sala.sh monstros off`, `./sala.sh sigil sem-monstros`; also available as the global command `doom-sala` (symlink in `~/.local/bin`), and `doom-sala --help`/`-h`/`ajuda` shows the help in Portuguese. (`monstros` = monsters, `sem-monstros` = no monsters, `ajuda` = help.) Arguments can be combined in any order. WADs: doom doom2 tnt plutonia freedoom1 freedoom2 sigil sigil2 nerve masterlevels + deathmatch packages `udmx` (32 maps), `udm1` (16), `vodm` (Vignettes of Deathmatch, 23), `finalfrg` (Final Frag, 32) and `aeondm` (AeonDM, 33 maps `AEON01..AEON33`, 89 MB pk3, Zandronum only). All load on top of `doom2.wad` with `-file`. PWADs become `-iwad` base + `-file` (sigil/sigil2 → doom.wad; nerve/masterlevels → doom2.wad; automatic start map E5M1/E6M1/MAP01). It rewrites the compose `command` block and recreates `sala1` (drops connected players). Monsters = `sv_nomonsters 0|1` in `Dados/doom/configs/sala1.cfg`. Tested 2026-10-11 (nerve MAP03, monsters off/on, back to freedoom2). The `map` in `sala1.cfg` is ignored at boot; the map is passed via `+map`.
- **Client and WADs:** the site and client scripts only download Freedoom. With commercial WADs (doom2, tnt, plutonia, sigil, nerve...), each player must have their own files (not distributable); sigil/nerve/masterlevels also require `-file` on the client.
- **Change WAD/map:** edit the room's `command` in the compose file (`-iwad /data/<iwad>.wad`, one `-file /data/<pwad>.wad` per PWAD) and the `map` in the `.cfg`; then `docker compose up -d`. IWAD = base game (only one; players need the same one). `nerve.wad` and `masterlevels.wad` require `doom2.wad`; `sigil*.wad` require `doom.wad`.
- **New room:** new service in the compose file (own UDP port, own `.cfg`, memory/CPU limits) + new UDP tunnel in the playit dashboard (`127.0.0.1:<porta>`; porta = port) + entries in `portas.md`, `ORGANIZACAO-CONTAINERS.md` and the dashboard.
- Connect (Zandronum client, console `~`): `connect <endereço-público>` (alternative IP `<ip-público>:<porta>`).

## Map rotation (tested 2026-10-10)
Tested in throwaway containers (own port, `docker run -i`, `nextmap` console command to simulate the end of the match; the `timelimit` clock only runs with players). Actual result, Freedoom 2:

| Mode | Config in `sala1.cfg` | Observed behavior |
|---|---|---|
| **Sequential (current)** | no list | MAP01 → MAP02 → MAP03 → MAP04 → MAP05… (follows the WAD order) |
| **Ordered list** | `clearmaplist`, `addmap MAP07`, `addmap MAP15`, `addmap MAP20`, `sv_maprotation 1` | MAP07 → MAP15 → MAP20 → back to MAP07 |
| **Random list** | the list above + `sv_randommaprotation 1` | picks among the maps in the list (saw 6, 8, 2, 4, 8, 6; never the same twice in a row) |
| **Fixed map** | `clearmaplist`, `addmap MAP10`, `sv_maprotation 1` | always reloads the same map |

- **Choosing specific maps:** that is the list itself — one `addmap <map>` per map, in the desired order (`MAPxx` in Doom 2/Freedoom 2/TNT/Plutonia; `ExMy` in `doom.wad`/`freedoom1.wad`). The maps must exist in the chosen IWAD (E1M1 does not exist in `doom2.wad`/`freedoom2.wad`). Map PWADs (`-file`) have their maps listed in the WAD itself.
- **How to apply:** edit `~/Servidor/Dados/doom/configs/sala1.cfg` (put the lines next to `timelimit`/`fraglimit`) and restart: `docker restart game-doom-server` (the cfg is mounted ro and re-read at boot; no `compose up` needed). To go back to sequential, delete the list lines.
- **When the map changes:** on reaching `timelimit 10` (minutes) or `fraglimit 30`, the scoreboard shows and the next map loads.
- **Interaction with `+map` / `sala.sh`:** with an active maplist the server **starts on the first map of the list** and ignores the compose `+map` (observed: `+map MAP01` with a list starting at MAP07 came up on MAP07). So `sala.sh` only applies in sequential mode; with a list, change the list's order/items. Without a list, `+map` sets the starting map and it proceeds sequentially from there.
- **Where the cfg `map` does not apply:** the `map MAP01` line in `sala1.cfg` is ignored at boot (only the compose `+map` counts).
- **Pending:** the room currently runs without a list (sequential). For fixed, random or selected-only rotation, apply one of the configs above; a script (`mapas.sh MAP07 MAP15 …`) does not exist yet.

## playit.gg — account and tunnel
- Agent "doom-server" (id `<id>`), custom UDP tunnel → `127.0.0.1:36920`, **Proxy Protocol off** (Zandronum does not understand it), IPv6 off.
- Tunnel dashboard (login required): https://playit.gg/account/tunnels (added 2026-10-10, link provided by the user).
- The **secret key** lives only in `~/Servidor/36xxx/doom/.env` (chmod 600, outside git).
- The agent only re-reads the account status on reconnect (after verifying the email the container had to be recreated).
- Free network: the address belongs to the playit domain, and the port may change if the tunnel is recreated. The premium network lets you choose the region.

## Limitations and caveats
- **Player IPs in the log:** with the port published by Docker (NAT), the server sees everyone as the gateway `192.168.208.1` ("from: LAN"). This hampers IP bans and telling players apart; solution if it becomes a problem: `network_mode: host` on the room.
- **Public list (master server):** not confirmed whether the room shows up (the announced IP/port may be the local ones, not the relay's). Plan B: advertise the direct address; plan C: cheap VPS as the entry point.
- **Relay validation:** the log only proved a connection (from inside the home network). A test from outside the network is still missing.
- **Commercial WADs** (`doom*.wad`, `plutonia`, `tnt`, `nerve`, `masterlevels`, `sigil*`): each player must have their own; **do not serve over HTTP** to players. The planned WAD download server (e.g. `<seu-domínio>` through the Cloudflare tunnel) must only serve community WADs and Freedoom.
- **Browser (doom-wasm)** was discarded: WebSocket/TCP, ~4 players, no mods.

## Next steps
1. Test from outside the network and check whether the room shows up in the launcher.
2. Switch the room to the chosen IWAD/PWAD (WADs are already in `Dados/doom/wads/`).
3. HTTP server for community WADs (automatic download by Zandronum).
4. More rooms (one per WAD/mode); regenerate the playit key.

## History — what was done (2026-10-10)
**Decisions**
1. Feasibility: Docker 29.7 / Compose 5.5, 15 GB RAM (11 GB free), 12 CPUs, port 10666 free → possible.
2. External access without Tailscale and without the router: Cloudflare Tunnel only carries HTTP/TCP (Spectrum/UDP is Enterprise). Doom in the browser (doom-wasm, WebSocket) was evaluated: discarded because it is TCP, ~4 players and no mods. Final requirement: 16-player rooms with community WADs → Zandronum + outbound UDP relay (playit.gg). Plan B: cheap VPS.
3. Chosen image: `rcdailey/zandronum-server:official-latest` (updated 2026-02-12, 561k pulls). Alternatives seen: `frozenfoxx/zandronum` (client via VNC), `ich777/zandronum` (Unraid-focused).
4. Port 36920/UDP (games range 279xx; 27910 was already used by cantuxrunit). Network in bridge with published port (not host) → see the IP limitation in the log.

**Execution**
1. Downloaded Freedoom 0.13.0 from GitHub (zip in an isolated directory, only `freedoom1.wad`/`freedoom2.wad` extracted) to `Dados/doom/wads/`.
2. Created `Dados/doom/configs/sala1.cfg` and `27xxx/doom/docker-compose.yml` (memory/CPU limits, label `category: jogos`, ro volumes). The room came up and opened UDP 36920.
3. Fix: the `gamemode` command does not exist in Zandronum → replaced by `deathmatch 1`; no more errors in the log.
4. Dashboard card (`services.json`, Jogos group) and entries in `portas.md` and `ORGANIZACAO-CONTAINERS.md`; README in the project.
5. playit.gg account created by the user; agent via Docker (`game-doom-playit`) with the secret key in `.env` (chmod 600, `.gitignore`, `.env.example` without the secret). The agent only reached `account_status="verified"` after recreating the container (it only re-reads on reconnect).
6. UDP tunnel created in the playit dashboard: `127.0.0.1:36920`, Proxy Protocol off → `<endereço-público>` (`tunnel_count=1`).
7. The user connected with Zandronum 3.2.1 (log: `Connect (v3.2.1)`, `Player joined the game`; origin seen as `192.168.208.1`, "LAN").
8. The user added commercial WADs to `Dados/doom/wads/`: `doom`, `doom2`, `plutonia`, `tnt`, `nerve`, `masterlevels`, `sigil`, `sigil2` (the room still runs `freedoom2.wad`).
9. An end-to-end test with a raw UDP packet proves nothing (Zandronum ignores packets outside the Huffman protocol); real validation needs a client.

**Files touched**
`Servidor/36xxx/doom/*`, `Servidor/Dados/doom/*`, `Servidor/27xxx/painel/site/services.json`, `Infra/portas.md`, `Infra/ORGANIZACAO-CONTAINERS.md`, this doc and the index in `~/.claude/CLAUDE.md`.
- Player guide: `doom-como-entrar.md` (how to join).

## Linux client — dependencies (verified 2026-10-10)
The `zandronum3.2.1-linux-x86_64` binary requires `libSDL-1.2.so.0` and `libjpeg.so.8` (`ldd`); `libfmodex64` ships in the tarball (use `LD_LIBRARY_PATH`). Debian 13 has no `libjpeg.so.8` (only `.62`) — it works on Ubuntu/Mint (`libsdl1.2debian libjpeg-turbo8`) and Arch (AUR). The `doom-como-entrar.md` guide has copy/paste scripts (Windows PowerShell and Linux bash); the Linux one was tested only up to download/extraction/lib checks, the Windows one was not tested.

## Rename (2026-10-10)
Container `doom-sala1` renamed to `game-doom-server` (`container_name` in the compose file; the service is still `sala1`, the `.cfg` is still `sala1.cfg`). Room restarted (drops connected players). Mentions of `doom-sala1` in the history above are the old name.

## Site / tutorial — <seu-domínio> (2026-10-10)
- **A single container** (`game-doom-server`): custom image (`Dockerfile` in `Servidor/36xxx/doom/`, based on `rcdailey/zandronum-server`) with `busybox httpd` on port **36921** (TCP) + Zandronum on UDP 36920. `start.sh` starts the site and does `exec /entrypoint.sh` (Zandronum stays the main process under tini).
- Content: `Servidor/36xxx/doom/site/` mounted ro (editing needs no restart): `index.html` (tutorial, copy buttons, Windows/Linux tabs), `server.txt` (**game address — the only place to edit when playit changes**; the page and scripts read from it), `win.ps1` and `linux.sh` (served scripts).
- Usage by players: Windows `irm https://<seu-domínio>/win.ps1 | iex`; Linux `curl -fsSL https://<seu-domínio>/linux.sh | bash`.
- Tunnel: ingress `<seu-domínio> → http://127.0.0.1:36921` in `~/.cloudflared/config.yml` (between cine and frendnerbet since 2026-10-11; backup `config.yml.bak.20261010`), CNAME created with `cloudflared tunnel route dns <tunel> <seu-domínio>`. **Requires `sudo systemctl restart <servico-do-tunel>.service` to take effect.** Dashboard card updated (port 36921, public).
- Room mode: explicit free-for-all deathmatch (`teamplay 0`, `ctf 0`, other modes 0), applied with no errors in the log.
- Pending: live status on the page (players/map), not done yet; changing the scripts also requires checking the blocks in `doom-como-entrar.md`.

## Windows — tested (2026-10-10)
`irm https://<seu-domínio>/win.ps1 | iex` / the `doom-como-entrar.md` block ran in PowerShell without admin and joined the server. Bug found in testing: `zandronum.com` uses the **Anubis** anti-bot and serves an HTML page ("Making sure you're not a bot!") to PowerShell's default User-Agent (which contains `Mozilla/5.0`), causing "Central Directory end record not found" in `Expand-Archive` (the original message was in Portuguese). Fixed with `-UserAgent 'curl/8.4.0'` + a check of the `PK` bytes. If Zandronum changes this protection, the script warns with a manual link. Linux (`curl`/`wget`) is not affected.

## /wad route — removed (2026-10-10)
The hidden route `<seu-domínio>/wad/` (Freedoom, hardlinks in `Dados/doom/wad-publico/`) was **removed** on request: mount taken out of the compose file, folders deleted (originals in `Dados/doom/wads/` intact). Commercial WADs are not published through the server (redistributing copyrighted content; a password or "hidden" does not change that).


## Port change (2026-10-11)
Project moved from `Servidor/27xxx/doom` to `Servidor/36xxx/doom`; ports 27920/UDP → **36920/UDP** (game) and 27921/TCP → **36921/TCP** (site). Cloudflare ingress and dashboard card updated. **Pending:** in the playit dashboard, change the UDP tunnel destination to `127.0.0.1:36920`; and `sudo systemctl restart <servico-do-tunel>.service` for the ingress to take effect.

## Deathmatch packages (2026-10-11)
Downloaded from the idgames mirror (`mirrors.lug.mtu.edu/idgames/levels/doom2/deathmatch/...`) to `Dados/doom/wads/`: `udmx.wad` (21 MB), `udm1.wad` (6.6 MB), `vodm.wad` (7.9 MB), `finalfrg.wad` (3 MB; it is `FF_PART1.WAD` from the zip), `aeondm.pk3` (89 MB). Tested: all come up on MAP01 (AEON01 for AeonDM) with no errors. Profiles in `sala.sh`. The name "entryway" on MAP01 of UDM1/Final Frag is the default Doom 2 name (the WADs do not define their own). Not downloaded: `dk_dm_3f` (DoomKid, no direct link). **Clients** need the same files (the site only distributes Freedoom); idgames links in the research section above. UDMX/Vignettes use resources that require an engine with limit removing (fine in Zandronum).

## /wad route on the site (2026-10-11)
`https://<seu-domínio>/wad/` serves the free WADs + a page with instructions (where to put the files, download commands for Windows/Linux). Source: `Dados/doom/wads-publicos/` (**hardlinks** to the files in `Dados/doom/wads/`: udmx, udm1, vodm, finalfrg, aeondm; plus the route's `index.html`), mounted ro at `/srv/site/wad` in the container (`docker-compose.yml`; the empty folder `36xxx/doom/site/wad` exists only as a mount point — Docker does not create a mountpoint inside a ro volume). `httpd.conf` gained `.wad`/`.pk3` → `application/octet-stream` (required `docker compose up -d --build`). Link added to `site/index.html`.
- **Do not expose commercial WADs** (doom, doom2, tnt, plutonia, nerve, masterlevels, sigil): hence the separate folder instead of mounting all of `wads/`.
- **Adding a new WAD:** copy it to `Dados/doom/wads/`, `ln -f wads/<arq> wads-publicos/<arq>` (arq = file) and add a row to the table in `wads-publicos/index.html` (and the profile in `sala.sh`). A hardlink breaks if the source file is replaced by another one (redo the `ln -f`).
- Game folder on clients: Windows `%USERPROFILE%\Doom`, Linux `~/Jogos/doom` (the installer's); files live next to the executable and `doom2.wad`.
- Tested: `/wad`, `/wad/udmx.wad` (21 MB), `/wad/aeondm.pk3` (89 MB, exact size) and externally via Cloudflare. AeonDM (89 MB) consumes home upload bandwidth on each download.

## Hash error and doom2.wad swap (2026-10-11)
A client (fedora, `/mnt/ssd_250_samsung/Jogos/Doom/wads/`) got a hash error when connecting with UDMX. Cause: the server's `doom2.wad` (`64a4c88a871da67492aaa2020a068cd8`, 14,951,361 bytes) differed from the fedora's (`25e1459ca71d321525f84628f45ca8cd`, 14,604,584 bytes, the original Doom 2 v1.9). `doom.wad`, `tnt`, `plutonia`, `nerve`, `masterlevels`, `sigil`, `sigil2`, `freedoom2` and `udmx` were already identical on both. **The server now uses the `doom2.wad` v1.9** (copied from fedora via scp; the old one stayed as `Dados/doom/wads/doom2.wad.bak`). Zandronum requires the same IWAD hash on the client: anyone with another Doom 2 version gets a hash error.
- **Pitfall:** replacing a WAD *at the same path* does not make `docker compose up -d` recreate the container (the compose file did not change) — the process keeps the old file in memory. Use `docker compose restart sala1`.
- Server access to fedora: SSH key login enabled today (`sshd` on in fedora, the Debian key in `authorized_keys`).

## Fedora client: organization and `jogar.sh -p` (2026-10-11)
- The "Doom (servidor)" shortcut (server) used `-i freedoom2.wad`, but the server runs doom2 + package → error "Missing file(s) / protected lump authentication failed". Fixed: `jogar.sh -p auto -s <endereço-público>`.
- `jogar.sh` (fedora, `/mnt/ssd_250_samsung/Jogos/Doom/`; jogar = play) gained `-p NOME` (NOME = name; packages identical to the `sala.sh` profiles; `-p auto` reads `https://<seu-domínio>/sala.txt`, which `doom-sala` writes to `site/sala.txt` on each switch) and now searches for files in all subfolders of `wads/`. `JOGAR_DRY=1` only prints the command. Backup: `jogar.sh.bak.20261011`.
- The fedora `wads/` folder was reorganized: `comerciais/` (commercial: doom, doom2, tnt, plutonia, nerve, masterlevels, sigil*, id1*, id24res, extras, iddm1), `outros/` (other: freedoom, DM packages, gothicdm), `baixadas/` (downloaded: Doomseeker), `antigos/` (old); `LEIAME.md` (README) there explains. `dados/zandronum.ini` gained the paths (backup `.bak.20261011b`). The server was **not** reorganized (still flat in `Dados/doom/wads`).
- **Pitfall:** `doom.desktop` with `-p auto` depends on the site being up; if `sala.txt` does not respond, the script warns and exits.

## Exit disabled (2026-10-11)
Any player could end the map by touching the exit switch (`dmflags 0`). Added `sv_noexit 1` at the end of `Dados/doom/configs/sala1.cfg` (backup `sala1.cfg.bak.20261011`). `sv_noexit` is a cvar flag of `dmflags` (`DF_NO_EXIT = 1<<10 = 1024`, confirmed in the Zandronum source, `src/d_main.cpp` and `src/doomdef.h`): **anyone who tries to exit the map dies** (it does not merely ignore the switch). The map changes only by `timelimit 10`, `fraglimit 30` or `doom-sala`. Same mechanism as `sv_nomonsters` (bit 4096): both are `dmflags` flags, so they must come **after** the `dmflags 0` line in the cfg (otherwise it zeroes the bits). To return to normal: `sv_noexit 0`.

## Real-time site: "Sala agora" (2026-10-11)
`<seu-domínio>` has the **Sala agora** ("Room now") section (WAD/package, map with name, monsters, exit, limits and required files with links to `/wad/`), refreshed every 10 s, and the header shows the current map. Source: `site/cgi-bin/sala` (sh script, `busybox httpd` CGI, run as `nobody`): reads `/proc/<pid>/cmdline` of `zandronum-server` (IWAD and `-file`), `/configs/sala1.cfg` (monsters, exit, limits, hostname) and the server log (last `*** MAPxx: name ***`, which also tracks automatic map changes by time/frags). Zandronum writes the log via `+logfile /logs/sala.log` (compose), but creates `sala.log__YYYY_MM_DD-HH_MM_SS.log` **on every boot**; `start.sh` deletes the previous ones and the CGI uses the most recent. Each log line has a `[HH:MM:SS]` prefix. Editing the CGI/`index.html` needs no restart (ro volume); changing `start.sh` requires `docker compose up -d --build sala1`. Test: `curl http://127.0.0.1:36921/cgi-bin/sala`. `doom-sala` also writes `site/sala.txt` (package name; used by fedora's `jogar.sh -p auto`; file ignored by git).
