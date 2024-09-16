#!/bin/sh

# Generate a random 8 digit hex number
DEF_TAG=$(openssl rand -hex 8)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

sed -i 's/\r//' docker-dev-config.env # Remove Windows line endings
source docker-dev-config.env

# Get the TAG is set in the config.env
TAG=$(grep "^TAG=" docker-dev-config.env | cut -d'=' -f2-)

# if TAG is not set in the config.env, set it to a random 8 digit hex number
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

echo -e "Project Name: ${YELLOW}${PROJECT_NAME}${NC}\n"

# Build the Docker image if not already built
# Check if the image with the same name already exists
if [ "$(docker images -q ${IMAGE_NAME} 2> /dev/null)" ]; then
    echo -e "${YELLOW}Docker Image already exists. Skipping the build process...${NC}"
else
    read -p "Install git in the dev-container (y/n)?" GIT

    cat <<EOF > Dockerfile.dev
FROM node:20.17.0-alpine3.19

RUN npm remove -g yarn || true
RUN npm install -g corepack && corepack enable && corepack prepare yarn@4.4.1 --activate
EOF

    if [ "$GIT" = "y" ]; then
        cat <<EOF >> Dockerfile.dev
RUN apk add --no-cache git
EOF
    fi

    cat <<EOF >> Dockerfile.dev
WORKDIR ${MOUNT_PATH}
EXPOSE ${CONTAINER_PORT}
CMD ["/bin/ash"]
EOF

    DOCKER_FILE_PATH=Dockerfile.dev
    echo -e "${BLUE}Building Docker Image with Yarn 4.4.1"
    echo -e "Docker Image Name:${YELLOW} ${IMAGE_NAME}${NC}"
    docker build -t ${IMAGE_NAME} -f ${DOCKER_FILE_PATH} .
fi

BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}Docker Image built successfully${NC}\n"
    echo -e "${BLUE}Starting Docker Container and mounting the project directory${NC}"
    # check if the container with the same already exists (running or stopped) remove it and start a new one
    if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
        docker stop ${CONTAINER_NAME}
        docker rm -f ${CONTAINER_NAME}
    fi

    # Run the Docker container
    docker run --rm -it -e CHOKIDAR_USEPOLLING=true -e WATCHPACK_POLLING=true -p ${HOST_PORT}:${CONTAINER_PORT} --name ${CONTAINER_NAME} -v $(pwd):${MOUNT_PATH} --user $(id -u):$(id -g) ${IMAGE_NAME} ash -c "echo Y | yarn --version && ash"

else
    echo -e "${RED}Docker Image build failed with status ${BUILD_STATUS}${NC}\n"
    exit 1
fi