# Stage 1: Build the React app

# FROM node:latest as build
FROM node:18-alpine AS build 

# We will need to update these commits each time we want to publish a new
# release. I'm setting these as ENVs so that they can exist outside of 
# any particular build. The Map Dragon version must be provided here as 
# well so that it gets baked into the build. 
ARG MAPDRAGON_COMMIT="506c53eabf2814f9a6d93aaed985565a03554a02"
ARG VITE_MAPDRAGON_VERSION="v2.2.2"

ARG VITE_CLIENT_ID
ARG VITE_VOCAB_ENDPOINT=/api 
ARG DEPLOY_ENV='dev' 


# Add git 
RUN apk update && apk add --no-cache git

WORKDIR /app
# Pull MD down from GH
RUN git clone https://github.com/NIH-NCPI/map-dragon . && \
  git checkout $MAPDRAGON_COMMIT 

RUN echo "VITE_CLIENT_ID=$VITE_CLIENT_ID" > .env && \
  echo "VITE_VOCAB_ENDPOINT=$VITE_VOCAB_ENDPOINT" >> .env && \
  echo "VITE_MAPDRAGON_VERSION=$VITE_MAPDRAGON_VERSION" >> .env && \
  echo "VITE_GH_VERSION=`git describe --tags`-$DEPLOY_ENV" >> .env

RUN cat .env 

RUN npm install 
RUN npm run build

# Stage 2: 
FROM python:3.13-alpine
ARG FLASK_PORT=8080

ARG LOCUTUS_COMMIT="e2e3772716cb028c36801f5d1b2e5b983497c420"
ENV LOCUTUS_COMMIT=${LOCUTUS_COMMIT}


RUN apk update && apk add --no-cache git

WORKDIR /app

RUN echo git clone https://github.com/NIH-NCPI/locutus . && \
  echo git checkout $LOCUTUS_COMMIT

RUN git clone https://github.com/NIH-NCPI/locutus . && \
  git checkout $LOCUTUS_COMMIT

COPY --from=build /app/dist ./src/locutus/static

RUN pip install gunicorn && pip install .

ENV FLASK_APP=src/locutus/app.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=$FLASK_PORT
ENV HOST=0.0.0.0
ENV UNICORN_HOST=0.0.0.0:$FLASK_PORT 

EXPOSE $FLASK_PORT 

# Required for AWS connections
RUN wget -P / https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
CMD ["gunicorn", "-b", ":8080", "src.locutus.app:create_app()"] 
# CMD ["flask", "run"]



