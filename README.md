# apython3 — Python 3.12 for PowerPC (iBook G4 / Mac OS X 10.4.11 Tiger)

古い PowerPC Mac でモダンな Python Web 開発（Flask / Django）をするために、
**Tiger 10.4.11 上で CPython 3.12 をネイティブビルド**する。

## ターゲット実機

| | |
|---|---|
| 機種 | iBook G4 (PowerBook6,5) / G4 7450 **1.2GHz 単コア** / RAM 1.25GB |
| OS | Mac OS X **10.4.11 Tiger**（Darwin 8.11、ビッグエンディアン、32bit ppc） |
| Xcode | 2.0（`MacOSX10.4u SDK` は未導入。ネイティブ = `/usr/include` 直参照） |
| 既存 | tigerbrew インストール済み（Formula ツリー展開済／git checkout ではない） |
| 接続 | `ssh ibook`（M2 mac から） |

## 戦略

- **クロスではなくネイティブ**。出来上がるのはどちらでも本物の PPC バイナリだが、
  CPython のビルド系はネイティブ前提で、Darwin-PPC はメンテされたクロス標的ではない。
  「机の横で数日放置」できるのでネイティブで押す。
- **toolchain は自力ビルドしない**。tigerbrew の `gcc` formula が 14.2.0 で
  `:tiger_altivec` の bottle（プリビルド）を持つ。C11/C17 は問題なし。
- C 依存も tigerbrew：`openssl3`(3.5.x) / `libffi`(3.4.7) / `sqlite` / `xz` /
  `readline` / `gdbm` / `zlib`。
- CPython は python.org のソースから。`.tgz` を使う（GNU tar 1.14 は `.xz` 不可）。
  PGO/LTO はオフ。`patches/*.patch` を当てて回す。

## 実行方法（M2 側から）

```sh
./run.sh 00_recon                 # 環境確認
./run.sh 10_brew_bootstrap        # 補助ツール
./run.sh 20_toolchain             # gcc 14（bottle）
./run.sh 30_deps                  # C ライブラリ群
./run.sh 40_build_cpython         # ★本体ビルド（1〜3時間 + 反復）
./run.sh 45_smoke                 # ssl / ctypes / sqlite / TLS 実接続
./run.sh 50_pip                   # pip 最新化 + 証明書
./run.sh 60_web                   # flask / django 疎通

./scripts/pull_logs.sh            # iBook のログを logs/ に回収
```

`run.sh` は rsync 後、iBook 側で `nohup` 実行するので SSH が切れても継続する。

## 想定される詰まりどころ

`notes/obstacles.md` に逐次記録。要点：

- **ビッグエンディアン + libffi**：`_ctypes` がビルドできても実行時に落ちる可能性。
  `45_smoke` の qsort コールバックで早期検知する。
- **Tiger に無い libc**：`clock_gettime`/`getentropy`/`utimensat`/`preadv` など →
  CPython 側フォールバックで大半は通る。`_posixsubprocess` は要注意（過去に ppc で報告あり）。
- **`_decimal`**：バンドル libmpdec の設定が PPC32-BE で `universal` に落ちるか。
- **`cryptography`（Rust）**：PPC Tiger では実質不可。Django/Flask コアは不要。
  必要になったら `cryptography<3.4`（CFFI 版）を検討。
- **証明書**：`ca-certificates` formula が無いので `curl.se/ca/cacert.pem` を取得して
  `$PREFIX/etc/cacert.pem` に置き、`SSL_CERT_FILE` / pip global.cert に設定。

## レイアウト

```
env.sh              共有変数（PY_VERSION, PREFIX=$HOME/apython312, CC=gcc-14 ...）
run.sh              M2→iBook ランナー（rsync + nohup + tail）
scripts/            00_recon .. 60_web、pull_logs
patches/            CPython ソースへの *.patch（-p1）
notes/obstacles.md  詰まりと対処の記録
logs/               ビルドログ（iBook から回収）
```
