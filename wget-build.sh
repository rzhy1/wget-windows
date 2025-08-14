#!/bin/bash

#
# wget build script for Windows environment
# Author: rzhy1
# 2025/7/31
#
# Optimized with assistance from Gemini
# 2025/08/01
#

# --- 脚本行为设置 ---
# 如果任何命令执行失败，立即退出脚本
set -e

# --- 全局环境变量定义 ---
export INSTALL_PATH=$PWD
export PKG_CONFIG_PATH="$INSTALL_PATH/lib/pkgconfig"
export WGET_GCC=x86_64-w64-mingw32-gcc
export WGET_MINGW_HOST=x86_64-w64-mingw32
export MINGW_STRIP_TOOL=x86_64-w64-mingw32-strip

# --- 核心编译参数定义 ---
# CFLAGS: 针对目标CPU进行优化，并启用代码/数据段拆分以便链接器进行"垃圾回收"。
export CFLAGS="-march=tigerlake -mtune=tigerlake -O2 -ffunction-sections -fdata-sections -pipe -g0"
export CXXFLAGS="$CFLAGS"

# LDFLAGS for dependencies: 不包含LTO，以确保所有configure测试都能通过。
export LDFLAGS_DEPS="-static -static-libgcc -Wl,--gc-sections"

# LTO_FLAGS: 单独定义LTO参数，只在编译wget主程序时使用。
export LTO_FLAGS="-flto=$(nproc)"

# 获取外部传入的SSL类型变量
ssl_type="$SSL_TYPE"

echo "Using GCC version:"
x86_64-w64-mingw32-gcc --version

# --- 依赖库编译 ---

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libz.a ]; then
  wget -q -O- https://zlib.net/zlib-1.3.1.tar.gz | tar xz
  cd zlib-* || exit
  CC=$WGET_GCC LDFLAGS="$LDFLAGS_DEPS" ./configure --64 --static --prefix="$INSTALL_PATH"
  make -j$(nproc) && make install && cd .. && rm -rf zlib-*
fi
end_time=$(date +%s.%N)
duration1=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

if [[ "$ssl_type" == "gnutls" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libgmp.a ]; then
    wget -nv -O- https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz | tar x --xz
    cd gmp-* || exit
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
    make -j$(nproc) && make install && cd .. && rm -rf gmp-*
  fi
  end_time=$(date +%s.%N)
  duration2=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libnettle.a ]; then
    wget -q -O- https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz | tar xz
    cd nettle-* || exit
    # 明确传递包含gmp的路径，以确保nettle能找到它并构建libhogweed
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" CFLAGS="-I$INSTALL_PATH/include $CFLAGS" \
    ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-documentation --prefix="$INSTALL_PATH" --enable-mini-gmp=no
    make -j$(nproc) && make install && cd .. && rm -rf nettle-*
  fi
  end_time=$(date +%s.%N)
  duration3=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libtasn1.a ]; then
    wget -q -O- https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz | tar xz
    cd libtasn1-* || exit
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-doc --prefix="$INSTALL_PATH"
    make -j$(nproc) && make install && cd .. && rm -rf libtasn1-*
  fi
  end_time=$(date +%s.%N)
  duration4=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
fi

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐" 
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libunistring.a ]; then
  wget -q -O- https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.gz | tar xz
  cd libunistring-* || exit
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
  make -j$(nproc) && make install && cd .. && rm -rf libunistring-*
fi
end_time=$(date +%s.%N)
duration5=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpg-error⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libgpg-error.a ]; then
  wget -q -O- https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.55.tar.gz | tar xz
  cd libgpg-error-* || exit
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc
  make -j$(nproc) && make install && cd .. && rm -rf libgpg-error-*
fi
end_time=$(date +%s.%N)
duration6=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libassuan⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libassuan.a ]; then
  wget -q -O- https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2 | tar xj
  cd libassuan-* || exit
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc --with-libgpg-error-prefix="$INSTALL_PATH"
  make -j$(nproc) && make install && cd .. && rm -rf libassuan-*
fi
end_time=$(date +%s.%N)
duration7=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpgme⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libgpgme.a ]; then
  wget -q -O- https://gnupg.org/ftp/gcrypt/gpgme/gpgme-2.0.0.tar.bz2 | tar xj
  cd gpgme-* || exit
  env PYTHON=/usr/bin/python3.12 LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libgpg-error-prefix="$INSTALL_PATH" --disable-gpg-test --disable-g13-test --disable-gpgsm-test --disable-gpgconf-test --disable-glibtest --with-libassuan-prefix="$INSTALL_PATH"
  make -j$(nproc) && make install && cd .. && rm -rf gpgme-*
fi
end_time=$(date +%s.%N)
duration8=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build c-ares⭐⭐⭐⭐⭐⭐" 
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libcares.a ]; then
  wget -q -O- https://github.com/c-ares/c-ares/releases/download/v1.34.5/c-ares-1.34.5.tar.gz | tar xz
  cd c-ares-* || exit
  CPPFLAGS="-DCARES_STATICLIB=1" LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-tests
  make -j$(nproc) && make install && cd .. && rm -rf c-ares-*
fi
end_time=$(date +%s.%N)
duration9=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libiconv.a ]; then
  wget -q -O- https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz | tar xz
  cd libiconv-* || exit
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
  make -j$(nproc) && make install && cd .. && rm -rf libiconv-*
fi
end_time=$(date +%s.%N)
duration10=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐" 
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libidn2.a ]; then
  wget -q -O- https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz | tar xz
  cd libidn2-* || exit
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --enable-static --disable-shared --disable-doc --prefix="$INSTALL_PATH"
  make -j$(nproc) && make install && cd .. && rm -rf libidn2-*
fi
end_time=$(date +%s.%N)
duration11=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libpsl.a ]; then
  wget -q -O- https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz | tar xz
  cd libpsl-* || exit
  LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-gtk-doc --enable-builtin --enable-runtime=libidn2 --with-libiconv-prefix="$INSTALL_PATH"
  make -j$(nproc) && make install && cd .. && rm -rf libpsl-*
fi
end_time=$(date +%s.%N)
duration12=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build pcre2⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libpcre2-8.a ]; then
  wget -q -O- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.gz | tar xz
  cd pcre2-* || exit
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
  make -j$(nproc) && make install && cd .. && rm -rf pcre2-*
fi
end_time=$(date +%s.%N)
duration13=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build expat⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libexpat.a ]; then
  wget -q -O- https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.gz | tar xz
  cd expat-* || exit
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --without-docbook --without-tests
  make -j$(nproc) && make install && cd .. && rm -rf expat-*
fi
end_time=$(date +%s.%N)
duration14=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmetalink⭐⭐⭐⭐⭐⭐"
start_time=$(date +%s.%N)
if [ ! -f "$INSTALL_PATH"/lib/libmetalink.a ]; then
  wget -q -O- https://github.com/metalink-dev/libmetalink/releases/download/release-0.1.3/libmetalink-0.1.3.tar.gz | tar xz
  cd libmetalink-* || exit
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libexpat
  make -j$(nproc) && make install && cd .. && rm -rf libmetalink-*
fi
end_time=$(date +%s.%N)
duration15=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")

if [[ "$ssl_type" == "gnutls" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libgnutls.a ]; then
    wget -q -O- https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.10.tar.xz | tar x --xz
    cd gnutls-* || exit
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --with-included-unistring --disable-openssl-compatibility --disable-hardware-acceleration --without-p11-kit --disable-tests --disable-doc --disable-full-test-suite --disable-tools --disable-cxx --disable-maintainer-mode --disable-libdane --disable-shared --enable-static 
    make -j$(nproc) && make install && cd .. && rm -rf gnutls-*
  fi
  end_time=$(date +%s.%N)
  duration16=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
fi

if [[ "$ssl_type" == "openssl" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build openssl⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  if [ ! -f "$INSTALL_PATH"/lib/libssl.a ]; then
    wget -q -O- https://github.com/openssl/openssl/releases/download/openssl-3.5.1/openssl-3.5.1.tar.gz | tar xz
    cd openssl-* || exit
    # 优化后的禁用列表
    DISABLED_FEATURES=(
      no-legacy no-fips no-deprecated no-autoalginit
      no-engine no-dso no-dynamic-engine no-async
      no-ui-console no-afalgeng no-devcryptoeng
      no-comp no-err no-tests no-unit-test no-uplink
      no-ssl3 no-tls1 no-tls1_1 no-dtls no-dtls1 no-dtls1_2
      no-sctp no-ct no-ocsp no-psk no-srp no-srtp no-cms
      no-ts no-rfc3779
      no-aria no-bf no-blake2 no-camellia no-cast no-chacha
      no-cmac no-des no-dh no-dsa no-ec2m no-ecdh no-ecdsa
      no-gost no-idea no-md2 no-md4 no-mdc2 no-poly1305
      no-rc2 no-rc4 no-rc5 no-rmd160 no-scrypt no-seed
      no-siphash no-siv no-sm2 no-sm3 no-sm4 no-whirlpool
    )
    export CFLAGS_OPENSSL="-Os -ffunction-sections -fdata-sections"
    CFLAGS="$CFLAGS_OPENSSL" ./Configure -static \
      --prefix="$INSTALL_PATH" \
      --libdir=lib \
      --cross-compile-prefix=x86_64-w64-mingw32- \
      mingw64 no-shared \
      --with-zlib-include="$INSTALL_PATH/include" \
      --with-zlib-lib="$INSTALL_PATH/lib/libz.a" \
      "${DISABLED_FEATURES[@]}"
    make -j$(nproc) && make install_sw && cd .. && rm -rf openssl-*
  fi
  end_time=$(date +%s.%N)
  duration17=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
fi

# --- 主程序 Wget 编译 ---

if [[ "$ssl_type" == "gnutls" ]]; then
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (gnuTLS)⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  rm -rf wget-*
  wget -q -O- https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz | tar xz
  cd wget-* || exit 1
  
  # 为 gnulib 在 MinGW-w64 下的 bug 打补丁
  sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
  sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h
  
  WGET_CFLAGS="-I$INSTALL_PATH/include -DGNUTLS_INTERNAL_BUILD=1 -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2"
  WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS $LTO_FLAGS"
  WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -lgnutls -lhogweed -lnettle -lgmp -ltasn1 -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lz -lbcrypt -lncrypt -lcrypt32 -lpthread -lws2_32 -liphlpapi"

  ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --disable-debug --enable-iri --enable-pcre2 --with-ssl=gnutls --with-included-libunistring --with-cares --with-libpsl --with-metalink --with-gpgme-prefix="$INSTALL_PATH" \
    CFLAGS="$WGET_CFLAGS" LDFLAGS="$WGET_LDFLAGS" LIBS="$WGET_LIBS"

  make -j$(nproc) && make install
  
  mkdir -p "$INSTALL_PATH"/wget-gnutls
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  rm -rf wget-*
  end_time=$(date +%s.%N)
  duration18=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
else
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (openssl)⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  rm -rf wget-*
  wget -q -O- https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz | tar xz
  cd wget-* || exit 1

  # 为 gnulib 在 MinGW-w64 下的 bug 打补丁
  sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
  sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h
  
  WGET_CFLAGS="-I$INSTALL_PATH/include -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2"
  WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS $LTO_FLAGS"
  WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -lssl -lcrypto -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lz -lbcrypt -lcrypt32 -lws2_32 -liphlpapi"

  ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --disable-debug --disable-nls --enable-iri --enable-pcre2 --with-ssl=openssl --with-included-libunistring --with-cares --with-libpsl --with-metalink --with-gpgme-prefix="$INSTALL_PATH" \
    CFLAGS="$WGET_CFLAGS" LDFLAGS="$WGET_LDFLAGS" LIBS="$WGET_LIBS"

  make -j$(nproc) && make install
  
  mkdir -p "$INSTALL_PATH"/wget-openssl
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  rm -rf wget-*
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
