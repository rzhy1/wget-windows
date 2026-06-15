#!/bin/bash

#
# wget build script for Windows environment
# Refactored for real parallel execution & optimized safety
#

set -o pipefail
set -e

# --- 全局环境变量定义 ---
export INSTALL_PATH=$PWD
export PKG_CONFIG_PATH="$INSTALL_PATH/lib/pkgconfig"
export WGET_GCC=x86_64-w64-mingw32-gcc
export WGET_MINGW_HOST=x86_64-w64-mingw32
export MINGW_STRIP_TOOL=x86_64-w64-mingw32-strip

# 安全获取 CPU 核心数
if command -v nproc >/dev/null 2>&1; then
    export NPROC=$(nproc)
else
    export NPROC=${NUMBER_OF_PROCESSORS:-4}
fi

# --- 核心编译参数定义 ---
export CFLAGS="-march=tigerlake -mtune=tigerlake -O2 -pipe -ffunction-sections -fdata-sections -fuse-linker-plugin -fvisibility=hidden -fno-stack-protector -fomit-frame-pointer -DNDEBUG -flto=$NPROC"
export CXXFLAGS="$CFLAGS"
export LDFLAGS_DEPS="-static -static-libgcc -Wl,--gc-sections -Wl,-S -flto=$NPROC"
export LTO_FLAGS="-flto=$NPROC"

ssl_type="$SSL_TYPE"

echo "Using GCC version:"
x86_64-w64-mingw32-gcc --version

# ========== 并行镜像测速选择函数 ==========
select_fastest_gnu_mirror() {
    local candidates=(
        "https://mirrors.aliyun.com/gnu"
        "https://mirrors.tuna.tsinghua.edu.cn/gnu"
        "https://mirrors.huaweicloud.com/gnu"
        "https://mirrors.ustc.edu.cn/gnu"
        "https://mirrors.tencent.com/gnu"
        "https://ftp.gnu.org/gnu"
        "https://ftp.jaist.ac.jp/pub/GNU"
        "http://mirrors.kernel.org/gnu"
    )

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local pids=()

    echo "[测速] 正在并行测试 GNU 镜像响应速度..." >&2

    # 并行发起连接测试
    for i in "${!candidates[@]}"; do
        local mirror="${candidates[i]}"
        (
            if command -v curl >/dev/null 2>&1; then
                local curl_output
                curl_output=$(curl -o /dev/null -s -w '%{http_code} %{time_total}' \
                    --connect-timeout 2 --max-time 4 "${mirror}/" 2>/dev/null)
                local http_code=$(echo "$curl_output" | awk '{print $1}')
                local tmp_time=$(echo "$curl_output" | awk '{print $2}')

                if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]] && \
                   awk -v t="$tmp_time" 'BEGIN{exit !(t > 0)}' 2>/dev/null; then
                    echo "$tmp_time $mirror" > "$tmp_dir/$i"
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget --spider --timeout=2 --tries=1 -O /dev/null "${mirror}/" >/dev/null 2>&1; then
                    echo "1.0 $mirror" > "$tmp_dir/$i"
                fi
            fi
        ) &
        pids+=($!)
    done

    # 修正点：等待所有测速子进程结束，使用 || true 避免因网络失败导致脚本闪退
    wait "${pids[@]}" 2>/dev/null || true

    # 评估最快镜像
    local fastest_url="${candidates[0]}"
    local fastest_time=999999

    for i in "${!candidates[@]}"; do
        if [ -f "$tmp_dir/$i" ]; then
            read -r t m < "$tmp_dir/$i"
            printf "  %-45s %.3f 秒\n" "$m" "$t" >&2
            if awk -v t1="$t" -v t2="$fastest_time" 'BEGIN{exit !(t1 < t2)}' 2>/dev/null; then
                fastest_time=$t
                fastest_url=$m
            fi
        fi
    done

    rm -rf "$tmp_dir"
    echo "[选择] 最快镜像: ${fastest_url} (${fastest_time}s)" >&2
    echo "$fastest_url"
}

GNU_MIRROR=$(select_fastest_gnu_mirror)
export GNU_MIRROR
echo "使用镜像源: $GNU_MIRROR" >&2


# ========== 并行执行辅助管理器 ==========
run_parallel() {
    local pids=()
    local cmds=("$@")
    local log_dir
    log_dir=$(mktemp -d)

    for cmd in "${cmds[@]}"; do
        ( $cmd > "$log_dir/${cmd}.log" 2>&1 ) &
        pids+=($!)
    done

    local failed=0
    for i in "${!pids[@]}"; do
        if ! wait "${pids[i]}"; then
            echo "错误: 任务 [${cmds[i]}] 编译失败！输出日志如下：" >&2
            cat "$log_dir/${cmds[i]}.log" >&2
            failed=1
        fi
    done

    rm -rf "$log_dir"
    if [ $failed -ne 0 ]; then
        exit 1
    fi
}


# --- 依赖库编译函数定义 ---

build_zlib() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libz.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf zlib-*
    ( wget -q -O- https://zlib.net/zlib-1.3.2.tar.gz || wget -q -O- https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz ) | tar xz
    cd zlib-* || exit 1
    CC=$WGET_GCC LDFLAGS="$LDFLAGS_DEPS" ./configure --64 --static --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_gmp() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libgmp.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf gmp-*
    wget -nv -O- ${GNU_MIRROR}/gmp/gmp-6.3.0.tar.xz | tar x --xz
    cd gmp-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_nettle() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libnettle.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf nettle-*
    wget -q -O- ${GNU_MIRROR}/nettle/nettle-4.0.tar.gz | tar xz
    cd nettle-* || exit 1
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" CFLAGS="-I$INSTALL_PATH/include $CFLAGS" \
    ./configure --host=$WGET_MINGW_HOST --disable-shared --enable-static --disable-documentation --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_libtasn1() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libtasn1.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf libtasn1-*
    wget -q -O- ${GNU_MIRROR}/libtasn1/libtasn1-4.21.0.tar.gz | tar xz
    cd libtasn1-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-doc --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_libunistring() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libunistring.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf libunistring-*
    wget -q -O- ${GNU_MIRROR}/libunistring/libunistring-1.4.2.tar.gz | tar xz
    cd libunistring-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_gpg_error() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpg-error⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libgpg-error.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf libgpg-error-*
    wget -q -O- https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.gz | tar xz
    cd libgpg-error-* || exit 1
    sed -i 's/w32_utils_init ()\./w32_utils_init ();/' src/w32-utils.c
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc
    make -j$NPROC && make install
  fi
}

build_libassuan() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libassuan⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libassuan.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf libassuan-*
    wget -q -O- https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2 | tar xj
    cd libassuan-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc --with-libgpg-error-prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_gpgme() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpgme⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libgpgme.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf gpgme-*
    wget -q -O- https://gnupg.org/ftp/gcrypt/gpgme/gpgme-2.1.0.tar.bz2 | tar xj
    cd gpgme-* || exit 1
    env PYTHON="$(command -v python3 || command -v python)" LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libgpg-error-prefix="$INSTALL_PATH" --disable-gpg-test --disable-g13-test --disable-gpgsm-test --disable-gpgconf-test --disable-glibtest --with-libassuan-prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_c_ares() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build c-ares⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libcares.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf c-ares-*
    wget -q -O- https://github.com/c-ares/c-ares/releases/download/v1.34.6/c-ares-1.34.6.tar.gz | tar xz
    cd c-ares-* || exit 1
    CPPFLAGS="-DCARES_STATICLIB=1" LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-tests
    make -j$NPROC && make install
  fi
}

build_libiconv() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libiconv.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf libiconv-*
    wget -q -O- ${GNU_MIRROR}/libiconv/libiconv-1.19.tar.gz | tar xz
    cd libiconv-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
    make -j$NPROC && make install
  fi
}

build_libidn2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libidn2.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf libidn2-*
    wget -q -O- ${GNU_MIRROR}/libidn/libidn2-2.3.8.tar.gz | tar xz
    cd libidn2-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --enable-static --disable-shared --disable-doc --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_libpsl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libpsl.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf libpsl-*
    wget -q -O- https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz | tar xz
    cd libpsl-* || exit 1
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-gtk-doc --enable-builtin --enable-runtime=libidn2 --with-libiconv-prefix="$INSTALL_PATH"
    make -j$NPROC && make install
  fi
}

build_pcre2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build pcre2⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libpcre2-8.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf pcre2-*
    wget -q -O- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.47/pcre2-10.47.tar.gz | tar xz
    cd pcre2-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
    make -j$NPROC && make install
  fi
}

build_expat() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build expat⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libexpat.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf expat-*
    wget -q -O- https://github.com/libexpat/libexpat/releases/download/R_2_8_1/expat-2.8.1.tar.gz | tar xz
    cd expat-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --without-docbook --without-tests
    make -j$NPROC && make install
  fi
}

build_libmetalink() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmetalink⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libmetalink.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf libmetalink-*
    wget -q -O- https://github.com/metalink-dev/libmetalink/releases/download/release-0.1.3/libmetalink-0.1.3.tar.gz | tar xz
    cd libmetalink-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libexpat
    make -j$NPROC && make install
  fi
}

build_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libgnutls.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf gnutls-*
    wget -q -O- https://gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz | tar x --xz
    cd gnutls-* || exit 1
    
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST \
      --prefix="$INSTALL_PATH" \
      --with-included-unistring \
      --disable-nls \
      --disable-shared \
      --enable-static \
      --disable-doc \
      --disable-tools \
      --disable-cxx \
      --disable-tests \
      --disable-maintainer-mode \
      --disable-hardware-acceleration \
      --disable-padlock \
      --disable-ocsp \
      --disable-dsa \
      --disable-dhe \
      --disable-ecdhe \
      --disable-gost \
      --disable-anon-authentication \
      --disable-psk-authentication \
      --disable-srp-authentication \
      --disable-alpn-support \
      --without-p11-kit \
      --without-tpm2 \
      --without-tpm \
      --without-idn \
      --without-brotli \
      --without-zstd \
      --disable-full-test-suite \
      --disable-valgrind-tests \
      --disable-seccomp-tests
    make -j$NPROC && make install
  fi
}

build_openssl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build openssl⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libssl.a ]; then
    cd "$INSTALL_PATH" || exit 1
    rm -rf openssl-*
    wget -q -O- https://github.com/openssl/openssl/releases/download/openssl-3.6.3/openssl-3.6.3.tar.gz | tar xz
    cd openssl-* || exit 1
    DISABLED_FEATURES=(
      no-quic no-err no-dso no-engine no-async no-autoalginit
      no-dtls no-sctp no-ssl3 no-tls1 no-tls1_1
      no-comp no-ts no-ocsp no-ct no-cms no-psk no-srp no-srtp no-rfc3779
      no-fips no-acvp-tests no-docs no-stdio no-ui-console
      no-afalgeng no-ssl-trace no-filenames
      no-aria no-bf no-blake2 no-camellia no-cast no-cmac
      no-dh no-dsa no-ec2m no-gost no-idea no-rc2 no-rc4 no-rc5 no-rmd160
      no-scrypt no-seed no-siphash no-siv no-sm2 no-sm3 no-sm4 no-whirlpool
      no-tests no-apps
    )
    CFLAGS="-march=tigerlake -mtune=tigerlake -Os -ffunction-sections -fdata-sections -pipe -g0 -fvisibility=hidden $LTO_FLAGS" \
    LDFLAGS="-Wl,--gc-sections -Wl,--icf=all -static -static-libgcc $LTO_FLAGS" \
    ./Configure -static \
      --prefix="$INSTALL_PATH" \
      --libdir=lib \
      --cross-compile-prefix=x86_64-w64-mingw32- \
      mingw64 no-shared \
      --with-zlib-include="$INSTALL_PATH/include" \
      --with-zlib-lib="$INSTALL_PATH/lib/libz.a" \
      "${DISABLED_FEATURES[@]}"
    make -j$NPROC && make install_sw
  fi
}

build_wget_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (gnuTLS)⭐⭐⭐⭐⭐⭐"
  cd "$INSTALL_PATH" || exit 1
  rm -rf wget-*
  wget -q -O- ${GNU_MIRROR}/wget/wget-1.25.0.tar.gz | tar xz
  cd wget-* || exit 1

  echo "正在修复 http-ntlm.c 以兼容 Nettle 4.0..."
  sed -i 's/nettle_md4_digest(&MD4, MD4_DIGEST_SIZE, ntbuffer);/{\n      uint8_t digest[MD4_DIGEST_SIZE];\n      nettle_md4_digest(\&MD4, digest);\n      memcpy(ntbuffer, digest, MD4_DIGEST_SIZE);\n    }/' src/http-ntlm.c

  # 修复 gnulib 兼容性
  sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
  sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h
 
  # 修正点：将全局优化参数 $CFLAGS 注入 WGET_CFLAGS
  WGET_CFLAGS="$CFLAGS -I$INSTALL_PATH/include -DGNUTLS_INTERNAL_BUILD=1 -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2 -DSO_LINGER=0 -DTCP_LINGER2=0 -D_DISABLE_CLOSE_WAIT"
  WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS -Wl,-u,strndup"
  WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -lgnutls -lhogweed -lnettle -lgmp -ltasn1 -lz -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lwinpthread -lws2_32 -liphlpapi -lcrypt32 -lbcrypt -lncrypt -lmingwex"

  ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" \
    --disable-debug --enable-iri --enable-pcre2 --with-ssl=gnutls \
    --with-included-libunistring=no --with-cares --with-libpsl --with-metalink \
    --with-gpgme-prefix="$INSTALL_PATH" \
    CFLAGS="$WGET_CFLAGS" LDFLAGS="$WGET_LDFLAGS" LIBS="$WGET_LIBS"

  make -j$NPROC && make install

  mkdir -p "$INSTALL_PATH"/wget-gnutls
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
  $MINGW_STRIP_TOOL --strip-all "$INSTALL_PATH"/wget-gnutls/wget-gnutls-x64.exe
}

build_wget_openssl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget (openssl)⭐⭐⭐⭐⭐⭐"
  cd "$INSTALL_PATH" || exit 1
  rm -rf wget-*
  wget -q -O- ${GNU_MIRROR}/wget/wget-1.25.0.tar.gz | tar xz
  cd wget-* || exit 1

  # 修复 gnulib 兼容性
  sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
  sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h
  
  # 修正点：将全局优化参数 $CFLAGS 注入 WGET_CFLAGS，剔除拼写错误的 $LDFLAGS_DEPS 
  WGET_CFLAGS="$CFLAGS -I$INSTALL_PATH/include -DCARES_STATICLIB=1 -DPCRE2_STATIC=1 -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2"
  WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS  -Wl,-u,strndup"
  WGET_LIBS="-lmetalink -lexpat -lcares -lpcre2-8 -lssl -lcrypto -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lz -lbcrypt -lcrypt32 -lgdi32 -lws2_32 -liphlpapi -lmingwex"
  
  ./configure --host=$WGET_MINGW_HOST --prefix="$INSTALL_PATH" --disable-debug --enable-iri --enable-pcre2 --with-ssl=openssl --with-included-libunistring=no --with-cares --with-libpsl --with-metalink --with-gpgme-prefix="$INSTALL_PATH" \
  CFLAGS="$WGET_CFLAGS" LDFLAGS="$WGET_LDFLAGS" LIBS="$WGET_LIBS"

  make -j$NPROC && make install
  
  mkdir -p "$INSTALL_PATH"/wget-openssl
  cp "$INSTALL_PATH"/bin/wget.exe "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
  $MINGW_STRIP_TOOL --strip-all "$INSTALL_PATH"/wget-openssl/wget-openssl-x64.exe
}


# --- 主执行流程 ---

# STAGE 1: 编译没有内部依赖或只依赖 zlib 的基础库
echo "--- LAUNCHING STAGE 1 BUILDS (PARALLEL) ---"
stage1_tasks=(build_gpg_error build_zlib build_libunistring build_c_ares build_libiconv build_pcre2 build_expat)
if [[ "$ssl_type" == "gnutls" ]]; then
  stage1_tasks+=(build_gmp build_libtasn1)
fi
run_parallel "${stage1_tasks[@]}"

# STAGE 2: 编译依赖于 STAGE 1 库的库
echo "--- LAUNCHING STAGE 2 BUILDS (PARALLEL) ---"
stage2_tasks=(build_libidn2 build_libassuan build_libmetalink)
if [[ "$ssl_type" == "gnutls" ]]; then
  stage2_tasks+=(build_nettle)
fi
if [[ "$ssl_type" == "openssl" ]]; then
  stage2_tasks+=(build_openssl)
fi
run_parallel "${stage2_tasks[@]}"

# STAGE 3: 编译依赖于 STAGE 2 库的库
echo "--- LAUNCHING STAGE 3 BUILDS (PARALLEL) ---"
run_parallel build_libpsl build_gpgme

# STAGE 4: 编译 GnuTLS（仅限 gnutls 模式）
if [[ "$ssl_type" == "gnutls" ]]; then
  echo "--- LAUNCHING STAGE 4 BUILD (gnutls) ---"
  build_gnutls
fi

# FINAL STAGE: 编译 Wget
echo "--- LAUNCHING FINAL BUILD (wget) ---"
find "$INSTALL_PATH/lib" -name "*.la" -delete 2>/dev/null || true
if [[ "$ssl_type" == "gnutls" ]]; then
  build_wget_gnutls
else
  build_wget_openssl
fi

echo "编译完成"
