# scx-bundler

Builds Debian packages for [sched-ext/scx](https://github.com/sched-ext/scx) and
[sched-ext/scx-loader](https://github.com/sched-ext/scx-loader) with a
sandboxed Rust toolchain — no `~/.cargo` or `~/.rustup` pollution.

## Packages

| Package | Contents | Source |
|---------|----------|--------|
| `scx-scheds` | sched_ext scheduler binaries (scx_bpfland, scx_rusty, ...) | [scx](https://github.com/sched-ext/scx) |
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
Both repos must have a matching `v<VERSION>` tag or the build fails.

```bash
make all                   # build both .debs → generate repo
make build                 # just build the .debs
make build VERSION=1.0.0   # build a specific upstream version
```

## Install

```bash
make install                # sudo dpkg -i both .debs
sudo dpkg -i repo/pool/*/*/*/*.deb
```

## How it works

1. Verifies the version tag exists in both upstream repos
2. `git clone` at the requested tag
3. `cargo build --release` with sandboxed Rust (`build/rust/{rustup,cargo}/`)
4. Scheduler binaries discovered dynamically with `find target/release -name 'scx_*'`
5. `dpkg-deb --build` into `repo/pool/main/`
6. `scx-tools` postinst copies config to `/etc/scx_loader/` and runs `daemon-reload`

## Clean

```bash
make clean           # remove build artifacts (keeps rust toolchain)
make clean-all       # remove build artifacts + repo pool/dists
rm -rf build/rust    # remove the sandboxed Rust toolchain entirely
```
