# docker-build

This directory contains Dockerfiles and scripts for building
Debian and CentOS Newlib and Linux toolchain packages.

## Notes

- The environment variable `PACKAGE_VERSION` must contain a hyphen
  separating two parts e.g. `2018.1-1`.
- The first part of the version is included in the package name
  to allow parallel installs of multiple toochain releases.
- The second part of the version isn't included in the package name
  to allow revisions to a particular toolchain release.

## Directory Layout

Multiple packages with the same major version share the same prefix so
that one PATH entry will make available all tools associated with a
major release. Example directory prefix for the version `2018.1-1`:

```
export RISCV=/opt/SiFive/SDK/2018.1
export PATH=${PATH}:${RISCV}/bin
```

## Package files

SiFive Ubuntu multilib toolchain packages for the version `2018.1-1`:

- `sifive-sdk-2018.1-gcc-common_2018.1-1_amd64.deb`
- `sifive-sdk-2018.1-gcc-newlib_2018.1-1_amd64.deb`
- `sifive-sdk-2018.1-gcc-linux_2018.1-1_amd64.deb`

SiFive CentOS multilib toolchain packages for the version `2018.1-1`:

- `sifive-sdk-2018.1-gcc-common-2018.1-1.x86_64.rpm`
- `sifive-sdk-2018.1-gcc-newlib-2018.1-1.x86_64.rpm`
- `sifive-sdk-2018.1-gcc-linux-2018.1-1.x86_64.rpm`

## Docker build

The packages are created using docker containers so that the build process
is agnostic to the host operating system. The package build script
builds a multilib Newlib toolchain and a multilib Linux toolchain and then
factors the common files into a toolchain-common package.

### Creating Ubuntu packages for the Newlib and Linux toolchains:

Execute these commands from the `riscv-gnu-toolchain` top-level directory:

```
docker build -f docker-build/Dockerfile.ubuntu -t toolchain-ubuntu docker-build/
docker run --rm -e PACKAGE_VERSION=2018.1-1 -v $(pwd):/usr/src/app \
       	           toolchain-ubuntu docker-build/package-build.sh
```

### Creating CentOS packages for the Newlib and Linux toolchains:

Execute these commands from the `riscv-gnu-toolchain` top-level directory:

```
docker build -f docker-build/Dockerfile.centos -t toolchain-centos docker-build/
docker run --rm -e PACKAGE_VERSION=2018.1-1 -v $(pwd):/usr/src/app \
       	   	   toolchain-centos docker-build/package-build.sh
```
