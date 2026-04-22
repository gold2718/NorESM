## Building and running NorESM in a container

### Introduction

This document is intended to provide instructions and tips for
building NorESM and running tests and experiments, all inside of a
container running on your local machine.

To modify and build a new container image, see [BUILD.md](#BUILD.md)

**Note** - Bellow is a WIP. Branches, tags etc might be wrong.

### Obtaining the container (one-time task)

See https://hub.docker.com/r/gold2718/noresm/tags for overview of available values for <tag>.
Functionality from tests are supported for <latest>->.
Obtain the container by running

```
podman pull docker.io/gold2718/noresm3:<tag>
```

docker works as well as podman. You can also substitute docker for
podman below.

### Running the container

To run the container, you need to run the `podman` (or `docker`)
command:

```
podman run --rm --tty --interactive=true          \
           --hostname container                   \
           --volume <HOME_DIR>:/home/user         \
           --volume <CESMDATA_DIR>:/home/cesmdata \
           --env CESMDATAROOT=<CESMDATA_DIR>      \
           --env TZ=Europe/Oslo                   \
           docker.io/gold2718/noresm3:vTest
```

The uppercase keyword arguments are:

- `<HOME_DIR>`: The full path to the "home" directory for the container (/home/user)
- `<CESMDATA_DIR>`: The location of a local directory to store input data. It is recommended to create a local directory with write access to the container so that downloaded files can persist across container sessions. Note that this directory can easily grow to dozens of GB.

You can also use additional `--volume` or `--env` commands to make
more local folders available to the container or to set more
environment variables inside the container when it launches.
