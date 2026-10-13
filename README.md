# scx-bundler

Builds Debian packages for [sched-ext/scx](https://github.com/sched-ext/scx) and
[sched-ext/scx-loader](https://github.com/sched-ext/scx-loader), plus a local APT
repository to serve them from. Rust is installed into `build/rust/`, so
`~/.cargo` and `~/.rustup` are left untouched.

| Package      | Contents                                              |
|--------------|-------------------------------------------------------|
| `scx-scheds` | scheduler binaries (`scx_*`, `scxtop`) and `scx.service` |
| `scx-tools`  | `scx_loader` daemon and `scxctl`                      |

## Build dependencies

`make` checks these first and prints the exact `apt install` line for anything missing.

```sh
sudo apt install git curl clang llvm pkg-config dpkg-dev \
    libbpf-dev libelf-dev libseccomp-dev zlib1g-dev protobuf-compiler
```

## Usage

```sh
make                     # build both .debs for VERSION and write repo metadata
make VERSION=1.1.4       # build another upstream tag (v1.1.4 must exist in both repos)
make REVISION=2          # rebuild the same upstream version with packaging fixes
make install             # apt install the built .debs
make -B debs             # force a rebuild
make clean               # drop sources and staging dirs, keep Rust and repo/
make distclean           # drop everything, including the Rust toolchain
```

## Services

- `scx-scheds` alone enables `scx.service`, which runs the scheduler set in
  `/etc/default/scx`.
- `scx-tools` disables `scx.service` and enables `scx_loader.service` instead,
  configured by `/etc/scx_loader/config.toml`. Removing `scx-tools` switches
  back to `scx.service`.
