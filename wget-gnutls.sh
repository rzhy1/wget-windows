#!/bin/bash
set -euo pipefail

export INSTALL_PATH=$PWD
export WGET_GCC=x86_64-w64-mingw32-gcc
export WGET_MINGW_HOST=x86_64-w64-mingw32
export WGET_ARCH=x86-64
export MINGW_STRIP_TOOL=x86_64-w64-mingw32-strip

# Function to download and build a library
build_library() {
  local url=$1
  local name=$2
  local configure_args=$3

  if [ ! -f "$INSTALL_PATH/lib/lib${name}.a" ]; then
    wget -O- "$url" | tar x --xz
    local dir=$(find . -maxdepth 1 -type d -name "${name}-*" | head -n 1)
    cd "$dir" || exit
    ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" $configure_args
    (($? != 0)) && { printf '%s\n' "[${name}] configure failed"; exit 1; }
    make -j$(nproc)
    (($? != 0)) && { printf '%s\n' "[${name}] make failed"; exit 1; }
    make install
    (($? != 0)) && { printf '%s\n' "[${name}] make install failed"; exit 1; }
    cd ..
  fi
}

# Build dependencies
build_library "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz" "gmp" "--disable-shared"
build_library "https://ftp.gnu.org/gnu/nettle/nettle-3.9.1.tar.gz" "nettle" "--disable-shared --disable-documentation"
build_library "https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz" "libtasn1" "--disable-shared --disable-doc"
build_library "https://ftp.gnu.org/gnu/libidn/libidn2-2.3.0.tar.gz" "libidn2" "--enable-static --disable-shared --disable-doc --disable-gcc-warnings"
build_library "https://ftp.gnu.org/gnu/libunistring/libunistring-1.2.tar.gz" "libunistring" "--disable-shared"
build_library "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.5.tar.xz" "gnutls" "--with-included-unistring --disable-openssl-compatibility --without-p11-kit --disable-tests --disable-doc --disable-shared --enable-static"
build_library "https://github.com/c-ares/c-ares/releases/download/v1.30.0/c-ares-1.30.0.tar.gz" "c-ares" "--enable-static --disable-shared --disable-tests --disable-debug"
build_library "https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz" "libiconv" "--disable-shared --enable-static"
build_library "https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz" "libpsl" "--disable-shared --enable-static --disable-gtk-doc --enable-builtin=libidn2 --enable-runtime=libidn2 --with-libiconv-prefix=$INSTALL_PATH"
build_library "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.gz" "pcre2" "--disable-shared --enable-static"
build_library "https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.49.tar.gz" "libgpg-error" "--disable-shared --enable-static --disable-doc"
build_library "https://gnupg.org/ftp/gcrypt/libassuan/libassuan-2.5.7.tar.bz2" "libassuan" "--disable-shared --enable-static --disable-doc --with-libgpg-error-prefix=$INSTALL_PATH"
build_library "https://gnupg.org/ftp/gcrypt/gpgme/gpgme-1.23.2.tar.bz2" "gpgme" "--disable-shared --enable-static --with-libgpg-error-prefix=$INSTALL_PATH --disable-gpg-test --disable-g13-test --disable-gpgsm-test --disable-gpgconf-test --disable-glibtest --with-libassuan-prefix=$INSTALL_PATH"
build_library "https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.gz" "expat" "--disable-shared --enable-static --without-docbook --without-tests --with-libgpg-error-prefix=$INSTALL_PATH"
build_library "https://github.com/metalink-dev/libmetalink/releases/download/release-0.1.3/libmetalink-0.1.3.tar.gz" "libmetalink" "--disable-shared --enable-static --with-libgpg-error-prefix=$INSTALL_PATH --with-libexpat"
build_library "https://zlib.net/zlib-1.3.1.tar.gz" "zlib" "--64 --static"

# Build wget with GnuTLS
rm -rf wget-*
wget -O- https://ftp.gnu.org/gnu/wget/wget-1.21.4.tar.gz | tar xz
cd wget-* || exit
chmod +x configure
CFLAGS="-I$INSTALL_PATH/include -DGNUTLS_INTERNAL_BUILD=1 -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -O2 -march=$WGET_ARCH -mtune=generic" \
LDFLAGS="-L$INSTALL_PATH/lib -static -static-libgcc" \
GNUTLS_CFLAGS=$CFLAGS \
GNUTLS_LIBS="-L$INSTALL_PATH/lib -lgnutls -lbcrypt -lncrypt" \
LIBPSL_CFLAGS=$CFLAGS \
LIBPSL_LIBS="-L$INSTALL_PATH/lib -lpsl" \
CARES_CFLAGS=$CFLAGS \
CARES_LIBS="-L$INSTALL_PATH/lib -lcares" \
PCRE2_CFLAGS=$CFLAGS \
PCRE2_LIBS="-L$INSTALL_PATH/lib -lpcre2-8"  \
METALINK_CFLAGS="-I$INSTALL_PATH/include" \
METALINK_LIBS="-L$INSTALL_PATH/lib -lmetalink -lexpat" \
LIBS="-L$INSTALL_PATH/lib -lhogweed -lnettle -lgmp -ltasn1 -lidn2 -lpsl -liphlpapi -lcares -lunistring -liconv -lpcre2-8 -lmetalink -lexpat -lgpgme -lassuan -lgpg-error -lz -lcrypt32 -lpthread" \
echo "⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - /configure"
./configure \
  --host=$WGET_MINGW_HOST \
  --prefix="$INSTALL_PATH" \
  --disable-debug \
  --disable-valgrind-tests \
  --enable-iri \
  --enable-pcre2 \
  --with-ssl=gnutls \
  --with-included-libunistring \
  --with-cares \
  --with-libpsl \
  --with-metalink \
  --with-gpgme-prefix="$INSTALL_PATH"
(($? != 0)) && { printf '%s\n' "[wget gnutls] configure failed"; exit 1; }
echo "⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - make clean"
make clean
make -j$(nproc)
(($? != 0)) && { printf '%s\n' "[wget gnutls] make failed"; exit 1; }
make install
(($? != 0)) && { printf '%s\n' "[wget gnutls] make install"; exit 1; }
mkdir "$INSTALL_PATH"/wget-gnutls
cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
$MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
