#!/bin/bash

set -eux

case "${PACKAGE_TYPE}" in
    newlib)
	fancy_name=Newlib
	extra_flags=
	;;
    linux)
	fancy_name=Linux
	extra_flags=--enable-linux
	;;
    *)
	echo "PACKAGE_TYPE must be 'newlib' or 'linux'"
	exit 1
esac

if [ "${PACKAGE_VERSION}" = "${PACKAGE_VERSION/-/_}" ]; then
    echo "PACKAGE_VERSION must contain a hyphen"
    exit 1
fi

pkg_version=$(echo ${PACKAGE_VERSION} | cut -d- -f1)
pkg_release=$(echo ${PACKAGE_VERSION} | cut -d- -f2)
pkg_type=${PACKAGE_TYPE}
pkg_arch=amd64
pkg_name=riscv-tools-${pkg_version}-${pkg_type}-toolchain
pkg_dir=/usr/src/app/${pkg_name}_${pkg_version}-${pkg_release}_${pkg_arch}
prefix=/opt/riscv/tools/${pkg_version}

rm -fr ${pkg_dir}
./configure ${extra_flags} --enable-multilib --with-cmodel=medany --prefix=${pkg_dir}${prefix}
make clean
make -j$(nproc)

strip ${pkg_dir}/${prefix}/bin/*
strip ${pkg_dir}/${prefix}/libexec/gcc/*/*/cc1
strip ${pkg_dir}/${prefix}/libexec/gcc/*/*/cc1plus
strip ${pkg_dir}/${prefix}/libexec/gcc/*/*/lto1

test -d ${pkg_dir}/DEBIAN || mkdir ${pkg_dir}/DEBIAN
cat << EOF > ${pkg_dir}/DEBIAN/control
Package: ${pkg_name}
Version: ${pkg_version}-${pkg_release}
Architecture: ${pkg_arch}
Description: RISC-V ${fancy_name} GNU Compiler Toolchain
Maintainer: sw-dev@groups.riscv.org
EOF

dpkg-deb --build ${pkg_dir}
