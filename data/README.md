# Server pack and persistent data

Extract the complete Forge **server pack** here, with `mods/`, `config/`, and all other supplied folders directly inside this folder. See the root [quickstart](../README.md) for setup.

Docker binds this entire directory to `/data`. Forge installation, worlds, player lists, settings, logs, and pack files survive container recreation. Stop the server before changing files or backing up the entire folder. Git ignores everything here except this README.
