# 詰まりと対処ログ

新しい問題は上に追記。日付は JST。

---

## 2026-08-29 環境調査（完了）

- iBook G4 は **Tiger 10.4.11**（当初 Leopard 想定だったが実機は Tiger）。
- システムコンパイラは Apple GCC 4.0.0 build 4061 のみ。C11 不可。
- tigerbrew はインストール済みだが `0.9.5 (no git repository)`。
  ただし `/usr/local/Library/Formula/` は完全に展開済み → `brew install` は可能。
- `brew` は `/usr/local/bin/brew`（非ログインシェルの PATH には無い。env.sh で対処）。
- portable-curl 7.58 / OpenSSL 1.0.2l で pypi / python.org / archive.org へ TLS OK。
- **`gcc` formula = 14.2.0、`:tiger_altivec` bottle あり** → toolchain 自力ビルド回避。
- `openssl3`=3.5.7 / `openssl`=1.1.1w / `libffi`=3.4.7 / sqlite / readline / ncurses /
  xz / pkg-config / gpatch / wget / git の formula あり。
- `ca-certificates` formula は **無い** → cacert.pem を curl.se から取得する方針。
- tigerbrew の `python3` は 3.10.20 → 3.12 は自前ビルド確定。
- インストール先は `sudo` 回避のため `$HOME/apython312`。

### 次アクション
1. `10_brew_bootstrap` → `20_toolchain`（gcc bottle 取得）
2. `30_deps`
3. `40_build_cpython`（ここから反復）
