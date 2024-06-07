///usr/bin/env nasm -f elf64 ${0:0:-4}.asm -o asm.o && zig build-exe -fPIC -freference-trace asm.o "$0" && rm ${0:0:-4}.o && ./${0:0:-4} "$@"; exit
const std    = @import("std");
const debugp = std.debug.print;
const prof   = @import("prof.zig");

const profEnabled = true;
const ProfArea = enum {
    read_1,  read_2, read_3, read_4,
    stor_1,  stor_2, stor_3, stor_4,
};
var gprof: prof.Profiler(profEnabled, ProfArea) = .{};

extern "asm" fn read_1(n: u64, data: *u64) void;
extern "asm" fn read_2(n: u64, data: *u64) void;
extern "asm" fn read_3(n: u64, data: *u64) void;
extern "asm" fn read_4(n: u64, data: *u64) void;
extern "asm" fn stor_1(n: u64, data: *u64) void;
extern "asm" fn stor_2(n: u64, data: *u64) void;
extern "asm" fn stor_3(n: u64, data: *u64) void;
extern "asm" fn stor_4(n: u64, data: *u64) void;


pub fn main() !void {
    var data: u64 = 0x0123456789abcdef;
    const n: u64 = 1024*1024*1024;
    gprof.area_data[@intFromEnum(ProfArea.read_1)] += (n*@sizeOf(u64));
    gprof.area_data[@intFromEnum(ProfArea.read_2)] += (n*@sizeOf(u64));
    gprof.area_data[@intFromEnum(ProfArea.read_3)] += (n*@sizeOf(u64));
    gprof.area_data[@intFromEnum(ProfArea.read_4)] += (n*@sizeOf(u64));
    gprof.area_data[@intFromEnum(ProfArea.stor_1)] += (n*@sizeOf(u64));
    gprof.area_data[@intFromEnum(ProfArea.stor_2)] += (n*@sizeOf(u64));
    gprof.area_data[@intFromEnum(ProfArea.stor_3)] += (n*@sizeOf(u64));
    gprof.area_data[@intFromEnum(ProfArea.stor_4)] += (n*@sizeOf(u64));
    try gprof.init();
    gprof.start(.read_1); read_1(n, &data); gprof.end(.read_1);
    gprof.start(.read_2); read_2(n, &data); gprof.end(.read_2);
    gprof.start(.read_3); read_3(n, &data); gprof.end(.read_3);
    gprof.start(.read_4); read_4(n, &data); gprof.end(.read_4);
    gprof.start(.stor_1); stor_1(n, &data); gprof.end(.stor_1);
    gprof.start(.stor_2); stor_2(n, &data); gprof.end(.stor_2);
    gprof.start(.stor_3); stor_3(n, &data); gprof.end(.stor_3);
    gprof.start(.stor_4); stor_4(n, &data); gprof.end(.stor_4);
    try gprof.sum(std.io.getStdErr().writer(), false);
}
