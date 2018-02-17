# docker-build

This directory contains Dockerfiles and scripts for building
Debian and CentOS Newlib and Linux toolchain packages.

## Notes

- The environment variable `PACKAGE_TYPE` must be `newlib` or `linux`.
- The environment variable `PACKAGE_VERSION` must contain a hyphen
  separating two parts e.g. `2018.1-1`.
- The first part of the version is included in the package name
  to allow parallel installations of toochain releases.
- The second part of the version isn't included in the package name
  to allow revisions to a particular toolchain release.

## Directory Layout

Multiple packages with the same major version share the same prefix so
that one PATH setting selects all tools associated with the release.
Example directory prefix for the version `2018.1-1`:

```
export RISCV=/opt/riscv/tools/2018.1
export PATH=${PATH}:${RISCV}/bin
```

## Package files

Example package files for the version `2018.1-1`:

- `riscv-tools-2018.1-newlib-toolchain-2018.1-1.x86_64.rpm`
- `riscv-tools-2018.1-newlib-toolchain_2018.1-1_amd64.deb`
- `riscv-tools-2018.1-linux-toolchain-2018.1-1.x86_64.rpm`
- `riscv-tools-2018.1-linux-toolchain_2018.1-1_amd64.deb`

## Docker build

The packages are created using docker containers so that the build process
is agnostic to the host operating system.

### Creating Debian packages for the Newlib and Linux toolchains:

Execute the current commands from the `riscv-gnu-toolchain` top-level directory:

```
docker build -f docker-build/Dockerfile.ubuntu -t toolchain-ubuntu docker-build/
docker run --rm -e PACKAGE_TYPE=newlib -e PACKAGE_VERSION=2018.1-1 \
                -v $(pwd):/usr/src/app toolchain-ubuntu docker-build/ubuntu-build.sh
docker run --rm -e PACKAGE_TYPE=linux -e PACKAGE_VERSION=2018.1-1 \
                -v $(pwd):/usr/src/app toolchain-ubuntu docker-build/ubuntu-build.sh
```

### Creating CentOS packages for the Newlib and Linux toolchains:

Execute the current commands from the `riscv-gnu-toolchain` top-level directory:

```
docker build -f docker-build/Dockerfile.centos -t toolchain-centos docker-build/
docker run --rm -e PACKAGE_TYPE=newlib -e PACKAGE_VERSION=2018.1-1 \
                -v $(pwd):/usr/src/app toolchain-centos docker-build/centos-build.sh
docker run --rm -e PACKAGE_TYPE=linux -e PACKAGE_VERSION=2018.1-1 \
                -v $(pwd):/usr/src/app toolchain-centos docker-build/centos-build.sh
```
