#!/bin/bash
set -eo pipefail

# ---------- 配置 ----------
SSL_TYPE="${SSL_TYPE:-gnutls}"
DEPS_URL="${DEPS_URL:-https://github.com/rzhy1/wget-windows/releases/download/wget-deps/wget-deps-${SSL_TYPE}.tar.zst}"
INSTALL_PATH="${INSTALL_PATH:-$HOME/wget-deps}"
WGET_VERSION="1.25.0"
MINGW_HOST="x86_64-w64-mingw32"
NPROC=$(nproc 2>/dev/null || echo 4)

# 编译优化参数
CFLAGS="-march=tigerlake -mtune=tigerlake -O2 -pipe -ffunction-sections -fdata-sections -fvisibility=hidden -fno-stack-protector -fomit-frame-pointer -DNDEBUG  -flto=$NPROC"
LDFLAGS_DEPS="-static -static-libgcc -Wl,--gc-sections -Wl,-S  -flto=$NPROC"
LTO_FLAGS="-flto=$NPROC"

# ---------- 快速镜像测速 ----------
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
    echo "[测速] GNU 镜像..." >&2
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

# ---------- 下载并解压预编译依赖 ----------
echo ">>> 下载预编译依赖包: $DEPS_URL"
wget -nv -O deps.tar.zst "$DEPS_URL"
echo ">>> 解压依赖到 $INSTALL_PATH"
mkdir -p "$INSTALL_PATH"
tar -I zstd -xf deps.tar.zst -C "$INSTALL_PATH"
rm deps.tar.zst

# 设置 pkg-config 路径
export PKG_CONFIG_PATH="$INSTALL_PATH/lib/pkgconfig"

# ---------- 编译 wget ----------
echo ">>> 下载 wget 源码"
wget -nv -O- "${GNU_MIRROR}/wget/wget-${WGET_VERSION}.tar.gz" | tar xz
cd wget-${WGET_VERSION} || exit 1

# 针对 GnuTLS 版本的 Nettle 4.0 兼容修复
if [[ "$SSL_TYPE" == "gnutls" ]]; then
    echo "修复 http-ntlm.c 以兼容 Nettle 4.0..."
    sed -i 's/nettle_md4_digest(&MD4, MD4_DIGEST_SIZE, ntbuffer);/{\n      uint8_t digest[MD4_DIGEST_SIZE];\n      nettle_md4_digest(\&MD4, digest);\n      memcpy(ntbuffer, digest, MD4_DIGEST_SIZE);\n    }/' src/http-ntlm.c
fi

# 修复 gnulib 兼容性（通用）
sed -i 's/__gl_error_call (error,/__gl_error_call ((error),/' lib/error.in.h
sed -i '/#include <stdio.h>/a extern void error (int, int, const char *, ...);' lib/error.in.h

# 编译选项
WGET_CFLAGS="-I$INSTALL_PATH/include -DNDEBUG -DF_DUPFD=0 -DF_GETFD=1 -DF_SETFD=2"
WGET_LDFLAGS="-L$INSTALL_PATH/lib $LDFLAGS_DEPS $LTO_FLAGS -Wl,-u,strndup"

if [[ "$SSL_TYPE" == "gnutls" ]]; then
    WGET_CFLAGS+=" -DGNUTLS_INTERNAL_BUILD=1"
    WGET_LIBS="-lgnutls -lhogweed -lnettle -lgmp -ltasn1 -lmingwex"
    SSL_OPT="--with-ssl=gnutls"
else
    WGET_LIBS="-lssl -lcrypto"
    SSL_OPT="--with-ssl=openssl"
fi

WGET_CFLAGS+=" -DCARES_STATICLIB=1 -DPCRE2_STATIC=1"
WGET_LIBS+=" -lmetalink -lexpat -lcares -lpcre2-8 -lpsl -lidn2 -lunistring -liconv -lgpgme -lassuan -lgpg-error -lz -lws2_32 -liphlpapi -lcrypt32 -lbcrypt -lncrypt -lwinpthread"

echo ">>> 配置 wget ($SSL_TYPE)"
./configure --host=$MINGW_HOST \
    --prefix="$INSTALL_PATH" \
    --disable-debug \
    --enable-iri \
    --enable-pcre2 \
    $SSL_OPT \
    --with-included-libunistring=no \
    --with-cares \
    --with-libpsl \
    --with-metalink \
    --with-gpgme-prefix="$INSTALL_PATH" \
    CFLAGS="$WGET_CFLAGS" \
    LDFLAGS="$WGET_LDFLAGS" \
    LIBS="$WGET_LIBS"

echo ">>> 编译 wget"
make -j$NPROC

# 安装并收集产物
mkdir -p "$HOME/output"
cp src/wget.exe "$HOME/output/wget-${SSL_TYPE}-x64.exe"
x86_64-w64-mingw32-strip --strip-all "$HOME/output/wget-${SSL_TYPE}-x64.exe"

echo ">>> 编译完成！"
ls -lh "$HOME/output/wget-${SSL_TYPE}-x64.exe"
