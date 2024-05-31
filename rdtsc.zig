///usr/bin/env zig run -freference-trace "$0" -- "$@"; exit
// Exploratory program for figuring out how to call rdtsc cpu instruction.

const std    = @import("std");
const debugp = std.debug.print;

pub fn main() !void {
    debugp("{d}\n", .{rdtsc()});

    debugp("os freq: {d}\n", .{std.time.ns_per_s});
    const mul: i128 = 5;
    const cpus = rdtsc();
    const ts = std.time.nanoTimestamp();
    var te: @TypeOf(ts) = 0;
    var td: @TypeOf(ts) = 0;
    while (td < std.time.ns_per_s*mul) {
        te = std.time.nanoTimestamp();
        td = te - ts;
    }
    const cpue = rdtsc();
    const cpud = cpue - cpus;
    const mib = std.math.pow(f64, 10,6);
    const cpumhz = (@as(f128, @floatFromInt(cpud))/mib)/mul;
    debugp("os timer: {d} -> {d} = {d} elapsed\n", .{ts, te, td});
    debugp("os seconds: {d}\n", .{@as(f128, @floatFromInt(td))/@as(f128, @floatFromInt(std.time.ns_per_s*mul))});
    debugp("cpu timer: {d} -> {d} = {d}MHz elapsed\n", .{cpus, cpue, cpumhz});
}

/// read CPU clocks
inline fn rdtsc() u64 {
    // https://www.felixcloutier.com/x86/rdtsc
    // https://www.felixcloutier.com/x86/rdtscp
    return asm (
        \\ rdtsc
        \\ sal $32, %%rdx
        \\ or %%rax, %%rdx
        : [ret] "={rdx}" (-> u64),
        :
        : "rax", "rdx");
}

