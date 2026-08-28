# apython3 共有環境設定 — 各スクリプトが先頭で `. "$(dirname "$0")/../env.sh"` する
# iBook G4 (PowerBook6,5) / Mac OS X 10.4.11 Tiger / GCC14(tigerbrew) 上で
# CPython 3.12 をネイティブビルドするための変数群。

set -eu

# --- ターゲットにするCPythonのバージョン（最新の 3.12.x に随時更新） ---
: "${PY_VERSION:=3.12.11}"

# --- インストール先（sudo不要。$HOME配下に隔離。tigerbrewの /usr/local とは分離） ---
: "${PREFIX:=$HOME/apython312}"

# --- tigerbrew ---
BREW_PREFIX=/usr/local
PCURL="$BREW_PREFIX/Library/Homebrew/vendor/portable-curl/current/bin/curl"
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

# --- コンパイラ（tigerbrew の gcc 14 bottle） ---
# gcc formula は gcc-14 / g++-14 を /usr/local/bin に置く
: "${CC:=$BREW_PREFIX/bin/gcc-14}"
: "${CXX:=$BREW_PREFIX/bin/g++-14}"
export CC CXX

# Tiger 向けデプロイメントターゲット
export MACOSX_DEPLOYMENT_TARGET=10.4

# 作業ディレクトリ（ソース展開・ビルド）
: "${WORK:=$HOME/apython3/work}"
: "${DL:=$HOME/apython3/dl}"

# 依存の prefix を解決するヘルパ（brew --prefix は 0.9.5 だと遅いので opt を直接見る）
brew_opt() { echo "$BREW_PREFIX/opt/$1"; }

# formula がインストール済みか（brew 0.9.5 の `brew list --versions X` は
# 未インストールでも exit 0 で空を返すので、Cellar の実体で判定する）
brew_installed() { [ -d "$BREW_PREFIX/Cellar/$1" ] && [ -n "$(ls -A "$BREW_PREFIX/Cellar/$1" 2>/dev/null)" ]; }

BREW="$BREW_PREFIX/bin/brew"

mkdir -p "$WORK" "$DL"

echo "[env] PY_VERSION=$PY_VERSION PREFIX=$PREFIX CC=$CC"
