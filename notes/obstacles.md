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

---

## 2026-08-29 stage 10→30 実行 → **toolchain 取得に失敗。tigerbrew が機能不全**

`brew install gcc` の結果、以下が判明:

1. **モダン bottle が Tiger で pour できない**
   ```
   /usr/bin/install_name_tool: object: .../libgmpxx.4.dylib
     malformed object (unknown load command 11)
   ```
   archive.org の `tiger_altivec` bottle は新しい cctools/ld64 でリンクされており、
   Tiger 同梱の `install_name_tool`（cctools-576）が Mach-O を解釈できない。
   → bottle を使うには先に `cctools`/`ld64` が要るが、その bottle も pour 不可。鶏卵。

2. **ソースビルドも失敗**：`xz` の configure が
   `C compiler cannot create executables`。素の `/usr/bin/gcc-4.0` は
   `int main(){}` を問題なくコンパイル・実行できるので、brew superenv が
   注入するフラグ/シムが原因（`MacOSX10.4u SDK` 不在が濃厚）。
   superenv: `CFLAGS=-Os -w -pipe -mcpu=7450 -faltivec -mmacosx-version-min=10.4`

3. **brew 0.9.5 が `pkgutil` 不在でハードエラー**
   `Error: No such file or directory - /usr/sbin/pkgutil`（Tiger に pkgutil は無い）。
   git checkout ではないので `brew update` で直せない。

4. **`MacOSX10.4u.sdk` が無い**（Xcode 2.0）。`brew doctor` も「Xcode 2.5 に上げろ」。

5. **passwordless sudo 不可**（かつ Tiger の sudo は `-n` 非対応）。
   → root 作業はユーザーが対話でパスワード入力する必要。SSH 自動化不可。

### 結論
現状の tigerbrew では **何もビルドできない**。Path C を続けるなら前提:
- **[必須] Xcode 2.5 を入れる**（→ `MacOSX10.4u.sdk` + gcc 4.0.1/5370）。
  `xcode25_8m1910_developerdvd.dmg`（Apple ID / 各所アーカイブ、約1GB）を
  ユーザーが手動ダウンロード＆インストール（要 admin パスワード）。
- その後どれか:
  - **A. tigerbrew 再ブート**：現行 mistydemeo/tigerbrew を git clone、
    `brew install cctools ld64` をソースから → 以後 bottle が pour 可能に → `brew install gcc`。
  - **B. MacPorts (legacy 2.9.x/2.7)**：全部ソースビルド。bottle 問題なし。要 SDK。
  - **C. toolchain 手組み**：gcc-4.0 → cctools-port → GCC 14 ソースビルド（G4 で数日〜）
    ＋ 依存も全部手ビルド。パッケージマネージャ無し。

### 別案（再掲・今回の証跡で補強）
今日ハマった壁（SDK 無し／brew 死亡／cctools 古すぎ／pkgutil 無し／sudo -n 無し）は
**すべて Tiger 固有の税**。Leopard 10.5.8 なら macos-powerpc / leopard-ports が
現役で bottle も通り `python312` はほぼ解決済み。iBook G4 1.2GHz は Leopard 対応。
→ 予備パーティションに Leopard を入れて dual-boot し、そちらで 3.12 を扱うのが
実務的には最短。要ユーザー判断。
