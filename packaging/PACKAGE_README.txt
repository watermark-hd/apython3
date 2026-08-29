apython312 — Python 3.12 for Mac OS X 10.4 "Tiger" (PowerPC)
============================================================

これは Mac OS X 10.4.11 Tiger の PowerPC Mac 向けにビルドされた
CPython 3.12.11 の再配置可能パッケージです。

  Python 3.12.11  /  GCC 14.2.0  /  OpenSSL 3.5.7
  pip / ssl / sqlite3 / ctypes / lzma / bz2 / zlib / readline / decimal ...

必要要件
--------
  * Mac OS X 10.4.x（Tiger）
  * PowerPC G4 (AltiVec) 以降  ※ G3 では動きません
  * 約 200 MB の空き容量

インストール
------------
  1. このフォルダ（または .dmg）の中の "install.command" をダブルクリック
  2. インストール先を聞かれます（既定: ~/Applications/apython312）
  3. 完了後、表示される PATH 設定を ~/.bash_profile に追記

  コマンドラインなら:
     tar xjf apython312-*-macosx10.4-powerpc.tar.bz2 -C ~/Applications
     ~/Applications/apython312/bin/python3.12 -V

使い方
------
     python3.12 -m pip install flask "django>=5.2,<5.3"
     python3.12 -m flask --app app.py run
     python3.12 -m django --version

制限
----
  * Rust ツールチェーンが要るパッケージは不可
    （cryptography>=3.4, pydantic-core, orjson, ruff, polars など）
    → 代わりに cryptography<3.4 をピン留め。Django コアは cryptography 不要。
  * C 拡張を含むパッケージは、ビルド環境（tigerbrew + GCC 14）が
    このマシンに無ければ、純 Python フォールバックのあるものだけ入ります。
  * _tkinter（GUI）は含まれません。

ビルド手順・パッチの詳細:
  https://github.com/watermark-hd/apython3
