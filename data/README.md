# Server pack and persistent data

Copy all contents of the downloaded Forge **server pack** here, including its Bash startup script and every supplied folder/file. If the archive has an outer folder, copy its contents so `run.sh` (or the author's other startup filename) sits here. Configure `SERVER_START_SCRIPT` and Java in `.env`; see the root [quickstart](../README.md).

Docker mounts this entire directory at `/data` and automatically executes the selected script there at container startup. The pack controls installation and Java startup; worlds, settings, libraries, logs, and downloaded files survive container recreation. Stop the server before edits or backups. Git ignores everything here except this README.
