///usr/bin/env zig run -fno-llvm -fno-lld "$0" -- "$@"; exit
const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    for (1..10) |i| { print("i: {}\n", .{i}); }
}
