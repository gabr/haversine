///usr/bin/env zig run -fno-llvm -fno-lld -fno-error-tracing -freference-trace "$0" -- "$@"; exit
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
const io        = std.io;
const dstderr   = std.debug.print;
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
    const args = try Args.get(allocator);
    const result = try parseAndCalculate(allocator, args);
    const stdout = io.getStdOut().writer();
    try stdout.print("{d}\n", .{result});
}

const Args = struct {
    args:  [][:0]u8,
    path:  []const u8,
    name:  []const u8,
    valid: bool,

    pub fn get(allocator: mem.Allocator) !Args {
        var a: Args = undefined;
        const stderr = io.getStdErr().writer();
        a.args = try std.process.argsAlloc(allocator);
        if (a.args.len < 3) { try stderr.writeAll(help); return error.NotEnoughArguments; }
        a.path = a.args[1];
        a.name = mem.trim(u8, a.args[2], " \t\n\r "); // the last one is hard space
        a.valid = if (a.args.len > 3 ) mem.eql(u8, "-valid", a.args[3]) else false;
        return a;
    }
};

/// Supply with the a Reader type
fn JSON_Reader(comptime T: type) type {
    return struct {
        reader: io.CountingReader(T),
        const Self = @This();

        /// Pass the reader instance to read JSON from
        pub fn init(reader: T) Self {
            return .{ .reader = io.countingReader(reader), };
        }

        pub fn getPos(self: *Self) u64 {
            return self.reader.bytes_read;
        }

        /// Moves to the next {
        pub fn nextObject(self: *Self) !void {
            const r = self.reader.reader();
            while (try r.readByte() != '{') {}
        }

        /// Moves to the next [
        pub fn nextArray(self: *Self) !void {
            const r = self.reader.reader();
            while (try r.readByte() != '[') {}
        }

        pub fn nextKey(self: *Self) ![]const u8 {
            const Static = struct { var buf: [255]u8 = undefined; };
            const r = self.reader.reader();
            while (try r.readByte() != '"') {}
            return try r.readUntilDelimiter(&Static.buf, '"');
        }

        pub fn nextNum(self: *Self) !f64 {
            const Static = struct { var buf: [255]u8 = undefined; };
            var b = try self.skipWhitespace();
            if (b == ':') b = try self.skipWhitespace();
            var i: usize = 0;
            const r = self.reader.reader();
            while (b == '-' or b == '+' or b == '.' or std.ascii.isDigit(b)) {
                Static.buf[i] = b; i+= 1;
                b = try r.readByte();
            }
            const float_str = mem.trim(u8, Static.buf[0..i], " ");
            return try std.fmt.parseFloat(f64, float_str);
        }

        /// returns first non whitespace byte
        fn skipWhitespace(self: *Self) !u8 {
            const r = self.reader.reader();
            var b = try r.readByte();
            while (std.ascii.isWhitespace(b)) { b = try r.readByte(); }
            return b;
        }
    };
}

fn nextFloat(reader: fs.File.Reader) !f64 {
    var buf: [8]u8 = undefined;
    try reader.readNoEof(&buf);
    return mem.bytesAsValue(f64, &buf).*;
}

fn parseAndCalculate(allocator: mem.Allocator, args: Args) !f64 {
    const data_json_file = try openFile(allocator, args, "data.json"); defer data_json_file.close();
    const hsin_json_file = try openFile(allocator, args, "hsin.json"); defer hsin_json_file.close();
    const data_f64_file  = try openFile(allocator, args, "data.f64");  defer data_f64_file .close();
    const hsin_f64_file  = try openFile(allocator, args, "hsin.f64");  defer hsin_f64_file .close();
    const validate = args.valid; if (validate) dstderr("validation enabled\n", .{});
    const bufjr = io.bufferedReader(data_json_file.reader());
    var djr = JSON_Reader(@TypeOf(bufjr)).init(bufjr); try djr.nextArray();
    const dfr = data_f64_file.reader();
    const hfr = hsin_f64_file.reader();
    var hjr = JSON_Reader(fs.File.Reader).init(hsin_json_file.reader()); try hjr.nextArray();
    var hsum: f64 = 0;
    var count: u32 = 0;
    while (true) {
        djr.nextObject() catch |err| switch (err) { error.EndOfStream => break, else => return err, };
        _ = try djr.nextKey(); const x0 = try djr.nextNum(); const x0pos = djr.getPos(); dstderr("[{d}]: {d}, ", .{x0pos, x0});
        _ = try djr.nextKey(); const y0 = try djr.nextNum(); const y0pos = djr.getPos(); dstderr("[{d}]: {d}, ", .{y0pos, y0});
        _ = try djr.nextKey(); const x1 = try djr.nextNum(); const x1pos = djr.getPos(); dstderr("[{d}]: {d}, ", .{x1pos, x1});
        _ = try djr.nextKey(); const y1 = try djr.nextNum(); const y1pos = djr.getPos(); dstderr("[{d}]: {d}\n", .{y1pos, y1});
        const hsin = haversine(x0, y0, x1, y1);
        hsum += hsin;
        count += 1;
        if (validate) {
            const err1 = "error: incorrect float at {d} byte, expected: {d}, got: {d}\n";
            const fx0 = try nextFloat(dfr); if (fx0 != x0) dstderr(err1, .{x0pos, fx0, x0});
            const fy0 = try nextFloat(dfr); if (fy0 != y0) dstderr(err1, .{y0pos, fy0, y0});
            const fx1 = try nextFloat(dfr); if (fx1 != x1) dstderr(err1, .{x1pos, fx1, x1});
            const fy1 = try nextFloat(dfr); if (fy1 != y1) dstderr(err1, .{y1pos, fy1, y1});
            const err2 = "error: incorrect Haversine distance for pairs: [{d}; {d}] [{d}; {d}] (at {d} byte), expected: {d}, got: {d}\n";
            const hsinj = try hjr.nextNum();  if (hsinj != hsin) dstderr(err2, .{ x0, y0, x1, y1, x0pos, hsinj, hsin });
            const hsinf = try nextFloat(hfr); if (hsinf != hsin) dstderr(err2, .{ x0, y0, x1, y1, x0pos, hsinf, hsin });
        }
    }
    const result = hsum / @as(f64, @floatFromInt(count));
    return result;
}

fn openFile( allocator: mem.Allocator, args: Args, suf: []const u8) !fs.File {
    const file_name = try mem.join(allocator, "-", &[_][]const u8{ args.name, suf });
    const file_path = try fs.path.join(allocator, &[_][]const u8{ args.path, file_name });
    return fs.cwd().openFile(file_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            dstderr("file '{s}' not found\n", .{file_path});
            return err;
        },
        else => return err,
    };
}

