#!/usr/bin/env bash

set -e
set -x


if [ ! -x "$(which ld)" -o ! -x "$(which gcc)" -o ! -x "$(which tar)" ]; then
	echo "${0}: missing binutils/gcc"
	exit 1
fi

if [ ! -x /usr/bin/wget -o ! -x /usr/bin/whiptail -o ! -x /usr/bin/gpg ]; then
	echo "${0}: missing wget/whiptail/gpg"
	echo "${0}: On Debian: \`sudo apt install wget whiptail gpg\`"
	echo "${0}: On ArchLinux: \`sudo pacman -S wget libnewt gpg\`"
	exit 1
fi

BIN_DLSITE="https://ftp.gnu.org/gnu/binutils"
GCC_DLSITE="https://bigsearcher.com/mirrors/gcc/releases"
GCC_DLSITE_BACKUP="http://mirror.koddos.net/gcc/releases"
CPUCORES=$(cat /proc/cpuinfo | grep -E '^processor' | wc -l)

# download choosen binutils version
BIN_CONTENT=$(wget "${BIN_DLSITE}" -q -O - | grep -oE '>binutils-[[:digit:]]+.[[:digit:]]+(|.[[:digit:]]+)(|.[[:digit:]]+).tar.gz<')
BIN_MENU=$(echo "${BIN_CONTENT}" | sed -n 's/^>binutils-\(.*\).tar.gz<$/\1 binutils-\1/p')
BINUTILS_VERSION=$(whiptail --menu 'choose binutils version' 35 55 25 ${BIN_MENU} 3>&1 1>&2 2>&3)
echo "binutils: ${BINUTILS_VERSION}"

# download choosen gcc version
GCC_CONTENT=$(wget "${GCC_DLSITE}" -q -O - | grep -oE '"gcc-[[:digit:]]+.[[:digit:]]+(|.[[:digit:]]+)/"')
GCC_MENU=$(echo "${GCC_CONTENT}" | sed -n 's/^"gcc-\(.*\)\/"$/\1 gcc-\1/p')
GCC_VERSION=$(whiptail --menu 'choose gcc version' 35 55 25 ${GCC_MENU} 3>&1 1>&2 2>&3)
echo "gcc: ${GCC_VERSION}"

# enable multilib?
MULTILIB_ENABLE=$(whiptail --clear --menu 'enable multilib? (requires libc-dev:i386 as well as libc-dev:amd64)' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
if [ x"${MULTILIB_ENABLE}" = x'y' ]; then
	MULTILIB_ARG="--enable-multilib"
else
	MULTILIB_ARG="--disable-multilib"
fi

# build gccgo?
GCCGO_ENABLE=$(whiptail --clear --menu 'build gccgo?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
if [ x"${GCCGO_ENABLE}" = x'y' ]; then
	GCCGO_BIN="--enable-gold=yes"
	GCCGO_GCC=",go"
else
	GCCGO_BIN="--enable-ld=yes"
	GCCGO_GCC=""
fi

# check build dirs existence
BIN_BUILD="binutils-${BINUTILS_VERSION}-build"
if [ -d ${BIN_BUILD} ]; then
	ANSW=$(whiptail --clear --menu 'binutils-build exists: delete?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
	if [ x"${ANSW}" = x'y' ]; then
		rm -rf ${BIN_BUILD}
	fi
fi
GCC_BUILD="gcc-${GCC_VERSION}-build"
if [ -d ${GCC_BUILD} ]; then
	ANSW=$(whiptail --clear --menu 'gcc-build exists: delete?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
	if [ x"${ANSW}" = x'y' ]; then
		rm -rf ${GCC_BUILD}
	fi
fi

# "sysroot"
INSTALLDIR="$(pwd)/gcc-${GCC_VERSION}-root"
if [ -d "${INSTALLDIR}" ]; then
	ANSW=$(whiptail --menu 'sysroot gcc-'"${GCC_VERSION}"'-root exists: delete?' 15 35 5 y yes n no 3>&1 1>&2 2>&3)
	if [ x"${ANSW}" = x'y' ]; then
		rm -rf "${INSTALLDIR}"
	fi
fi

# get the source code
if [ ! -f "binutils-${BINUTILS_VERSION}.tar.gz" ]; then
	wget -O "binutils-${BINUTILS_VERSION}.tar.gz" "${BIN_DLSITE}/binutils-${BINUTILS_VERSION}.tar.gz"
fi
test -d ${BIN_BUILD} || tar -xvf binutils-${BINUTILS_VERSION}.tar.gz
if [ ! -f "gcc-${GCC_VERSION}.tar.bz2" -a ! -f "gcc-${GCC_VERSION}.tar.gz" ]; then
	wget -O "gcc-${GCC_VERSION}.tar.bz2" "${GCC_DLSITE}/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.bz2" || \
		{ rm -f "gcc-${GCC_VERSION}.tar.bz2"; \
			wget -O "gcc-${GCC_VERSION}.tar.gz" "${GCC_DLSITE}/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz" || \
			rm -f "gcc-${GCC_VERSION}.tar.gz"; }
fi
if [ ! -f "gcc-${GCC_VERSION}.tar.bz2" -a ! -f "gcc-${GCC_VERSION}.tar.gz" ]; then
	wget -O "gcc-${GCC_VERSION}.tar.bz2" "${GCC_DLSITE_BACKUP}/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.bz2" || \
		{ rm -f "gcc-${GCC_VERSION}.tar.bz2"; \
			wget -O "gcc-${GCC_VERSION}.tar.gz" "${GCC_DLSITE_BACKUP}/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz" || \
			{ rm -f "gcc-${GCC_VERSION}.tar.gz"; false; }; }
fi
if [ ! -f "gcc-${GCC_VERSION}.tar.bz2.sig" -a ! -f "gcc-${GCC_VERSION}.tar.gz.sig" ]; then
	wget -O "gcc-${GCC_VERSION}.tar.bz2.sig" "${GCC_DLSITE_BACKUP}/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.bz2.sig" || \
		{ rm -f "gcc-${GCC_VERSION}.tar.bz2.sig"; \
			wget -O "gcc-${GCC_VERSION}.tar.gz.sig" "${GCC_DLSITE_BACKUP}/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz.sig" || \
			{ rm -f "gcc-${GCC_VERSION}.tar.gz.sig"; false; }; }
fi
gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys "B215 C163 3BCA 0477 615F 1B35 A5B3 A004 745C 015A"
gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys "B3C4 2148 A44E 6983 B3E4 CC07 93FA 9B1A B75C 61B8"
gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys "90AA 4704 69D3 965A 87A5 DCB4 94D0 3953 902C 9419"
gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys "80F9 8B2E 0DAB 6C82 81BD F541 A7C8 C3B2 F71E DF1C"
gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys "7F74 F97C 1034 68EE 5D75 0B58 3AB0 0996 FC26 A641"
gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys "33C2 35A3 4C46 AA3F FB29 3709 A328 C3A2 C3C4 5C06"
gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys "D3A9 3CAD 751C 2AF4 F8C7 AD51 6C35 B993 09B5 FA62"
if [ -f "gcc-${GCC_VERSION}.tar.bz2.sig" ]; then
    gpg --verify "gcc-${GCC_VERSION}.tar.bz2.sig"
fi
if [ -f "gcc-${GCC_VERSION}.tar.gz.sig" ]; then
    gpg --verify "gcc-${GCC_VERSION}.tar.gz.sig"
fi
test ! -d ${GCC_BUILD} -a -r gcc-${GCC_VERSION}.tar.bz2 && tar -xvf gcc-${GCC_VERSION}.tar.bz2
test ! -d ${GCC_BUILD} -a -r gcc-${GCC_VERSION}.tar.gz && tar -xvf gcc-${GCC_VERSION}.tar.gz

# download the prerequisites e.g. GMP,MPFR,MPC
cd gcc-${GCC_VERSION}
if [ -x ./contrib/download_prerequisites ]; then
	./contrib/download_prerequisites
else
	# c&p from gcc5 `download_prerequisites` script
	# Necessary to build GCC.
	MPFR=mpfr-2.4.2
	GMP=gmp-4.3.2
	MPC=mpc-0.8.1
	if [ ! -f "$MPFR.tar.bz2" -o ! -h mpfr ]; then
		rm -rf mpfr
		wget -O "$MPFR.tar.bz2" "ftp://gcc.gnu.org/pub/gcc/infrastructure/$MPFR.tar.bz2"
		tar xjf $MPFR.tar.bz2
		ln -sf $MPFR mpfr
	fi
	if [ ! -f "$GMP.tar.bz2" -o ! -h gmp ]; then
		rm -rf gmp
		wget -O "$GMP.tar.bz2" "ftp://gcc.gnu.org/pub/gcc/infrastructure/$GMP.tar.bz2"
		tar xjf $GMP.tar.bz2
		ln -sf $GMP gmp
	fi
	if [ ! -f "$MPC.tar.gz" -o ! -h mpc ]; then
		rm -rf mpc
		wget -O "$MPC.tar.gz" "ftp://gcc.gnu.org/pub/gcc/infrastructure/$MPC.tar.gz"
		tar xzf $MPC.tar.gz
		ln -sf $MPC mpc
	fi
fi

# set multiarch vars (if debian based)
if [ -x /usr/bin/dpkg-architecture ]; then
	BUILD_ARCH=$(/usr/bin/dpkg-architecture -q DEB_BUILD_MULTIARCH)
	HOST_ARCH=$(/usr/bin/dpkg-architecture -q DEB_HOST_MULTIARCH)
	TARGET_ARCH=$(/usr/bin/dpkg-architecture -q DEB_TARGET_MULTIARCH)
	MULTIARCH="--build=${BUILD_ARCH} --host=${HOST_ARCH} --target=${TARGET_ARCH}"
	LPATH="/usr/lib/${TARGET_ARCH}"
else
	MULTIARCH=""
	LPATH="/usr/lib"
fi

if [ x"${LIBRARY_PATH}" != x ]; then
	export LIBRARY_PATH="${LIBRARY_PATH}:${LPATH}"
else
	export LIBRARY_PATH="${LPATH}"
fi
unset LPATH

# create the build directories
cd ..
mkdir ${BIN_BUILD} ${GCC_BUILD} || true

cd ${BIN_BUILD}
# build binutils
../binutils-${BINUTILS_VERSION}/configure            \
    ${MULTIARCH}                                     \
    ${MULTILIB_ARG}                                  \
    --prefix=${INSTALLDIR}                           \
    --disable-nls                                    \
    ${GCCGO_BIN}                                     \
&& sed -i 's|^MAKEINFO\s\+=\s\+makeinfo$|MAKEINFO = true|' ./Makefile \
&& make -j${CPUCORES:-2}                             \
&& make install

cd ../${GCC_BUILD}
# build gcc
../gcc-${GCC_VERSION}/configure                      \
    --prefix=${INSTALLDIR}                           \
    ${MULTIARCH}                                     \
    --with-as=${INSTALLDIR}/bin/as                   \
    --with-ld=${INSTALLDIR}/bin/ld                   \
    --enable-static                                  \
    --enable-shared                                  \
    --enable-threads=posix                           \
    --enable-__cxa_atexit                            \
    --enable-clocale=gnu                             \
    --enable-languages=c,c++${GCCGO_GCC}             \
    ${MULTILIB_ARG}                                  \
    --with-system-zlib                               \
    ${GCCGO_BIN}                                     \
    --enable-lto                                     \
    --disable-nls                                    \
&& sed -i 's|^MAKEINFO\s\+=\s\+makeinfo$|MAKEINFO = true|' ./Makefile \
&& make -j${CPUCORES:-2}                             \
&& make install

# write activation script to gcc root
cat << EOF > "${INSTALLDIR}/activate.sh"
#!/bin/bash

DIR="\$(realpath "\$(dirname "\${BASH_SOURCE}")")"
echo "*** ROOT: \${DIR}"
export PATH="\${DIR}/bin:\${DIR}/usr/bin:\${PATH}"
export CMAKE_C_COMPILER="\${DIR}/bin/gcc"
export CMAKE_CXX_COMPILER="\${DIR}/bin/g++"
export CC="\${CMAKE_C_COMPILER}"
export CXX="\${CMAKE_CXX_COMPILER}"
export LD_LIBRARY_PATH="\${DIR}/lib:\${DIR}/lib64"
EOF
chmod +x "${INSTALLDIR}/activate.sh"

# Notes
#
#   --enable-shared --enable-threads=posix --enable-__cxa_atexit: 
#       These parameters are required to build the C++ libraries to published standards.
#   
#   --enable-clocale=gnu: 
#       This parameter is a failsafe for incomplete locale data.
#   
#   --disable-multilib: 
#       This parameter ensures that files are created for the specific
#       architecture of your computer.
#        This will disable building 32-bit support on 64-bit systems where the
#        32 bit version of libc is not installed and you do not want to go
#        through the trouble of building it. Diagnosis: "Compiler build fails
#        with fatal error: gnu/stubs-32.h: No such file or directory"
#   
#   --with-system-zlib: 
#       Uses the system zlib instead of the bundled one. zlib is used for
#       compressing and uncompressing GCC's intermediate language in LTO (Link
#       Time Optimization) object files.
#   
#   --enable-languages=all
#   --enable-languages=c,c++,fortran,go,objc,obj-c++: 
#       This command identifies which languages to build. You may modify this
#       command to remove undesired language
#
#   --enable-gold[=ARG]
#       build gold [ARG={default,yes,no}]
#   --enable-ld[=ARG]
#       build ld [ARG={default,yes,no}]
#   --enable-lto
#       enable link time optimization support
