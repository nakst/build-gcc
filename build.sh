#!/bin/bash

set -eux

BINUTILS_VERSION=2.36.1
GCC_VERSION=11.1.0

PREFIX=`pwd`/essence/cross
SYSROOT=`pwd`/essence/root
export PATH=${PREFIX}/bin:$PATH

echo "::set-output name=GCC_VERSION::${GCC_VERSION}"

# ================ Build function ================

BuildForTarget() {
	mkdir build-binutils
	cd build-binutils
	$BINUTILS_SOURCE/configure --target=$TARGET --prefix=$PREFIX $BINUTILS_CONFIGURE_EXTRA --disable-nls --disable-werror > binutils_configure.txt
	make -j`nproc` > binutils_make.txt
	make install > binutils_make_install.txt
	cd ..
	rm -rf build-binutils
	
	mkdir build-gcc
	cd build-gcc
	$GCC_SOURCE/configure --target=$TARGET --prefix=$PREFIX --disable-nls $GCC_CONFIGURE_EXTRA --enable-languages=c,c++ > gcc_configure.txt
	make all-gcc -j`nproc` > gcc_make_all_gcc.txt
	make all-target-libgcc -j`nproc` > gcc_make_all_target_libgcc.txt
	make install-gcc > gcc_make_install_gcc.txt
	make install-target-libgcc > gcc_make_install_target_libgcc.txt
	
	if [ "$TARGET" = "x86_64-essence" ]; then
		echo > $PREFIX/lib/gcc/$TARGET/$GCC_VERSION/include/mm_malloc.h
		cd ../essence
		./start.sh build
		cd ../build-gcc
		make all-target-libstdc++-v3 -j`nproc` > gcc_make_all_target_libstdcpp.txt
		make install-target-libstdc++-v3 > gcc_make_install_target_libstdcpp.txt
	fi
	
	cd ..
	rm -rf build-gcc
	
	strip --strip-unneeded $PREFIX/bin/$TARGET-* \
		$PREFIX/libexec/gcc/$TARGET/$GCC_VERSION/cc1 \
		$PREFIX/libexec/gcc/$TARGET/$GCC_VERSION/cc1plus \
		$PREFIX/libexec/gcc/$TARGET/$GCC_VERSION/collect2 \
		$PREFIX/libexec/gcc/$TARGET/$GCC_VERSION/lto1 \
		$PREFIX/libexec/gcc/$TARGET/$GCC_VERSION/lto-wrapper
	
	mv $PREFIX prefix
	tar -cJf gcc-$TARGET.tar.xz prefix
	rm -rf prefix
}

# ================ Download sources ================

git clone --depth=1 https://gitlab.com/nakst/essence.git
mkdir -p ${SYSROOT}/Applications/POSIX/include essence/bin
cd essence
echo accepted_license=1 > bin/build_config.ini
./start.sh q
ports/gcc/port.sh download-only
cd ..

cp essence/bin/cache/ftp___ftp_gnu_org_gnu_binutils_binutils_* binutils.tar.xz
cp essence/bin/cache/ftp___ftp_gnu_org_gnu_gcc_gcc_* gcc.tar.xz
tar --warning=none -xJf binutils.tar.xz
tar --warning=none -xJf gcc.tar.xz

# ================ x86_64-essence ================

BINUTILS_SOURCE=../essence/bin/binutils-src
GCC_SOURCE=../essence/bin/gcc-src
BINUTILS_CONFIGURE_EXTRA=--with-sysroot=$SYSROOT
GCC_CONFIGURE_EXTRA=--with-sysroot=$SYSROOT
TARGET=x86_64-essence

cd essence
ports/musl/build.sh x86_64
cd ..

BuildForTarget

# ================ Generic targets ================

BINUTILS_SOURCE=../binutils-$BINUTILS_VERSION
GCC_SOURCE=../gcc-$GCC_VERSION
BINUTILS_CONFIGURE_EXTRA=--with-sysroot
GCC_CONFIGURE_EXTRA=--without-headers

TARGET=i686-elf
BuildForTarget
TARGET=arm-none-eabi
BuildForTarget
TARGET=aarch64-none-elf
BuildForTarget

# ================ Linux targets ================

BINUTILS_CONFIGURE_EXTRA=""
GCC_CONFIGURE_EXTRA=""

TARGET=i686-pc-linux-gnu
BuildForTarget
TARGET=x86_64-pc-linux-gnu
BuildForTarget
