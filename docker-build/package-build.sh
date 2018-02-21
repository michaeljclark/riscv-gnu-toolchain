#!/bin/bash

set -e

if [ ! -f /etc/os-release ]; then
    echo "/etc/os-release is not present"
    exit 1
fi

. /etc/os-release

case "${NAME}" in
    CentOS*)
	pkg_type=rpm
	pkg_arch=x86_64
	suffix_sep='-'
	arch_sep='.'
	;;
    Ubuntu)
	pkg_type=deb
	pkg_arch=amd64
	suffix_sep='_'
	arch_sep='_'
	;;
    *)
	echo "/etc/os must be 'Centos' or 'Ubuntu'"
	exit 1
esac

if [ "${PACKAGE_VERSION}" = "${PACKAGE_VERSION/-/_}" ]; then
    echo "PACKAGE_VERSION must contain a hyphen"
    exit 1
fi

pkg_version=$(echo ${PACKAGE_VERSION} | cut -d- -f1)
pkg_release=$(echo ${PACKAGE_VERSION} | cut -d- -f2)

pkg_prefix=/opt/riscv/tools/${pkg_version}
pkg_suffix=${suffix_sep}${pkg_version}-${pkg_release}${arch_sep}${pkg_arch}

pkg_toolchain_linux=riscv-tools-${pkg_version}-toolchain-linux
pkg_toolchain_newlib=riscv-tools-${pkg_version}-toolchain-newlib
pkg_toolchain_common=riscv-tools-${pkg_version}-toolchain-common

#
# build toolchains
#

build_toolchain_newlib_dir=/usr/src/app/${pkg_toolchain_newlib}${pkg_suffix}.build
build_toolchain_linux_dir=/usr/src/app/${pkg_toolchain_linux}${pkg_suffix}.build

# build newlib toolchain
if [ ! -d ${build_toolchain_newlib_dir} -o ! "$PRESERVE" = "yes" ]; then
    echo "=== building newlib toolchain to $(basename ${build_toolchain_newlib_dir}) ==="
    rm -fr ${build_toolchain_newlib_dir}
    ./configure --enable-multilib \
		--with-cmodel=medany \
		--prefix=${build_toolchain_newlib_dir}${pkg_prefix}
    make clean
    make -j$(nproc)
fi

# build linux toolchain
if [ ! -d ${build_toolchain_linux_dir} -o ! "$PRESERVE" = "yes" ]; then
    echo "=== building linux toolchain to $(basename ${build_toolchain_linux_dir}) ==="
    rm -fr ${build_toolchain_linux_dir}
    ./configure --enable-linux \
		--enable-multilib \
		--with-cmodel=medany \
		--prefix=${build_toolchain_linux_dir}${pkg_prefix}
    make clean
    make -j$(nproc)
fi

# strip executables
for pkg_dir in ${build_toolchain_newlib_dir} ${build_toolchain_linux_dir}; do
    echo "=== striping executables in $(basename ${pkg_dir}) ==="
    strip ${pkg_dir}/${pkg_prefix}/bin/*
    strip ${pkg_dir}/${pkg_prefix}/libexec/gcc/*/*/cc1
    strip ${pkg_dir}/${pkg_prefix}/libexec/gcc/*/*/cc1plus
    strip ${pkg_dir}/${pkg_prefix}/libexec/gcc/*/*/lto1
done

#
# package staging directories
#

stage_toolchain_common_dir=/usr/src/app/${pkg_toolchain_common}${pkg_suffix}
stage_toolchain_newlib_dir=/usr/src/app/${pkg_toolchain_newlib}${pkg_suffix}
stage_toolchain_linux_dir=/usr/src/app/${pkg_toolchain_linux}${pkg_suffix}

# build package file lists

echo "=== finding common files between $(basename ${build_toolchain_newlib_dir}) and $(basename ${build_toolchain_linux_dir}) ==="
( cd ${build_toolchain_newlib_dir} && find . -type f -o -type l | sed 's#\.\/#/#' ) \
    > ${build_toolchain_newlib_dir}.list
( cd ${build_toolchain_linux_dir} && find . -type f -o -type l | sed 's#\.\/#/#' ) \
    > ${build_toolchain_linux_dir}.list

echo "=== creating $(basename ${stage_toolchain_common_dir}.list) ==="
cat ${build_toolchain_newlib_dir}.list ${build_toolchain_linux_dir}.list \
    | sort | uniq -d > ${stage_toolchain_common_dir}.list

echo "=== creating $(basename ${stage_toolchain_newlib_dir}.list) ==="
cat ${build_toolchain_newlib_dir}.list ${stage_toolchain_common_dir}.list \
    | sort | uniq -u > ${stage_toolchain_newlib_dir}.list

echo "=== creating $(basename ${stage_toolchain_linux_dir}.list) ==="
cat ${build_toolchain_linux_dir}.list ${stage_toolchain_common_dir}.list \
    | sort | uniq -u > ${stage_toolchain_linux_dir}.list

# create staging directories

create_stage_directory()
{
    source_dir=$1
    target_dir=$2
    file_list=$3

    echo "=== staging $(basename ${target_dir}) using $(basename ${file_list}) ==="
    
    rm -fr ${target_dir}
    mkdir ${target_dir}
    for file in $(cat ${file_list}); do
	if [ ! -d $(dirname ${target_dir}${file}) ]; then
	    mkdir -p $(dirname ${target_dir}${file})
	fi
	ln -P ${source_dir}${file} ${target_dir}${file}
    done
}

create_stage_directory ${build_toolchain_newlib_dir} ${stage_toolchain_common_dir} ${stage_toolchain_common_dir}.list
create_stage_directory ${build_toolchain_newlib_dir} ${stage_toolchain_newlib_dir} ${stage_toolchain_newlib_dir}.list
create_stage_directory ${build_toolchain_linux_dir} ${stage_toolchain_linux_dir} ${stage_toolchain_linux_dir}.list

#
# create packages
#

create_deb()
{
    pkg_desc=$1
    pkg_name=$2
    pkg_dir=$3
    pkg_depends=$4

    echo "=== creating ${pkg_dir}.deb ==="

    test -d ${pkg_dir}/DEBIAN || mkdir ${pkg_dir}/DEBIAN
    cat << EOF > ${pkg_dir}/DEBIAN/control
Package: ${pkg_name}
Version: ${pkg_version}-${pkg_release}
Architecture: ${pkg_arch}
Description: ${pkg_desc}
Maintainer: sw-dev@groups.riscv.org
${pkg_depends}
EOF

    dpkg-deb --build ${pkg_dir}
}

create_rpm()
{
    pkg_desc=$1
    pkg_name=$2
    pkg_dir=$3
    pkg_requires=$4

    echo "=== creating ${pkg_dir}.rpm ==="
    
    cat << EOF > ${pkg_name}.spec
Name: ${pkg_name}
Version: ${pkg_version}
Release: ${pkg_release}
Summary: ${pkg_desc}
License: GPL
AutoReqProv: no
${pkg_requires}
%define __os_install_post %{nil}
%define _unpackaged_files_terminate_build 0
%description
${pkg_desc} - C and C++ cross-compiler
%prep
%build
%install
rsync -a ${pkg_dir}/ %buildroot/
%files
EOF

    for file in $(cat ${pkg_dir}.list); do
	if [ -h ${pkg_dir}${file} ]; then
	    echo ${file} >> ${pkg_name}.spec
	elif [ -f ${pkg_dir}${file} ]; then
	    stat -c "%%attr(0%a, root, root) ${file}" ${pkg_dir}${file} >> ${pkg_name}.spec
	fi
    done

    rpmbuild -bb ${pkg_name}.spec
    cp /root/rpmbuild/RPMS/${pkg_arch}/${pkg_name}-${pkg_version}-${pkg_release}.${pkg_arch}.rpm ./

}

if [ "${pkg_type}" = "rpm" ]; then
    create_rpm "RISC-V GNU Compiler Toolchain Common" \
	       ${pkg_toolchain_common} \
	       ${stage_toolchain_common_dir} \
	       "Requires: python >= 2.7.5"
    create_rpm "RISC-V GNU Compiler Toolchain Newlib" \
	       ${pkg_toolchain_newlib} \
	       ${stage_toolchain_newlib_dir} \
	       "Requires: ${pkg_toolchain_common} = ${pkg_version}-${pkg_release}"
    create_rpm "RISC-V GNU Compiler Toolchain Linux"  \
	       ${pkg_toolchain_linux} \
	       ${stage_toolchain_linux_dir} \
	       "Requires: ${pkg_toolchain_common} = ${pkg_version}-${pkg_release}"
elif [ "${pkg_type}" = "deb" ]; then
    create_deb "RISC-V GNU Compiler Toolchain Common" \
	       ${pkg_toolchain_common} \
	       ${stage_toolchain_common_dir} \
	       "Depends: python (>= 2.7.5)"
    create_deb "RISC-V GNU Compiler Toolchain Newlib" \
	       ${pkg_toolchain_newlib} \
	       ${stage_toolchain_newlib_dir} \
	       "Depends: ${pkg_toolchain_common} (= ${pkg_version}-${pkg_release})"
    create_deb "RISC-V GNU Compiler Toolchain Linux"  \
	       ${pkg_toolchain_linux} \
	       ${stage_toolchain_linux_dir} \
	       "Depends: ${pkg_toolchain_common} (= ${pkg_version}-${pkg_release})"
fi
