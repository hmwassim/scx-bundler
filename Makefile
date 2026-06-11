VERSION ?= 1.1.1
RELEASE := trixie
RUSTUP_HOME := $(abspath build/rust/rustup)
CARGO_HOME := $(abspath build/rust/cargo)
export RUSTUP_HOME
export CARGO_HOME

.PHONY: all build build-scx build-scx-tools repo install install-scx install-scx-tools \
        setup-rust clean clean-all check-deps

all: build repo

setup-rust: check-deps
	@echo "==> Installing rustup (sandboxed in build/rust/)..."
	@mkdir -p "$(RUSTUP_HOME)" "$(CARGO_HOME)"
	@if ! command -v rustup &>/dev/null && [ ! -f "$(RUSTUP_HOME)/bin/rustup" ]; then \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
		  | sh -s -- -y --no-modify-path --default-toolchain stable \
		    --rustup-home "$(RUSTUP_HOME)" --verbose 2>&1; \
		echo "RUSTUP_HOME=$(RUSTUP_HOME)" > "$(CARGO_HOME)/env"; \
		echo "CARGO_HOME=$(CARGO_HOME)" >> "$(CARGO_HOME)/env"; \
	fi
	@echo "    Rust ready: $$("$(RUSTUP_HOME)/bin/rustc" --version 2>/dev/null)"

build: | setup-rust
build: build-scx build-scx-tools

build-scx:
	@echo "==> Building scx package..."
	packages/scx/build.sh $(VERSION)

build-scx-tools:
	@echo "==> Building scx-tools package..."
	packages/scx-tools/build.sh $(VERSION)

repo:
	@echo "==> Generating APT repository metadata..."
	scripts/update-repo.sh $(RELEASE)

install: install-scx install-scx-tools

install-scx:
	sudo dpkg -i repo/pool/main/s/scx/scx_$(VERSION)_amd64.deb

install-scx-tools:
	sudo dpkg -i repo/pool/main/s/scx-tools/scx-tools_$(VERSION)_amd64.deb

check-deps:
	@echo "==> Checking build dependencies..."
	scripts/check-deps.sh

clean:
	rm -rf build/*

clean-all: clean
	rm -rf repo/pool repo/dists
