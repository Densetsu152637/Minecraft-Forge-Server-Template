#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temp_root=$(cd -- "${TMPDIR:-/tmp}" && pwd -P)
fixture=$(mktemp -d "$temp_root/forge-launcher-tests.XXXXXX")
fixture=$(cd -- "$fixture" && pwd -P)
cleanup() {
    # Delete only the resolved, uniquely named fixture beneath our temp root.
    case "$fixture" in
        "$temp_root"/forge-launcher-tests.*) rm -rf -- "$fixture" ;;
        *) printf 'Refusing cleanup of unexpected fixture path: %s\n' "$fixture" >&2 ;;
    esac
}
trap cleanup EXIT
repo="$fixture/server directory with spaces"
mkdir -p "$repo/data/mods" "$fixture/bin" "$fixture/elsewhere"
cp "$source_dir/start.sh" "$source_dir/docker-compose.yml" "$repo/"
export DOCKER_TEST_LOG="$fixture/docker-calls"
export DOCKER_TEST_ENV="$fixture/compose-env"
export DOCKER_TEST_CONFIG_FAIL=0 DOCKER_TEST_DAEMON_FAIL=0 DOCKER_TEST_UP_FAIL=0 DOCKER_TEST_VERSION_FAIL=0 DOCKER_TEST_STOP_FAIL=0
cat > "$fixture/bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'CALL' >> "$DOCKER_TEST_LOG"
printf '<%s>\n' "$@" >> "$DOCKER_TEST_LOG"
if [[ "$1" == info ]]; then
    exit "$DOCKER_TEST_DAEMON_FAIL"
fi
if [[ "$2" == version ]]; then
    exit "$DOCKER_TEST_VERSION_FAIL"
fi
for arg in "$@"; do
    case "$arg" in
        --quiet) exit "$DOCKER_TEST_CONFIG_FAIL" ;;
        --environment) cat "$DOCKER_TEST_ENV"; exit ;;
        --services) printf 'forge\n'; exit ;;
        up) exit "$DOCKER_TEST_UP_FAIL" ;;
        stop) exit "$DOCKER_TEST_STOP_FAIL" ;;
    esac
done
MOCK
chmod +x "$fixture/bin/docker"
export PATH="$fixture/bin:$PATH"
bash_command=$(command -v bash)

expect_failure() {
    local expected=$1
    shift
    if "$@" > "$fixture/output" 2>&1; then
        printf 'FAIL: command unexpectedly succeeded (%s)\n' "$expected" >&2
        exit 1
    fi
    grep -F -- "$expected" "$fixture/output" >/dev/null
}

expect_failure 'Missing .env' "$bash_command" "$repo/start.sh"
cp "$source_dir/.env.example" "$repo/.env"
# Keep only the directory utility available so Docker genuinely cannot be found.
mkdir "$fixture/no-docker"
cat > "$fixture/no-docker/dirname" <<'UTILITY'
#!/bin/bash
path=${!#}
printf '%s\n' "${path%/*}"
UTILITY
chmod +x "$fixture/no-docker/dirname"
expect_failure 'Docker was not found' env PATH="$fixture/no-docker" "$bash_command" "$repo/start.sh"
printf 'EULA=false\nJAVA_VERSION=17\n' > "$DOCKER_TEST_ENV"
expect_failure 'EULA=true' "$bash_command" "$repo/start.sh"
printf 'EULA=true\nJAVA_VERSION=17\n' > "$DOCKER_TEST_ENV"
expect_failure 'No mod jars' "$bash_command" "$repo/start.sh"
mkdir "$repo/data/mods/not-a-file.jar"
expect_failure 'No mod jars' "$bash_command" "$repo/start.sh"
touch "$repo/data/mods/pack.jar"
printf 'EULA=true\nJAVA_VERSION=25\n' > "$DOCKER_TEST_ENV"
expect_failure 'JAVA_VERSION' "$bash_command" "$repo/start.sh"
printf 'EULA=true\nJAVA_VERSION=17\n' > "$DOCKER_TEST_ENV"
DOCKER_TEST_CONFIG_FAIL=2 expect_failure 'Invalid Compose' "$bash_command" "$repo/start.sh"
DOCKER_TEST_DAEMON_FAIL=3 expect_failure 'Cannot reach Docker' "$bash_command" "$repo/start.sh"
DOCKER_TEST_VERSION_FAIL=4 expect_failure 'Docker Compose is unavailable' "$bash_command" "$repo/start.sh"
expect_failure 'Usage:' "$bash_command" "$repo/start.sh" erase
expect_failure 'Usage:' "$bash_command" "$repo/start.sh" start extra
# Even shell-looking .env content must remain inert; only Compose reads it.
printf 'touch "%s/executed"\n' "$fixture" >> "$repo/.env"
printf 'saved world\n' > "$repo/data/world.dat"
printf 'custom setting\n' > "$repo/data/server.properties"
cp "$repo/data/world.dat" "$fixture/world.before"
cp "$repo/data/server.properties" "$fixture/settings.before"
: > "$DOCKER_TEST_LOG"
cd "$fixture/elsewhere"
"$bash_command" "$repo/start.sh" > "$fixture/output"
grep -F 'Startup requested' "$fixture/output" >/dev/null
for action in restart stop logs status config; do
    "$bash_command" "$repo/start.sh" "$action" > "$fixture/output"
done
[[ ! -e "$fixture/executed" ]]
cmp "$fixture/world.before" "$repo/data/world.dat"
cmp "$fixture/settings.before" "$repo/data/server.properties"
# Every project invocation preserves absolute paths as single arguments.
project_calls=$(grep -c '^<--project-directory>$' "$DOCKER_TEST_LOG")
[[ $(grep -Fxc "<$repo>" "$DOCKER_TEST_LOG") == "$project_calls" ]]
[[ $(grep -Fxc "<$repo/.env>" "$DOCKER_TEST_LOG") == "$project_calls" ]]
[[ $(grep -Fxc "<$repo/docker-compose.yml>" "$DOCKER_TEST_LOG") == "$project_calls" ]]
grep -Fx '<stop>' "$DOCKER_TEST_LOG" >/dev/null
grep -Fx '<ps>' "$DOCKER_TEST_LOG" >/dev/null
grep -Fx '<logs>' "$DOCKER_TEST_LOG" >/dev/null
if grep -Ex '<(down|-v|rm)>' "$DOCKER_TEST_LOG"; then
    printf 'FAIL: destructive lifecycle command\n' >&2
    exit 1
fi
# Startup errors propagate with the original nonzero status and no success text.
set +e
DOCKER_TEST_UP_FAIL=7 "$bash_command" "$repo/start.sh" > "$fixture/output" 2>&1
result=$?
set -e
[[ "$result" == 7 ]]
if grep -F 'Startup requested' "$fixture/output"; then
    exit 1
fi
# A failed graceful stop must not proceed to recreate the server.
: > "$DOCKER_TEST_LOG"
set +e
DOCKER_TEST_STOP_FAIL=8 "$bash_command" "$repo/start.sh" restart > "$fixture/output" 2>&1
result=$?
set -e
[[ "$result" == 8 ]]
if grep -Fx '<up>' "$DOCKER_TEST_LOG"; then
    exit 1
fi
DOCKER_TEST_DAEMON_FAIL=3 "$bash_command" "$repo/start.sh" config > "$fixture/output"
grep -Fx forge "$fixture/output" >/dev/null
printf 'PASS: launcher guards, lifecycle identity, failure propagation, and file preservation\n'
