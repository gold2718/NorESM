# syntax=docker/dockerfile:1

## Base image is ESMF build stack
# See https://github.com/esmf-org/esmf-containers/blob/main/build-esmf/linux-gcc/base/Dockerfile

# build arguments
ARG BASE_TAG=latest
ARG ESMF_VERSION=8.9.0
## Generic microarchitecture to build for. Keep this generic (see the pin below).
## x86_64 matches the base image; x86_64_v3 buys AVX2 but forces a full rebuild
## of the base stack and drops pre-Haswell / pre-Zen1 hosts.
## NB: do NOT name this TARGET_ARCH. ARGs are exported into every RUN, GNU Make
## imports the environment, and TARGET_ARCH is a built-in Make variable used in
## its implicit rules (COMPILE.f = $(FC) $(FFLAGS) $(TARGET_ARCH) -c). That
## splices a bare "x86_64" into every compile and breaks openblas/lapack with
## "gfortran: error: x86_64: linker input file not found".
ARG NORESM_TARGET_ARCH=x86_64
ARG MAINTAINER=unknown

FROM esmf/esmf-build-stack:${BASE_TAG}

## ARGs declared before FROM are out of scope after it -- re-declare the ones
## the build stages below still need.
ARG ESMF_VERSION
ARG NORESM_TARGET_ARCH
ARG MAINTAINER

## Add an about string
LABEL description="Container for building and running NorESM3"

## Add some provenance
LABEL maintainer="${MAINTAINER}"

ENV USER=root

USER root

## Add some basic tools to the ESMF build stack
RUN                                                 \
  apt-get update --yes                           && \
  DEBIAN_FRONTEND=noninteractive                    \
  apt-get install --yes --no-install-recommends     \
  gdb                                               \
  m4                                                \
  libgeos-dev                                       \
  libproj-dev                                       \
  npm                                               \
  pip                                               \
  rsync                                             \
  subversion                                        \
  valgrind                                          \
  valgrind-mpi                                      \
  wget                                           && \
  apt-get clean                                  && \
  rm -rf /var/lib/apt/lists/*

ENV PATH=/usr/local/bin:$PATH

## Pin a generic microarchitecture so the image stays portable.
## Spack defaults to concretizer:targets:granularity=microarchitectures, which
## pins to the *build host's* CPU (e.g. zen3). znver3 codegen emits AMD-only
## opcodes (clzero, mwaitx) that SIGILL on any Intel host, however modern.
## x86_64 also matches the base image, so --reuse below picks up its existing
## builds instead of rebuilding the whole stack.
## MUST come before the first spack install.
RUN                                                                    \
  . ${SPACK_ROOT}/share/spack/setup-env.sh                          && \
  spack env activate ${SPACK_ENV_DEFAULT}                           && \
  spack config add "packages:all:require:'target=${NORESM_TARGET_ARCH}'"

## Install Python libaries
RUN                                                 \
  . ${SPACK_ROOT}/share/spack/setup-env.sh       && \
  spack env activate ${SPACK_ENV_DEFAULT}        && \
  spack install --add --fail-fast -j4               \
  py-matplotlib py-joblib py-netcdf4 py-pytest

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
  spack config add "packages:parallelio:require:'+pnetcdf +fortran'"    && \
  spack add esmf @=${ESMF_VERSION}+external-parallelio+pnetcdf          && \
  spack add parallelio +pnetcdf +fortran                                && \
  spack add netlib-lapack                                               && \
  spack add parallel-netcdf                                             && \
  spack concretize --force --reuse                                      && \
  spack install --no-checksum                                           && \
  spack gc -y                                                           && \
  spack clean --all

# Verification gate for correct parallelio install
RUN                                                                          \
  . ${SPACK_ROOT}/share/spack/setup-env.sh                                && \
  spack env activate ${SPACK_ENV_DEFAULT}                                 && \
  nm -D "$(spack location -i parallelio)/lib/libpioc.so" | grep -q ncmpi_ || \
  { echo "FATAL: PIO built without PnetCDF"; exit 1; }                    && \
  grep -q 'ESMF_PNETCDF=1' "$(spack location -i esmf)/lib/esmf.mk"        && \
  echo "OK, ESMF and PIO agree on PnetCDF"

# Verification gate for portable microarchitecture -- fail loudly rather than
# shipping an image that SIGILLs on a different CPU vendor. Allows any generic
# target (x86_64, x86_64_v2..v4, aarch64) rather than exactly the requested one,
# since the base image's own linux-x86_64 tree legitimately remains alongside a
# NORESM_TARGET_ARCH=x86_64_v3 build. Anything vendor-specific (zen3, skylake)
# fails the build.
RUN                                                                          \
  stray="$(ls -1 ${SPACK_ROOT}/opt/spack | grep '^linux-' |                  \
           grep -vE '^linux-(x86_64(_v[234])?|aarch64)$' || true)";          \
  if [ -n "$stray" ]; then                                                   \
    echo "FATAL: host-specific install trees present: $stray"; exit 1;       \
  fi;                                                                        \
  echo "OK, all installs target a generic microarchitecture"

## Install Claude code
RUN npm install -g @anthropic-ai/claude-code

## Install ncview2 (https://github.com/benmsanderson/ncview2) with geo extras
## (cartopy/cmocean) for coastline overlays and ocean colormaps.
## GEOS/PROJ system libs are already installed above
## (libgeos-dev, libproj-dev).
RUN pip install --no-cache-dir --break-system-packages \
              "ncview2[geo] @ git+https://github.com/benmsanderson/ncview2.git"

## Set the environment (need to still be user root here)
## Multiple variables on one line does not seem to work on podman
ENV HOSTNAME "container"
ENV CIMEHOST "container"
ENV MODULES_DEFAULT="esmf netlib-lapack ${MODULES_DEFAULT}"

## Final useful environment adjustments
RUN \
  . ${SPACK_ROOT}/share/spack/setup-env.sh                              && \
  spack env activate ${SPACK_ENV_DEFAULT}                               && \
  echo "export EBROOTESMF=\"$(spack find --format "{prefix}" esmf)\"" >> /home/dev/.bash_aliases && \
  echo "export LAPACK_LIBDIR=\"$(spack find --format "{prefix}" netlib-lapack)/lib\"" >> /home/dev/.bash_aliases && \
  chown dev:users /home/dev/.bash_aliases
COPY --chown=dev:dev bashrc /home/dev/.bashrc
USER dev:users
SHELL ["/bin/bash", "-l"]
#ENTRYPOINT "/bin/bash", "-l"
