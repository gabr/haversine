///usr/bin/env zig run -fno-llvm -fno-lld -fno-error-tracing "$0" -- "$@"; exit
// -fno-llvm           disables LLVM to have faster compile time
// -fno-lld            disables LLD to have faster linking time
// -fno-error-tracing  print only simple error message on error
const help =
\\parse-data
\\  A program for parsing JSON file with latitude-longitude point
\\  pairs and calculating Haversine distance for each point.
\\  It can also verify its parsing and calculations using binary files
\\  (extension .f64) with the same floating point values as in the JSON.
\\
\\Usage:
\\  parse-data path name [-valid]
\\
\\    path    <string>  Path to the directory with JSON and f64 files
\\    name    <string>  Prefix name of the files in given path
\\    -valid  <flag>    Optional flag.  If present program will validate
\\                      JSON data and calculations using f64 files.
\\                      Errors will be printed to the standard error.
\\
\\The output of the program is a single float value which is an averrage
\\of all Haversine distances from all the pairs in given JSON data file.
\\It is printed to the standard output.
\\
\\The expected files in the supplied path:
\\  1. name-data.json - the JSON data with the latitude and longitude pairs
\\for validation (-valid flag):
\\  2. name-data.f64  - binary file with the same floats as in data.json
\\  3. name-hsin.json - Haversine distance for each pair as a JSON
\\  4. name-hsin.f64  - Haversine distance for each pair as binary floats
\\
\\The expected JSON format for name-data.json:
\\  {"pairs":[
\\    {"x0":float, "y0":float, "x1":float, "y1":float},
\\    ...
\\  ]}
\\for name-hsin.json:
\\  {"haversine distances":[
\\    float,
\\    ...
\\  ]}
\\
\\Examples:
\\  # ./parse-data.zig data/ three
\\  123.4577
\\  # ./parse-data.zig data/ with-error --validate
\\  error: ....
\\  error: ....
\\  ...
\\  123.4577
\\
;

const std       = @import("std");
//const dstderr   = std.debug.print;
const fs        = std.fs;
const assert    = std.debug.assert;
const mem       = std.mem;
const haversine = @import("common.zig").haversine;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    // Lack of arena.deinit() is intentional as there is no
    // need to free the memory in this short living program.
    // Same will go for all the allocations that will follow.
    const args = try Args.get(allocator); _ = args;
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("output\n");
}

const Args = struct {
    args:  [][:0]u8,
    path:  []const u8,
    name:  []const u8,
    valid: bool,

    pub fn get(allocator: mem.Allocator) !Args {
        var a: Args = undefined;
        const stderr = std.io.getStdErr().writer();
        a.args = try std.process.argsAlloc(allocator);
        if (a.args.len < 3) { try stderr.writeAll(help); return error.NotEnoughArguments; }
        a.path = a.args[1];
        a.name = mem.trim(u8, a.args[2], " \t\n\r "); // the last one is hard space
        a.valid = if (a.args.len > 3 ) mem.eql(u8, "-valid", a.args[3]) else false;
        return a;
    }
};

