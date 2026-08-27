#! /bin/bash

# =================================================================
#
# This script builds an image of the NorESM container.
#
# Use cases include:
# 1. Create custom image from Dockerfile_NorESM3.gnu
# 2. Save a modified version of the the existing image.
# It is not necessary if you are only using the existing one
#
# =================================================================

command="podman"
dry_run="no"

usage() {
    local cmd="$(basename ${BASH_SOURCE[0]})"
    echo "usage: ${cmd} [ --dry-run ] [ --docker ] <tag name>"
}

if [ -L "${BASH_SOURCE[0]}" ]; then
    myfile="$(readlink -f ${BASH_SOURCE[0]})"
else
    myfile="${BASH_SOURCE[0]}"
fi
if [ -n "${myfile}" ]; then
    context_dir="$(cd $(dirname ${myfile}}); pwd -P)"
else
    echo "ERROR: No BASH_SOURCE??"
    usage
    exit -1
fi

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

IMAGE_NAME="${IMAGE_NAME:-docker.io/gold2718/noresm3}"
TAG=""

while [ $# -gt 0 ]; do
    if [ "${1}" == "--dry-run" ]; then
        dry_run="yes"
        shift
    elif [ "${1}" == "--docker" ]; then
        command="sudo docker"
        shift
    elif [ -z "${TAG}" ]; then
        TAG="${1}"
        shift
    else
        echo "ERROR: Unrecognized argument, '${1}'"
        usage
        exit 3
    fi
done

cd ${context_dir}
if [ $? -ne 0 ]; then
    echo "ERROR: Unable to cd to image directory, '${context_dir}'"
    exit 2
fi

#podman pull continuumio/miniconda3
buildargs="--file Dockerfile_NorESM3.gnu"
buildargs="${buildargs} --tag ${IMAGE_NAME}:${TAG}"
buildargs="${buildargs} --build-arg MAINTAINER=\"${USER}\""
if [ "${dry_run}" == "yes" ]; then
    echo "Command: ${command} build ${buildargs} ${context_dir}"
else
    ${command} build ${buildargs} ${context_dir}
fi
