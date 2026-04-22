# syntax=docker/dockerfile:1

## Base image is ESMF build stack
# See https://github.com/esmf-org/esmf-containers/blob/main/build-esmf/linux-gcc/base/Dockerfile

# build arguments
ARG BASE_TAG=latest
ARG ESMF_VERSION=8.9.0

FROM esmf/esmf-build-stack:${BASE_TAG}

## Add an about string
LABEL description="Container for building and running NorESM3"

## Add some provenance
MAINTAINER ${USER}

ENV USER=root

USER root

## Add some basic tools to the ESMF build stack
RUN                                                 \
  apt-get update --yes                           && \
  DEBIAN_FRONTEND=noninteractive                    \
  apt-get install --yes --no-install-recommends     \
  gdb                                               \
  pip                                               \
  subversion                                        \
  valgrind                                          \
  valgrind-mpi                                      \
  wget                                           && \
  apt-get clean                                  && \
  rm -rf /var/lib/apt/lists/*
#  libblas-dev                                       \
#  liblapack-dev                                     \
#  libpnetcdf-dev                                    \
#  apt-get install --yes --no-install-recommends     \
#  python3-matplotlib                                \
#  python3-joblib                                    \
#  python3-netcdf4                                   \
#  python3-pytest                                 && \

ENV PATH=/usr/local/bin:$PATH

## Install Python libaries
RUN                                                 \
  . ${SPACK_ROOT}/share/spack/setup-env.sh       && \
  spack env activate ${SPACK_ENV_DEFAULT}        && \
  spack install --add py-matplotlib              && \
  spack install --add py-joblib                  && \
  spack install --add py-netcdf4                 && \
  spack install --add py-pytest

## Perl libraries
RUN                                                                         \
  apt-get update --yes                                                   && \
  DEBIAN_FRONTEND=noninteractive                                            \
    apt-get --yes --no-install-recommends install zlib1g-dev libxml2-dev && \
  rm -rf /var/lib/apt/lists/*                                            && \
  cpan install XML::LibXML

## Install ESMF
ENV ESMF_VERSION="${ESMF_VERSION}"
RUN                                                                        \
  . ${SPACK_ROOT}/share/spack/setup-env.sh                              && \
  spack env activate ${SPACK_ENV_DEFAULT}                               && \
  spack add esmf @=8.9.0+external-parallelio+pnetcdf                    && \
  spack add netlib-lapack                                               && \
  spack add parallel-netcdf                                             && \
  spack concretize --force --reuse                                      && \
  spack install --no-checksum                                           && \
  spack gc -y                                                           && \
  spack clean --all
#  spack add esmf @8.9.0 +external-parallelio +pnetcdf ~python           && \


## Set the environment (need to still be user root here)
## Multiple variables on one line does not seem to work on podman
ENV HOSTNAME "container"
ENV CIMEHOST "container"
ENV MODULES_DEFAULT="esmf netlib-lapack ${MODULES_DEFAULT}"

## Final useful environment adjustments
RUN \
  . ${SPACK_ROOT}/share/spack/setup-env.sh                              && \
  spack env activate ${SPACK_ENV_DEFAULT}                               && \
  echo "export EBROOTESMF=\"$(dirname $(dirname $(find ${SPACK_ROOT} -name esmf.mk)))\"" >> /home/dev/.bash_aliases && \
  echo "export LAPACK_LIBDIR=\"$(spack find --format "{prefix}" netlib-lapack)\"" >> /home/dev/.bash_aliases
COPY --chown=dev:dev bashrc /home/dev/.bashrc
USER dev:users
SHELL ["/bin/bash", "-l"]
#ENTRYPOINT "/bin/bash", "-l"
