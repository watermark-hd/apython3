# 詰まりと対処ログ

新しい問題は上に追記。日付は JST。

---

## 2026-08-29 (3) toolchain 環境の修復 — 完了

真因: **この Tiger は `/usr/include` がほぼ空（2 files）**、`/usr/lib` も
`crt1.o`/`gcrt1.o`/`dylib1.o`/`bundle1.o`/`libSystemStubs.a` 等が欠落。
2022年頃に部分再インストールされた形跡（libSystem 等の日付が Jan 2022）。
→ `-isysroot` 無しの素リンクが `ld: can't locate file for: -lcrt1.o` で全滅し、
  brew のソースビルドが全部これで死んでいた。

対処（`07_fixup_usrlib.sh`、sudo bash で実行）:
- `/usr/include` を 10.4u SDK から pax で丸ごと復元（2 → 2516 files）
- `/usr/lib` に SDK 由来の `.o/.a/.dylib` で欠落分を補完（BLAS/LAPACK も来た）
- `CoreFoundation`/`CoreServices`/`SystemConfiguration`/`Security`/`ApplicationServices`
  のフレームワークヘッダを実フレームワークへ復元
- **`MACOSX_DEPLOYMENT_TARGET=10.4` 必須**：未設定だと gcc-4.0 が 10.1 を既定にして
  `-undefined dynamic_lookup`（bundle=Python C拡張）が弾かれる

結果: exe / dylib / **bundle** が bare gcc でリンク OK。
`brew install mpfr` がプレーン環境（superenv 迂回）で正常にコンパイル継続。

補足:
- superenv の `Library/ENV/4.3/cc` シムは shebang が `/System/Library/Frameworks/
  Ruby.framework/...`（Leopard+ パス、Tiger に無い）で実行不能。
  → brew は素の env で動くので実害なし。念のため 20/30 は `--env=std` 指定に。
- iBook の長時間ジョブを foreground ssh で回すと切断時に SIGHUP 死。
  必ず iBook 側 `nohup`（mpfr が一度これで make 完了直後に殺された）。
- M2→iBook の `rsync` がしばしば 2分でタイムアウト → `scp` で個別転送に切替。

### 進行中
`20_toolchain`（旧版）が gcc 依存を順にビルド中: gmp(bottle済) → mpfr → libmpc →
isl → **gcc 14.2.0 bottle pour**。次の関門は「gcc bottle が pour できるか
（cctools-622.9 の install_name_tool で足りるか）」と「gcc-14 が C11 を通すか」。

---

## 2026-08-29 (2) Xcode 2.5 導入 → tigerbrew 復活 → **bottle pour 成功**

- Xcode 2.5 の DMG（archive.org, md5 一致）を iBook に取得。
- CLI `installer` は古い形式 pkg のスクリプトでコケる（`DeveloperTools.pkg` が
  "The upgrade failed"）→ **`06_xcode25_extract.sh` で pax 直展開**に切替：
  - `MacOSX10.4.Universal.pkg` → `/Developer`（SDK は `./SDKs/...` 起点なので注意）
  - `DeveloperToolsCLI.pkg` / `gcc4.0.pkg` / `DevToolsSystem.pkg` → `/`
  - 結果: `MacOSX10.4u.sdk` 導入 / `gcc-4.0.1 build 5370` / `cctools-622.9~2`
- `-isysroot /Developer/SDKs/MacOSX10.4u.sdk` 付きの素コンパイル・リンクが通ることを確認。
- `11_rebootstrap_brew.sh` で現行 mistydemeo/tigerbrew を `/usr/local` に上書き。
  - ハマり: Tiger の GNU tar 1.14 は `--strip-components` 非対応 → 素展開＋単一トップ処理。
  - ハマり: Tiger の `head` は `-c` 非対応 → gzip 整合性チェックは `gzip -t` に変更。
  - git ビルドは重いので既定スキップ（`INSTALL_GIT=1` で有効化）。
- **`brew install --force-bottle xz` が pour 成功**（`xz 5.8.1` 動作）。
  → 再ブート済みコード（pkgutil ハードエラー解消）＋ 新 cctools-622.9 の
    `install_name_tool` で bottle の Mach-O を扱えるようになった。
  → **`12_cctools`（cctools ソースビルド）は不要になった可能性大**。

### 次アクション（実行中）
- `10_brew_bootstrap`（gpatch/pkg-config/xz）→ `20_toolchain`（`brew install gcc` = 14.2.0 bottle）
- その後 `30_deps` → `40_build_cpython`

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

## 2026-08-29 (4) GCC 14.2.0 導入成功 — toolchain 完成

- `brew install --force-bottle gcc` で GCC 14.2.0 の tiger_altivec bottle が pour 成功
  （依存 mpfr/libmpc/isl/cctools/ld64/gmp/zlib/gettext/texinfo/perl は先に導入済み）。
- `--force-bottle` 必須：外すと brew がソースビルドを試み「gcc cannot be built with
  any available compilers（GCC 4.0.1 では GCC 14 は無理）」で停止する。
- 検証: `-std=c11 -Werror` で `_Static_assert` / `_Generic` / `<stdatomic.h>` /
  無名 struct・union OK。`endian=BE` 確認。C++17（make_unique/vector/string）OK。
  bundle（`-bundle -undefined dynamic_lookup`、Python C 拡張形式）OK。
- 既知の無害な傷: 毎リンクで `ld: warning: ... -mlong-branch ... /usr/lib/crt1.o`。
  SDK 由来の crt1.o が旧フラグでビルドされているだけ。必要なら LDFLAGS に `-Wl,-w`。
- Tiger の `ps -p <pid>` は存在しない PID でも exit 0 になることがある（監視スクリプト誤検出）。
  → `ps -p PID -o state=` が空かどうかで判定する。
- `pgrep` は Tiger に無い。

### 進行中
`30_deps`（openssl3 / libffi / sqlite / readline / gdbm）→ その後 `40_build_cpython`。
