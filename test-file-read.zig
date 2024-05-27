///usr/bin/env zig run -fno-error-tracing -freference-trace "$0" -- "$@"; exit
// -fno-error-tracing  print only simple error message on error
// A simple program to test file read bandwidth
const std       = @import("std");
const io        = std.io;
const dstderr   = std.debug.print;
const fs        = std.fs;
const assert    = std.debug.assert;
const prof      = @import("prof.zig");

const profEnabled = true;
const ProfArea = enum { big_json1, big_json2, small_json1, small_json2 };
var gprof: prof.Profiler(profEnabled, ProfArea) = .{};

pub fn main() !void {
    gprof.init();
    try testFile("data/big-data.json",     .big_json1);
    try testFile("data/big-data.json",     .big_json2);
    try testFile("data/three-data.json", .small_json1);
    try testFile("data/three-data.json", .small_json2);
    try gprof.sum(io.getStdErr().writer());
}

pub fn testFile(path: []const u8, comptime area: ProfArea) !void {
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
