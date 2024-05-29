#/bin/bash
# A script to build release versions of each program for speed.
set -eu # exit on error and if there is unassigned variable use
build() {
    local -r file="$1"; shift
    [ $file.zig -ot $file ] && echo $file.zig no changes && return 0
    [ -f $file   ] && rm $file
    [ -f $file.o ] && rm $file.o
    ( # use subshell to disable set -x after rm command
        set -x # show the executed command
        zig build-exe -fno-strip -O ReleaseFast $file.zig
        rm $file.o # don't need that
    )
}

build generate-data
build parse-data
build test-file-read
