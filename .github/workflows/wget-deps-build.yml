name: Build wget deps

on:
  workflow_dispatch:
  push:
    branches: [ master ]
    paths:
      - '.github/workflows/wget-deps-build.yml'
      - 'build_wget_deps.sh'
  schedule:
    - cron: "0 0 * * 0"

jobs:
  build-deps:
    strategy:
      matrix:
        ssl: [gnutls, openssl]
      fail-fast: false
    runs-on: ubuntu-24.04
    name: Build wget deps (${{ matrix.ssl }})
    env:
      SSL_TYPE: ${{ matrix.ssl }}
    steps:
      - uses: actions/checkout@v6

      - name: 安装依赖
        run: |
          set -e
          sudo apt-get update
          sudo apt-get install -y mingw-w64 mingw-w64-tools gcc
          # 增加 libtool, autopoint, texinfo 等常见缺失工具
          sudo apt-get install -y make m4 pkg-config automake autoconf libtool autopoint gettext autoconf-archive gperf texinfo python3-dev python3-venv zstd
          python3 -m venv myenv
          source myenv/bin/activate
          pip3 install setuptools
          pip3 install --upgrade setuptools
          x86_64-w64-mingw32-gcc --version || { echo "编译器检查失败"; exit 1; }

      - name: 构建依赖包 (${{ matrix.ssl }})
        id: build_deps
        run: |
          set -eo pipefail
          chmod +x build_wget_deps.sh
          echo "::group::构建日志"
          ./build_wget_deps.sh 2>&1 | tee build.log
          echo "::endgroup::"
          if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo "::error::构建失败"
            exit 1
          fi

      - name: 收集失败日志
        if: failure()
        run: |
          echo "::group::收集诊断信息"
          mkdir -p failure_logs
          [ -f build.log ] && mv build.log failure_logs/
          uname -a > failure_logs/system_info.txt
          dpkg -l >> failure_logs/system_info.txt
          env > failure_logs/environment.txt
          x86_64-w64-mingw32-gcc -v 2> failure_logs/compiler_info.txt
          ls -laR > failure_logs/directory_structure.txt
          echo "::endgroup::"

      - name: 上传失败日志
        if: failure()
        uses: actions/upload-artifact@v7
        with:
          name: 失败日志-deps-${{ matrix.ssl }}-${{ github.run_id }}
          path: failure_logs/
          retention-days: 7

      - name: 上传依赖包
        if: success()
        uses: actions/upload-artifact@v7
        with:
          name: wget-deps-${{ matrix.ssl }}
          path: wget-deps-${{ matrix.ssl }}.tar.zst

      - name: 发布依赖包
        if: success()
        uses: ncipollo/release-action@v1
        with:
          tag: wget-deps-${{ matrix.ssl }}
          allowUpdates: true
          artifacts: "wget-deps-${{ matrix.ssl }}.tar.zst"
          body: |
            ## wget 预编译依赖包（${{ matrix.ssl }} 路线）
            - 包含所有静态库、头文件和 pkgconfig
            - 适用于交叉编译 wget (MinGW-w64)
            - 自动生成，每周更新
          token: ${{ secrets.GITHUB_TOKEN }}
