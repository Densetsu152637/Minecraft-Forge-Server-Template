# Minecraft Forge server template

Run a downloaded Forge **server pack** with Docker. Build the Java runtime image once, then let the container automatically execute the **server pack's own Bash startup script**. The complete pack, world, settings, and logs stay in `data/` across container stops and recreation.

## Quickstart

The workflow is **clone → copy server pack into `data/` → configure `.env` → `docker-compose build` → `docker-compose up -d`**. Run every command below from a terminal in this repository's directory. PowerShell, Git Bash, and Linux terminals work; Java and Bash are provided inside the container.

1. Clone this repository and open its directory. Install and start Docker with current Docker Compose support; on Windows, use Docker Desktop with **Linux containers**.
2. Download the pack author's Forge **server pack**, rather than a client export containing only `manifest.json` and `overrides/`. Copy **all extracted contents** into `data/`. If the archive has an outer folder, copy that folder's contents so the startup script is directly under `data/`, alongside all supplied configuration, mods, installers, libraries, and other files. Packs may download missing files on first startup; no preexisting mod jars are required by this template.
3. Copy `.env.example` to `.env`. In PowerShell:

   ```powershell
   Copy-Item .env.example .env
   ```

   In Bash:

   ```bash
   cp .env.example .env
   ```

   Edit `.env`: set `JAVA_VERSION` to the major version required by the pack (commonly `8`, `17`, or `21`) and `SERVER_START_SCRIPT` to its Bash startup filename, such as `run.sh` or `startserver.sh`. For paths with spaces, use `SERVER_START_SCRIPT="start server.sh"`; paths are relative to `data/`. Read the [Minecraft EULA](https://aka.ms/MinecraftEULA) and set `EULA=true` only if you agree. Configure the pack's own version and memory settings as its author directs, for example in `user_jvm_args.txt` or its supplied variables file; this template does not override them. Keep the script running Java in the foreground, using the pack's documented headless/`nogui` option.
4. Build the runtime image:

   ```text
   docker-compose build
   ```

   This downloads Java and installs Bash, common download/archive tools, and the container entrypoint. It does **not** execute the pack or copy `data/` into the image.
5. Start the server:

   ```text
   docker-compose up -d
   docker-compose logs -f --tail 100 forge
   ```

   At runtime, the container starts in `/data`, records your EULA acceptance in `eula.txt`, and executes the selected pack script with Bash. That script controls Forge installation and Java startup. First startup may download files and take several minutes. Wait for Minecraft's `Done` message before connecting. Ctrl+C stops following logs while the server keeps running.
6. Stop the server when needed:

   ```text
   docker-compose stop
   ```

   Docker sends SIGINT (like Ctrl+C) to the pack script and its child processes and allows up to 120 seconds for shutdown. This lets a foreground Bash script wait while Java handles shutdown. Check the logs for world saving; the pack's script and Java process must handle shutdown correctly.

These examples use the requested `docker-compose` command from a current Docker Compose installation. If your installation exposes only the plugin command, replace `docker-compose` with `docker compose` throughout. The obsolete Python Compose v1 is not supported.

A typical layout is:

```text
Minecraft-Forge-Server-Template/
  .env
  Dockerfile.Server
  docker-compose.yml
  scripts/start-server.sh     # template container entrypoint
  data/
    run.sh                   # the downloaded pack's actual startup script
    user_jvm_args.txt         # if supplied
    mods/                    # if supplied or created by the pack installer
    config/
    server.properties        # if supplied or generated
    ...                      # all other server-pack files
```

A pack that supplies only a Windows `.bat` launcher needs a supported Bash startup script from its author. Scripts run with Linux Bash and must have Unix **LF** line endings, including any helper scripts they source. Use your editor's line-ending conversion if needed. Follow the author's Linux setup instructions and preconfigure installer prompts where supported. For a necessary interactive prompt, use `docker-compose attach forge`; detach with Ctrl+P, Ctrl+Q. Do not background Java or launch a separate detached server from the pack script, because the container must own the running process.

## Everyday commands

```text
docker-compose up -d                  # start/recreate with current configuration
docker-compose stop                  # stop and preserve containers and all data
docker-compose ps                    # inspect process state
docker-compose logs -f --tail 100 forge
docker-compose config --quiet        # validate Compose configuration
```

`up -d` starts the process; it does not establish Minecraft readiness. This generic script runtime has no Minecraft healthcheck: use logs and the `Done` message. A failed script leaves an exited container for diagnosis rather than restarting its installer repeatedly.

After editing `.env` or Compose settings, use `docker-compose up -d` to apply them. After changing `JAVA_VERSION`, the Dockerfile, or the template entrypoint, run `docker-compose build` then `docker-compose up -d` to recreate with the new image. Pack file changes in `data/` are bind mounted and do not require rebuilding; stop the server before changing them, then start it again. Avoid `docker-compose restart` when applying changed environment or image settings.

Compose automatically loads `.env` in this directory. Exported shell variables can override its values. Keep `COMPOSE_PROJECT_NAME` unchanged after setup; use different names and host ports for multiple copies.

## Keeping your world and settings

The entire `./data` directory is mounted at `/data`: pack files, Forge libraries, worlds, player lists, configuration, logs, and `server.properties` persist. The template modifies only `eula.txt` to record explicit acceptance; the downloaded script may create or update other files according to the author's behavior.

Keep `server-port=25565` and normally leave `server-ip` blank in the pack's `server.properties`. `SERVER_PORT` in `.env` changes the published **host** port only. Connect with the matching client modpack to `localhost:25565`, or `<server-LAN-IP>:25565` from another computer; use your selected host port if different and allow it through the host firewall.

Before updates or backups, stop the server and back up **all of `data/` plus `.env`** outside this repository. Follow the pack author's upgrade instructions and remove obsolete mods deliberately. Do not re-extract the original pack on every startup. Container persistence does not protect against accidental deletion or incompatible world upgrades.

`.env` and runtime contents in `data/` are ignored by Git; only `data/README.md` is tracked. The image build context also excludes pack data, worlds, `.env`, and repository history. The legacy root `mods/` and `config/` folders are not mounted; move existing content into the corresponding folders inside `data/` while stopped.

## Troubleshooting

- **Missing startup script:** copy the full server pack into `data/`, without an extra outer directory, and match `SERVER_START_SCRIPT` to its actual Bash filename. A nested relative path is supported and still starts with `/data` as the working directory.
- **EULA error:** read the EULA and set `EULA=true` if you agree, then use `docker-compose up -d` to apply the change.
- **CRLF / `$'\r': command not found`:** save the pack's Bash scripts with LF line endings. The entrypoint reports CRLF in the selected script before executing it.
- **Java or memory errors:** match `JAVA_VERSION` to the author's requirements and rebuild/recreate. Change heap settings in the pack's own JVM arguments/configuration, leaving RAM for Docker and the host OS.
- **Container exits or hangs at a prompt:** inspect `docker-compose logs --tail 100 forge` and `data/crash-reports/`; check the pack's Linux instructions, foreground launch behavior, downloaded files, and any required interactive setup.
- **Cannot reach Docker or mounted files:** start Docker Desktop/the daemon, select Linux containers, confirm `docker info`, and ensure Docker can access the drive holding this repository. For WSL, enable Docker integration for your distro. The default runtime user is root; on Linux, files created by the pack may be owned by root, so use appropriate permissions when editing them on the host.
- **Port in use:** choose a free `SERVER_PORT` in `.env` and run `docker-compose up -d`.

The runtime uses the official [Eclipse Temurin Java image](https://hub.docker.com/_/eclipse-temurin) and [Tini](https://github.com/krallin/tini) to forward SIGINT to the script's process group. Java image tags receive upstream updates; for an intentional refresh, back up first, use `docker-compose build --pull`, then recreate with `docker-compose up -d`.

## Development checks

```bash
bash -n scripts/start-server.sh tests/test-entrypoint.sh
bash tests/test-entrypoint.sh
docker-compose --env-file .env.example config --quiet
docker-compose --env-file .env.example config --services
```

The Bash tests use temporary fixture scripts to check startup guards, path and argument handling, pack exit status, EULA recording, and preservation of existing world/settings files. They do not download or boot Minecraft. A real server boot still requires an actual pack and Docker daemon; container lifecycle checks can use an isolated fixture pack without touching `data/`.
