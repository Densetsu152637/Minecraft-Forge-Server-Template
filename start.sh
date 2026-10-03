#!/usr/bin/env bash
# Invoke with Bash, including from Git Bash on Windows.
set -euo pipefail

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

action=${1:-start}
if (( $# > 1 )); then
    fail 'Usage: bash start.sh [start|restart|stop|logs|status|config]'
fi
case "$action" in
    start|restart|stop|logs|status|config) ;;
    *) fail 'Usage: bash start.sh [start|restart|stop|logs|status|config]' ;;
esac

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f "$repo_dir/.env" ]] || fail 'Missing .env. Copy .env.example to .env and match the server pack versions.'
command -v docker >/dev/null 2>&1 || fail 'Docker was not found. Install Docker with the Compose plugin and open a new terminal.'
docker compose version >/dev/null || fail 'Docker Compose is unavailable. Install the modern Docker Compose plugin.'
compose=(docker compose --project-directory "$repo_dir" --env-file "$repo_dir/.env" -f "$repo_dir/docker-compose.yml")
# Compose parses .env itself; never execute local configuration as shell code.
"${compose[@]}" config --quiet || fail 'Invalid Compose configuration. Check .env and docker-compose.yml.'

if [[ "$action" == config ]]; then
    "${compose[@]}" config --services
    exit
fi

if [[ "$action" == start || "$action" == restart ]]; then
    resolved_env=$("${compose[@]}" config --environment)
    eula=
    java_version=
    while IFS= read -r line; do
        case "$line" in
            EULA=*) eula=${line#EULA=} ;;
            JAVA_VERSION=*) java_version=${line#JAVA_VERSION=} ;;
        esac
    done <<< "$resolved_env"
    case "$eula" in
        [tT][rR][uU][eE]) ;;
        *) fail 'Read https://aka.ms/MinecraftEULA and set EULA=true in .env if you agree.' ;;
    esac
    case "$java_version" in
        8|17|21) ;;
        *) fail 'Set JAVA_VERSION in .env to 8, 17, or 21 as required by the pack.' ;;
    esac
    has_mods=false
    for mod in "$repo_dir"/data/mods/*.jar; do
        if [[ -f "$mod" ]]; then
            has_mods=true
            break
        fi
    done
    [[ "$has_mods" == true ]] || fail 'No mod jars in data/mods. Extract the complete Forge SERVER pack into data/ (not a nested pack folder).'
fi

docker info >/dev/null || fail 'Cannot reach Docker. Start Docker Desktop/the Docker daemon and check access.'
case "$action" in
    start|restart)
        if [[ "$action" == restart ]]; then
            "${compose[@]}" stop forge
        fi
        "${compose[@]}" up -d forge
        printf 'Startup requested. Follow logs with: bash "%s/start.sh" logs\n' "$repo_dir"
        printf 'Check readiness with: bash "%s/start.sh" status\n' "$repo_dir"
        ;;
    stop) "${compose[@]}" stop forge ;;
    logs) "${compose[@]}" logs --follow --tail 100 forge ;;
    status) "${compose[@]}" ps forge ;;
esac
