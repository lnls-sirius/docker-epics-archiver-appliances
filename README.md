# Docker images for the EPICS Archiver Appliances

Docker containers holding the EPICS archiver appliances.

## Building

1) Execute `build-docker-generic-appliance.sh` to build the base image for all the containers which will hold the appliances.
2) Change the working directory to `docker-appliance-images` and execute `build-docker-appliance-images.sh`. It will build 4 different images, one for each appliance.

## Running

Change to `docker-appliance-images/` and execute `run-appliance-images.sh` to start all appliances. This script should be used only during development. For production, use these images with Docker Compose, Swarm or Kubernetes, according to this [project](https://github.com/lnls-sirius/docker-epics-archiver-composed). Enjoy!

## Dockerhub

All images described by this project were pushed into [this Dockerhub repo](https://hub.docker.com/u/lnlscon/).
