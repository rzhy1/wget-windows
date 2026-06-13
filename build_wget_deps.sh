#!/bin/bash

#
# wget 依赖预编译打包脚本
# 学习 wget2 deps 的思路：编译所有静态依赖 → 打包 include/lib/pkgconfig
# 用法: SSL_TYPE=gnutls ./build_wget_deps.sh    # 打包 GnuTLS 依赖
#       SSL_TYPE=openssl ./build_wget_deps.sh   # 打包 OpenSSL 依赖
#

set -o pipefail
set -e

# --- 全局环境变量定义 ---
export INSTALL_PATH="$HOME/wget-deps-install"   # 固定安装目录，避免与源码混在一起
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

# 编译参数
export CFLAGS="-march=tigerlake -mtune=tigerlake -O2 -pipe -ffunction-sections -fdata-sections -fuse-linker-plugin -fvisibility=hidden -fno-stack-protector -fomit-frame-pointer -DNDEBUG"
export CXXFLAGS="$CFLAGS"
export LDFLAGS_DEPS="-static -static-libgcc -Wl,--gc-sections -Wl,-S"
export LTO_FLAGS="-flto=$NPROC"

ssl_type="${SSL_TYPE:-gnutls}"   # 默认打包 GnuTLS 依赖

echo ">>> 打包目标: SSL_TYPE=$ssl_type"
x86_64-w64-mingw32-gcc --version

# ---------- 镜像自动测速选择 ----------
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
    local tmp_dir fast_time=999999 fast_url="${candidates[0]}"
    tmp_dir=$(mktemp -d)
    echo "[测速] 正在并行测试 GNU 镜像..." >&2

    for i in "${!candidates[@]}"; do
        local mirror="${candidates[i]}"
        (
            if command -v curl >/dev/null 2>&1; then
                local out
                out=$(curl -o /dev/null -s -w '%{http_code} %{time_total}' --connect-timeout 2 --max-time 4 "${mirror}/" 2>/dev/null)
                local code=$(echo "$out" | awk '{print $1}')
                local t=$(echo "$out" | awk '{print $2}')
                if [[ "$code" =~ ^[23][0-9][0-9]$ ]] && awk -v t="$t" 'BEGIN{exit !(t>0)}'; then
                    echo "$t $mirror" > "$tmp_dir/$i"
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget --spider --timeout=2 --tries=1 -O /dev/null "${mirror}/" >/dev/null 2>&1; then
                    echo "1.0 $mirror" > "$tmp_dir/$i"
                fi
            fi
        ) &
    done
    wait

    for i in "${!candidates[@]}"; do
        if [ -f "$tmp_dir/$i" ]; then
            read -r t m < "$tmp_dir/$i"
            printf "  %-45s %.3f 秒\n" "$m" "$t" >&2
            if awk -v t1="$t" -v t2="$fast_time" 'BEGIN{exit !(t1 < t2)}'; then
                fast_time=$t
                fast_url=$m
            fi
        fi
    done
    rm -rf "$tmp_dir"
    echo "[选择] 最快镜像: ${fast_url} (${fast_time}s)" >&2
    echo "$fast_url"
}
GNU_MIRROR=$(select_fastest_gnu_mirror)
export GNU_MIRROR

# ---------- 并行辅助 ----------
run_parallel() {
    local pids=() cmds=("$@") log_dir
    log_dir=$(mktemp -d)
    for cmd in "${cmds[@]}"; do
        ( $cmd > "$log_dir/${cmd}.log" 2>&1 ) &
        pids+=($!)
    done
    local failed=0
    for i in "${!pids[@]}"; do
        if ! wait "${pids[i]}"; then
            echo "错误: 任务 [${cmds[i]}] 编译失败！日志如下：" >&2
            cat "$log_dir/${cmds[i]}.log" >&2
            failed=1
        fi
    done
    rm -rf "$log_dir"
    [ $failed -ne 0 ] && exit 1
}

# --- 所有依赖编译函数（与 wget 构建脚本完全一致，仅安装到 INSTALL_PATH）---
mkdir -p "$INSTALL_PATH"

build_zlib() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libz.a ]; then
    rm -rf zlib-*
    ( wget -q -O- https://zlib.net/zlib-1.3.2.tar.gz || wget -q -O- https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz ) | tar xz
    cd zlib-* || exit 1
    CC=$WGET_GCC LDFLAGS="$LDFLAGS_DEPS" ./configure --64 --static --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_gmp() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libgmp.a ]; then
    rm -rf gmp-*
    wget -nv -O- ${GNU_MIRROR}/gmp/gmp-6.3.0.tar.xz | tar x --xz
    cd gmp-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_nettle() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libnettle.a ]; then
    rm -rf nettle-*
    wget -q -O- ${GNU_MIRROR}/nettle/nettle-4.0.tar.gz | tar xz
    cd nettle-* || exit 1
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" CFLAGS="-I$INSTALL_PATH/include $CFLAGS" \
    ./configure --host=$WGET_MINGW_HOST --disable-shared --enable-static --disable-documentation --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_libtasn1() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libtasn1.a ]; then
    rm -rf libtasn1-*
    wget -q -O- ${GNU_MIRROR}/libtasn1/libtasn1-4.21.0.tar.gz | tar xz
    cd libtasn1-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-doc --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_libunistring() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libunistring.a ]; then
    rm -rf libunistring-*
    wget -q -O- ${GNU_MIRROR}/libunistring/libunistring-1.4.2.tar.gz | tar xz
    cd libunistring-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_gpg_error() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpg-error⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libgpg-error.a ]; then
    rm -rf libgpg-error-*
    wget -q -O- https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.gz | tar xz
    cd libgpg-error-* || exit 1
    sed -i 's/w32_utils_init ()\./w32_utils_init ();/' src/w32-utils.c
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc
    make -j$NPROC && make install
    cd ..
  fi
}

build_libassuan() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libassuan⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libassuan.a ]; then
    rm -rf libassuan-*
    wget -q -O- https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2 | tar xj
    cd libassuan-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc --with-libgpg-error-prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_gpgme() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gpgme⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libgpgme.a ]; then
    rm -rf gpgme-*
    wget -q -O- https://gnupg.org/ftp/gcrypt/gpgme/gpgme-2.1.0.tar.bz2 | tar xj
    cd gpgme-* || exit 1
    env PYTHON="$(command -v python3 || command -v python)" LDFLAGS="$LDFLAGS_DEPS" \
    ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static \
      --with-libgpg-error-prefix="$INSTALL_PATH" --disable-gpg-test --disable-g13-test \
      --disable-gpgsm-test --disable-gpgconf-test --disable-glibtest --with-libassuan-prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_c_ares() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build c-ares⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libcares.a ]; then
    rm -rf c-ares-*
    wget -q -O- https://github.com/c-ares/c-ares/releases/download/v1.34.6/c-ares-1.34.6.tar.gz | tar xz
    cd c-ares-* || exit 1
    CPPFLAGS="-DCARES_STATICLIB=1" LDFLAGS="$LDFLAGS_DEPS" \
    ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-tests
    make -j$NPROC && make install
    cd ..
  fi
}

build_libiconv() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libiconv.a ]; then
    rm -rf libiconv-*
    wget -q -O- ${GNU_MIRROR}/libiconv/libiconv-1.19.tar.gz | tar xz
    cd libiconv-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
    make -j$NPROC && make install
    cd ..
  fi
}

build_libidn2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libidn2.a ]; then
    rm -rf libidn2-*
    wget -q -O- ${GNU_MIRROR}/libidn/libidn2-2.3.8.tar.gz | tar xz
    cd libidn2-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --enable-static --disable-shared --disable-doc --prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_libpsl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libpsl.a ]; then
    rm -rf libpsl-*
    wget -q -O- https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz | tar xz
    cd libpsl-* || exit 1
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" \
    ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static \
      --disable-gtk-doc --enable-builtin --enable-runtime=libidn2 --with-libiconv-prefix="$INSTALL_PATH"
    make -j$NPROC && make install
    cd ..
  fi
}

build_pcre2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build pcre2⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libpcre2-8.a ]; then
    rm -rf pcre2-*
    wget -q -O- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.47/pcre2-10.47.tar.gz | tar xz
    cd pcre2-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static
    make -j$NPROC && make install
    cd ..
  fi
}

build_expat() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build expat⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libexpat.a ]; then
    rm -rf expat-*
    wget -q -O- https://github.com/libexpat/libexpat/releases/download/R_2_8_1/expat-2.8.1.tar.gz | tar xz
    cd expat-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --without-docbook --without-tests
    make -j$NPROC && make install
    cd ..
  fi
}

build_libmetalink() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmetalink⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libmetalink.a ]; then
    rm -rf libmetalink-*
    wget -q -O- https://github.com/metalink-dev/libmetalink/releases/download/release-0.1.3/libmetalink-0.1.3.tar.gz | tar xz
    cd libmetalink-* || exit 1
    LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libexpat
    make -j$NPROC && make install
    cd ..
  fi
}

build_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libgnutls.a ]; then
    rm -rf gnutls-*
    wget -q -O- https://gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz | tar x --xz
    cd gnutls-* || exit 1
    LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" \
    ./configure --host=$WGET_MINGW_HOST \
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
    cd ..
  fi
}

build_openssl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build openssl⭐⭐⭐⭐⭐⭐"
  if [ ! -f "$INSTALL_PATH"/lib/libssl.a ]; then
    rm -rf openssl-*
    wget -q -O- https://github.com/openssl/openssl/releases/download/openssl-3.6.2/openssl-3.6.2.tar.gz | tar xz
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
    cd ..
  fi
}

# --- 主执行流程：按依赖顺序并行编译，最后打包 ---
mkdir -p "$INSTALL_PATH"

echo "--- STAGE 1: 基础库 (并行) ---"
stage1=(build_gpg_error build_zlib build_libunistring build_c_ares build_libiconv build_pcre2 build_expat)
if [[ "$ssl_type" == "gnutls" ]]; then
    stage1+=(build_gmp build_libtasn1)
fi
run_parallel "${stage1[@]}"

echo "--- STAGE 2: 二级依赖 (并行) ---"
stage2=(build_libidn2 build_libassuan build_libmetalink)
if [[ "$ssl_type" == "gnutls" ]]; then
    stage2+=(build_nettle)
else
    stage2+=(build_openssl)
fi
run_parallel "${stage2[@]}"

echo "--- STAGE 3: 三级依赖 (并行) ---"
run_parallel build_libpsl build_gpgme

if [[ "$ssl_type" == "gnutls" ]]; then
    echo "--- STAGE 4: 编译 GnuTLS ---"
    build_gnutls
fi

# ========== 关键步骤：打包所有依赖（模仿 wget2 deps 的做法） ==========
echo "=============================================="
echo ">>> 开始打包依赖：wget-deps.tar.zst"
# 打包 include、lib、pkgconfig 三个目录
tar -I zstd -cf wget-deps.tar.zst -C "$INSTALL_PATH" include lib pkgconfig

# 复制到当前目录，方便后续 CI 上传
cp -fv wget-deps.tar.zst "${PWD}/" || true
if [ -n "${GITHUB_WORKSPACE}" ]; then
    cp -fv wget-deps.tar.zst "${GITHUB_WORKSPACE}/"
fi

echo ">>> 打包完成！"
ls -lh wget-deps.tar.zst
