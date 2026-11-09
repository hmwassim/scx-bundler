# scx-bundler

Builds Debian 13 (trixie) amd64 packages for the
[sched_ext](https://github.com/sched-ext) userspace:

| Package | Upstream | Contents |
|---|---|---|
| `scx-scheds` | [sched-ext/scx](https://github.com/sched-ext/scx) | the schedulers (`scx_bpfland`, `scx_lavd`, `scx_rusty`, …) and `scxtop` |
| `scx-tools` | [sched-ext/scx-loader](https://github.com/sched-ext/scx-loader) | `scx_loader` (D-Bus service), `scxctl`, `scxtui` |

## Build

Requires Docker.

```sh
./build.sh all          # or: ./build.sh scx-scheds / ./build.sh scx-tools
```

Each package is built in a fresh `debian:trixie` container with `dpkg-buildpackage`
and checked with `lintian`. The results go to `out/`, for example
`out/scx-scheds_1.1.4-1_amd64.deb`.

Rust comes from `trixie-backports`, because upstream needs a newer version than trixie
has. The schedulers' BPF code is built with trixie's `clang-22`, because some schedulers
refuse older clang. Crates are downloaded with `cargo fetch --locked` before the build, and the build
itself runs offline (`--frozen`).

## New release

The version in each `debian/changelog` decides which upstream tag is built. The upstream
part of `1.1.5-1` is `1.1.5`, so the tag `v1.1.5` is built. To package a new upstream
release:

```sh
cd scx-scheds && dch -v 1.1.5-1 "Package scx 1.1.5." && cd ..
./build.sh scx-scheds
```

To rebuild the same upstream version with packaging changes, bump only the revision
(`1.1.5-2`).

## Install

```sh
sudo apt install ./out/scx-scheds_*.deb ./out/scx-tools_*.deb
```

The kernel needs `CONFIG_SCHED_CLASS_EXT=y`, and Debian's own kernels have it.

The kernel runs only one sched_ext scheduler at a time, so use only one of these
two ways to start a scheduler:

- **`scx.service`** (from scx-scheds) runs the scheduler named in `/etc/default/scx`:
  `sudo systemctl enable --now scx.service`.
- **`scx_loader`** (from scx-tools) starts and switches schedulers on request:
  `scxctl start --sched bpfland`. D-Bus starts it on demand. To start a scheduler at
  boot, set `default_sched` in `/etc/scx_loader.toml` (copy it from
  `/usr/share/scx_loader/config.toml`) and run `sudo systemctl enable scx_loader`.

Neither service is enabled on install. To try a scheduler once, run it directly:
`sudo scx_bpfland`.

License texts for the bundled Rust crates are in
`/usr/share/doc/<package>/THIRD-PARTY-LICENSES.gz`.
