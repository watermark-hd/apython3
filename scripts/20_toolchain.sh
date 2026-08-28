#!/bin/bash
# モダン GCC を入れる。tigerbrew の gcc formula は 14.2.0 で
# :tiger_altivec の bottle（プリビルド）があるため、自力ビルドは基本不要。
. "$(dirname "$0")/../env.sh"

BREW="$BREW_PREFIX/bin/brew"

if [ -x "$CC" ]; then
  echo "既に存在: $CC"
  "$CC" --version | head -1
else
  echo "==== brew install gcc（bottle。依存: gmp mpfr libmpc isl zlib cctools ld64） ===="
  # --force-bottle: 何があってもソースビルドに落とさない（G4 では致命的に遅い）
  "$BREW" install --force-bottle gcc 2>&1 | tail -60 \
    || "$BREW" install gcc 2>&1 | tail -80
fi

echo
echo "==== 検証: gcc-14 が動くか ===="
"$CC" --version | head -1
"$CXX" --version | head -1

echo "==== 検証: C11 コンパイル ===="
cat > "$WORK/c11test.c" <<'EOF'
#include <stdio.h>
#include <stdatomic.h>
#include <stdalign.h>
_Static_assert(sizeof(int) == 4, "int must be 32-bit");
int main(void) {
    _Atomic int a = 0;
    atomic_fetch_add(&a, 41);
    int b = _Generic(1, int: 1, default: 0);
    printf("c11 ok a=%d b=%d endian=%s\n", a + b,
           b, (*(char*)&(int){1}) ? "little" : "big");
    return 0;
}
EOF
"$CC" -std=c11 -O2 "$WORK/c11test.c" -o "$WORK/c11test" && "$WORK/c11test"

echo "==== 検証: C++11 ===="
cat > "$WORK/cxx11test.cpp" <<'EOF'
#include <memory>
#include <cstdio>
int main(){ auto p = std::make_shared<int>(42); std::printf("cxx11 ok %d\n", *p); }
EOF
"$CXX" -std=c++11 -O2 "$WORK/cxx11test.cpp" -o "$WORK/cxx11test" && "$WORK/cxx11test"

echo
echo "toolchain OK"
