///usr/bin/env zig run -fno-llvm -fno-lld -fno-error-tracing "$0" -- "$@"; exit
// -fno-llvm           disables LLVM to have faster compile time
// -fno-lld            disables LLD to have faster linking time
// -fno-error-tracing  print only simple error message on error
const help =
\\generate-data
\\  A program for generating random latitude-longitude point
\\  pairs with Haversine distances calculated for each point.
\\
\\Usage:
\\  generate-data output name count [seed]
\\
\\    output  <string>  Existing location in which output files will be generated.
\\    name    <string>  Name prefix used for each of the generated output files.
\\    count   <u34>     Positive numeric value of how many pairs to generate.
\\    seed    <u64>     Optional positive numeric value used as a seed for randomness.
\\
\\The output of the program are files:
\\  1. name-data.json - the JSON data with the latitude and longitude pairs
\\  2. name-data.f64  - binary file with the same floats as in data.json
\\  3. name-hsin.json - Haversine distance for each pair as a JSON
\\  4. name-hsin.f64  - Haversine distance for each pair as binary floats
\\  5. name-info.txt  - summary and general info about the data
\\
\\Examples:
\\  # mkdir data
\\  # ./generate-data.zig data/ one   1
\\  # ./generate-data.zig data/ small 10
\\  # ./generate-data.zig data/ big   100000
\\  # ./generate-data.zig data/ huge  100000000
\\  # ./generate-data.zig data/ max   4294967295
\\  # KNOWN_SEED=13
\\  # ./generate-data.zig data/ retest 10 $KNOWN_SEED
\\
\\
;

const std       = @import("std");
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
    var out: Output = undefined;
    try out.init(allocator, args);
    // doing it like that to at least try to flush the data out in case of any error
    defer out.deinit() catch |err| dstderr("failed to deinit output files\nerror: {s}\n", .{@errorName(err)});
    try generate(allocator, args, &out);
}

const Args = struct {
    args:  [][:0]u8,
    out:   []const u8,
    name:  []const u8,
    count: u34,
    seed:  u64,

    /// Get command line arguments with initial validation and parsing.
    pub fn get(allocator: mem.Allocator) !Args {
        var a: Args = undefined;
        const stderr = std.io.getStdErr().writer();
        a.args = try std.process.argsAlloc(allocator);
        if (a.args.len < 4) { try stderr.writeAll(help); return error.NotEnoughArguments; }
        a.out = a.args[1];
        a.name = mem.trim(u8, a.args[2], " \t\n\r "); // the last one is hard space
        if (a.name.len == 0) { dstderr("empty name\n", .{}); return error.IncorrectArgument; }
        a.count = try parseInt(u32, a.args[3]);
        a.seed = if (a.args.len > 4) try parseInt(u64, a.args[4]) else 0x0123456789abcdef;
        return a;
    }

    fn parseInt(T: type, val: []const u8) !T {
        return std.fmt.parseInt(T, val, 10) catch |err| {
            dstderr("value: '{s}' failed to parse as a positive integer\n", .{val});
            return err;
        };
    }
};

pub const File = enum {
    data_json,
    data_f64,
    hsin_json,
    hsin_f64,
    info_txt
};

const Output = struct {
    dir:    fs.Dir,
    file:   [count]fs.File,
    buffer: [count]BufWriter,
    writer: [count]BufWriter.Writer,

    pub const count = @typeInfo(File).Enum.fields.len;
    pub const BufWriter = std.io.BufferedWriter(10*4096, fs.File.Writer);

    pub fn init(self: *Output, allocator: mem.Allocator, args: Args) !void {
        self.dir = fs.cwd().openDir(args.out, .{}) catch |err| {
            dstderr("cannot open output path '{s}'\n", .{args.out});
            return err;
        };
        for (0..count) |i| {
            // generate file name from enum
            const file_name = try allocator.dupe(u8, @tagName(@as(File, @enumFromInt(i))));
            file_name[4] = '.'; // replace _ with .
            self.file  [i] = try createFile(allocator, self.dir, args.name, file_name);
            self.buffer[i] = .{ .unbuffered_writer = self.file[i].writer() };
            self.writer[i] = self.buffer[i].writer();
        }
        try self.startJsons();
    }

    pub fn deinit(self: *Output) !void {
        try self.closeJsons();
        for (0..count) |i| {
            try self.buffer[i].flush();
                self.file  [i].close();
        }
        self.dir.close();
    }

    fn startJsons(self: *Output) !void {
        // write directly to file to skip buffer as it's size is calculated
        // for each data line without considering the header
        try self.file[@intFromEnum(File.data_json)].writer().writeAll("{\"pairs\":[\n");
        try self.file[@intFromEnum(File.hsin_json)].writer().writeAll("{\"haversine distances\":[\n");
    }

    fn closeJsons(self: *Output) !void {
        // remove tailing commas from files before closing
        try self.buffer[@intFromEnum(File.data_json)].flush();  // Flush out the buffers
        try self.buffer[@intFromEnum(File.hsin_json)].flush();  // so we can seek back in files.
        try self.file[@intFromEnum(File.data_json)].seekBy(-2); // Remove new line and the comma
        try self.file[@intFromEnum(File.hsin_json)].seekBy(-2); // in both files.
        // trust me I'm a highly trained kitten =^..^= <meow, meow, -2, meo>
        try self.writer[@intFromEnum(File.data_json)].writeAll("\n]}\n");
        try self.writer[@intFromEnum(File.hsin_json)].writeAll("\n]}\n");
    }

    /// Puts message both into info.txt file and stderr
    pub fn info(self: *Output, comptime fmt: []const u8, args: anytype) !void {
        dstderr(fmt, args);
        try self.writer[@intFromEnum(File.info_txt)].print(fmt, args);
    }

    /// Writes all the data to the correct float binary output files
    pub fn writeFloat(self: *Output, lon1: f64, lat1: f64, lon2: f64, lat2: f64, hsin: f64) !void {
        try self.writer[@intFromEnum(File.data_f64)].writeAll(&mem.toBytes(lon1));
        try self.writer[@intFromEnum(File.data_f64)].writeAll(&mem.toBytes(lat1));
        try self.writer[@intFromEnum(File.data_f64)].writeAll(&mem.toBytes(lon2));
        try self.writer[@intFromEnum(File.data_f64)].writeAll(&mem.toBytes(lat2));
        try self.writer[@intFromEnum(File.hsin_f64)].writeAll(&mem.toBytes(hsin));
    }

    /// Writes all the data to the correct json output files
    pub fn writeJson(self: *Output, lon1: f64, lat1: f64, lon2: f64, lat2: f64, hsin: f64) !void {
        const data_json_fmt = "  {{\"x0\":{d}, \"y0\":{d}, \"x1\":{d}, \"y1\":{d}}},\n";
        const hsin_json_fmt = "  {d},\n";
        try self.writer[@intFromEnum(File.data_json)].print(data_json_fmt, .{lon1, lat1, lon2, lat2});
        try self.writer[@intFromEnum(File.hsin_json)].print(hsin_json_fmt, .{hsin});
    }

    /// Creates file with given name prefix and suffix in given directory.
    /// Will fail if file already exists.
    fn createFile(allocator: mem.Allocator, outdir: fs.Dir, name: []const u8, suf: []const u8) !fs.File {
        const path = try mem.join(allocator, "-", &[_][]const u8{ name, suf });
        // the .exclusive = true is so we faile if the file already exist
        return outdir.createFile(path, .{ .exclusive = true }) catch |err| {
            dstderr("failed to create file: '{s}'\n", .{path});
            return err;
        };
    }
};

fn getRandomFloatInRange(rand: *std.Random, min: f64, max: f64) f64 {
    assert(max > min);
    const r = rand.float(f64);
    return (1.0 - r)*min + r*max;
}

fn generate(allocator: mem.Allocator, args: Args, out: *Output) !void {
    try out.info("cmd:   {s}\n", .{try mem.join(allocator, " ", args.args)});
    try out.info("out:   {s}\n", .{args.out});
    try out.info("name:  {s}\n", .{args.name});
    try out.info("count: {d}\n", .{args.count});
    try out.info("seed:  {d}\n", .{args.seed});
    var hsum: f64 = 0;
    var pcg = std.Random.Pcg.init(args.seed);
    var rand = pcg.random();
    for (0..args.count) |_| {
        const lon1 = getRandomFloatInRange(&rand, -180, 180);
        const lat1 = getRandomFloatInRange(&rand,  -90,  90);
        const lon2 = getRandomFloatInRange(&rand, -180, 180);
        const lat2 = getRandomFloatInRange(&rand,  -90,  90);
        const hsin = haversine(lon1, lat1, lon2, lat2);
        hsum += hsin;
        try out.writeFloat(lon1, lat1, lon2, lat2, hsin);
        try out.writeJson(lon1, lat1, lon2, lat2, hsin);
    }
    const havr = hsum / @as(f64, @floatFromInt(args.count));
    try out.info("\nHaversine sums average: {d}\n", .{havr});
}

