#!/bin/bash

#
# wget build script for Windows environment
# Author: rzhy1
# 2025/7/31

set -e # 如果任何命令失败，立即退出脚本

export INSTALL_PATH=$PWD
export PKG_CONFIG_PATH="$INSTALL_PATH/lib/pkgconfig"
export WGET_GCC=x86_64-w64-mingw32-gcc
export WGET_MINGW_HOST=x86_64-w64-mingw32
export WGET_ARCH=x86-64
export MINGW_STRIP_TOOL=x86_64-w64-mingw32-strip

export LDFLAGS="-static -static-libgcc -Wl,--gc-sections -flto=$(nproc)" 
export CFLAGS="-march=tigerlake -mtune=tigerlake -O2 -ffunction-sections -fdata-sections -pipe -g0"
export CXXFLAGS="$CFLAGS"

ssl_type="$SSL_TYPE"

echo "x86_64-w64-mingw32-gcc版本是："
x86_64-w64-mingw32-gcc --version

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libz.a ]; then
  wget -O- https://zlib.net/zlib-1.3.1.tar.gz | tar xz
  cd zlib-* || exit
  CC=$WGET_GCC ./configure --64 --static --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[zlib] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration1=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

if [[ "$ssl_type" == "gnutls" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libgmp.a ]; then
    wget -nv -O- https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz | tar x --xz
    cd gmp-* || exit
    ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
    (($? != 0)) && { printf '%s\n' "[gmp] configure failed"; exit 1; }
    make -j$(nproc) && make install && cd ..
  fi
  end_time=$(date +%s.%N)
  duration2=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libnettle.a ]; then
    wget -O- https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz | tar xz
    cd nettle-* || exit
    CFLAGS="-I$INSTALL_PATH/include $CFLAGS" \
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS" \
    CFLAGS="-I$INSTALL_PATH/include $CFLAGS -flto=$(nproc)" \
    ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-documentation --libdir="$INSTALL_PATH/lib" --prefix="$INSTALL_PATH"
    (($? != 0)) && { printf '%s\n' "[nettle] configure failed"; exit 1; }
    make -j$(nproc) && make install && cd ..
  fi
  end_time=$(date +%s.%N)
  duration3=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libtasn1.a ]; then
    wget -O- https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz | tar xz
    cd libtasn1-* || exit
    ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-doc --prefix="$INSTALL_PATH"
    (($? != 0)) && { printf '%s\n' "[tasn] configure failed"; exit 1; }
    make -j$(nproc) && make install && cd ..
  fi
  end_time=$(date +%s.%N)
  duration4=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
fi

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐" 
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libunistring.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.gz | tar xz
  cd libunistring-* || exit
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[unistring] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration5=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpg-error⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libgpg-error.a ]; then
  wget -O- https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.55.tar.gz | tar xz
  cd libgpg-error-* || exit
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc
  (($? != 0)) && { printf '%s\n' "[gpg-error] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration6=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libassuan⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libassuan.a ]; then
  wget -O- https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2 | tar xj
  cd libassuan-* || exit
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc --with-libgpg-error-prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[assuan] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration7=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpgme⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libgpgme.a ]; then
  wget -O- https://gnupg.org/ftp/gcrypt/gpgme/gpgme-2.0.0.tar.bz2 | tar xj
  cd gpgme-* || exit
  env PYTHON=/usr/bin/python3.12 CFLAGS="-DGPGRT_ENABLE_ES_MACROS $CFLAGS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libgpg-error-prefix="$INSTALL_PATH" --disable-gpg-test --disable-g13-test --disable-gpgsm-test --disable-gpgconf-test --disable-glibtest --with-libassuan-prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[gpgme] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration8=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build c-ares⭐⭐⭐⭐⭐⭐" 
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libcares.a ]; then
  wget -O- https://github.com/c-ares/c-ares/releases/download/v1.34.5/c-ares-1.34.5.tar.gz | tar xz
  cd c-ares-* || exit
  CPPFLAGS="-DCARES_STATICLIB=1" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-tests
  (($? != 0)) && { printf '%s\n' "[cares] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration9=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libiconv.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz | tar xz
  cd libiconv-* || exit
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
  (($? != 0)) && { printf '%s\n' "[iconv] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration10=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐" 
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libidn2.a ]; then
  wget -O- https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz | tar xz
  cd libidn2-* || exit
  ./configure --host=$WGET_MINGW_HOST --enable-static --disable-shared --disable-doc --prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[idn2] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration11=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libpsl.a ]; then
  wget -O- https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz | tar xz
  cd libpsl-* || exit
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-gtk-doc --enable-builtin --enable-runtime=libidn2 --with-libiconv-prefix="$INSTALL_PATH"
  (($? != 0)) && { printf '%s\n' "[psl] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration12=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build pcre2⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libpcre2-8.a ]; then
  wget -O- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.gz | tar xz
  cd pcre2-* || exit
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
  (($? != 0)) && { printf '%s\n' "[pcre2] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration13=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build expat⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libexpat.a ]; then
  wget -O- https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.gz | tar xz
  cd expat-* || exit
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --without-docbook --without-tests
  (($? != 0)) && { printf '%s\n' "[expat] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration14=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmetalink⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libmetalink.a ]; then
  wget -O- https://github.com/metalink-dev/libmetalink/releases/download/release-0.1.3/libmetalink-0.1.3.tar.gz | tar xz
  cd libmetalink-* || exit
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libexpat
  (($? != 0)) && { printf '%s\n' "[metalink] configure failed"; exit 1; }
  make -j$(nproc) && make install && cd ..
fi
end_time=$(date +%s.%N)
duration15=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

if [[ "$ssl_type" == "gnutls" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libgnutls.a ]; then
    wget -O- https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.10.tar.xz | tar x --xz
    cd gnutls-* || exit
    PKG_CONFIG_PATH="$INSTALL_PATH/lib/pkgconfig" \
    CFLAGS="-I$INSTALL_PATH/include $CFLAGS" \
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
    ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --with-included-unistring --disable-openssl-compatibility --disable-hardware-acceleration --without-p11-kit --disable-tests --disable-doc --disable-full-test-suite --disable-tools --disable-cxx --disable-maintainer-mode --disable-libdane --disable-shared --enable-static 
    (($? != 0)) && { printf '%s\n' "[gnutls] configure failed"; exit 1; }
    make -j$(nproc) && make install && cd ..
  fi
  end_time=$(date +%s.%N)
  duration16=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
fi

if [[ "$ssl_type" == "openssl" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build openssl⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libssl.a ]; then
    wget -O- https://github.com/openssl/openssl/releases/download/openssl-3.5.1/openssl-3.5.1.tar.gz | tar xz
    cd openssl-* || exit
    ./Configure -static --prefix="$INSTALL_PATH" --libdir=lib --cross-compile-prefix=x86_64-w64-mingw32- mingw64 no-shared enable-asm no-tests --with-zlib-include="$INSTALL_PATH/include" --with-zlib-lib="$INSTALL_PATH/lib/libz.a"
    make -j$(nproc) && make install_sw && cd ..
  fi
  end_time=$(date +%s.%N)
  duration17=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
fi

# --- 主程序 Wget 编译 ---

if [[ "$ssl_type" == "gnutls" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (gnuTLS)⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  rm -rf wget-*
  wget -O- https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz | tar xz
  cd wget-* || exit 1
  # Apply patches for gnulib bugs
  sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
  sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h
  
  WGET_CFLAGS="-I$INSTALL_PATH/include -DGNUTLS_INTERNAL_BUILD=1 -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2"
  WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -lgnutls -lhogweed -lnettle -lgmp -ltasn1 -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lz -lbcrypt -lncrypt -lcrypt32 -lpthread -lws2_32 -liphlpapi"

  ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --disable-debug --enable-iri --enable-pcre2 --with-ssl=gnutls --with-included-libunistring --with-cares --with-libpsl --with-metalink --with-gpgme-prefix="$INSTALL_PATH" \
    CFLAGS="$WGET_CFLAGS" \
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS" \
    LIBS="$WGET_LIBS"
  (($? != 0)) && { printf '%s\n' "[wget gnutls] configure failed"; exit 1; }
  
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[wget gnutls] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[wget gnutls] make install"; exit 1; }
  
  mkdir -p "$INSTALL_PATH"/wget-gnutls
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  end_time=$(date +%s.%N)
  duration18=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
else
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (openssl)⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  rm -rf wget-*
  wget -O- https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz | tar xz
  cd wget-* || exit 1
  # Apply patches for gnulib bugs
  sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
  sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h
  
  WGET_CFLAGS="-I$INSTALL_PATH/include -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2"
  WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -lssl -lcrypto -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lz -lbcrypt -lcrypt32 -lws2_32 -liphlpapi"
  ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --disable-debug --enable-iri --enable-pcre2 --with-ssl=openssl --with-included-libunistring --with-cares --with-libpsl --with-metalink --with-gpgme-prefix="$INSTALL_PATH" \
    CFLAGS="$WGET_CFLAGS" \
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS" \
    LIBS="$WGET_LIBS"
  (($? != 0)) && { printf '%s\n' "[wget openssl] configure failed"; exit 1; }
  
  make -j$(nproc)
  (($? != 0)) && { printf '%s\n' "[wget openssl] make failed"; exit 1; }
  make install
  (($? != 0)) && { printf '%s\n' "[wget openssl] make install"; exit 1; }
  
  mkdir -p "$INSTALL_PATH"/wget-openssl
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  end_time=$(date +%s.%N)
  duration19=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
fi

echo "--- Build Durations ---"
echo "zlib: ${duration1}s"
if [[ "$ssl_type" == "gnutls" ]]; then
  echo "gmp: ${duration2}s"
  echo "nettle: ${duration3}s"
  echo "libtasn1: ${duration4}s"
fi
echo "libunistring: ${duration5}s"
echo "gpg-error: ${duration6}s"
echo "libassuan: ${duration7}s"
echo "gpgme: ${duration8}s"
echo "c-ares: ${duration9}s"
echo "libiconv: ${duration10}s"
echo "libidn2: ${duration11}s"
echo "libpsl: ${duration12}s"
echo "pcre2: ${duration13}s"
echo "expat: ${duration14}s"
echo "libmetalink: ${duration15}s"
if [[ "$ssl_type" == "gnutls" ]]; then
  echo "gnutls: ${duration16}s"
  echo "wget (gnuTLS): ${duration18}s"
elif [[ "$ssl_type" == "openssl" ]]; then
  echo "openssl: ${duration17}s"
  echo "wget (openssl): ${duration19}s"
fi
echo "编译完成"
