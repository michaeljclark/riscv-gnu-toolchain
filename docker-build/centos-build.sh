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
pkg_arch=x86_64
pkg_name=riscv-tools-${pkg_version}-${pkg_type}-toolchain
pkg_dir=/usr/src/app/${pkg_name}-${pkg_version}-${pkg_release}-${pkg_arch}
prefix=/opt/riscv/tools/${pkg_version}

rm -fr ${pkg_dir}
./configure ${extra_flags} --enable-multilib --with-cmodel=medany --prefix=${pkg_dir}${prefix}
make clean
make -j$(nproc)

strip ${pkg_dir}/${prefix}/bin/*
strip ${pkg_dir}/${prefix}/libexec/gcc/*/*/cc1
strip ${pkg_dir}/${prefix}/libexec/gcc/*/*/cc1plus
strip ${pkg_dir}/${prefix}/libexec/gcc/*/*/lto1

cat << EOF > ${pkg_name}.spec
Name: ${pkg_name}
Version: ${pkg_version}
Release: ${pkg_release}
Requires: python >= 2.7.5
Summary: RISC-V ${fancy_name} GNU Compiler Toolchain
License: GPL
%define __os_install_post %{nil}
%define _unpackaged_files_terminate_build 0
%description
RISC-V GNU Compiler Toolchain C and C++ cross-compiler with ${fancy_name}
%prep
%build
%install
rsync -a ${pkg_dir}/ %buildroot/
%files
EOF

( cd ${pkg_dir} && find . -type f -exec stat -c "%%attr(0%a, root, root) %n" {} \; | sed 's#\.\/#/#' ) >> ${pkg_name}.spec
( cd ${pkg_dir} && find . -type l | sed 's#\.\/#/#' ) >> ${pkg_name}.spec

rpmbuild -bb ${pkg_name}.spec
cp /root/rpmbuild/RPMS/${pkg_arch}/${pkg_name}-${pkg_version}-${pkg_release}.${pkg_arch}.rpm ./
