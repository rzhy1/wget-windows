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
export PKG_CONFIG_PATH=$INSTALL_PATH/lib/pkgconfig:$PKG_CONFIG_PATH
export LDFLAGS="-flto=$(nproc)" 
echo "查询"
pkg-config --libs python-3.12
pkg-config --cflags python-3.12
pkg-config --libs python3
pkg-config --cflags python3

# 获取 GitHub Actions workflow 传递的 ssl 变量
ssl_type="$SSL_TYPE"

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
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
end_time=$(date +%s.%N)
duration1=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
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
end_time=$(date +%s.%N)
duration2=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [[ "$ssl_type" == "gnutls" ]] &&  [ ! -f "$INSTALL_PATH"/lib/libnettle.a ]; then
  wget -O- https://ftp.gnu.org/gnu/nettle/nettle-3.10.1.tar.gz | tar xz
  cd nettle-* || exit
  CFLAGS="-I$INSTALL_PATH/include -flto=$(nproc)" \
  LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS" \
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --disable-documentation \
  --libdir=$INSTALL_PATH/lib \
  --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[nettle] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[nettle] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[nettle] make install"; exit 1; }
  cd ..
fi
end_time=$(date +%s.%N)
duration3=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [[ "$ssl_type" == "gnutls" ]] &&  [ ! -f "$INSTALL_PATH"/lib/libtasn1.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz | tar xz
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
end_time=$(date +%s.%N)
duration4=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libunistring.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.gz | tar xz
  cd libunistring-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  CFLAGS="-O2 -g0 -flto=$(nproc)" \
  CXXFLAGS="-O2 -g0 -flto=$(nproc)"
  (($? != 0)) && { printf '%s\n' "[unistring] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[unistring] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[unistring] make install"; exit 1; }
  cd ..
fi
end_time=$(date +%s.%N)
duration5=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpg-error⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libgpg-error.a ]; then
  wget -O- https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.51.tar.gz | tar xz
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
end_time=$(date +%s.%N)
duration6=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libassuan⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
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
end_time=$(date +%s.%N)
duration7=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpgme⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libgpgme.a ]; then
  wget -O- https://gnupg.org/ftp/gcrypt/gpgme/gpgme-1.24.1.tar.bz2 | tar xj
  cd gpgme-* || exit
  env PYTHON=/usr/bin/python3.12.3 LIBS="-L$INSTALL_PATH/lib" ./configure \
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
end_time=$(date +%s.%N)
duration8=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build c-ares⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libcares.a ]; then
  wget -O- https://github.com/c-ares/c-ares/releases/download/v1.34.4/c-ares-1.34.4.tar.gz | tar xz
  cd c-ares-* || exit
  CPPFLAGS="-DCARES_STATICLIB=1" \
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --disable-tests
  (($? != 0)) && { printf '%s\n' "[cares] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[cares] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[cares] make install"; exit 1; }
  cd ..
fi
end_time=$(date +%s.%N)
duration9=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libiconv.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz | tar xz
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
end_time=$(date +%s.%N)
duration10=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐" 
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
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
end_time=$(date +%s.%N)
duration11=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libpsl.a ]; then
  wget -O- https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz | tar xz
  cd libpsl-* || exit
  CFLAGS="-I$INSTALL_PATH/include -flto=$(nproc)" \
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
end_time=$(date +%s.%N)
duration12=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build pcre2⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libpcre2-8.a ]; then
  wget -O- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.gz | tar xz
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
end_time=$(date +%s.%N)
duration13=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build expat⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libexpat.a ]; then
  wget -O- https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.gz | tar xz
  cd expat-* || exit
  ./configure \
  --host=$WGET_MINGW_HOST \
  --disable-shared \
  --prefix="$INSTALL_PATH" \
  --enable-static \
  --without-docbook \
  --without-tests
  (($? != 0)) && { printf '%s\n' "[expat] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[expat] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[expat] make install"; exit 1; }
  cd ..
fi
end_time=$(date +%s.%N)
duration14=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmetalink⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
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
  --with-libexpat
  (($? != 0)) && { printf '%s\n' "[metalink] configure failed"; exit 1; }
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[metalink] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[metalink] make install"; exit 1; }
  cd ..
fi
end_time=$(date +%s.%N)
duration15=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [[ "$ssl_type" == "gnutls" ]] && [ ! -f "$INSTALL_PATH"/lib/libgnutls.a ]; then
  wget -O- https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.9.tar.xz | tar x --xz
  cd gnutls-* || exit
  CFLAGS="-I$INSTALL_PATH/include" \
  LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS" \
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
  --disable-hardware-acceleration \
  --without-p11-kit \
  --disable-tests \
  --disable-doc \
  --disable-full-test-suite \
  --disable-tools \
  --disable-cxx \
  --disable-maintainer-mode \
  --disable-libdane \
  --disable-shared \
  --enable-static 
  (($? != 0)) && { printf '%s\n' "[gnutls] configure failed"; exit 1; }
  make -j4
  (($? != 0)) && { printf '%s\n' "[gnutls] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[gnutls] make install"; exit 1; }
  cd ..
fi
end_time=$(date +%s.%N)
duration16=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build openssl⭐⭐⭐⭐⭐⭐"
# -----------------------------------------------------------------------------
start_time=$(date +%s.%N)
if [[ "$ssl_type" == "openssl" ]] && [ ! -f "$INSTALL_PATH"/lib/libssl.a ]; then
  #wget -O- https://github.com/openssl/openssl/releases/download/openssl-3.4.0/openssl-3.4.0.tar.gz | tar xz
  wget -O- https://openssl.org/source/old/1.1.1/openssl-1.1.1w.tar.gz | tar xz
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
end_time=$(date +%s.%N)
duration17=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
# -----------------------------------------------------------------------------
if [[ "$ssl_type" == "gnutls" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (gnuTLS)⭐⭐⭐⭐⭐⭐"
  # -----------------------------------------------------------------------------
  start_time=$(date +%s.%N)
  rm -rf wget-*
  wget -O- https://ftp.gnu.org/gnu/wget/wget-1.21.4.tar.gz | tar xz
  cd wget-* || exit 1
  chmod +x configure
  CFLAGS="-I$INSTALL_PATH/include -DGNUTLS_INTERNAL_BUILD=1 -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -O2 -pipe -march=tigerlake -mtune=tigerlake -flto=$(nproc)" \
   LDFLAGS="-L$INSTALL_PATH/lib -static -static-libgcc $LDFLAGS" \
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
  make -j4
  (($? != 0)) && { printf '%s\n' "[wget gnutls] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[wget gnutls] make install"; exit 1; }
  mkdir "$INSTALL_PATH"/wget-gnutls
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  end_time=$(date +%s.%N)
  duration18=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
else
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (openssl)⭐⭐⭐⭐⭐⭐"
  # -----------------------------------------------------------------------------
  start_time=$(date +%s.%N)
  rm -rf wget-*
  wget -O- https://ftp.gnu.org/gnu/wget/wget-1.21.4.tar.gz | tar xz
  cd wget-* || exit 1
  chmod +x configure
  # cp ../windows-openssl.diff .
  # patch src/openssl.c < windows-openssl.diff
   CFLAGS="-I$INSTALL_PATH/include -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -O2 -pipe -march=tigerlake -mtune=tigerlake -flto=$(nproc)" \
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
   LIBS="-L$INSTALL_PATH/lib -liconv -lunistring -lidn2 -lpsl -liphlpapi -lcares -lpcre2-8 -lmetalink -lexpat -lgpgme -lassuan -lgpg-error  -lcrypto -lssl -lz -lcrypt32" \
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
  make -j4
  (($? != 0)) && { printf '%s\n' "[wget openssl] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[wget openssl] make install"; exit 1; }
  mkdir "$INSTALL_PATH"/wget-openssl
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  end_time=$(date +%s.%N)
  duration19=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
fi
echo "编译 zlib 用时: ${duration1}s"
[[ "$ssl_type" == "gnutls" ]] && echo "编译 gmp  用时: ${duration2}s"
[[ "$ssl_type" == "gnutls" ]] && echo "编译 nettle  用时: ${duration3}s"
[[ "$ssl_type" == "gnutls" ]] && echo "编译 libtasn1 用时: ${duration4}s"
echo "编译 libunistring  用时: ${duration5}s"
echo "编译 gpg-error 用时: ${duration6}s"
echo "编译 libassuan 用时: ${duration7}s"
echo "编译 gpgme 用时: ${duration8}s"
echo "编译 c-ares  用时: ${duration9}s"
echo "编译 libiconv 用时: ${duration10}s"
echo "编译 libidn2  用时: ${duration11}s"
echo "编译 libpsl 用时: ${duration12}s"
echo "编译 pcre2 用时: ${duration13}s"
echo "编译 expat 用时: ${duration14}s"
echo "编译 libmetalink 用时: ${duration15}s"
[[ "$ssl_type" == "gnutls" ]] && echo "编译 gnutls 用时: ${duration16}s"
[[ "$ssl_type" == "openssl" ]] && echo "编译 openssl 用时: ${duration17}s"
[[ "$ssl_type" == "gnutls" ]] && echo "编译 wget (gnuTLS) 用时: ${duration18}s"
[[ "$ssl_type" == "openssl" ]] && echo "编译 wget (openssl) 用时: ${duration19}s"
echo "编译完成"
