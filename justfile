# Quick local check of the image before deployment.
#
# Builds exactly what the Dockerfile pins (MAPDRAGON_COMMIT, LOCUTUS_COMMIT,
# VITE_MAPDRAGON_VERSION), so what you look at is what gets deployed. Update
# those in the Dockerfile first, then:
#
#   cp .env.example .env    # once; fill in UMLS_API_KEY / VITE_CLIENT_ID
#   just test               # build, start, seed, then open the URL it prints
#
# Run `just` to list all recipes.

pinned_vars := "MAPDRAGON_COMMIT VITE_MAPDRAGON_VERSION LOCUTUS_COMMIT"

default:
    @just --list

# Build from the Dockerfile pins, start everything, and seed the local DB
test: up seed
    @echo ""
    @echo "Ready: http://localhost:${APP_PORT:-8080}  (API: /api/version)"

# Build the image from the Dockerfile pins and start app + mongo
up: check-pins
    docker compose up -d --build --wait app

# Seed the local mongo from config.yaml (institutions, admins, terminologies)
seed:
    docker compose run --rm seed

# Seed the remote database given by MONGO_URI in .env
seed-remote:
    docker compose run --rm --no-deps seed

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
