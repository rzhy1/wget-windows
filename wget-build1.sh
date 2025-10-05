#!/bin/bash

#
# wget build script for Windows (MinGW-w64)
# Author: rzhy1
# Optimized for separate dependency packaging
# Version: 2025/10/04
#

# --- 脚本行为设置 ---
set -e  # 任意命令失败立即退出

# --- 全局环境变量定义 ---
export INSTALL_PATH=$PWD
export PKG_CONFIG_PATH="$INSTALL_PATH/lib/pkgconfig"
export WGET_GCC=x86_64-w64-mingw32-gcc
export WGET_MINGW_HOST=x86_64-w64-mingw32
export MINGW_STRIP_TOOL=x86_64-w64-mingw32-strip

# --- 核心优化参数定义 ---
# 针对目标 CPU 优化，并启用函数/数据分节，便于链接器进行“死代码回收”
export CFLAGS="-march=tigerlake -mtune=tigerlake -O2 -ffunction-sections -fdata-sections -pipe -fvisibility=hidden -flto"
export CXXFLAGS="$CFLAGS"

# 静态链接选项
export LDFLAGS_STATIC="-static -static-libgcc -static-libstdc++"

# 主程序链接优化参数（含 LTO、段回收与符号剥离）
export LTO_FLAGS="-flto=$(nproc) -fuse-linker-plugin -Wl,--gc-sections -Wl,--strip-all"

# SSL 类型（外部传入）
ssl_type="$SSL_TYPE"

echo "Using GCC version:"
x86_64-w64-mingw32-gcc --version
echo "SSL TYPE: $ssl_type"
echo

# --- 编译函数定义 ---

build_wget_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐ $(date '+%Y/%m/%d %a %H:%M:%S') - build wget (GnuTLS) ⭐⭐⭐⭐⭐⭐"
  (
    rm -rf wget-*
    wget -q -O- https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz | tar xz
    cd wget-* || exit 1

    # 修复 MinGW gnulib bug
    sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
    sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h

    WGET_CFLAGS="-I$INSTALL_PATH/include -DGNUTLS_INTERNAL_BUILD=1 -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG"
    WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_STATIC $LTO_FLAGS"
    WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -lgnutls -lhogweed -lnettle -lgmp -ltasn1 -lz \
               -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error \
               -lwinpthread -lws2_32 -liphlpapi -lcrypt32 -lbcrypt -lncrypt"

    ./configure \
      --host=$WGET_MINGW_HOST \
      --prefix="$INSTALL_PATH" \
      --disable-debug \
      --enable-iri \
      --enable-pcre2 \
      --with-ssl=gnutls \
      --with-included-libunistring \
      --with-cares \
      --with-libpsl \
      --with-metalink \
      --with-gpgme-prefix="$INSTALL_PATH" \
      CFLAGS="$WGET_CFLAGS" LDFLAGS="$WGET_LDFLAGS" LIBS="$WGET_LIBS"

    make -j$(nproc)
    make install

    mkdir -p "$INSTALL_PATH/wget-gnutls"
    cp "$INSTALL_PATH/bin/wget.exe" "$INSTALL_PATH/wget-gnutls/wget-gnutls-x64.exe"
    $MINGW_STRIP_TOOL --strip-all "$INSTALL_PATH/wget-gnutls/wget-gnutls-x64.exe"
  )
}

build_wget_openssl() {
  echo "⭐⭐⭐⭐⭐⭐ $(date '+%Y/%m/%d %a %H:%M:%S') - build wget (OpenSSL) ⭐⭐⭐⭐⭐⭐"
  (
    rm -rf wget-*
    wget -q -O- https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz | tar xz
    cd wget-* || exit 1

    # 修复 MinGW gnulib bug
    sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
    sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h

    WGET_CFLAGS="-I$INSTALL_PATH/include -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DNDEBUG"
    WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_STATIC $LTO_FLAGS"
    WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 \
               -Wl,--whole-archive -lssl -lcrypto -Wl,--no-whole-archive \
               -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error \
               -lz -lbcrypt -lcrypt32 -lws2_32 -liphlpapi"

    ./configure \
      --host=$WGET_MINGW_HOST \
      --prefix="$INSTALL_PATH" \
      --disable-debug \
      --enable-iri \
      --enable-pcre2 \
      --with-ssl=openssl \
      --with-included-libunistring \
      --with-cares \
      --with-libpsl \
      --with-metalink \
      --with-gpgme-prefix="$INSTALL_PATH" \
      CFLAGS="$WGET_CFLAGS" LDFLAGS="$WGET_LDFLAGS" LIBS="$WGET_LIBS"

    make -j$(nproc)
    make install

    mkdir -p "$INSTALL_PATH/wget-openssl"
    cp "$INSTALL_PATH/bin/wget.exe" "$INSTALL_PATH/wget-openssl/wget-openssl-x64.exe"
    $MINGW_STRIP_TOOL --strip-all "$INSTALL_PATH/wget-openssl/wget-openssl-x64.exe"
  )
}

# --- 主执行流程 ---
echo "--- LAUNCHING FINAL BUILD (wget) ---"

if [[ "$ssl_type" == "gnutls" ]]; then
  echo ">>> 下载并解压 GnuTLS 依赖..."
  wget -q -O wget-gnutls-deps.tar.zst \
    https://github.com/rzhy1/wget-windows/releases/download/wget-1.25.0/wget-gnutls-deps.tar.zst
  tar -I zstd -xf wget-gnutls-deps.tar.zst -C "$PWD"
  build_wget_gnutls
else
  echo ">>> 下载并解压 OpenSSL 依赖..."
  wget -q -O wget-openssl-deps.tar.zst \
    https://github.com/rzhy1/wget-windows/releases/download/wget-1.25.0/wget-openssl-deps.tar.zst
  tar -I zstd -xf wget-openssl-deps.tar.zst -C "$PWD"
  build_wget_openssl
fi

echo "✅ 编译完成，结果保存在 wget-${ssl_type}/wget-${ssl_type}-x64.exe"
