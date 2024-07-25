#
# wget build script for Windows environment
# Author: rzhy1
# 2024/6/12
#
export INSTALL_PATH=$PWD
export WGET_GCC=x86_64-w64-mingw32-gcc
export WGET_MINGW_HOST=x86_64-w64-mingw32
export WGET_ARCH=x86-64
export MINGW_STRIP_TOOL=x86_64-w64-mingw32-strip

# 获取 GitHub Actions workflow 传递的 ssl 变量
ssl_type="$SSL_TYPE"

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libz.a ]; then
  wget -O- https://zlib.net/zlib-1.3.1.tar.gz | tar xz
  cd zlib-* || exit
  CC=$WGET_GCC ./configure --64 --static --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[zlib] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[zlib] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[zlib] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
if [[ "$ssl_type" == "gnutls" ]] &&  [ ! -f "$INSTALL_PATH"/lib/libgmp.a ]; then
  wget -nv -O- https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz | tar x --xz
  cd gmp-* || exit
  ./configure \
   --host=$WGET_MINGW_HOST \
   --disable-shared \
   --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[gmp] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[gmp] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[gmp] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
if [[ "$ssl_type" == "gnutls" ]] &&  [ ! -f "$INSTALL_PATH"/lib/libnettle.a ]; then
  wget -O- https://ftp.gnu.org/gnu/nettle/nettle-3.10.tar.gz | tar xz
  cd nettle-* || exit
  CFLAGS="-I$INSTALL_PATH/include" \
  LDFLAGS="-L$INSTALL_PATH/lib" \
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --disable-documentation \
  --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[nettle] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[nettle] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[nettle] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [[ "$ssl_type" == "gnutls" ]] &&  [ ! -f "$INSTALL_PATH"/lib/libtasn1.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz | tar xz
  cd libtasn1-* || exit
  ./configure \
   --host=$WGET_MINGW_HOST \
   --disable-shared \
   --disable-doc \
   --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[tasn] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[tasn] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[tasn] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libunistring.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libunistring/libunistring-1.2.tar.gz | tar xz
  cd libunistring-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[unistring] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[unistring] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[unistring] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpg-error⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libgpg-error.a ]; then
  wget -O- https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.50.tar.gz | tar xz
  cd libgpg-error-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --disable-doc
  (($? != 0)) && { printf '%s\n' "[gpg-error] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[gpg-error] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[gpg-error] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libassuan⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libassuan.a ]; then
  wget -O- https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.1.tar.bz2 | tar xj
  cd libassuan-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --disable-doc \
  --with-libgpg-error-prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[assuan] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[assuan] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[assuan] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpgme⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libgpgme.a ]; then
  wget -O- https://gnupg.org/ftp/gcrypt/gpgme/gpgme-1.23.2.tar.bz2 | tar xj
  cd gpgme-* || exit
  env PYTHON=/usr/bin/python3.11 ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --with-libgpg-error-prefix="$INSTALL_PATH" \
  --disable-gpg-test \
  --disable-g13-test \
  --disable-gpgsm-test \
  --disable-gpgconf-test \
  --disable-glibtest \
  --with-libassuan-prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[gpgme] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[gpgme] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[gpgme] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build c-ares⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libcares.a ]; then
  wget -O- https://github.com/c-ares/c-ares/releases/download/v1.32.3/c-ares-1.32.3.tar.gz | tar xz
  cd c-ares-* || exit
  CPPFLAGS="-DCARES_STATICLIB=1" \
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --disable-tests \
  --disable-debug
  (($? != 0)) && { printf '%s\n' "[cares] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[cares] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[cares] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libiconv.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz | tar xz
  cd libiconv-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static
  (($? != 0)) && { printf '%s\n' "[iconv] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[iconv] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[iconv] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libidn2.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libidn/libidn2-2.3.0.tar.gz | tar xz
  cd libidn2-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --enable-static \
  --disable-shared \
  --disable-doc \
  --disable-gcc-warnings \
  --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[idn2] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[idn2] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[idn2] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libpsl.a ]; then
  wget -O- https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz | tar xz
  cd libpsl-* || exit
  CFLAGS="-I$INSTALL_PATH/include" \
  LIBS="-L$INSTALL_PATH/lib -lunistring -lidn2" \
  LIBIDN2_CFLAGS="-I$INSTALL_PATH/include" \
  LIBIDN2_LIBS="-L$INSTALL_PATH/lib -lunistring -lidn2" \
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --disable-gtk-doc \
  --enable-builtin \
  --enable-runtime=libidn2 \
  --with-libiconv-prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[psl] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[psl] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[psl] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build pcre2⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libpcre2-8.a ]; then
  wget -O- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.gz | tar xz
  cd pcre2-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static
  (($? != 0)) && { printf '%s\n' "[pcre2] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[pcre2] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[pcre2] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build expat⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libexpat.a ]; then
  wget -O- https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.gz | tar xz
  cd expat-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --without-docbook \
  --without-tests \
  --with-libgpg-error-prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[expat] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[expat] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[expat] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmetalink⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [ ! -f "$INSTALL_PATH"/lib/libmetalink.a ]; then
  wget -O- https://github.com/metalink-dev/libmetalink/releases/download/release-0.1.3/libmetalink-0.1.3.tar.gz | tar xz
  cd libmetalink-* || exit
  EXPAT_CFLAGS="-I$INSTALL_PATH/include" \
  EXPAT_LIBS="-L$INSTALL_PATH/lib -lexpat" \
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --with-libgpg-error-prefix="$INSTALL_PATH" \
  --with-libexpat
  (($? != 0)) && { printf '%s\n' "[metalink] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[metalink] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[metalink] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [[ "$ssl_type" == "gnutls" ]] && [ ! -f "$INSTALL_PATH"/lib/libgnutls.a ]; then
  wget -O- https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.6.tar.xz | tar x --xz
  cd gnutls-* || exit
  PKG_CONFIG_PATH="$INSTALL_PATH/lib/pkgconfig" \
  CFLAGS="-I$INSTALL_PATH/include" \
  LDFLAGS="-L$INSTALL_PATH/lib" \
  GMP_LIBS="-L$INSTALL_PATH/lib -lgmp" \
  NETTLE_LIBS="-L$INSTALL_PATH/lib -lnettle -lgmp" \
  HOGWEED_LIBS="-L$INSTALL_PATH/lib -lhogweed -lnettle -lgmp" \
  LIBTASN1_LIBS="-L$INSTALL_PATH/lib -ltasn1" \
  LIBIDN2_LIBS="-L$INSTALL_PATH/lib -lidn2" \
  GMP_CFLAGS=$CFLAGS \
  LIBTASN1_CFLAGS=$CFLAGS \
  NETTLE_CFLAGS=$CFLAGS \
  HOGWEED_CFLAGS=$CFLAGS \
  LIBIDN2_CFLAGS=$CFLAGS \
  ./configure \
  --host=$WGET_MINGW_HOST \
  --prefix="$INSTALL_PATH" \
  --with-included-unistring \
  --disable-openssl-compatibility \
  --without-p11-kit \
  --disable-tests \
  --disable-doc \
  --disable-shared \
  --enable-static
  (($? != 0)) && { printf '%s\n' "[gnutls] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[gnutls] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[gnutls] make install"; exit 1; }
  cd ..
fi
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build openssl⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
if [[ "$ssl_type" == "openssl" ]] && [ ! -f "$INSTALL_PATH"/lib/libssl.a ]; then
  wget -O- https://github.com/openssl/openssl/releases/download/openssl-3.3.1/openssl-3.3.1.tar.gz | tar xz
  #wget -O- https://openssl.org/source/old/1.1.1/openssl-1.1.1w.tar.gz | tar xz
  cd openssl-* || exit
  ./Configure \
  -static \
  --prefix="$INSTALL_PATH" \
  --cross-compile-prefix=x86_64-w64-mingw32- \
  mingw64 \
  no-shared \
  enable-asm \
  no-tests \
  --with-zlib-include="$INSTALL_PATH" \
  --with-zlib-lib="$INSTALL_PATH"/lib/libz.a
 make -j$(nproc)
 make install_sw
 cd ..
fi
# -----------------------------------------------------------------------------
if [[ "$ssl_type" == "gnutls" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (gnuTLS)⭐⭐⭐⭐⭐⭐"
  # -----------------------------------------------------------------------------
  rm -rf wget-*
  wget -O- https://ftp.gnu.org/gnu/wget/wget-1.21.4.tar.gz | tar xz
  cd wget-* || exit
  chmod +x configure
  CFLAGS="-I$INSTALL_PATH/include -DGNUTLS_INTERNAL_BUILD=1 -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -O2 -pipe -march=$WGET_ARCH -mtune=generic" \
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
  make clean
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[wget gnutls] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[wget gnutls] make install"; exit 1; }
  mkdir "$INSTALL_PATH"/wget-gnutls
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
else
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (openssl)⭐⭐⭐⭐⭐⭐"
  # -----------------------------------------------------------------------------
  rm -rf wget-*
  wget -O- https://ftp.gnu.org/gnu/wget/wget-1.21.4.tar.gz | tar xz
  cd wget-* || exit
  which x86_64-w64-mingw32-gcc
  chmod +x configure
  # cp ../windows-openssl.diff .
  # patch src/openssl.c < windows-openssl.diff
   CFLAGS="-I$INSTALL_PATH/include -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -O2 -pipe -march=$WGET_ARCH -mtune=generic" \
   LDFLAGS="-L$INSTALL_PATH/lib -static -static-libgcc" \
   OPENSSL_CFLAGS=$CFLAGS \
   OPENSSL_LIBS="-L$INSTALL_PATH/lib64 -lcrypto -lssl -lbcrypt -lz" \
   LIBPSL_CFLAGS=$CFLAGS \
   LIBPSL_LIBS="-L$INSTALL_PATH/lib -lpsl" \
   CARES_CFLAGS=$CFLAGS \
   CARES_LIBS="-L$INSTALL_PATH/lib -lcares" \
   PCRE2_CFLAGS=$CFLAGS \
   PCRE2_LIBS="-L$INSTALL_PATH/lib -lpcre2-8"  \
   METALINK_CFLAGS="-I$INSTALL_PATH/include" \
   METALINK_LIBS="-L$INSTALL_PATH/lib -lmetalink -lexpat" \
  ./configure \
   --host=$WGET_MINGW_HOST \
   --prefix="$INSTALL_PATH" \
   --disable-debug \
   --disable-valgrind-tests \
   --enable-iri \
   --enable-pcre2 \
   --with-ssl=openssl \
   --with-included-libunistring \
   --with-cares \
   --with-libpsl \
   --with-metalink \
   --with-gpgme-prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[wget openssl] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[wget openssl] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[wget openssl] make install"; exit 1; }
  mkdir "$INSTALL_PATH"/wget-openssl
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
fi
