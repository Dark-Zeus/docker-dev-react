#!/bin/sh

DEF_TAG=$(openssl rand -hex 4)

sed -i 's/\r//' docker-dev-config.env
source docker-dev-config.env

TAG=$(grep "^RAND=" docker-dev-config.env | cut -d'=' -f2-)

if [ -z "$TAG" ]; then
    sed -i "s/^TAG=.*$/TAG=${DEF_TAG}/" docker-dev-config.env
    TAG=${DEF_TAG}
fi

DEF_PROJECT_NAME="react-app"
DEF_MOUNT_PATH=/usr/src/app
DEF_HOST_PORT=8080
DEF_CONTAINER_PORT=3000

# if any of above variables are not set in the config.env, set them to default values
if [ -z "${PROJECT_NAME}" ]; then
    PROJECT_NAME=${DEF_PROJECT_NAME}
fi

if [ -z "${MOUNT_PATH}" ]; then
    MOUNT_PATH=${DEF_MOUNT_PATH}
fi

if [ -z "${HOST_PORT}" ]; then
    HOST_PORT=${DEF_HOST_PORT}
fi

if [ -z "${CONTAINER_PORT}" ]; then
    CONTAINER_PORT=${DEF_CONTAINER_PORT}
fi

IMAGE_NAME=${PROJECT_NAME}-dev-image:${TAG}
CONTAINER_NAME=${PROJECT_NAME}-dev-container-${TAG}

cat <<EOF > Dockerfile.dev
FROM node:20.17.0-alpine3.19
RUN npm install -g corepack && corepack enable && corepack prepare yarn@4.4.1 --activate
WORKDIR ${MOUNT_PATH}
EXPOSE ${CONTAINER_PORT}
CMD ["/bin/ash"]
EOF

DOCKER_FILE_PATH=Dockerfile.dev

echo "Project Name: ${PROJECT_NAME}"

echo "Building Docker Image with Yarn 4.4.1"
echo "Docker Image Name: ${IMAGE_NAME}"

# Build the Docker image if not already built
docker build -t ${IMAGE_NAME} -f ${DOCKER_FILE_PATH} .

echo "Docker Image built successfully"
echo "Starting Docker Container and mounting the project directory"

# check if the container with the same already exists (running or stopped) remove it and start a new one
if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
    docker stop ${CONTAINER_NAME}
    docker rm -f ${CONTAINER_NAME}
fi

# Run the Docker container
docker run -it -e CHOKIDAR_USEPOLLING=true -e WATCHPACK_POLLING=true -p ${HOST_PORT}:${CONTAINER_PORT} --name ${CONTAINER_NAME} -v $(pwd):${MOUNT_PATH} ${IMAGE_NAME} ash