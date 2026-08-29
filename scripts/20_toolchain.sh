#!/bin/bash
# モダン GCC を入れる。cctools/ld64（scripts/12）が入っていれば
# gcc 14.2.0 の :tiger_altivec bottle が pour できるはず。ダメならソースビルド。
. "$(dirname "$0")/../env.sh"

if [ ! -d /Developer/SDKs/MacOSX10.4u.sdk ]; then
  echo "!! 10.4u SDK が無い。先に Xcode 2.5。"; exit 1
fi

# このシステムでは superenv の cc シムが壊れている（Ruby.framework shebang）ため
# 常に --env=std を使う。bottle は env 非依存、source dep のみ std env でビルドされる。
ENVSTD="--env=std"

if brew_installed gcc && [ -x "$CC" ]; then
  echo "既にインストール済み:"
  "$CC" --version | head -1
else
  echo "==== bottle 無し依存を先に std env でソースビルド（mpfr / libmpc / isl） ===="
  for d in mpfr libmpc isl; do
    brew_installed "$d" && { echo "  already: $d"; continue; }
    echo "  -- $d --"
    "$BREW" install $ENVSTD --build-from-source "$d" 2>&1 | tail -15
    brew_installed "$d" || { echo "!! $d ビルド失敗"; exit 1; }
  done
  echo "==== brew install gcc（gmp/mpfr/libmpc/isl/cctools/ld64 は導入済み → gcc bottle を pour） ===="
  "$BREW" install $ENVSTD --force-bottle gcc 2>"$BREW" install $ENVSTD gcc 2>&11 | tail -60
fi

echo
if [ ! -x "$CC" ]; then
  echo "!! $CC が生成されなかった。logs を確認すること。"
  exit 1
fi

echo "==== 検証: gcc-14 / g++-14 ===="
"$CC" --version | head -1
"$CXX" --version | head -1

echo "==== 検証: C11 コンパイル ===="
cat > "$WORK/c11test.c" <<'EOF'
#include <stdio.h>
#include <stdatomic.h>
_Static_assert(sizeof(int) == 4, "int must be 32-bit");
int main(void) {
    _Atomic int a = 0;
    atomic_fetch_add(&a, 41);
    int b = _Generic(1, int: 1, default: 0);
    printf("c11 ok a=%d endian=%s\n", a + b,
           (*(char*)&(int){1}) ? "little" : "big");
    return 0;
}
EOF
"$CC" -std=c11 -O2 "$WORK/c11test.c" -o "$WORK/c11test" || { echo "!! C11 コンパイル失敗"; exit 1; }
"$WORK/c11test" || { echo "!! C11 実行失敗"; exit 1; }

echo "==== 検証: C++11 ===="
cat > "$WORK/cxx11test.cpp" <<'EOF'
#include <memory>
#include <cstdio>
int main(){ auto p = std::make_shared<int>(42); std::printf("cxx11 ok %d\n", *p); }
EOF
"$CXX" -std=c++11 -O2 "$WORK/cxx11test.cpp" -o "$WORK/cxx11test" || { echo "!! C++11 失敗"; exit 1; }
"$WORK/cxx11test" || { echo "!! C++11 実行失敗"; exit 1; }

echo
echo "toolchain OK"
