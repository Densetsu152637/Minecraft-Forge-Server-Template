#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

[[ "${EULA:-false}" == true ]] || fail 'Read https://aka.ms/MinecraftEULA and set EULA=true in .env if you agree.'

# Docker sets the working directory to the mounted server pack root, /data.
data_dir=$(pwd -P)
script=${SERVER_START_SCRIPT:-run.sh}
[[ "$script" != /* ]] || fail 'SERVER_START_SCRIPT must be a path relative to data/.'
script_path=$(readlink -f -- "$data_dir/$script") || fail 'Cannot resolve SERVER_START_SCRIPT inside data/.'
case "$script_path" in
    "$data_dir"/*) ;;
    *) fail 'SERVER_START_SCRIPT must stay inside data/.' ;;
esac
[[ -f "$script_path" && -r "$script_path" ]] || fail "Missing readable server pack Bash script: $script. Copy the complete SERVER pack into data/ and set SERVER_START_SCRIPT."
if LC_ALL=C grep -qU $'\r' "$script_path"; then
    fail 'The server pack Bash script has CRLF line endings. Save it with Unix LF endings before starting.'
fi

# Record only the explicitly accepted EULA; keep unrelated pack settings intact.
if [[ -f eula.txt ]]; then
    if grep -Eq '^[[:space:]]*eula[[:space:]]*=' eula.txt; then
        sed -i 's/^[[:space:]]*eula[[:space:]]*=.*/eula=true/' eula.txt
    else
        printf '\neula=true\n' >> eula.txt
    fi
else
    printf 'eula=true\n' > eula.txt
fi

printf 'Starting server pack script: %s\n' "$script"
exec bash "$script_path" "$@"
