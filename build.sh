#!/bin/sh
set -eu

PACKAGES='scx-scheds scx-tools'
IMAGE='debian:trixie'

usage() {
   echo "usage: $0 scx-scheds | scx-tools | all" >&2
   exit 2
}

upstream_repo() {
   case "$1" in
   scx-scheds) echo 'https://github.com/sched-ext/scx.git' ;;
   scx-tools) echo 'https://github.com/sched-ext/scx-loader.git' ;;
   *) usage ;;
   esac
}

inside() {
   pkg="$1"
   repo="$(upstream_repo "$pkg")"
   export DEBIAN_FRONTEND=noninteractive

   # Installing build dependencies, Rust from backports (upstream needs >= 1.91)
   echo 'deb http://deb.debian.org/debian trixie-backports main' \
      >/etc/apt/sources.list.d/backports.list
   apt-get update
   apt-get install -y --no-install-recommends \
      build-essential lintian git ca-certificates
   apt-get install -y --no-install-recommends -t trixie-backports cargo rustc
   apt-get build-dep -y --no-install-recommends "/src/$pkg"

   version="$(dpkg-parsechangelog -l "/src/$pkg/debian/changelog" -S Version)"
   upstream="${version%-*}"

   echo "Fetching [$pkg v$upstream]..."
   rm -rf "/build/$pkg"
   git clone --depth 1 --branch "v$upstream" "$repo" "/build/$pkg"
   cp -r "/src/$pkg/debian" "/build/$pkg/debian"

   cd "/build/$pkg"
   CARGO_HOME="/build/$pkg/debian/cargo-home" cargo fetch --locked

   echo "Building [$pkg $version]..."
   dpkg-buildpackage -b -us -uc

   deb="/build/${pkg}_${version}_amd64.deb"
   lintian --fail-on error "$deb"

   mkdir -p /src/out
   cp "$deb" /src/out/
   chown "$HOST_UID:$HOST_GID" /src/out "/src/out/$(basename "$deb")"
   echo "Done [out/$(basename "$deb")]"
}

if [ "${1:-}" = '--inside' ]; then
   inside "$2"
   exit 0
fi

[ $# -eq 1 ] || usage
case "$1" in
all) targets="$PACKAGES" ;;
scx-scheds | scx-tools) targets="$1" ;;
*) usage ;;
esac

cd "$(dirname "$0")"

# Removing the container on Ctrl-C, docker run alone leaves it running
container=''
trap '[ -n "$container" ] && docker rm -f "$container" >/dev/null 2>&1; exit 130' INT TERM

for pkg in $targets; do
   container="scx-bundler-$pkg-$$"
   docker run --rm --name "$container" \
      -v "$PWD:/src" \
      -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
      "$IMAGE" /src/build.sh --inside "$pkg"
done
