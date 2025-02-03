# Project: mapdragon-unified - Docker Compose Setup

## Overview

This project uses Docker Compose to set up a multi-service application consisting of:

1. **Map-Dragon** - A frontend service built with React.
2. **Locutus** - A backend service built with Flask.
3. **Nginx** - A reverse proxy to route requests between the frontend and backend.

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
- **Dockerfile**: `Dockerfile.mac` (Used if you are using a MacBook with an ARM-based chip.)
- **Ports**: Exposes port `80` on both the host and the container.
- **Environment Variables**:
  - `FLASK_ENV=local`: Runs Flask in local development mode.
  - `FLASK_RUN_PORT=80`: Configures Flask to run on port 80.
  - `GOOGLE_APPLICATION_CREDENTIALS`: Path to Google Cloud credentials.
- **Volumes**:
  - Mounts `mapdragon-unified-creds.json` into the container at `/app/mapdragon-unified-creds.json`.
  - Uses environment variables from `loc.env`.

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

- **Using Dockerfile.mac**
   If you are using a MacBook with an ARM-based chip, ensure you are using the Dockerfile.mac located in the locutus directory. This Dockerfile is specifically tailored to build and run the Locutus service on ARM-based hardware.
- **Google Cloud Credentials**:
  Place your GOOGLE_APPLICATION_CREDENTIALS file (`mapdragon-unified-creds.json`) in the project root (contact Morgan to get this file).
- **Environment File**:
  Create a `loc.env` file in the root directory with necessary environment variables. Example:
  ```env
  REGION = "us-central1"
  SERVICE = "mapdragon-unified"
  PROJECT_ID="mapdragon-unified"
  ```
- **Nginx Configuration**:
  Ensure `nginx.conf` exists in the project root with a valid configuration. Example:
```
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

## Troubleshooting

- **Caching Issues During Builds**:
  If you encounter unexpected behavior or changes not being applied, rebuild the services without using the cache:
  ```bash
  docker-compose build --no-cache
  ```



