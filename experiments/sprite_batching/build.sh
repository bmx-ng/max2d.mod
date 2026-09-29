#!/bin/sh
set -eu
probe_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sdk_dir=$(CDPATH= cd -- "$probe_dir/../../../.." && pwd)
clang -O3 -DNDEBUG -mmacosx-version-min=11.0 -c "$probe_dir/probe.c" \
	-I"$sdk_dir/mod/sdl3.mod/sdl3.mod/SDL3/include" -o "$probe_dir/probe.o"
"$sdk_dir/bin/bmk" makeapp -r -t gui -o "$probe_dir/sprite-probe" "$probe_dir/probe.bmx"
