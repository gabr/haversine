#/bin/bash
# A helper script to build and debug
set -eu # exit on error and if there is unassigned variable use
debug() {
    local -r file="$1"; shift
    [ -f $file   ] && rm $file
    [ -f $file.o ] && rm $file.o
    ( # use subshell to disable set -x after rm command
        set -x # show the executed command
        zig build-exe -O Debug -fno-strip $file.zig
        rm $file.o # don't need that
        gdb -ex "$(echo run $@)" "$file"
    )
}

#debug "generate-data"
debug "parse-data" data three -valid -prof
