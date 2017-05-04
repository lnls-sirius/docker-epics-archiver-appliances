# Docker images for the EPICS Archiver Appliances

Docker containers holding the EPICS archiver appliances.

## Building

1) Execute `build-docker-generic-appliance.sh` to build the base image for all the containers which will hold the appliances.
2) Change the working directory to `docker-appliance-images` and execute `build-docker-appliance-images.sh`. It will build 4 different images, one for each appliance.

## Running

Change to `docker-appliance-images/` and execute `run-appliance-images.sh` to start all appliances. Enjoy!
