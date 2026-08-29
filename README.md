# apython3 — CPython 3.12 on Mac OS X 10.4 "Tiger" (PowerPC)

Build scripts, patches, and a field report for getting a **modern Python 3.12
with pip, Flask and Django running on a PowerPC Mac running Mac OS X 10.4.11
Tiger** — the last macOS that boots on PowerPC, released 2005.

As far as I can tell this combination had no prior art: Python 3.10/3.11 have
been built for **Leopard** PPC by the MacPorts/tigerbrew communities, but not
3.12, and not on **Tiger**.

## Result

Built and verified on an **iBook G4 (PowerBook6,5), 1.2 GHz 7447A, 1.25 GB RAM,
Mac OS X 10.4.11**:

```
Python 3.12.11 (main, Aug 30 2026) [GCC 14.2.0]
sys.byteorder = 'big'   platform = macOS-10.4.11-Power_Macintosh-powerpc-32bit

pip 26.2.1 · OpenSSL 3.5.7 · SQLite 3.50.4
imports OK (no failures): ssl, hashlib, _hashlib, ctypes, sqlite3, lzma, bz2,
  zlib, decimal, readline, socket, select, zoneinfo, _datetime, _csv, json,
  xml.etree, concurrent.futures, multiprocessing, asyncio, _scproxy, ...
_ctypes big-endian: qsort() + Python callback → [1,2,3,4,5]   (libffi closures OK)
TLS: real HTTPS handshake to pypi.org → 200

pip install flask        → Flask 3.1.3, GET / → 200   (markupsafe C ext built natively → PPC wheel)
pip install "django<5.3" → Django 5.2.17, migrate OK, runserver → 200
```

Only `_tkinter` is missing (no Tcl/Tk; irrelevant for web work).

### What works / what doesn't

| | |
|---|---|
| ✅ | pure-Python packages; C-extension packages that build against this toolchain |
| ✅ | Flask, Django (+ SQLite), HTTPS/TLS, pip, `ctypes` (big-endian verified) |
| ❌ | anything needing Rust — `cryptography>=3.4`, `pydantic-core`, `orjson`, `ruff`, `polars` … → pin `cryptography<3.4`; Django core needs no `cryptography` |
| △ | `numpy` / `scipy` / `Pillow` / `lxml` — heavy C extensions, not attempted here |

## The machine it was built on

| | |
|---|---|
| Model | iBook G4 (PowerBook6,5), G4 7447A **1.2 GHz single core**, 1.25 GB RAM |
| OS | Mac OS X **10.4.11** (Darwin 8.11), **big-endian**, 32-bit PowerPC |
| Dev tools at start | Xcode **2.0** — no `MacOSX10.4u` SDK, and this install had a **stripped `/usr/include` (2 files) and no framework headers** (a partial system reinstall at some point) |
| Package manager | tigerbrew, present but non-functional (see below) |
| Driven from | an Apple-silicon Mac over `ssh ibook`; all heavy work runs on the iBook under `nohup` |

## Strategy

- **Native build, not cross.** The resulting interpreter is a real PowerPC
  binary either way; "native/cross" only describes where the *compiler* runs.
  CPython's build system assumes native, and Darwin/PPC is not a maintained
  cross target, so cross-compiling means fighting `configure` the whole way.
- **Don't build the toolchain by hand.** tigerbrew's `gcc` formula is 14.2.0
  with a prebuilt `tiger_altivec` bottle — GCC 14 handles C11/C17 fine.
- **Vendor the C deps from tigerbrew**: `openssl3` (3.5.7), `libffi` (3.4.7),
  `sqlite`, `xz`, `readline`, `gdbm`, `zlib`.
- **CPython from python.org source** (`.tgz` — GNU tar 1.14 has no `.xz`),
  PGO/LTO off, with the four patches in [`patches/`](patches/).

## Build procedure

Everything is driven from a modern Mac via `./run.sh <script>` (rsync → run on
the iBook under `nohup` → tail). Steps that need `root` on the iBook are run by
hand there (`sudo bash ~/apython3/scripts/NN_*.sh`).

```sh
# 0. one-time toolchain environment (the "Tiger tax")
#    Xcode 2.5 DMG → extract payloads with pax (the .mpkg installer is broken on Tiger)
sudo bash scripts/06_xcode25_extract.sh     # MacOSX10.4u SDK + gcc 4.0.1 + cctools-622
sudo bash scripts/07_fixup_usrlib.sh        # restore /usr/include + crt1.o/libSystemStubs from SDK
sudo bash scripts/08_fixup_frameworks.sh    # restore CoreFoundation/CoreServices/Carbon/... headers
./run.sh 11_rebootstrap_brew                # current tigerbrew over /usr/local
./run.sh 13_patch_brew                      # os/mac.rb: guard pkgutil (absent on Tiger)

# 1. toolchain + deps
./run.sh 10_brew_bootstrap                  # gpatch, pkg-config, xz
./run.sh 20_toolchain                       # gcc 14.2.0  (brew install --force-bottle gcc)
./run.sh 30_deps                            # openssl3, libffi, sqlite, readline, gdbm, zlib

# 2. CPython
./run.sh 40_build_cpython                   # download, patch, configure, make, make install
#   RESUME=1 ./run.sh 40_build_cpython      # continue an interrupted make without re-configuring
./run.sh 45_smoke                           # imports, ctypes callback, TLS, sqlite

# 3. web stack + package
./run.sh 50_pip                             # pip upgrade + cert wiring
./run.sh 60_web                             # pip install flask / django, runserver smoke test
./run.sh 70_package                         # relocatable tarball + .dmg in dist/
```

## The four source patches

All are the same shape: **CPython 3.12 assumes any `__APPLE__` target has an API
that actually arrived in 10.5 or 10.6.**

| patch | problem |
|---|---|
| [`0001-thread_pthread-tiger-native-id`](patches/0001-thread_pthread-tiger-native-id.patch) | `pthread_threadid_np()` (10.6+) — fall back to `pthread_mach_thread_np()` |
| [`0002-posixmodule-tiger-no-copyfile`](patches/0002-posixmodule-tiger-no-copyfile.patch) | `<copyfile.h>` / `fcopyfile()` / `COPYFILE_*` (10.5+) — `#if 0` the 4 blocks |
| [`0003-posixmodule-tiger-ttyname`](patches/0003-posixmodule-tiger-ttyname.patch) | Tiger defaults `__DARWIN_UNIX03` off → `ttyname_r` has the legacy `char *` signature — use `ttyname()` |
| `_scproxy` | needs SystemConfiguration→CoreServices→CarbonCore headers (restored by `08_fixup_frameworks.sh`); `urllib.request` imports it unconditionally on darwin, so it can't just be disabled |

Plus one tigerbrew fix ([`13_patch_brew.sh`](scripts/13_patch_brew.sh)):
`os/mac.rb`'s `pkgutil_info()` raises `ENOENT` on Tiger (no `/usr/sbin/pkgutil`),
which kills every `make install`.

The full blow-by-blow — every wall and how it was cleared — is in
[`notes/obstacles.md`](notes/obstacles.md).

## Layout

```
run.sh              driver: rsync repo to the iBook, run a script under nohup, tail
env.sh              shared vars (PY_VERSION, PREFIX=$HOME/apython312, CC=gcc-14, …)
scripts/            05..70, numbered in build order
patches/            *.patch applied to the CPython source (patch -p1)
packaging/          install.command + PACKAGE_README.txt for the distributable
notes/obstacles.md  the field report
dist/               built package (gitignored; see Releases)
```

## Using the prebuilt package

See [Releases](../../releases) for `apython312-3.12.11-macosx10.4-powerpc.dmg`
(a relocatable tree — vendored `libssl`/`libcrypto`/`libsqlite3`/`libffi`/… with
`@loader_path` install names — plus a double-clickable `install.command`).
Needs a G4 (AltiVec) or better on 10.4.x.

## Credits

Toolchain and bottles from [tigerbrew](https://github.com/mistydemeo/tigerbrew)
and the wider [macos-powerpc](https://macos-powerpc.org) / MacRumors PowerPC
community. Built with the help of Claude (Anthropic).

## License

MIT — see [LICENSE](LICENSE).
