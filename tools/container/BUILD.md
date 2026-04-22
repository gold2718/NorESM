## [Building the NorESM container image](https://xkcd.com/1988/)

### Introduction

This document is intended to help you build a podman (Docker)
container which can build and run NorESM

**Note** - Bellow is a WIP. Branches, tags etc might be wrong.

### Building the container image

To build a new image, edit Dockerfile_NorESM3.gnu and call the build
script with a tag name, e.g.:
```
<NorESMroot>/tools/container/build_noresm3_image.sh <tag name>
```

You can also change the image name by setting the `IMAGE_NAME` environment
variable.
