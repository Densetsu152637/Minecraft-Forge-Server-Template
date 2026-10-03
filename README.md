# Minecraft Forge server template

Run a downloaded CurseForge **Forge server pack** using Docker and Bash. Docker installs Forge and runs Java; the complete pack, world, player lists, settings, and logs stay in this repository's `data/` folder across container restarts and recreation.

## Quickstart

The startup workflow is **extract the server pack → configure `.env` → run `bash start.sh`**. This template uses a prebuilt Docker image, so there is no `docker compose build` step. The Bash launcher validates your setup and runs `docker compose up -d forge` with this repository's configuration; Docker downloads the image automatically when needed.

1. Install Docker with the modern Compose plugin. On Windows, install/start Docker Desktop with Linux containers and use **Git Bash**, or use WSL with Docker Desktop's WSL integration enabled. You do not need Java on the host.
2. Download the pack author's **server pack** from CurseForge. A client pack/export containing `manifest.json` and `overrides/` is not a ready server pack. Confirm that the pack uses Forge, and note its Minecraft, Forge, and Java versions.
3. Extract **all contents** of the server pack into `data/`. If the ZIP contains an outer folder, move that folder's contents into `data/`; `mods/` must be directly inside `data/`. Keep `config/`, `defaultconfigs/`, `kubejs/`, `scripts/`, and other supplied files alongside it. Do not place mods in the repository's old root `mods/` folder.
4. In a Bash terminal, open this repository and run:

   ```bash
   cp .env.example .env
   ```

   Edit `.env` in a text editor. Match `MC_VERSION`, `FORGE_VERSION`, and `JAVA_VERSION` to the pack author's requirements. The supplied `1.20.1`, `47.1.0`, and Java `17` are examples, not versions that work for every pack. Use Java `8`, `17`, or `21` as required by your pack. Set `MEMORY` to the recommended heap size and leave additional RAM for Docker, native memory, and your operating system. Read the [Minecraft EULA](https://aka.ms/MinecraftEULA), and set `EULA=true` only if you agree.
5. Start the server:

   ```bash
   bash start.sh
   bash start.sh logs
   ```

   The first start downloads the image and installs the matching Forge runtime into `data/`, so it can take several minutes and requires internet access. Watch for the Minecraft `Done` message. Press Ctrl+C to stop following logs; the server keeps running.
6. Connect using the matching client modpack to `localhost:25565` on this computer, or `<server-LAN-IP>:25565` from another computer on your network. If you changed `SERVER_PORT`, connect to that port instead. Allow that port through the host firewall for LAN access.

The layout before first start should look like this:

```text
Minecraft-Forge-Server-Template/
  .env
  docker-compose.yml
  start.sh
  data/
    mods/                 # contains the pack's .jar files
    config/
    defaultconfigs/       # if supplied
    kubejs/               # if supplied
    scripts/              # if supplied
    server.properties     # if supplied
    ...                   # keep other server-pack files too
```

Packs requiring a mandatory custom installer or launch script need the author's setup instructions before using this template. The template runs standard Forge itself and does not execute downloaded `.bat`/`.sh` scripts. Fabric, NeoForge, and client-only exports are outside this template's scope. If a pack downloads its mods during installation, complete the author's setup first so `data/mods/` contains the resulting jars.

## Everyday commands

```bash
bash start.sh           # start/recreate with current configuration; keeps data
bash start.sh restart   # graceful stop, then start with current configuration
bash start.sh status    # inspect running/starting/healthy state
bash start.sh logs      # follow the latest 100 log lines
bash start.sh stop      # graceful shutdown, allowing up to 120 seconds
bash start.sh config    # validate configuration and list services; no daemon needed
```

The launcher always uses this repository's `.env`, Compose file, and project directory, even when invoked from elsewhere, for example `bash "/path with spaces/to/repo/start.sh" stop`. Use these commands consistently. `COMPOSE_PROJECT_NAME` in `.env` identifies the Docker project; keep it unchanged after setup. For multiple copies, give each a different project name and `SERVER_PORT` before the first start.

The container has a Minecraft healthcheck. A `starting` state during installation is normal; `healthy` means its Minecraft probe succeeded. An `unhealthy` state needs log investigation and does not automatically restart a running container. Large packs can take longer than the five-minute healthcheck startup allowance. `bash start.sh` requests startup; it does not wait for readiness.

## Keeping your world and settings

The only bind mount is `./data:/data`. World folders, Forge libraries, mods, configuration, player lists, `server.properties`, logs, and other runtime files all persist there. Existing `server.properties` is preserved rather than overwritten by the image's default settings. Edit it while the server is stopped, then start again. Keep `enable-status=true` for the default healthcheck, `server-port=25565` for the internal container port, and normally leave `server-ip` blank so the server listens inside the container. `SERVER_PORT` in `.env` changes the published host port only.

Before updating a pack or changing Minecraft/Forge versions, stop the server and **back up the entire `data/` folder plus `.env`** somewhere outside this repository. Follow the pack author's update instructions; remove obsolete mods deliberately. Do not re-extract the original pack on every startup, and do not delete `data/` to repair a container problem. Container recreation keeps the files, but persistence is not a backup against accidental deletion or incompatible world upgrades.

`data/` contents and `.env` are ignored by Git, including player lists and local settings. Only the explanatory `data/README.md` is tracked. The legacy root `mods/` and `config/` directories are not mounted; move any existing contents into `data/mods/` and `data/config/` while stopped before using this version.

## Troubleshooting

- **Missing `.env` or invalid configuration:** copy the example, check required versions and port values, then run `bash start.sh config`. Shell environment variables can override `.env` through Compose; unset conflicting exported variables if the wrong settings are being used. The launcher does not execute `.env` as a shell script.
- **No mod jars found:** check for `data/mods/*.jar`, not `data/<pack-name>/mods/`, or complete the author's server-pack installer first.
- **Cannot reach Docker:** start Docker Desktop/the daemon, select Linux containers, and confirm that your terminal has access with `docker info`.
- **Windows bind/path issues:** run from Git Bash with normal paths such as `/d/Git Repositories/...`; Git Bash converts the launcher's absolute arguments for Docker Desktop. If you have globally set `MSYS_NO_PATHCONV` or `MSYS2_ARG_CONV_EXCL`, unset them for this workflow. In WSL, enable Docker integration for your distro and use WSL paths. Ensure Docker can share/access the drive containing `data/`.
- **Crash or missing mods:** inspect `bash start.sh logs` and `data/crash-reports/`. Check the exact Minecraft/Forge/Java versions, required pack files, and available RAM. If logs report a client-only mod, use the author's server pack rather than mixing client mods into it.
- **Port already in use:** choose a free `SERVER_PORT` in `.env`, then run `bash start.sh` to apply it.

This uses the maintained [itzg Minecraft server image](https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/server-types/forge/) with an explicit [Java tag](https://docker-minecraft-server.readthedocs.io/en/latest/versions/java/) and its [persistent data directory](https://docker-minecraft-server.readthedocs.io/en/latest/data-directory/). Tags receive upstream updates; for a controlled update, back up first, pull the service image using the same Compose options, then start again.

## Development checks

```bash
bash -n start.sh tests/test-start.sh
bash tests/test-start.sh
docker compose --project-directory . --env-file .env.example -f docker-compose.yml config --quiet
docker compose --project-directory . --env-file .env.example -f docker-compose.yml config --services
```

The launcher tests use an isolated temporary server directory and a fake Docker executable. They check startup guards, consistent lifecycle targets, failure propagation, and preservation of existing files without downloading or starting a server. A real modpack boot still requires an actual server pack and Docker daemon.
