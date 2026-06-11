VERSION ?= $(shell cat VERSION 2>/dev/null || echo 1.1.1)
RELEASE := trixie
RUSTUP_HOME := $(abspath build/rust/rustup)
CARGO_HOME := $(abspath build/rust/cargo)
export RUSTUP_HOME
export CARGO_HOME

.PHONY: all build build-scheds build-tools repo install install-scheds install-tools \
        setup-rust clean clean-all check-deps

all: build repo

setup-rust: check-deps
	@echo "==> Installing rustup (sandboxed in build/rust/)..."
	@mkdir -p "$(RUSTUP_HOME)" "$(CARGO_HOME)"
	@if [ ! -x "$(RUSTUP_HOME)/bin/rustup" ]; then \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
		  | RUSTUP_HOME="$(RUSTUP_HOME)" CARGO_HOME="$(CARGO_HOME)" sh -s -- \
		    -y --no-modify-path --default-toolchain stable 2>&1; \
		echo "RUSTUP_HOME=$(RUSTUP_HOME)" > "$(CARGO_HOME)/env"; \
		echo "CARGO_HOME=$(CARGO_HOME)" >> "$(CARGO_HOME)/env"; \
	fi
	@echo "    Rust ready: $$(RUSTUP_HOME="$(RUSTUP_HOME)" CARGO_HOME="$(CARGO_HOME)" "$(RUSTUP_HOME)/bin/rustc" --version 2>/dev/null)"

build: | setup-rust
build: build-scheds build-tools

build-scheds:
	@echo "==> Building scx-scheds package..."
	packages/scx-scheds/build.sh $(VERSION)

build-tools:
	@echo "==> Building scx-tools package..."
	packages/scx-tools/build.sh $(VERSION)

repo:
	@echo "==> Generating APT repository metadata..."
	scripts/update-repo.sh $(RELEASE)

install: install-scheds install-tools

install-scheds:
	sudo dpkg -i repo/pool/main/s/scx-scheds/scx-scheds_$(VERSION)_amd64.deb

install-tools:
	sudo dpkg -i repo/pool/main/s/scx-tools/scx-tools_$(VERSION)_amd64.deb

check-deps:
	@echo "==> Checking build dependencies..."
	scripts/check-deps.sh

clean:
	rm -rf build/*

clean-all: clean
	rm -rf repo/pool repo/dists
