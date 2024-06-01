///usr/bin/env nasm -f elf64 test-asm.asm -o asm.o && zig build-exe -fPIC -freference-trace asm.o "$0" && rm ${0:0:-4}.o && ./${0:0:-4} "$@"; exit
const std    = @import("std");
const debugp = std.debug.print;

extern "asm" fn add(a: u64, b: u64) u64;

pub fn main() !void {
    debugp("asm test: {d}\n", .{add(1, 2)});
}
