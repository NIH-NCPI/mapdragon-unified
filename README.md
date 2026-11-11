# Unified Map Dragon
This repository is for building a single containerized version of the map-dragon application. 

The final image will be based on the following repositories:
- **MapDragon**: [https://github.com/NIH-NCPI/map-dragon.git](https://github.com/NIH-NCPI/map-dragon.git)
- **Locutus**: [https://github.com/NIH-NCPI/locutus.git](https://github.com/NIH-NCPI/locutus.git)

## Environment Variables Required to Build Container
When building the image itself, there are a handful of environment variables you'll need to provide:
- VITE_CLIENT_ID - The ouath2 client ID to be used to authenticate users. 
- FLASK_ENV (OPTIONAL) - This will be appended to the front-end version
- VITE_MAPDRAGON_VERSION (OPTIONAL) - If you want to provide a specific version for the front end

## Environment Variables Required for Deploying to GCP Via Cloud Run
- REGION=us-central
- PROJECT_ID (GCP project to deploy to)
- GOOGLE_APPLICATION_CREDENTIALS (required) This is the service token created for the relevant project 
## Environment Variables Required for Running Container
- UMLS_API_KEY - This is required and is an API token generated for UMLS access
- MONGO_URI - This is required and contains the necessary credentials necessary for connecting to the MongoDB database. 

For now, the container should always listen on port 8080. 

### MONGO_URI Notes
We are currently assuming username and password as well as the database name are contained in the URI. If those need to be handled separately, we'll need to make some changes to the underlying application. The convention Google uses is: 

mongodb://{username}:{password}@{hostname}:{port}/{database} (and includes some GCP specific http parameters)

For our local development, we can simply use something along the lines of:
mongodb://localhost:27017/locutus  (where locutus is the database we are using)

# DB Provisioning
For now, provisioning a new database simply requires loading a couple of core terminologies and some basic search configuration details. This can be run as a simple script. Once the database has those two terminologies, it should be ready for use. 

# Local testing with Docker Compose
`docker-compose.yml` builds the same `Dockerfile` used by the GCP and AWS deployments and runs it alongside a local MongoDB, so you can check that a front-end/back-end commit combination works before deploying.

```bash
cp .env.example .env          # set UMLS_API_KEY (required) and VITE_CLIENT_ID
docker compose up --build
```

- App: http://localhost:8080 
- API health/version: http://localhost:8080/api/version
- Local MongoDB (for seeding/inspection): `mongodb://locutus:locutus@localhost:27017/locutus?authSource=admin`

The `app` service has a healthcheck against `/api/version`. `docker compose ps` shows `healthy` once it's serving.

**Testing other commits:** set `MAPDRAGON_COMMIT`, `VITE_MAPDRAGON_VERSION`, and/or `LOCUTUS_COMMIT` in `.env` (or the shell) and rebuild. If they're unset, the commits pinned in the `Dockerfile` are used.

**Testing against a cloud database:** set `MONGO_URI` in `.env` (see `.env.example` for Firestore and DocumentDB examples) and start only the app:

```bash
docker compose up --build --no-deps app
```

**Platform:** images are built for `linux/amd64` by default to match Cloud Run and AWS. On Apple Silicon this runs under emulation and is slow. Set `DOCKER_PLATFORM=linux/arm64` for faster local builds.

**Reset the local database:** `docker compose down -v`

Note: a fresh local database has no terminologies loaded. See "DB Provisioning" above.

**Testing with a copy of real data:** pull a dump of the database you work with into `backups/` (git-ignored), then point `TEST_DUMP` at it in `.env`:

```bash
just db-dump-remote dev.locutus.json.gz   # dumps SOURCE_MONGO_URI (or MONGO_URI) from .env
# .env: TEST_DUMP=backups/dev.locutus.json.gz
just test
```

With `TEST_DUMP` set, every `just test` wipes the local database, loads the dump and then seeds only the institutions and admin emails from `config.yaml`, so you can sign in. Dumps hold real user emails and the admin list: keep them in `backups/` and never commit them. `just db-dump` and `just db-load <file>` copy the local database to and from a file. See the [locutils docs](https://github.com/carrollaboratory/locutus-utils) for `locutils dump` / `locutils load`.
