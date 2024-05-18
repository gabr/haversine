///usr/bin/env zig run -freference-trace "$0" -- "$@"; exit
// Exploratory program for figuring out how to call rdtsc cpu instruction.
// https://www.felixcloutier.com/x86/rdtsc
// https://www.felixcloutier.com/x86/rdtscp

const std     = @import("std");
const dstderr = std.debug.print;
const assert  = std.debug.assert;
const mem     = std.mem;

pub fn main() !void {
    dstderr("{d}\n", .{rdtsc()});
}

inline fn rdtsc() u64 {
    return asm (
        \\ rdtsc
        \\ sal $32, %%rdx
        \\ or %%rax, %%rdx
        : [ret] "={rdx}" (-> u64),
        :
        : "rax", "rdx");
}

