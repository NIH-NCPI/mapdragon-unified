# Quick local check of the image before deployment.
#
# Builds exactly what the Dockerfile pins (MAPDRAGON_COMMIT, LOCUTUS_COMMIT,
# VITE_MAPDRAGON_VERSION), so what you look at is what gets deployed. Update
# those in the Dockerfile first, then:
#
#   cp .env.example .env    # once; fill in UMLS_API_KEY / VITE_CLIENT_ID
#   just test               # build, start, seed, then open the URL it prints
#
# To test against a copy of real data, pull a dump down once
# (just db-dump-remote), then run `just test-dump backups/<file>` (or set
# TEST_DUMP=backups/<file> in .env and run `just test-dump`). Each run starts
# from that dump instead of an empty database.
#
# Run `just` to list all recipes.

pinned_vars := "MAPDRAGON_COMMIT VITE_MAPDRAGON_VERSION LOCUTUS_COMMIT"

# Hands dumps written inside the locutils container back to you
locutils_run := "docker compose run --rm -e HOST_UID=$(id -u) -e HOST_GID=$(id -g)"

default:
    @just --list

# Build from the Dockerfile pins, start everything, and seed the local DB
test: up seed
    @echo ""
    @echo "Ready: http://localhost:${APP_PORT:-8080}  (API: /api/version)"

# Like test, but wipes the local DB and starts from a dump (file, else TEST_DUMP in .env)
test-dump file="": check-pins
    #!/usr/bin/env bash
    set -euo pipefail
    dump="{{file}}"
    [ -n "$dump" ] || dump="$(just _env TEST_DUMP)"
    if [ -z "$dump" ]; then
        echo "error: give a dump file (just test-dump backups/<file>) or set TEST_DUMP in .env." >&2
        exit 1
    fi
    just _check-test-dump "$dump"
    docker compose build app
    echo "Wiping the local database and loading $dump"
    docker compose down
    docker volume rm -f mapdragon-unified_mongo-data >/dev/null
    {{locutils_run}} locutils load -i "$dump" --yes
    docker compose up -d --wait app
    # Only institutions and admin emails, so local testers can sign in
    # and administer. Terminologies come from the dump.
    {{locutils_run}} locutils --config ./config.yaml -o include \
        --institutions --force-institutions --force-admin \
        --no-terminologies --no-api-ontologies
    echo ""
    echo "Ready: http://localhost:${APP_PORT:-8080}  (API: /api/version)"

# Build the image from the Dockerfile pins and start app + mongo
up: check-pins
    docker compose up -d --build --wait app

# Seed the local mongo from config.yaml (institutions, admins, terminologies)
seed:
    docker compose run --rm seed

# Seed the remote database given by MONGO_URI in .env
seed-remote:
    docker compose run --rm --no-deps seed

# Dump the local mongo service to backups/ (default: timestamped name)
db-dump file="":
    #!/usr/bin/env bash
    set -euo pipefail
    out="$(just _dump-path "{{file}}" local)"
    {{locutils_run}} locutils dump -o "$out"

# Dump SOURCE_MONGO_URI (or MONGO_URI) from .env to backups/; extra args go to locutils dump
db-dump-remote file="" *args:
    #!/usr/bin/env bash
    set -euo pipefail
    out="$(just _dump-path "{{file}}" remote)"
    {{locutils_run}} --no-deps locutils-remote dump -o "$out" {{args}}

# Load a dump into the local mongo service, replacing what's there
db-load file:
    {{locutils_run}} locutils load -i "{{file}}" --replace

# Follow the app logs
logs:
    docker compose logs -f app

# Stop everything (keeps the local database)
down:
    docker compose down

# Stop everything and wipe the local database for a clean test
reset:
    docker compose down -v

# Show the pinned commits and refuse to build if anything overrides them
check-pins:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building with Dockerfile pins:"
    grep -E '^ARG (MAPDRAGON_COMMIT|VITE_MAPDRAGON_VERSION|LOCUTUS_COMMIT)=' Dockerfile | sed 's/^ARG /  /'
    bad=0
    for v in {{pinned_vars}}; do
        if [ -n "${!v:-}" ]; then
            echo "error: $v is set in your shell; unset it so the Dockerfile pin is used." >&2
            bad=1
        fi
        if [ -f .env ] && grep -qE "^[[:space:]]*(export[[:space:]]+)?$v=" .env; then
            echo "error: $v is set in .env; remove or comment it out so the Dockerfile pin is used." >&2
            bad=1
        fi
    done
    exit $bad

# Value of a variable from the shell, else from .env (empty if unset)
[private]
_env name:
    #!/usr/bin/env bash
    set -euo pipefail
    name="{{name}}"
    if [ -n "${!name:-}" ]; then
        printf '%s\n' "${!name}"
    elif [ -f .env ]; then
        sed -nE 's/^[[:space:]]*(export[[:space:]]+)?{{name}}=//p' .env | tail -n 1 \
            | sed -E "s/[[:space:]]+#.*$//; s/^['\"]//; s/['\"]$//"
    fi

# Resolve a dump file name under backups/ and make sure the folder exists
[private]
_dump-path file label:
    #!/usr/bin/env bash
    set -euo pipefail
    out="{{file}}"
    [ -n "$out" ] || out="{{label}}-$(date -u +%Y%m%dT%H%M%SZ).locutus.json.gz"
    case "$out" in
        */*) ;;
        *) out="backups/$out" ;;
    esac
    case "$out" in
        backups/*) ;;
        *) echo "error: dumps are written under backups/, which git ignores (got $out)." >&2; exit 1 ;;
    esac
    mkdir -p backups
    echo "$out"

# Make sure a test dump is usable and only ever lands in the local mongo
[private]
_check-test-dump dump:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{dump}}" ]; then
        echo "error: dump file \"{{dump}}\" does not exist." >&2
        exit 1
    fi
    if [ -n "$(just _env MONGO_URI)" ]; then
        echo "error: the dump is loaded into the local mongo service, but MONGO_URI in .env points the app at another database. Comment out MONGO_URI (use SOURCE_MONGO_URI for remote dumps)." >&2
        exit 1
    fi
    case "{{dump}}" in
        backups/*) ;;
        *) echo "warning: {{dump}} is outside backups/. Dumps hold real user emails; keep them where git ignores them." >&2 ;;
    esac
    if git ls-files --error-unmatch "{{dump}}" >/dev/null 2>&1; then
        echo "warning: {{dump}} is tracked by git. Dumps hold real user emails; remove it from the repo." >&2
    fi
