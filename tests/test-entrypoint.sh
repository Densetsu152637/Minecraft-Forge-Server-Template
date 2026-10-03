#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temp_root=$(cd -- "${TMPDIR:-/tmp}" && pwd -P)
fixture=$(mktemp -d "$temp_root/forge-entrypoint-tests.XXXXXX")
fixture=$(cd -- "$fixture" && pwd -P)
cleanup() {
    case "$fixture" in
        "$temp_root"/forge-entrypoint-tests.*) rm -rf -- "$fixture" ;;
        *) printf 'Refusing cleanup of unexpected fixture path: %s\n' "$fixture" >&2 ;;
    esac
}
trap cleanup EXIT
pack="$fixture/server pack with spaces"
mkdir -p "$pack/nested scripts" "$fixture/elsewhere"
entrypoint="$source_dir/scripts/start-server.sh"
export EULA=true
export SERVER_START_SCRIPT=run.sh
export PACK_TEST_OUTPUT="$fixture/pack-output"
unset PACK_TEST_EXIT
cd "$pack"

expect_failure() {
    local expected=$1
    shift
    if "$@" > "$fixture/output" 2>&1; then
        printf 'FAIL: command unexpectedly succeeded (%s)\n' "$expected" >&2
        exit 1
    fi
    grep -F -- "$expected" "$fixture/output" >/dev/null
}

# Rejected startup cannot run a pack script or record EULA acceptance.
EULA=false expect_failure 'EULA=true' bash "$entrypoint"
EULA=TRUE expect_failure 'EULA=true' bash "$entrypoint"
expect_failure 'Missing readable server pack Bash script' bash "$entrypoint"
[[ ! -e eula.txt && ! -e "$PACK_TEST_OUTPUT" ]]
mkdir directory.sh
SERVER_START_SCRIPT=directory.sh expect_failure 'Missing readable' bash "$entrypoint"
SERVER_START_SCRIPT=/outside.sh expect_failure 'relative to data/' bash "$entrypoint"
printf 'echo should-not-run\n' > "$fixture/outside.sh"
SERVER_START_SCRIPT=../outside.sh expect_failure 'stay inside data/' bash "$entrypoint"
printf '#!/bin/bash\r\nprintf bad\r\n' > run.sh
expect_failure 'CRLF line endings' bash "$entrypoint"
[[ ! -e eula.txt && ! -e "$PACK_TEST_OUTPUT" ]]

cat > run.sh <<'PACK'
#!/usr/bin/env bash
set -euo pipefail
{
    pwd -P
    printf '<%s>\n' "$@"
    printf 'EULA=%s\n' "$EULA"
} > "$PACK_TEST_OUTPUT"
exit "${PACK_TEST_EXIT:-0}"
PACK
printf 'saved world\n' > world.dat
printf 'custom setting\n' > server.properties
cp world.dat "$fixture/world.before"
cp server.properties "$fixture/settings.before"
bash "$entrypoint" 'argument with spaces' '--nogui' > "$fixture/output"
printf '%s\n<argument with spaces>\n<--nogui>\nEULA=true\n' "$pack" > "$fixture/expected"
cmp "$fixture/expected" "$PACK_TEST_OUTPUT"
grep -Fx 'eula=true' eula.txt >/dev/null
cmp "$fixture/world.before" world.dat
cmp "$fixture/settings.before" server.properties

# The chosen nested filename is one path, and its working directory is the pack root.
cp run.sh 'nested scripts/start server.sh'
SERVER_START_SCRIPT='nested scripts/start server.sh' bash "$entrypoint" 'literal $HOME; not shell code' > "$fixture/output"
printf '%s\n<literal $HOME; not shell code>\nEULA=true\n' "$pack" > "$fixture/expected"
cmp "$fixture/expected" "$PACK_TEST_OUTPUT"

# Preserve EULA comments/unrelated properties, replacing only active EULA values.
printf '# pack EULA file\neula=false\nother=value\n' > eula.txt
bash "$entrypoint" > "$fixture/output"
printf '# pack EULA file\neula=true\nother=value\n' > "$fixture/expected"
cmp "$fixture/expected" eula.txt
printf '# no active EULA property' > eula.txt
bash "$entrypoint" > "$fixture/output"
grep -Fx '# no active EULA property' eula.txt >/dev/null
grep -Fx 'eula=true' eula.txt >/dev/null

# The downloaded script controls the process result; failures remain failures.
set +e
PACK_TEST_EXIT=23 bash "$entrypoint" > "$fixture/output" 2>&1
result=$?
set -e
[[ "$result" == 23 ]]
cmp "$fixture/world.before" world.dat
cmp "$fixture/settings.before" server.properties
printf 'PASS: entrypoint guards, pack script execution, argument/exit forwarding, EULA, and file preservation\n'
