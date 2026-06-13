#!/bin/bash
set -o pipefail
set -e

# --- 全局变量 ---
export INSTALL_PATH="$HOME/wget-deps-install"
export PKG_CONFIG_PATH="$INSTALL_PATH/lib/pkgconfig"
export WGET_GCC=x86_64-w64-mingw32-gcc
export WGET_MINGW_HOST=x86_64-w64-mingw32
export MINGW_STRIP_TOOL=x86_64-w64-mingw32-strip

if command -v nproc >/dev/null 2>&1; then
    export NPROC=$(nproc)
else
    export NPROC=${NUMBER_OF_PROCESSORS:-4}
fi

export CFLAGS="-march=tigerlake -mtune=tigerlake -O2 -pipe -ffunction-sections -fdata-sections -fvisibility=hidden -fno-stack-protector -fomit-frame-pointer -DNDEBUG -flto=$NPROC"
export CXXFLAGS="$CFLAGS"
export LDFLAGS_DEPS="-static -static-libgcc -Wl,--gc-sections -Wl,-S -flto=$NPROC"
export LTO_FLAGS="-flto=$NPROC"

ssl_type="${SSL_TYPE:-gnutls}"
echo ">>> 打包目标: SSL_TYPE=$ssl_type"
x86_64-w64-mingw32-gcc --version

# ---- 带校验的下载函数 ----
download() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0
    while [ $retry -lt $max_retries ]; do
        echo "下载: $url → $output (尝试 $((retry+1)))" >&2
        if wget -nv -O "$output" "$url"; then
            if [ -f "$output" ]; then
                local size
                size=$(stat -c%s "$output" 2>/dev/null || echo 0)
                if [ "$size" -gt 1024 ]; then
                    return 0
                else
                    echo "文件过小 (${size} bytes)，可能损坏，重试..." >&2
                fi
            fi
        fi
        retry=$((retry+1))
        sleep 5
    done
    echo "错误: 下载失败 $url" >&2
    return 1
}

# ---- 镜像测速 ----
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

# ---- 并行辅助 ----
run_parallel() {
    local pids=() cmds=("$@") log_dir
    log_dir=$(mktemp -d)
    echo "并行启动任务: ${cmds[*]}" >&2
    for cmd in "${cmds[@]}"; do
        ( $cmd > "$log_dir/${cmd}.log" 2>&1 ) &
        pids+=($!)
    done
    local failed=0
    for i in "${!pids[@]}"; do
        if ! wait "${pids[i]}"; then
            echo "=============================================" >&2
            echo "错误: 任务 [${cmds[i]}] 编译失败！日志如下：" >&2
            cat "$log_dir/${cmds[i]}.log" >&2
            echo "=============================================" >&2
            failed=1
        fi
    done
    rm -rf "$log_dir"
    if [ $failed -ne 0 ]; then
        exit 1
    fi
}

# ---- 所有构建函数（全部先下载到文件再解压） ----
mkdir -p "$INSTALL_PATH"

build_zlib() {
  echo ">>> 构建 zlib"
  if [ -f "$INSTALL_PATH/lib/libz.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf zlib-*
  local tarball="zlib.tar.gz"
  download "https://zlib.net/zlib-1.3.2.tar.gz" "$tarball" || download "https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd zlib-* || exit 1
  CC=$WGET_GCC LDFLAGS="$LDFLAGS_DEPS" ./configure --64 --static --prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_gmp() {
  echo ">>> 构建 gmp"
  if [ -f "$INSTALL_PATH/lib/libgmp.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf gmp-*
  local tarball="gmp.tar.xz"
  download "${GNU_MIRROR}/gmp/gmp-6.3.0.tar.xz" "$tarball" || exit 1
  tar xf "$tarball" || exit 1
  rm -f "$tarball"
  cd gmp-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_nettle() {
  echo ">>> 构建 nettle"
  if [ -f "$INSTALL_PATH/lib/libnettle.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf nettle-*
  local tarball="nettle.tar.gz"
  download "${GNU_MIRROR}/nettle/nettle-4.0.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd nettle-* || exit 1
  LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" CFLAGS="-I$INSTALL_PATH/include $CFLAGS" \
  ./configure --host=$WGET_MINGW_HOST --disable-shared --enable-static --disable-documentation --prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_libtasn1() {
  echo ">>> 构建 libtasn1"
  if [ -f "$INSTALL_PATH/lib/libtasn1.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf libtasn1-*
  local tarball="libtasn1.tar.gz"
  download "${GNU_MIRROR}/libtasn1/libtasn1-4.21.0.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd libtasn1-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --disable-doc --prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_libunistring() {
  echo ">>> 构建 libunistring"
  if [ -f "$INSTALL_PATH/lib/libunistring.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf libunistring-*
  local tarball="libunistring.tar.gz"
  download "${GNU_MIRROR}/libunistring/libunistring-1.4.2.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd libunistring-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_gpg_error() {
  echo ">>> 构建 libgpg-error"
  if [ -f "$INSTALL_PATH/lib/libgpg-error.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf libgpg-error-*
  local tarball="libgpg-error.tar.gz"
  download "https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.61.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd libgpg-error-* || exit 1
  sed -i 's/w32_utils_init ()\./w32_utils_init ();/' src/w32-utils.c
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc --disable-nls || exit 1
  make -j$NPROC && make install
  cd ..
}

build_libassuan() {
  echo ">>> 构建 libassuan"
  if [ -f "$INSTALL_PATH/lib/libassuan.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf libassuan-*
  local tarball="libassuan.tar.bz2"
  download "https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2" "$tarball" || exit 1
  tar xf "$tarball" || exit 1
  rm -f "$tarball"
  cd libassuan-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-doc --with-libgpg-error-prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_gpgme() {
  echo ">>> 构建 gpgme"
  if [ -f "$INSTALL_PATH/lib/libgpgme.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf gpgme-*
  local tarball="gpgme.tar.bz2"
  download "https://gnupg.org/ftp/gcrypt/gpgme/gpgme-2.1.0.tar.bz2" "$tarball" || exit 1
  tar xf "$tarball" || exit 1
  rm -f "$tarball"
  cd gpgme-* || exit 1
  env PYTHON="$(command -v python3 || command -v python)" LDFLAGS="$LDFLAGS_DEPS" \
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static \
    --with-libgpg-error-prefix="$INSTALL_PATH" --disable-gpg-test --disable-g13-test \
    --disable-gpgsm-test --disable-gpgconf-test --disable-glibtest --with-libassuan-prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_c_ares() {
  echo ">>> 构建 c-ares"
  if [ -f "$INSTALL_PATH/lib/libcares.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf c-ares-*
  local tarball="cares.tar.gz"
  download "https://github.com/c-ares/c-ares/releases/download/v1.34.6/c-ares-1.34.6.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd c-ares-* || exit 1
  CPPFLAGS="-DCARES_STATICLIB=1" LDFLAGS="$LDFLAGS_DEPS" \
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --disable-tests || exit 1
  make -j$NPROC && make install
  cd ..
}

build_libiconv() {
  echo ">>> 构建 libiconv"
  if [ -f "$INSTALL_PATH/lib/libiconv.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf libiconv-*
  local tarball="libiconv.tar.gz"
  download "${GNU_MIRROR}/libiconv/libiconv-1.19.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd libiconv-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static || exit 1
  make -j$NPROC && make install
  cd ..
}

build_libidn2() {
  echo ">>> 构建 libidn2"
  if [ -f "$INSTALL_PATH/lib/libidn2.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf libidn2-*
  local tarball="libidn2.tar.gz"
  download "${GNU_MIRROR}/libidn/libidn2-2.3.8.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd libidn2-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --enable-static --disable-shared --disable-doc --prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_libpsl() {
  echo ">>> 构建 libpsl"
  if [ -f "$INSTALL_PATH/lib/libpsl.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf libpsl-*
  local tarball="libpsl.tar.gz"
  download "https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd libpsl-* || exit 1
  LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS" \
  ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static \
    --disable-gtk-doc --enable-builtin --enable-runtime=libidn2 --with-libiconv-prefix="$INSTALL_PATH" || exit 1
  make -j$NPROC && make install
  cd ..
}

build_pcre2() {
  echo ">>> 构建 pcre2"
  if [ -f "$INSTALL_PATH/lib/libpcre2-8.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf pcre2-*
  local tarball="pcre2.tar.gz"
  download "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.47/pcre2-10.47.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd pcre2-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static || exit 1
  make -j$NPROC && make install
  cd ..
}

build_expat() {
  echo ">>> 构建 expat"
  if [ -f "$INSTALL_PATH/lib/libexpat.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf expat-*
  local tarball="expat.tar.gz"
  download "https://github.com/libexpat/libexpat/releases/download/R_2_8_1/expat-2.8.1.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd expat-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --without-docbook --without-tests || exit 1
  make -j$NPROC && make install
  cd ..
}

build_libmetalink() {
  echo ">>> 构建 libmetalink"
  if [ -f "$INSTALL_PATH/lib/libmetalink.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf libmetalink-*
  local tarball="libmetalink.tar.gz"
  download "https://github.com/metalink-dev/libmetalink/releases/download/release-0.1.3/libmetalink-0.1.3.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
  cd libmetalink-* || exit 1
  LDFLAGS="$LDFLAGS_DEPS" ./configure --host=$WGET_MINGW_HOST --disable-shared --prefix="$INSTALL_PATH" --enable-static --with-libexpat || exit 1
  make -j$NPROC && make install
  cd ..
}

build_gnutls() {
  echo ">>> 构建 gnutls"
  if [ -f "$INSTALL_PATH/lib/libgnutls.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf gnutls-*
  local tarball="gnutls.tar.xz"
  download "https://gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz" "$tarball" || exit 1
  tar xf "$tarball" || exit 1
  rm -f "$tarball"
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
    --disable-seccomp-tests || exit 1
  make -j$NPROC && make install
  cd ..
}

build_openssl() {
  echo ">>> 构建 openssl"
  if [ -f "$INSTALL_PATH/lib/libssl.a" ]; then return 0; fi
  cd "$INSTALL_PATH" || exit 1
  rm -rf openssl-*
  local tarball="openssl.tar.gz"
  download "https://github.com/openssl/openssl/releases/download/openssl-3.6.2/openssl-3.6.2.tar.gz" "$tarball" || exit 1
  tar xzf "$tarball" || exit 1
  rm -f "$tarball"
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
    "${DISABLED_FEATURES[@]}" || exit 1
  make -j$NPROC && make install_sw
  cd ..
}

# ========== 主流程 ==========
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

# 打包前检查
if [ ! -d "$INSTALL_PATH/include" ] || [ ! -d "$INSTALL_PATH/lib" ]; then
    echo "错误: 缺少 include 或 lib 目录，构建可能不完整" >&2
    exit 1
fi

echo ">>> 开始打包依赖：wget-deps.tar.zst"
tar -I zstd -cf wget-deps.tar.zst -C "$INSTALL_PATH" include lib
mv wget-deps.tar.zst "wget-deps-${ssl_type}.tar.zst"
echo ">>> 打包完成！"
ls -lh "wget-deps-${ssl_type}.tar.zst"
