#!/bin/bash
# tigerbrew(0.9.5) の Tiger 非互換箇所をパッチする。冪等。
#   - os/mac.rb: pkgutil_info が /usr/sbin/pkgutil 不在で ENOENT 例外 → make install 後に死ぬ
. "$(dirname "$0")/../env.sh"
HB="$BREW_PREFIX/Library/Homebrew"

echo "== pkgutil_info の ENOENT ガード =="
f="$HB/os/mac.rb"
if grep -q 'File.exist?("/usr/sbin/pkgutil")' "$f"; then
  echo "  既にパッチ済み"
else
  cp "$f" "$f.bak.$(date +%s)"
  /usr/bin/perl -0pi -e 's{\@pkginfo\[key\] = Utils\.popen_read\("/usr/sbin/pkgutil", "--pkg-info", key\)\.strip}{\@pkginfo[key] = File.exist?("/usr/sbin/pkgutil") ? Utils.popen_read("/usr/sbin/pkgutil", "--pkg-info", key).strip : ""}' "$f"
  ruby -c "$f" && echo "  パッチ適用 OK" || { echo "  !! 構文エラー、巻き戻し"; mv "$f.bak."* "$f"; exit 1; }
fi

echo "done"
