#!/bin/bash
set -e

echo "================================"
echo "Building Hive Metastore Image"
echo "================================"

# Configuration
HIVE_IMAGE="hive-metastore"
HIVE_VERSION="3.1.3-jdk11-hadoop3.3.6"
TAG="local"
FULL_IMAGE_NAME="${HIVE_IMAGE}:${HIVE_VERSION}-${TAG}"

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if Dockerfile exists
if [ ! -f "dockerfiles/hive-metastore/Dockerfile" ]; then
    echo "ERROR: Dockerfile not found at dockerfiles/hive-metastore/Dockerfile"
    exit 1
fi

# Check if configuration templates exist
if [ ! -f "dockerfiles/hive-metastore/config/core-site.xml.template" ]; then
    echo "ERROR: core-site.xml.template not found"
    exit 1
fi

if [ ! -f "dockerfiles/hive-metastore/config/metastore-site.xml.template" ]; then
    echo "ERROR: metastore-site.xml.template not found"
    exit 1
fi

if [ ! -f "dockerfiles/hive-metastore/entrypoint.sh" ]; then
    echo "ERROR: entrypoint.sh not found"
    exit 1
fi

echo "Building Docker image: ${FULL_IMAGE_NAME}"
echo ""

# Build the image
docker build \
    -t "${FULL_IMAGE_NAME}" \
    -f dockerfiles/hive-metastore/Dockerfile \
    dockerfiles/hive-metastore/

# Check if build was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "================================"
    echo "Build Successful!"
    echo "================================"
    echo "Image: ${FULL_IMAGE_NAME}"
    echo ""

    # Display image details
    echo "Image Details:"
    docker images "${HIVE_IMAGE}" | grep "${HIVE_VERSION}"

    echo ""
    echo "Image Layers:"
    docker history "${FULL_IMAGE_NAME}" --no-trunc=false --human=true | head -n 10

    echo ""
    echo "Image Size:"
    docker inspect "${FULL_IMAGE_NAME}" --format='{{.Size}}' | numfmt --to=iec-i --suffix=B

    echo ""
    echo "To run the image locally:"
    echo "  docker run -e AWS_ACCESS_KEY_ID=<key> \\"
    echo "             -e AWS_SECRET_ACCESS_KEY=<secret> \\"
    echo "             -e AWS_REGION=ap-south-1 \\"
    echo "             -e S3_BUCKET=users.anxietyaicure.com \\"
    echo "             -e DB_HOST=postgres \\"
    echo "             -e DB_PORT=5432 \\"
    echo "             -e DB_NAME=metastore \\"
    echo "             -e DB_USER=hive \\"
    echo "             -e DB_PASSWORD=<password> \\"
    echo "             -p 9083:9083 \\"
    echo "             ${FULL_IMAGE_NAME}"

else
    echo ""
    echo "================================"
    echo "Build Failed!"
    echo "================================"
    exit 1
fi
