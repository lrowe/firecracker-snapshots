.PHONY: all clean snaprun

ARCH := $(shell uname -m)
FIRECRACKER_CI = https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/20260318-4392a8d19ab0-0/x86_64
FIRECRACKER_VERSION = v1.15.0
FIRECRACKER_SUFFIX = -$(FIRECRACKER_VERSION)-$(ARCH)

all: snaprun target/measure target/measurefvsock target/measureunix

clean:
	rm -rf target

target/vmlinux:
	mkdir -p target
	curl -L -o $@ $(FIRECRACKER_CI)/vmlinux-6.1.164

target/firecracker$(FIRECRACKER_SUFFIX):
	mkdir -p $@
	curl -L https://github.com/firecracker-microvm/firecracker/releases/download/$(FIRECRACKER_VERSION)/firecracker$(FIRECRACKER_SUFFIX).tgz | tar -xz --strip-components=1 -C $@
	cd target/firecracker; for f in *$(FIRECRACKER_SUFFIX); do ln -s "$$f" "$${f%$(FIRECRACKER_SUFFIX)}"; done

target/firecracker: target/firecracker$(FIRECRACKER_SUFFIX)
	rm -f $@
	ln -s firecracker$(FIRECRACKER_SUFFIX)/firecracker$(FIRECRACKER_SUFFIX) target/firecracker

target/root.squashfs: Dockerfile init.sh target/helloworld
	rm -f $@
	docker buildx build --output type=tar,dest=- . | sqfstar $@

target/helloworld:
	mkdir -p target
	deno compile \
		--allow-all \
		--unstable-vsock \
		--v8-flags=--predictable,--max-old-space-size=64,--max-semi-space-size=64 \
		-o target/helloworld \
		'data:,Deno.serve(() => new Response("Hello, World!"))'

target/helloworld.snapshot target/helloworld.mem &: target/firecracker target/root.squashfs target/vmlinux target/measurefvsock snapshot.sh
	./snapshot.sh

snaprun: target/firecracker target/root.squashfs target/helloworld.snapshot target/helloworld.mem target/measurefvsock snaprun.sh
	./snaprun.sh

target/measure: measure.cpp
	g++ -o $@ measure.cpp -std=c++20 -pthread

target/measurefvsock: measurefvsock.cpp
	g++ -o $@ measurefvsock.cpp -std=c++20 -pthread

target/measureunix: measureunix.cpp
	g++ -o $@ measureunix.cpp -std=c++20 -pthread
