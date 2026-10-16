# VERSION=x.y.z overrides both packages at once.
ifdef VERSION
SCHEDS_VERSION := $(VERSION)
TOOLS_VERSION  := $(VERSION)
endif
include versions.mk
# Bump for packaging-only changes to the same upstream version; reset to 1 on a new one.
REVISION        ?= 1
SCHEDS_REVISION ?= $(REVISION)
TOOLS_REVISION  ?= $(REVISION)
SUITE   ?= trixie

export RUSTUP_HOME := $(CURDIR)/build/rust/rustup
export CARGO_HOME  := $(CURDIR)/build/rust/cargo
CARGO := $(CARGO_HOME)/bin/cargo

POOL  := repo/pool/main/s
SCHEDS_DEB := $(POOL)/scx-scheds/scx-scheds_$(SCHEDS_VERSION)-$(SCHEDS_REVISION)_amd64.deb
TOOLS_DEB  := $(POOL)/scx-tools/scx-tools_$(TOOLS_VERSION)-$(TOOLS_REVISION)_amd64.deb
DEBS       := $(SCHEDS_DEB) $(TOOLS_DEB)

# libbpf-sys fails to build in paths containing spaces
ifneq ($(words $(CURDIR)),1)
$(error move the checkout to a path without spaces)
endif

.PHONY: all debs repo install deps clean distclean

all: repo

debs: $(DEBS)

repo: $(DEBS)
	./mkrepo.sh $(SUITE)

install: $(DEBS)
	sudo apt install $(addprefix ./,$(DEBS))

deps:
	@./check-deps.sh

$(CARGO): | deps
	mkdir -p $(RUSTUP_HOME) $(CARGO_HOME)
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
		sh -s -- -y --no-modify-path --default-toolchain stable

$(SCHEDS_DEB): | deps $(CARGO)
	./build.sh scx-scheds $(SCHEDS_VERSION) $(SCHEDS_REVISION)

$(TOOLS_DEB): | deps $(CARGO)
	./build.sh scx-tools $(TOOLS_VERSION) $(TOOLS_REVISION)

clean:
	rm -rf build/src build/root

distclean:
	rm -rf build repo
