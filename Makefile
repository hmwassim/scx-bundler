VERSION  ?= $(shell cat VERSION)
# Bump for packaging-only changes to the same upstream VERSION; reset to 1 on a new VERSION.
REVISION ?= 1
SUITE   ?= trixie

export RUSTUP_HOME := $(CURDIR)/build/rust/rustup
export CARGO_HOME  := $(CURDIR)/build/rust/cargo
CARGO := $(CARGO_HOME)/bin/cargo

POOL  := repo/pool/main/s
DEBS  := $(POOL)/scx-scheds/scx-scheds_$(VERSION)-$(REVISION)_amd64.deb \
         $(POOL)/scx-tools/scx-tools_$(VERSION)-$(REVISION)_amd64.deb

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

$(POOL)/scx-scheds/scx-scheds_$(VERSION)-$(REVISION)_amd64.deb: | deps $(CARGO)
	./build.sh scx-scheds $(VERSION) $(REVISION)

$(POOL)/scx-tools/scx-tools_$(VERSION)-$(REVISION)_amd64.deb: | deps $(CARGO)
	./build.sh scx-tools $(VERSION) $(REVISION)

clean:
	rm -rf build/src build/root

distclean:
	rm -rf build repo
