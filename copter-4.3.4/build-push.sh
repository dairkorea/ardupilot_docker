set -x
IMAGE_NAME=registry.dairkorea.com/github/ardupilot/sitl/copter
IMAGE_TAG=4.3.4-A
if [[ `docker build . -t ${IMAGE_NAME}:${IMAGE_TAG}` -ne 0 ]]; then
    echo "docker build failed"
    exit 1
fi
if [[ `docker push ${IMAGE_NAME}:${IMAGE_TAG}` -ne 0 ]]; then
    echo "docker push failed"
    exit 1
fi

