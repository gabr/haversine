///usr/bin/env nasm -f elf64 ${0:0:-4}.asm -o asm.o && zig build-exe -fPIC -freference-trace asm.o "$0" && rm ${0:0:-4}.o && ./${0:0:-4} "$@"; exit
const std    = @import("std");
const debugp = std.debug.print;
const prof   = @import("prof.zig");

const profEnabled = true;
const ProfArea = enum { read_4x2, read_8x2, read_16x2, read_32x2, read_64x2, };
var gprof: prof.Profiler(profEnabled, ProfArea) = .{};

extern "asm" fn read_4x2 (n: u64, data: [*]u8) void;
extern "asm" fn read_8x2 (n: u64, data: [*]u8) void;
extern "asm" fn read_16x2(n: u64, data: [*]u8) void;
extern "asm" fn read_32x2(n: u64, data: [*]u8) void;
extern "asm" fn read_64x2(n: u64, data: [*]u8) void;

pub fn main() !void {
    var data = [_]u8{1} ** 1024;
    const n: u64 = 1024*1024*1024*64;
    gprof.area_data[@intFromEnum(ProfArea.read_4x2)]  += n;
    gprof.area_data[@intFromEnum(ProfArea.read_8x2)]  += n;
    gprof.area_data[@intFromEnum(ProfArea.read_16x2)] += n;
    gprof.area_data[@intFromEnum(ProfArea.read_32x2)] += n;
    gprof.area_data[@intFromEnum(ProfArea.read_64x2)] += n;
    try gprof.init();
    gprof.start(.read_4x2);   read_4x2(n, &data);  gprof.end(.read_4x2);
    gprof.start(.read_8x2);   read_8x2(n, &data);  gprof.end(.read_8x2);
    gprof.start(.read_16x2); read_16x2(n, &data); gprof.end(.read_16x2);
    gprof.start(.read_32x2); read_32x2(n, &data); gprof.end(.read_32x2);
    //gprof.start(.read_64x2); read_64x2(n, &data); gprof.end(.read_64x2); <-- does not work :(
    try gprof.sum(std.io.getStdErr().writer(), false);
}
