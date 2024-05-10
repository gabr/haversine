#/bin/bash
set -eu # exit on error and if there is unassigned variable use
file="generate-data"
[ -f $file   ] && rm $file
[ -f $file.o ] && rm $file.o
set -x # show the executed command
zig build-exe -O ReleaseFast $file.zig
rm $file.o # don't need that
