# Stage 1: Build the React app

# FROM node:latest as build
FROM node:18-alpine AS build 

ARG VITE_CLIENT_ID
ARG VITE_VOCAB_ENDPOINT=/api 
ARG VITE_MAPDRAGON_VERSION=''
ARG FLASK_ENV='dev' 

# Add git 
RUN apk update && apk add --no-cache git

WORKDIR /app
# Pull MD down from GH
RUN git clone https://github.com/NIH-NCPI/map-dragon .

RUN echo "VITE_CLIENT_ID=$VITE_CLIENT_ID" > .env && \
  echo "VITE_VOCAB_ENDPOINT=$VITE_VOCAB_ENDPOINT" >> .env
RUN  if [[ -z $VITE_MAPDRAGON_VERSION ]] ; \
    then echo "VITE_MAPDRAGON_VERSION=`git describe --tags`-$FLASK_ENV" >> .env ; \
  else echo "VITE_MAPDRAGON_VERSION=$VITE_MAPDRAGON_VERSION" >> .env ; \
  echo "VITE_GH_VERSION=`git describe --tags`-$FLASK_ENV" \
  fi

RUN cat .env 

RUN npm install 
RUN npm run build

# Stage 2: 
FROM python:3.13-alpine
ARG FLASK_PORT=8080
# ARG MONGO_URI=mongodb://localhost:27017/locutus



RUN apk update && apk add --no-cache git

WORKDIR /app

RUN git clone -b mongodb https://github.com/NIH-NCPI/locutus .
COPY --from=build /app/dist ./src/locutus/static

RUN pip install gunicorn && pip install .

ENV FLASK_APP=src/locutus/app.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=$FLASK_PORT
ENV HOST=0.0.0.0
ENV UNICORN_HOST=0.0.0.0:$FLASK_PORT 
# ENV FLASK_ENV=$FLASK_ENV
# ENV MONGO_URI=$MONGO_URI
# ENV UMLS_API_KEY=$UMLS_API_KEY

EXPOSE $FLASK_PORT 

CMD ["gunicorn", "-b", ":8080", "src.locutus.app:create_app()"] 
# CMD ["flask", "run"]



