#!/bin/bash

#
# wget build script for Windows environment
# Author: rzhy1
# Refactored for parallel execution
# 2025/08/30
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
export CFLAGS="-march=tigerlake -mtune=tigerlake -O2 -ffunction-sections -fdata-sections -pipe -g0 -fvisibility=hidden"
export CXXFLAGS="$CFLAGS"

# LDFLAGS for dependencies: 不包含LTO，以确保所有configure测试都能通过。
export LDFLAGS_DEPS="-static -static-libgcc -Wl,--gc-sections -Wl,-S"

# LTO_FLAGS: 单独定义LTO参数，只在编译wget主程序时使用。
export LTO_FLAGS="-flto=$(nproc) -fuse-linker-plugin"

# 获取外部传入的SSL类型变量
ssl_type="$SSL_TYPE"

echo "Using GCC version:"
x86_64-w64-mingw32-gcc --version

# --- 依赖库编译函数定义 ---

build_zlib() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libz.a ]; then
      wget -q -O- https://zlib.net/zlib-1.3.1.tar.gz | tar xz
      cd zlib-* || exit
      CC=$WGET_GCC LDFLAGS="$LDFLAGS_DEPS" ./configure --64 --static --prefix="$INSTALL_PATH"
      make -j$(nproc) && make install
    fi
  )
}

build_gmp() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libgmp.a ]; then
      wget -nv -O- https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz | tar x --xz
      cd gmp-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
      make -j$(nproc) && make install
    fi
  )
}

build_nettle() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libnettle.a ]; then
      wget -q -O- https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz | tar xz
      cd nettle-* || exit
      # 明确传递包含gmp的路径，以确保nettle能找到它并构建libhogweed
      LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" CFLAGS="-I$INSTALL_PATH/include $CFLAGS" \
      ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-documentation --prefix="$INSTALL_PATH" --enable-mini-gmp=no
      make -j$(nproc) && make install
    fi
  )
}

build_libtasn1() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libtasn1.a ]; then
      wget -q -O- https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz | tar xz
      cd libtasn1-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-doc --prefix="$INSTALL_PATH"
      make -j$(nproc) && make install
    fi
  )
}

build_libunistring() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libunistring.a ]; then
      wget -q -O- https://ftp.gnu.org/gnu/libunistring/libunistring-1.4.tar.gz | tar xz
      cd libunistring-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
      make -j$(nproc) && make install
    fi
  )
}

build_gpg_error() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpg-error⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libgpg-error.a ]; then
      wget -q -O- https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.55.tar.gz | tar xz
      cd libgpg-error-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc
      make -j$(nproc) && make install
    fi
  )
}

build_libassuan() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libassuan⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libassuan.a ]; then
      wget -q -O- https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2 | tar xj
      cd libassuan-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc --with-libgpg-error-prefix="$INSTALL_PATH"
      make -j$(nproc) && make install
    fi
  )
}

build_gpgme() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpgme⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libgpgme.a ]; then
      wget -q -O- https://gnupg.org/ftp/gcrypt/gpgme/gpgme-2.0.1.tar.bz2 | tar xj
      cd gpgme-* || exit
      env PYTHON=/usr/bin/python3.12 LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libgpg-error-prefix="$INSTALL_PATH" --disable-gpg-test --disable-g13-test --disable-gpgsm-test --disable-gpgconf-test --disable-glibtest --with-libassuan-prefix="$INSTALL_PATH"
      make -j$(nproc) && make install
    fi
  )
}

build_c_ares() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build c-ares⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libcares.a ]; then
      wget -q -O- https://github.com/c-ares/c-ares/releases/download/v1.34.5/c-ares-1.34.5.tar.gz | tar xz
      cd c-ares-* || exit
      CPPFLAGS="-DCARES_STATICLIB=1" LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-tests
      make -j$(nproc) && make install
    fi
  )
}

build_libiconv() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libiconv.a ]; then
      wget -q -O- https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz | tar xz
      cd libiconv-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
      make -j$(nproc) && make install
    fi
  )
}

build_libidn2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libidn2.a ]; then
      wget -q -O- https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz | tar xz
      cd libidn2-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --enable-static --disable-shared --disable-doc --prefix="$INSTALL_PATH"
      make -j$(nproc) && make install
    fi
  )
}

build_libpsl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libpsl.a ]; then
      wget -q -O- https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz | tar xz
      cd libpsl-* || exit
      LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-gtk-doc --enable-builtin --enable-runtime=libidn2 --with-libiconv-prefix="$INSTALL_PATH"
      make -j$(nproc) && make install
    fi
  )
}

build_pcre2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build pcre2⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libpcre2-8.a ]; then
      wget -q -O- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.46/pcre2-10.46.tar.gz | tar xz
      cd pcre2-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
      make -j$(nproc) && make install
    fi
  )
}

build_expat() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build expat⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libexpat.a ]; then
      wget -q -O- https://github.com/libexpat/libexpat/releases/download/R_2_7_3/expat-2.7.3.tar.gz | tar xz
      cd expat-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --without-docbook --without-tests
      make -j$(nproc) && make install
    fi
  )
}

build_libmetalink() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmetalink⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libmetalink.a ]; then
      wget -q -O- https://github.com/metalink-dev/libmetalink/releases/download/release-0.1.3/libmetalink-0.1.3.tar.gz | tar xz
      cd libmetalink-* || exit
      LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libexpat
      make -j$(nproc) && make install
    fi
  )
}

build_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libgnutls.a ]; then
      rm -rf gnutls-*
      wget -q -O- https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.10.tar.xz | tar x --xz
      cd gnutls-* || exit
      LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --with-included-unistring --disable-openssl-compatibility --disable-hardware-acceleration --without-p11-kit --disable-tests --disable-doc --disable-full-test-suite --disable-tools --disable-cxx --disable-maintainer-mode --disable-libdane --disable-shared --enable-static
      make -j$(nproc) && make install
    fi
  )
}

build_openssl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build openssl⭐⭐⭐⭐⭐⭐"
  (
    if [ ! -f "$INSTALL_PATH"/lib/libssl.a ]; then
      rm -rf openssl-*
      wget -q -O- https://github.com/openssl/openssl/releases/download/openssl-3.6.0/openssl-3.6.0.tar.gz | tar xz
      cd openssl-* || exit
      # 优化后的禁用列表
      DISABLED_FEATURES=(
        no-err no-dso no-engine no-async no-autoalginit
        no-dtls no-sctp no-ssl3 no-tls1 no-tls1_1
        no-comp no-ts no-ocsp no-ct no-cms no-psk no-srp no-srtp no-rfc3779
        no-fips
        no-aria no-bf no-blake2 no-camellia no-cast no-cmac no-dh no-dsa
        no-ec2m no-gost no-idea no-rc2 no-rc4 no-rc5 no-rmd160 no-scrypt
        no-seed no-siphash no-siv no-sm2 no-sm3 no-sm4 no-whirlpool
        no-tests no-apps
      )
      CFLAGS="-march=tigerlake -mtune=tigerlake -Os -ffunction-sections -fdata-sections -pipe -g0 $LTO_FLAGS" \
      LDFLAGS="-Wl,--gc-sections -static -static-libgcc $LTO_FLAGS" \
      ./Configure -static \
        --prefix="$INSTALL_PATH" \
        --libdir=lib \
        --cross-compile-prefix=x86_64-w64-mingw32- \
        mingw64 no-shared \
        --with-zlib-include="$INSTALL_PATH/include" \
        --with-zlib-lib="$INSTALL_PATH/lib/libz.a" \
        "${DISABLED_FEATURES[@]}"
      make -j$(nproc) && make install_sw
      $MINGW_STRIP_TOOL --strip-unneeded "$INSTALL_PATH"/lib/libcrypto.a || true
      $MINGW_STRIP_TOOL --strip-unneeded "$INSTALL_PATH"/lib/libssl.a || true
    fi
  )
}

build_wget_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (gnuTLS)⭐⭐⭐⭐⭐⭐"
  (
    rm -rf wget-*
    wget -q -O- https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz | tar xz
    cd wget-* || exit 1
    
    # 为 gnulib 在 MinGW-w64 下的 bug 打补丁
    sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
    sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h
    
    WGET_CFLAGS="-I$INSTALL_PATH/include -DGNUTLS_INTERNAL_BUILD=1 -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2 -flto=$(nproc) -DSO_LINGER=0 -DTCP_LINGER2=0 -D_DISABLE_CLOSE_WAIT"
    WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS $LTO_FLAGS"
    WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -lgnutls -lhogweed -lnettle -lgmp -ltasn1 -lz -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lwinpthread -lws2_32 -liphlpapi -lcrypt32 -lbcrypt -lncrypt"
    ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --disable-debug --enable-iri --enable-pcre2 --with-ssl=gnutls --with-included-libunistring --with-cares --with-libpsl --with-metalink --with-gpgme-prefix="$INSTALL_PATH" \
      CFLAGS="$WGET_CFLAGS" LDFLAGS="$WGET_LDFLAGS" LIBS="$WGET_LIBS"

    make -j$(nproc) && make install
    
    mkdir -p "$INSTALL_PATH"/wget-gnutls
    cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
    $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  )
}

build_wget_openssl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (openssl)⭐⭐⭐⭐⭐⭐"
  (
    rm -rf wget-*
    wget -q -O- https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz | tar xz
    cd wget-* || exit 1

    # 为 gnulib 在 MinGW-w64 下的 bug 打补丁
    sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
    sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h
    
    WGET_CFLAGS="-I$INSTALL_PATH/include -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2"
    WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS $LTO_FLAGS"
    WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -Wl,--whole-archive -lssl -lcrypto -Wl,--no-whole-archive -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lz -lbcrypt -lcrypt32 -lws2_32 -liphlpapi"

    ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --disable-debug --enable-iri --enable-pcre2 --with-ssl=openssl --with-included-libunistring --with-cares --with-libpsl --with-metalink --with-gpgme-prefix="$INSTALL_PATH" \
      CFLAGS="$WGET_CFLAGS" LDFLAGS="$WGET_LDFLAGS" LIBS="$WGET_LIBS"

    make -j$(nproc) && make install
    
    mkdir -p "$INSTALL_PATH"/wget-openssl
    cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
    $MINGW_STRIP_TOOL "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  )
}


# --- 主执行流程 ---

# STAGE 1: 编译没有内部依赖或只依赖zlib的基础库
echo "--- LAUNCHING STAGE 1 BUILDS ---"
build_zlib &
build_libunistring &
build_gpg_error &
build_c_ares &
build_libiconv &
build_pcre2 &
build_expat &

if [[ "$ssl_type" == "gnutls" ]]; then
  build_gmp &
  build_libtasn1 &
fi
wait

# STAGE 2: 编译依赖于STAGE 1库的库
echo "--- LAUNCHING STAGE 2 BUILDS ---"
build_libidn2 &       # Depends on libunistring
build_libassuan &     # Depends on gpg-error
build_libmetalink &   # Depends on expat

if [[ "$ssl_type" == "gnutls" ]]; then
  build_nettle &      # Depends on gmp
fi
if [[ "$ssl_type" == "openssl" ]]; then
  build_openssl &     # Depends on zlib
fi
wait

# STAGE 3: 编译依赖于STAGE 2库的库
echo "--- LAUNCHING STAGE 3 BUILDS ---"
build_libpsl &        # Depends on libidn2, libiconv
build_gpgme &         # Depends on libassuan, gpg-error
wait

# STAGE 4: 编译GnuTLS (如果需要)
if [[ "$ssl_type" == "gnutls" ]]; then
  echo "--- LAUNCHING STAGE 4 BUILD (gnutls) ---"
  build_gnutls &
fi
wait

# --- FINAL STAGE: 打包依赖和构建结果 ---
echo ">>> 打包依赖和构建结果..."
cd "$INSTALL_PATH" || { echo "❌ 路径无效: $INSTALL_PATH"; exit 1; }

if [[ "$ssl_type" == "gnutls" ]]; then
  PACKAGE_NAME="wget-gnutls-deps.tar.zst"
else
  PACKAGE_NAME="wget-openssl-deps.tar.zst"
fi

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/include" "$TMPDIR/lib" "$TMPDIR/pkgconfig"

for d in include lib pkgconfig; do
  [ -d "$INSTALL_PATH/$d" ] && cp -a "$INSTALL_PATH/$d" "$TMPDIR/" 2>/dev/null || true
done
[ -d "$INSTALL_PATH/wget-$ssl_type" ] && cp -a "$INSTALL_PATH/wget-$ssl_type" "$TMPDIR/" || echo "⚠️ 未找到 wget-$ssl_type 目录"

echo ">>> 打包内容预览："
find "$TMPDIR" -maxdepth 2 -type f | sort | head -n 30

# 在 /tmp 中打包，避免与 GITHUB_WORKSPACE 路径冲突
TAR_PATH="/tmp/${PACKAGE_NAME}"
tar -I zstd -cf "$TAR_PATH" -C "$TMPDIR" .

# 再复制到 GITHUB_WORKSPACE
cp -fv "$TAR_PATH" "${GITHUB_WORKSPACE}/" || { echo "❌ 复制包失败"; exit 1; }

echo ">>> 打包完成，生成文件："
ls -lh "${GITHUB_WORKSPACE}/${PACKAGE_NAME}"

rm -rf "$TMPDIR"
echo "🎉 最终构建完成并已打包：${PACKAGE_NAME}"
