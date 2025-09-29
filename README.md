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
