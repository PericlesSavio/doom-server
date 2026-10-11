# Servidor de Doom (Zandronum) — Docker + relay playit.gg

_Criado em 10/10/2026, revisado em 11/10/2026. Repositório: `este repositório` (copia deste doc em `docs/`). Estado real: `docker ps`, `~/Servidor/36xxx/doom/docker-compose.yml`. Este doc é histórico/explicação._

## Resumo
Servidor multiplayer de Doom (Zandronum) em container, para salas de até 16 jogadores com WADs da comunidade (estilo ZDaemon dos anos 2000). O jogo usa **UDP**, que o Cloudflare Tunnel (`<tunel>`) não transporta; o acesso externo é feito por um **relay UDP de saída (playit.gg)**, sem Tailscale e sem mexer no roteador.

## Arquitetura
```
jogador --UDP--> <endereço-público> (playit, rede grátis, região Brasil)
              --> agente game-doom-playit (host) --> 127.0.0.1:36920 --> container game-doom-server
```
| Peça | Detalhe |
|---|---|
| Projeto | `~/Servidor/36xxx/doom/` (compose, Dockerfile, `sala.sh`, `site/`, README, `.env`, `.env.example`, `.gitignore`); repo git `este repositório` (branch `main`) |
| Dados | `~/Servidor/Dados/doom/wads/` (IWADs/PWADs, ro), `.../configs/<sala>.cfg` (ro), `.../wads-publicos/` (WADs livres servidos em `/wad`, ro) e `.../logs/` (log do servidor, rw) |
| Sala 1 (teste) | container `game-doom-server`, imagem `rcdailey/zandronum-server:official-latest` (Zandronum 3.2.1), UDP **36920** |
| Relay | container `game-doom-playit`, imagem `ghcr.io/playit-cloud/playit-agent:1.0`, `network_mode: host` |
| Limites | sala1: 256 MB / 0,5 CPU; playit: 128 MB / 0,25 CPU (uso real ~22 MB e ~15 MB) |
| Painel | card "Doom (Zandronum)" no grupo Jogos (`services.json`, porta 36921, público `<seu-domínio>`) |
| Hostname no tunnel Cloudflare | `<seu-domínio>` -> 36921 (só o site; o jogo é UDP e não passa) |

## Sala 1 — config atual (11/10/2026)
`doom2.wad` v1.9 + pacote `udmx` (troca com `doom-sala`), deathmatch, 16 jogadores, timelimit 10 / fraglimit 30, sem senha, `sv_hostname "Frendner - Sala 1 (teste)"`, `sv_updatemaster 1`, `sv_noexit 1` (quem tenta sair do mapa morre) e monstros ligados (`sv_nomonsters 0`). O que vale é o `command` do compose + `sala1.cfg`; o estado em tempo real está em `https://<seu-domínio>/cgi-bin/sala`.

## Operação
- Subir/aplicar mudanças: `cd ~/Servidor/36xxx/doom && docker compose up -d` (recria a sala e derruba os conectados).
- Logs: `docker logs game-doom-server`, `docker logs game-doom-playit` (o agente deve mostrar `tunnel_count=1`, `account_status="verified"`).
- **Trocar WAD / mapa / monstros (rápido):** `~/Servidor/36xxx/doom/sala.sh` (junção dos antigos `mapa.sh` e `iwad.sh`, 11/10/2026; os dois foram removidos). Sem argumento mostra o estado. Exemplos: `./sala.sh doom2 MAP07`, `./sala.sh MAP05`, `./sala.sh monstros off`, `./sala.sh sigil sem-monstros`; também como comando global `doom-sala` (symlink em `~/.local/bin`) e `doom-sala --help`/`-h`/`ajuda` mostra a ajuda em português. Argumentos combináveis em qualquer ordem. WADs: doom doom2 tnt plutonia freedoom1 freedoom2 sigil sigil2 nerve masterlevels + pacotes de deathmatch `udmx` (32 mapas), `udm1` (16), `vodm` (Vignettes of Deathmatch, 23), `finalfrg` (Final Frag, 32) e `aeondm` (AeonDM, 33 mapas `AEON01..AEON33`, pk3 de 89 MB, só Zandronum). Todos carregam sobre `doom2.wad` com `-file`. PWADs viram `-iwad` base + `-file` (sigil/sigil2 → doom.wad; nerve/masterlevels → doom2.wad; mapa inicial automático E5M1/E6M1/MAP01). Reescreve o bloco `command` do compose e recria a `sala1` (derruba os conectados). Monstros = `sv_nomonsters 0|1` em `Dados/doom/configs/sala1.cfg`. Testado em 11/10/2026 (nerve MAP03, monstros off/on, volta ao freedoom2). O `map` do `sala1.cfg` é ignorado no boot; o mapa vai por `+map`.
- **Cliente e WADs:** o site e os scripts de cliente só baixam o Freedoom. Com WAD comercial (doom2, tnt, plutonia, sigil, nerve...), cada jogador precisa ter os próprios arquivos (não distribuíveis); sigil/nerve/masterlevels também exigem o `-file` no cliente.
- **Trocar WAD/mapa:** editar o `command` da sala no compose (`-iwad /data/<iwad>.wad`, um `-file /data/<pwad>.wad` por PWAD) e o `map` no `.cfg`; depois `docker compose up -d`. IWAD = jogo base (um só; jogadores precisam do mesmo). `nerve.wad` e `masterlevels.wad` exigem `doom2.wad`; `sigil*.wad` exigem `doom.wad`.
- **Nova sala:** novo serviço no compose (porta UDP própria, `.cfg` próprio, limites de memória/CPU) + novo túnel UDP no painel do playit (`127.0.0.1:<porta>`) + registro em `portas.md`, `ORGANIZACAO-CONTAINERS.md` e painel.
- Conectar (cliente Zandronum, console `~`): `connect <endereço-público>` (IP alternativo `<ip-público>:<porta>`).

## Rotação de mapas (testada em 10/10/2026)
Testado em containers descartáveis (porta própria, `docker run -i`, comando `nextmap` no console para simular o fim da partida; o relógio de `timelimit` só corre com jogadores). Resultado real, Freedoom 2:

| Modo | Config no `sala1.cfg` | Comportamento observado |
|---|---|---|
| **Sequencial (atual)** | nenhuma lista | MAP01 → MAP02 → MAP03 → MAP04 → MAP05… (segue a ordem do WAD) |
| **Lista em ordem** | `clearmaplist`, `addmap MAP07`, `addmap MAP15`, `addmap MAP20`, `sv_maprotation 1` | MAP07 → MAP15 → MAP20 → volta ao MAP07 |
| **Lista aleatória** | a lista acima + `sv_randommaprotation 1` | sorteia entre os mapas da lista (viu-se 6, 8, 2, 4, 8, 6; sem repetir em seguida) |
| **Mapa fixo** | `clearmaplist`, `addmap MAP10`, `sv_maprotation 1` | recarrega sempre o mesmo mapa |

- **Escolher mapas específicos:** é a própria lista — um `addmap <mapa>` por mapa, na ordem desejada (`MAPxx` no Doom 2/Freedoom 2/TNT/Plutonia; `ExMy` no `doom.wad`/`freedoom1.wad`). Os mapas precisam existir no IWAD escolhido (E1M1 não existe no `doom2.wad`/`freedoom2.wad`). PWADs de mapa (`-file`) têm os mapas listados no próprio WAD.
- **Como aplicar:** editar `~/Servidor/Dados/doom/configs/sala1.cfg` (colocar as linhas junto do `timelimit`/`fraglimit`) e reiniciar: `docker restart game-doom-server` (o cfg é montado ro e relido no boot; não precisa de `compose up`). Para voltar ao sequencial, apagar as linhas da lista.
- **Quando troca de mapa:** ao atingir `timelimit 10` (minutos) ou `fraglimit 30`, vem a tela de pontuação e o próximo mapa carrega.
- **Interação com `+map` / `sala.sh`:** com `maplist` ativa o servidor **começa no primeiro mapa da lista** e ignora o `+map` do compose (observado: `+map MAP01` com lista iniciando em MAP07 subiu em MAP07). Ou seja, `sala.sh` só vale no modo sequencial; com lista, mude a ordem/itens da lista. Sem lista, `+map` define o mapa inicial e dali segue em sequência.
- **Onde o `map` do cfg não vale:** a linha `map MAP01` do `sala1.cfg` é ignorada no boot (vale só o `+map` do compose).
- **Pendência:** a sala hoje roda sem lista (sequencial). Se quiser rotação fixa, aleatória ou só alguns mapas, aplicar uma das configs acima; um script (`mapas.sh MAP07 MAP15 …`) ainda não existe.

## playit.gg — conta e túnel
- Agente "doom-server" (id `<id>`), túnel UDP custom → `127.0.0.1:36920`, **Proxy Protocol desligado** (o Zandronum não entende), IPv6 desligado.
- Painel do túnel (login necessário): https://playit.gg/account/tunnels (adicionado em 10/10/2026, link fornecido pelo usuário).
- A **secret key** fica só em `~/Servidor/36xxx/doom/.env` (chmod 600, fora do git). 
- O agente só relê o status da conta ao reconectar (após verificar o e-mail foi preciso recriar o container).
- Rede grátis: o endereço é do domínio do playit, a porta pode mudar se o túnel for recriado. A rede premium permite escolher a região.

## Limitações e cuidados
- **IP dos jogadores no log:** com a porta publicada pelo Docker (NAT), o servidor vê todos como o gateway `192.168.208.1` ("from: LAN"). Atrapalha ban por IP e distinguir jogadores; solução se for problema: `network_mode: host` na sala.
- **Lista pública (master server):** não confirmado se a sala aparece (IP/porta anunciados podem ser os locais, não os do relay). Plano B: divulgar o endereço direto; plano C: VPS barato como ponto de entrada.
- **Validação do relay:** o log só provou conexão (de dentro de casa). Falta teste de fora da rede.
- **WADs comerciais** (`doom*.wad`, `plutonia`, `tnt`, `nerve`, `masterlevels`, `sigil*`): cada jogador deve ter o seu; **não servir por HTTP** aos jogadores. O servidor de download de WADs planejado (ex.: `<seu-domínio>` pelo tunnel Cloudflare) só deve servir WADs da comunidade e o Freedoom.
- **Navegador (doom-wasm)** foi descartado: WebSocket/TCP, ~4 jogadores, sem mods.

## Próximos passos
1. Testar de fora da rede e ver se a sala aparece no launcher.
2. Trocar a sala para IWAD/PWAD escolhidos (WADs já estão em `Dados/doom/wads/`).
3. Servidor HTTP de WADs da comunidade (download automático pelo Zandronum).
4. Mais salas (uma por WAD/modo); regenerar a chave do playit.

## Histórico — o que foi feito (10/10/2026)
**Decisões**
1. Viabilidade: Docker 29.7 / Compose 5.5, 15 GB RAM (11 GB livres), 12 CPUs, porta 10666 livre → possível.
2. Acesso externo sem Tailscale e sem roteador: o Cloudflare Tunnel só leva HTTP/TCP (Spectrum/UDP é Enterprise). Avaliado Doom no navegador (doom-wasm, WebSocket): descartado por ser TCP, ~4 jogadores e sem mods. Requisito final: salas de 16 jogadores com WADs da comunidade → Zandronum + relay UDP de saída (playit.gg). Plano B: VPS barato.
3. Imagem escolhida: `rcdailey/zandronum-server:official-latest` (atualizada em 12/02/2026, 561 mil pulls). Alternativas vistas: `frozenfoxx/zandronum` (cliente via VNC), `ich777/zandronum` (focada em Unraid).
4. Porta 36920/UDP (faixa 279xx de jogos; 27910 já era do cantuxrunit). Rede em bridge com porta publicada (não host) → ver limitação do IP no log.

**Execução**
1. Baixado o Freedoom 0.13.0 do GitHub (zip em diretório isolado, só os `freedoom1.wad`/`freedoom2.wad` extraídos) para `Dados/doom/wads/`.
2. Criados `Dados/doom/configs/sala1.cfg` e `27xxx/doom/docker-compose.yml` (limites de memória/CPU, rótulo `category: jogos`, volumes ro). Sala subiu e abriu o UDP 36920.
3. Correção: o comando `gamemode` não existe no Zandronum → trocado por `deathmatch 1`; sem mais erros no log.
4. Card no painel (`services.json`, grupo Jogos) e registro em `portas.md` e `ORGANIZACAO-CONTAINERS.md`; README no projeto.
5. Conta no playit.gg criada pelo usuário; agente via Docker (`game-doom-playit`) com a secret key no `.env` (chmod 600, `.gitignore`, `.env.example` sem segredo). O agente só passou a `account_status="verified"` após recriar o container (ele só relê ao reconectar).
6. Túnel UDP criado no painel do playit: `127.0.0.1:36920`, Proxy Protocol desligado → `<endereço-público>` (`tunnel_count=1`).
7. Usuário conectou pelo Zandronum 3.2.1 (log: `Connect (v3.2.1)`, `Player joined the game`; origem vista como `192.168.208.1`, "LAN").
8. Usuário adicionou WADs comerciais em `Dados/doom/wads/`: `doom`, `doom2`, `plutonia`, `tnt`, `nerve`, `masterlevels`, `sigil`, `sigil2` (a sala segue com `freedoom2.wad`).
9. Teste de ponta a ponta por pacote UDP cru não prova nada (o Zandronum ignora pacotes fora do protocolo Huffman); a validação real é com cliente.

**Arquivos tocados**
`Servidor/36xxx/doom/*`, `Servidor/Dados/doom/*`, `Servidor/27xxx/painel/site/services.json`, `Infra/portas.md`, `Infra/ORGANIZACAO-CONTAINERS.md`, este doc e o índice do `~/.claude/CLAUDE.md`.
- Guia para jogadores: `doom-como-entrar.md`.

## Cliente Linux — dependências (verificado em 10/10/2026)
O binário `zandronum3.2.1-linux-x86_64` pede `libSDL-1.2.so.0` e `libjpeg.so.8` (`ldd`); a `libfmodex64` vem no tarball (usar `LD_LIBRARY_PATH`). No Debian 13 não existe `libjpeg.so.8` (só `.62`) — funciona em Ubuntu/Mint (`libsdl1.2debian libjpeg-turbo8`) e Arch (AUR). O guia `doom-como-entrar.md` tem scripts de copiar/colar (Windows PowerShell e Linux bash); o de Linux foi testado só até download/extração/checagem de libs, o de Windows não foi testado.

## Renomeação (10/10/2026)
Container `doom-sala1` renomeado para `game-doom-server` (`container_name` no compose; o serviço continua `sala1`, o `.cfg` continua `sala1.cfg`). Sala reiniciada (derruba conectados). Menções a `doom-sala1` no histórico acima são o nome antigo.

## Site / tutorial — <seu-domínio> (10/10/2026)
- **Um único container** (`game-doom-server`): imagem própria (`Dockerfile` em `Servidor/36xxx/doom/`, base `rcdailey/zandronum-server`) com `busybox httpd` na porta **36921** (TCP) + Zandronum na UDP 36920. `start.sh` sobe o site e faz `exec /entrypoint.sh` (o Zandronum segue como processo principal sob tini).
- Conteúdo: `Servidor/36xxx/doom/site/` montado ro (editar não exige restart): `index.html` (tutorial, botões copiar, abas Windows/Linux), `server.txt` (**endereço do jogo — único lugar a editar quando o playit mudar**; página e scripts leem dele), `win.ps1` e `linux.sh` (scripts servidos).
- Uso pelos jogadores: Windows `irm https://<seu-domínio>/win.ps1 | iex`; Linux `curl -fsSL https://<seu-domínio>/linux.sh | bash`.
- Túnel: ingress `<seu-domínio> → http://127.0.0.1:36921` em `~/.cloudflared/config.yml` (entre cine e frendnerbet desde 11/10/2026; backup `config.yml.bak.20261010`), CNAME criado com `cloudflared tunnel route dns <tunel> <seu-domínio>`. **Requer `sudo systemctl restart <servico-do-tunel>.service` para valer.** Card do painel atualizado (porta 36921, público).
- Modo da sala: deathmatch FFA explícito (`teamplay 0`, `ctf 0`, demais modos 0), aplicado e sem erros no log.
- Pendências: status ao vivo na página (jogadores/mapa), ainda não feito; mudança dos scripts exige conferir também os blocos de `doom-como-entrar.md`.

## Windows — testado (10/10/2026)
`irm https://<seu-domínio>/win.ps1 | iex` / bloco de `doom-como-entrar.md` rodou em PowerShell sem admin e entrou no servidor. Bug achado no teste: `zandronum.com` usa o anti-bot **Anubis** e serve uma página HTML ("Making sure you're not a bot!") ao User-Agent padrão do PowerShell (contém `Mozilla/5.0`), o que gerava "registro Final de Diretório Central não foi localizado" no `Expand-Archive`. Corrigido com `-UserAgent 'curl/8.4.0'` + checagem dos bytes `PK`. Se o Zandronum mudar essa proteção, o script avisa com link manual. Linux (`curl`/`wget`) não é afetado.

## Rota /wad — removida (10/10/2026)
A rota oculta `<seu-domínio>/wad/` (Freedoom, hardlinks em `Dados/doom/wad-publico/`) foi **removida** a pedido: montagem tirada do compose, pastas apagadas (originais em `Dados/doom/wads/` intactos). Não se publicam WADs comerciais pelo servidor (redistribuição de conteúdo com copyright; senha ou "escondido" não muda isso).


## Mudança de portas (11/10/2026)
Projeto movido de `Servidor/27xxx/doom` para `Servidor/36xxx/doom`; portas 27920/UDP → **36920/UDP** (jogo) e 27921/TCP → **36921/TCP** (site). Ingress do Cloudflare e card do painel atualizados. **Pendência:** no painel do playit, trocar o destino do túnel UDP para `127.0.0.1:36920`; e `sudo systemctl restart <servico-do-tunel>.service` para o ingress valer.

## Pacotes de deathmatch (11/10/2026)
Baixados do espelho do idgames (`mirrors.lug.mtu.edu/idgames/levels/doom2/deathmatch/...`) para `Dados/doom/wads/`: `udmx.wad` (21 MB), `udm1.wad` (6,6 MB), `vodm.wad` (7,9 MB), `finalfrg.wad` (3 MB; é o `FF_PART1.WAD` do zip), `aeondm.pk3` (89 MB). Testados: todos sobem em MAP01 (AEON01 no AeonDM) sem erro. Perfis em `sala.sh`. O nome "entryway" no MAP01 do UDM1/Final Frag é o nome padrão do Doom 2 (os WADs não definem nome próprio). Não baixado: `dk_dm_3f` (DoomKid, sem link direto). **Clientes** precisam ter os mesmos arquivos (o site só distribui o Freedoom); links do idgames na seção de pesquisa acima. UDMX/Vignettes usam recursos que exigem engine com limit removing (ok no Zandronum).

## Rota /wad no site (11/10/2026)
`https://<seu-domínio>/wad/` serve os WADs livres + página com instruções (onde colocar os arquivos, comandos de download para Windows/Linux). Origem: `Dados/doom/wads-publicos/` (**hardlinks** dos arquivos de `Dados/doom/wads/`: udmx, udm1, vodm, finalfrg, aeondm; mais o `index.html` da rota), montada ro em `/srv/site/wad` no container (`docker-compose.yml`; a pasta vazia `36xxx/doom/site/wad` existe só como ponto de montagem — o Docker não cria mountpoint dentro de volume ro). `httpd.conf` ganhou `.wad`/`.pk3` → `application/octet-stream` (exigiu `docker compose up -d --build`). Link adicionado no `site/index.html`.
- **Não expor WADs comerciais** (doom, doom2, tnt, plutonia, nerve, masterlevels, sigil): por isso a pasta separada em vez de montar `wads/` inteiro.
- **Adicionar um WAD novo:** copiar para `Dados/doom/wads/`, `ln -f wads/<arq> wads-publicos/<arq>` e acrescentar uma linha na tabela do `wads-publicos/index.html` (e o perfil no `sala.sh`). Hardlink quebra se o arquivo de origem for substituído por outro (refazer o `ln -f`).
- Pasta do jogo nos clientes: Windows `%USERPROFILE%\Doom`, Linux `~/Jogos/doom` (a do instalador); arquivos ficam junto do executável e do `doom2.wad`.
- Testado: `/wad`, `/wad/udmx.wad` (21 MB), `/wad/aeondm.pk3` (89 MB, tamanho exato) e externo via Cloudflare. O AeonDM (89 MB) consome upload da casa a cada download.

## Erro de hash e troca do doom2.wad (11/10/2026)
Cliente (fedora, `/mnt/ssd_250_samsung/Jogos/Doom/wads/`) dava erro de hash ao conectar com o UDMX. Causa: `doom2.wad` do servidor (`64a4c88a871da67492aaa2020a068cd8`, 14.951.361 bytes) era diferente do do fedora (`25e1459ca71d321525f84628f45ca8cd`, 14.604.584 bytes, o Doom 2 v1.9 original). `doom.wad`, `tnt`, `plutonia`, `nerve`, `masterlevels`, `sigil`, `sigil2`, `freedoom2` e `udmx` já eram idênticos nos dois. **Servidor passou a usar o `doom2.wad` v1.9** (copiado do fedora por scp; o antigo ficou em `Dados/doom/wads/doom2.wad.bak`). O Zandronum exige o mesmo hash de IWAD no cliente: quem tiver outra versão do Doom 2 toma erro de hash.
- **Armadilha:** trocar um WAD *no mesmo caminho* não faz o `docker compose up -d` recriar o container (o compose não mudou) — o processo continua com o arquivo antigo na memória. Usar `docker compose restart sala1`.
- Acesso do servidor ao fedora: SSH por chave habilitado hoje (`sshd` ligado no fedora, chave do Debian em `authorized_keys`).

## Cliente fedora: organização e `jogar.sh -p` (11/10/2026)
- O atalho "Doom (servidor)" usava `-i freedoom2.wad`, mas o servidor roda doom2 + pacote → erro "Missing file(s) / protected lump authentication failed". Corrigido: `jogar.sh -p auto -s <endereço-público>`.
- `jogar.sh` (fedora, `/mnt/ssd_250_samsung/Jogos/Doom/`) ganhou `-p NOME` (pacotes iguais aos perfis do `sala.sh`; `-p auto` lê `https://<seu-domínio>/sala.txt`, que o `doom-sala` grava em `site/sala.txt` a cada troca) e passou a procurar arquivos em todas as subpastas de `wads/`. `JOGAR_DRY=1` só mostra o comando. Backup: `jogar.sh.bak.20261011`.
- Pasta `wads/` do fedora reorganizada: `comerciais/` (doom, doom2, tnt, plutonia, nerve, masterlevels, sigil*, id1*, id24res, extras, iddm1), `outros/` (freedoom, pacotes DM, gothicdm), `baixadas/` (Doomseeker), `antigos/`; `LEIAME.md` lá explica. `dados/zandronum.ini` ganhou os caminhos (backup `.bak.20261011b`). O servidor **não** foi reorganizado (continua plano em `Dados/doom/wads`).
- **Armadilha:** `doom.desktop` com `-p auto` depende do site estar no ar; se `sala.txt` não responder, o script avisa e sai.

## Exit desativado (11/10/2026)
Qualquer jogador podia encerrar o mapa tocando no switch de saída (`dmflags 0`). Adicionado `sv_noexit 1` ao final de `Dados/doom/configs/sala1.cfg` (backup `sala1.cfg.bak.20261011`). `sv_noexit` é um cvar-flag do `dmflags` (`DF_NO_EXIT = 1<<10 = 1024`, confirmado no código-fonte do Zandronum, `src/d_main.cpp` e `src/doomdef.h`): **quem tenta sair do mapa morre** (não é só ignorar o switch). O mapa muda só por `timelimit 10`, `fraglimit 30` ou `doom-sala`. Mesma mecânica do `sv_nomonsters` (bit 4096): ambos são flags do `dmflags`, então devem ficar **depois** da linha `dmflags 0` no cfg (senão ela zera os bits). Para voltar ao normal: `sv_noexit 0`.

## Site em tempo real: "Sala agora" (11/10/2026)
`<seu-domínio>` tem a seção **Sala agora** (WAD/pacote, mapa com nome, monstros, saída, limites e arquivos necessários com links para `/wad/`), atualizada a cada 10 s e o topo mostra o mapa atual. Fonte: `site/cgi-bin/sala` (script sh, CGI do `busybox httpd`, executado como `nobody`): lê `/proc/<pid>/cmdline` do `zandronum-server` (IWAD e `-file`), `/configs/sala1.cfg` (monstros, exit, limites, hostname) e o log do servidor (último `*** MAPxx: nome ***`, o que acompanha também a troca automática de mapa por tempo/frags). O Zandronum grava o log por `+logfile /logs/sala.log` (compose), mas cria `sala.log__AAAA_MM_DD-HH_MM_SS.log` **a cada boot**; o `start.sh` apaga os anteriores e o CGI usa o mais recente. Cada linha do log tem prefixo `[HH:MM:SS]`. Editar o CGI/`index.html` não exige restart (volume ro); mudar o `start.sh` exige `docker compose up -d --build sala1`. Teste: `curl http://127.0.0.1:36921/cgi-bin/sala`. `doom-sala` também grava `site/sala.txt` (nome do pacote; usado pelo `jogar.sh -p auto` do fedora; arquivo ignorado pelo git).
