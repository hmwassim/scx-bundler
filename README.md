# scx-bundler

Builds Debian packages for [sched-ext/scx](https://github.com/sched-ext/scx) and
[sched-ext/scx-loader](https://github.com/sched-ext/scx-loader) with a
sandboxed Rust toolchain — no `~/.cargo` or `~/.rustup` pollution.

## Packages

| Package | Contents | Source |
|---------|----------|--------|
| `scx` | sched_ext scheduler binaries (scx_bpfland, scx_rusty, ...) | [scx](https://github.com/sched-ext/scx) |
| `scx-tools` | scx_loader daemon + scxctl CLI | [scx-loader](https://github.com/sched-ext/scx-loader) |

## Dependencies

```bash
sudo apt install git dpkg-dev gzip coreutils curl clang
# optional — needed for compiling the schedulers:
sudo apt install libbpf-dev libelf-dev libcap-dev zlib1g-dev libseccomp-dev \
                 llvm linux-libc-dev
```

## Build

Rust is bootstrapped via rustup into `build/rust/` on first run.

```bash
make all                   # setup-rust → build both .debs → generate repo
make build                 # just build the .debs
make build VERSION=1.0.0   # build a specific upstream version
```

Output `.deb` files go to `repo/pool/`, APT metadata to `repo/dists/`.

## Install

```bash
make install          # sudo dpkg -i both .debs
sudo dpkg -i repo/pool/*/*/*/*.deb   # or manually
```

## How it works

1. `git clone` upstream source at the requested version tag
2. `cargo build --release` with sandboxed Rust (`build/rust/{rustup,cargo}/`)
3. `dpkg-deb --build` into `repo/pool/main/`
4. `scripts/update-repo.sh` generates `Packages.gz` + `Release`

Rust is completely contained — set `RUSTUP_HOME` and `CARGO_HOME` to your own
paths if you want to reuse the toolchain across projects.

## Clean

```bash
make clean           # remove build artifacts (keeps rust toolchain)
make clean-all       # remove build artifacts + repo pool/dists
rm -rf build/rust    # remove the sandboxed Rust toolchain entirely
```
