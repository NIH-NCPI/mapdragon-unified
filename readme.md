# Project: mapdragon-unified - Docker Compose Setup

## Overview

This project uses Docker Compose to set up a multi-service application consisting of:

1. **Map-Dragon** - A frontend service built with React.
2. **Locutus** - A backend service built with Flask using Google Cloud Firestore with MongoDB compatibility.
3. **Nginx** - A reverse proxy to route requests between the frontend and backend.

## Database Configuration

This project supports two database configurations:

1. **Google Cloud Firestore with MongoDB compatibility** (Recommended for production)
2. **Local MongoDB** (For local development)

The Flask backend automatically detects which database to use based on the `DB_TYPE` environment variable and connects accordingly via PyMongo.

## Prerequisites

Before starting, ensure you have the following installed:

- [Docker](https://www.docker.com/products/docker-desktop)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Services Overview

### 1. **MapDragon** (Frontend)

- **Build Context**: `./map-dragon`
- **Dockerfile**: `Dockerfile`
- **Ports**: Exposes port `5173` on the host, mapped to port `5173` in the container.
- **Dependencies**: Waits for `Locutus` to start.

### 2. **Locutus** (Backend)

- **Build Context**: `./locutus`
- **Dockerfile**: `Dockerfile` (automatically detects and handles ARM64/Apple Silicon requirements)
- **Ports**: Exposes port `80` on both the host and the container
- **Environment Variables**:
  - `FLASK_ENV=local`: Runs Flask in local development mode
  - `FLASK_RUN_PORT=80`: Configures Flask to run on port 80
  - `DB_TYPE=mongodb`: Configures the backend to use MongoDB/Firestore-compat mode
  - `GOOGLE_APPLICATION_CREDENTIALS`: Path to Google Cloud credentials (optional for Firestore-compat)
  - `FIRESTORE_MONGO_URI`: MongoDB-compatible connection string for Firestore
- **Volumes**:
  - Mounts `mapdragon-unified-creds.json` into the container (if using GCP credentials)
  - Uses environment variables from `.env`
- **Database**: Connects to either local MongoDB or Google Cloud Firestore using MongoDB wire protocol compatibility
### 3. **Nginx** (Reverse Proxy)

- **Image**: Uses the latest official Nginx image.
- **Ports**: Exposes port `8080` on the host, mapped to port `80` in the container.
- **Configuration**:
  - Uses `nginx.conf` from the project root, mounted into the container at `/etc/nginx/nginx.conf`.

### Network Configuration

- All services are connected to a custom `shared_network` using the `bridge` driver.

## How to Use

### 1. Clone the Repositories

To set up the application, clone the following repositories into the mapdragon-unified repository directory:

- **MapDragon**: [https://github.com/NIH-NCPI/map-dragon.git](https://github.com/NIH-NCPI/map-dragon.git)
- **Locutus**: [https://github.com/NIH-NCPI/locutus.git](https://github.com/NIH-NCPI/locutus.git)

Use the following commands to clone the repositories into the correct locations:

```bash
git clone https://github.com/NIH-NCPI/mapdragon-unified.git 

cd mapdragon-unified
```

```bash
git clone https://github.com/NIH-NCPI/map-dragon.git map-dragon
git clone https://github.com/NIH-NCPI/locutus.git locutus

```

### 2. Prepare Required Files

- **Google Cloud Credentials**:
  Place your GOOGLE_APPLICATION_CREDENTIALS file (`mapdragon-unified-creds.json`) in the project root (contact Morgan to get this file).
- **Environment File**:
  Create a `.env` file in the root directory with necessary environment variables.w Example:
  ```env
  # These are required if you are connecting to a GCP managed service like Firestore or running the application on the cloude. For your local machine, you can skip them. 
  # REGION="us-central1"
  # SERVICE="mapdragon-unified"
  # PROJECT_ID="mapdragon-unified"
  
  # GOOGLE_APPLICATION_CREDENTIALS=./mapdragon-unified-creds.json
  # FIRESTORE_DB_USERNAME=your-firestore-db-username-here
  # FIRESTORE_DB_PASSWORD=your-firestore-db-password-here
  # If using the enterprise version of firestore, you would provide the mongo URI
  # MONGO_URI=mongodb://${FIRESTORE_DB_USERNAME}:${FIRESTORE_DB_PASSWORD}.us-central1.firestore.goog:443/locutus?tls=true&retryWrites=false&loadBalanced=true&authMechanism=SCRAM-SHA-256&authMechanismProperties=ENVIRONMENT:gcp,TOKEN_RESOURCE:FIRESTORE
  
  # For regular mongoDB, you provide the database's connection string
  # You only need DB and Password if you are connecting to a server outside your local machine
  # DB_NAME=admin
  # DB_PASSWORD=password
  # MONGO_URI=mongodb://${DB_NAME}:${DB_PASSWORD}@mongo:27017/locutus
  MONGO_URI=mongodb://localhost:27017/locutus

  # MongoDB databases require you to provide the database name in your connection string like those shown above
  DB_TYPE=mongodb
  ```
  
  **Note**: Replace `your-firestore-password-here` with the actual password from your Firestore MongoDB "Users" tab. The database name in the URI (`locutus`) should match your Firestore MongoDB-compatible Database ID exactly.
- **Nginx Configuration**:
  Ensure `nginx.conf` exists in the project root with a valid configuration. Example:
  ```nginx
  events {
      worker_connections 512; # Adjust as needed
  }

  http {
      server {
          listen 80;

          # Route to mapdragon
          location / {
              proxy_pass http://mapdragon:5173;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
          }

          # Route to locutus API
          location /api/ {
              proxy_pass http://locutus:80;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
          }
      }
  }
  ```

### 3. Build and Start the Services

Run the following command to build and start the services:

```bash
docker-compose up --build
```

### 4. Access the Application

- **Frontend (MapDragon)**: [http://localhost:8080/](http://localhost:8080/)
- **Backend (Locutus)**: [http://localhost:8080/api](http://localhost:8080/api)

### 5. Stop the Services

To stop and remove the containers, networks, and volumes:

```bash
docker-compose down --volumes
```

## Firestore MongoDB Compatibility

This project uses Google Cloud Firestore's MongoDB-compatible mode instead of a traditional MongoDB instance. Key details:

### Connection Requirements

- **URI Format**: The `FIRESTORE_MONGO_URI` must include specific parameters:
  ```
  mongodb://username:password@project-id.region.firestore.goog:443/database-name?tls=true&retryWrites=false&loadBalanced=true&authMechanism=SCRAM-SHA-256&authMechanismProperties=ENVIRONMENT:gcp,TOKEN_RESOURCE:FIRESTORE
  ```
- **Database Name**: Must exactly match your Firestore MongoDB-compatible Database ID (e.g., `mapdragon-unified#loc-mongo`). Use URL encoding for special characters (`#` becomes `%23`).
- **Authentication**: Username and password come from the Firestore MongoDB "Users" tab in Google Cloud Console.
- **Environment Variable**: The backend automatically uses `FIRESTORE_MONGO_URI` when `DB_TYPE=mongodb`, falling back to `MONGO_URI` for local development.

### Supported Operations

- Basic CRUD operations via PyMongo
- Most standard MongoDB queries
- **Note**: Some MongoDB operators like `$addToSet` are not supported and require workarounds

### Migration Notes

- Firestore native import/export commands do not work with MongoDB-compatible databases
- To migrate data from native Firestore to MongoDB-compat, use a custom Python script that reads from `google-cloud-firestore` and writes via `pymongo`

## Troubleshooting

### General Issues

- **Caching Issues During Builds**:
  If you encounter unexpected behavior or changes not being applied, rebuild the services without using the cache:
  ```bash
  docker-compose build --no-cache
  ```

### Firestore MongoDB Compatibility Issues

- **"Invalid database" Error**:
  - Ensure the database name in your URI exactly matches your Firestore MongoDB-compatible Database ID
  - Check for proper URL encoding of special characters (e.g., `#` should be `%23`)
  
- **"ServerSelectionTimeoutError"**:
  - Verify Docker container has root certificates (`ca-certificates`)
  - Confirm outbound network access to `*.firestore.goog:443`
  - Ensure TLS is enabled in the URI
  - Check username/password credentials

- **"Operator not supported" Errors**:
  - Some MongoDB operators like `$addToSet` are not supported
  - Use read-modify-write patterns as workarounds
  - Consult Firestore MongoDB compatibility documentation for supported operations

### Recent Fixes

- **Database Name Parsing**: The backend now automatically parses the database name from the `FIRESTORE_MONGO_URI` path, ensuring exact matching with Firestore MongoDB-compatible Database IDs
- **PyMongo Compatibility**: Replaced Firestore-native methods (`.to_dict()`, `.stream()`) with PyMongo equivalents in the Study API  
- **Operator Workarounds**: Implemented workarounds for unsupported MongoDB operators like `$addToSet` using read-modify-write patterns
- **Environment Variable Priority**: The backend now prioritizes `FIRESTORE_MONGO_URI` over `MONGO_URI` when `DB_TYPE=mongodb`



