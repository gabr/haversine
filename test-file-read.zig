///usr/bin/env zig run -freference-trace "$0" -- "$@"; exit
// A simple program to test file read bandwidth
const std       = @import("std");
const io        = std.io;
const debugp    = std.debug.print;
const fs        = std.fs;
const assert    = std.debug.assert;
const prof      = @import("prof.zig");

const profEnabled = true;
const ProfArea = enum {
    big_json1,    big_json2,
    small_json1,  small_json2,
    big_float1,   big_float2,
    small_float1, small_float2,
};
var gprof: prof.Profiler(profEnabled, ProfArea) = .{};

pub fn main() !void {
    try gprof.init();
    try testFile("data/big-data.json",   .big_json1);
    try testFile("data/big-data.json",   .big_json2);
    try testFile("data/three-data.json", .small_json1);
    try testFile("data/three-data.json", .small_json2);
    try testFile("data/big-data.f64",    .big_float1);
    try testFile("data/big-data.f64",    .big_float2);
    try testFile("data/three-data.f64",  .small_float1);
    try testFile("data/three-data.f64",  .small_float2);
    try gprof.sum(io.getStdErr().writer(), true);
}

pub fn testFile(path: []const u8, comptime area: ProfArea) !void {
    for (1..1000) |_| {
        const file = try fs.cwd().openFile(path, .{}); defer file.close();
        const file_size = (try file.stat()).size;
        gprof.area_data[@intFromEnum(area)] += file_size;
        const bufsiz = 4096;
        const BufType = prof.ProfiledBufferedReader(profEnabled, bufsiz, fs.File.Reader, ProfArea, area);
        var bufdjr: BufType = .{ .inner_reader = file.reader(), .profiler = &gprof, };
        const reader = bufdjr.reader();
        var buf: [bufsiz]u8 = undefined;
        var read: usize = 0;
        gprof.start(area);
        while (read < file_size) {
            read += try reader.read(&buf);
        }
        gprof.end(area);
    }
}
