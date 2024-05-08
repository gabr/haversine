///usr/bin/env zig run -fno-llvm -fno-lld -fno-error-tracing "$0" -- "$@"; exit
// -fno-llvm           disables LLVM to have faster compile time
// -fno-lld            disables LLD to have faster linking time
// -fno-error-tracing  print only simple error message on error
const std    = @import("std");
const stderr = std.debug.print;
const fs     = std.fs;
const assert = std.debug.assert;
const mem    = std.mem;
const math   = std.math;

// This is intentionally here and not inside Args struct because
// it acts also as a documentation for the source code reader.
const help =
\\generate-data.zig
\\  A program for generating random latitude and longitude point
\\  pairs with Haversine distances calculated for each point.
\\
\\Usage:
\\  ./generate-data.zig output name count [seed]
\\
\\    output  [string]  Existing location in which output files will be generated.
\\    name    [string]  Name prefix used for each of the generated output files.
\\    count   [u64]     Positive numeric value of how many pairs to generate.
\\    seed    [u64]     Optional positive numeric value used as a seed for randomness.
\\
\\The output of the program are files:
\\
\\  1. name-data.json - the JSON output with the latitude and longitude pairs
\\  2. name-data.f64  - binary file with the same floats as in output.json
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
\\  # ./generate-data.zig data/ max   18446744073709551615
\\  # KNOWN_SEED=13
\\  # ./generate-data.zig data/ retest 10 $KNOWN_SEED
\\
\\
;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    // Lack of arena.deinit() is intentional as there is no
    // need to free the memory in this short living program.
    // Same will go for all the allocations that will follow.
    const args = try Args.get(allocator);
    var out  = try Output.init(allocator, args);

    try out.info.txt.print("Test\n", .{});

    for (0..args.count) |i| { stderr("i: {}\n", .{i}); }

    // latitude  (y): [ -90;  90]
    // longitude (x): [-180; 180]
    // {"pairs":[
    //     {"x0":102.1633205722960440, "y0":-24.9977499718717624, "x1":-14.3322557404258362, "y1":62.6708294856625940},
    //     {"x0":106.8565762320475301, "y0":11.9375999763435772,  "x1":160.8862834978823457, "y1":69.1998577207801731},
    //     {"x0":-8.8878390193835415,  "y0":19.0969814947109811,  "x1":-46.8743926814281267, "y1":43.8734538780514995},
    //     {"x0":-14.6150077801348424, "y0":38.3262373436592725,  "x1":-44.3948041164556955, "y1":53.2633096739310474},
    //     {"x0":152.2097004499833020, "y0":28.8075361257721383,  "x1":150.6987913536557357, "y1":32.0449908116227959},
    //     {"x0":163.7513986349316610, "y0":32.3825205307932791,  "x1":152.5987721841468954, "y1":29.8302328719929157},
    //     {"x0":131.0675707860914372, "y0":47.0663770222409354,  "x1":123.5929119363244411, "y1":46.3284990503599943},
    //     {"x0":122.1332570844595011, "y0":47.1276485830673622,  "x1":122.2277624036606340, "y1":45.8344893091440824},
    //     {"x0":177.4032764475290946, "y0":-29.8936958880840180, "x1":93.6601882829341008,  "y1":-79.6531326321997426},
    //     {"x0":8.1610847750272519,   "y0":-38.2671013246085465, "x1":14.7521018520305667,  "y1":-61.2419556816616790}
    // ]}

    try out.deinit();
}

const Args = struct {
    args:  [][:0]u8,
    out:   []const u8,
    name:  []const u8,
    count: u64,
    seed:  u64,

    /// Get command line arguments with initial validation and parsing.
    pub fn get(allocator: mem.Allocator) !Args {
        var a: Args = undefined;
        a.args = try std.process.argsAlloc(allocator);
        if (a.args.len < 4) { stderr(help, .{}); return error.NotEnoughArguments; }
        a.out = a.args[1];
        a.name = mem.trim(u8, a.args[2], " \t\n\r "); // the last one is hard space
        if (a.name.len == 0) { stderr("empty name\n", .{}); return error.IncorrectArgument; }
        a.count = try parseU64(a.args[3]);
        a.seed = if (a.args.len > 4) try parseU64(a.args[4]) else 0;
        return a;
    }

    fn parseU64(val: []const u8) !u64 {
        return std.fmt.parseInt(u64, val, 10) catch |err| {
            stderr("value: '{s}' failed to parse as a positive integer\n", .{val});
            return err;
        };
    }
};

const Output = struct {
    // The structs are here to mimic the file names when accessing
    // the fields like: file "name-data.json" is: "Output.data.json".
    // See the help variable at the top to understand output structre.
    // These are meant to be accessed directly to write into files.
    data: struct { json: BufWriter.Writer, f64: BufWriter.Writer, },
    hsin: struct { json: BufWriter.Writer, f64: BufWriter.Writer, },
    info: struct { txt:  BufWriter.Writer, },
    // These are stored only for the deinit() function.
    dir: fs.Dir,
    file: struct {
        data: struct { json: fs.File, f64: fs.File, },
        hsin: struct { json: fs.File, f64: fs.File, },
        info: struct { txt:  fs.File, },
    },
    buffer: struct {
        data: struct { json: BufWriter, f64: BufWriter, },
        hsin: struct { json: BufWriter, f64: BufWriter, },
        info: struct { txt:  BufWriter, },
    },

    const BufWriter = std.io.BufferedWriter(4096, fs.File.Writer);

    pub fn init(allocator: mem.Allocator, args: Args) !*Output {
        var out: Output = undefined;
        out.dir = fs.cwd().openDir(args.out, .{}) catch |err| {
            stderr("cannot open output path '{s}'\n", .{args.out});
            return err;
        };
        out.file.data.json = try createFile(allocator, out.dir, args.name, "data.json");
        out.file.data.f64  = try createFile(allocator, out.dir, args.name, "data.f64" );
        out.file.hsin.json = try createFile(allocator, out.dir, args.name, "hsin.json");
        out.file.hsin.f64  = try createFile(allocator, out.dir, args.name, "hsin.f64" );
        out.file.info.txt  = try createFile(allocator, out.dir, args.name, "info.txt" );
        out.buffer.data.json = BufWriter { .unbuffered_writer = out.file.data.json.writer() };
        out.buffer.data.f64  = BufWriter { .unbuffered_writer = out.file.data.f64 .writer() };
        out.buffer.hsin.json = BufWriter { .unbuffered_writer = out.file.hsin.json.writer() };
        out.buffer.hsin.f64  = BufWriter { .unbuffered_writer = out.file.hsin.f64 .writer() };
        out.buffer.info.txt  = BufWriter { .unbuffered_writer = out.file.info.txt .writer() };
        out.data.json = out.buffer.data.json.writer();
        out.data.f64  = out.buffer.data.f64 .writer();
        out.hsin.json = out.buffer.hsin.json.writer();
        out.hsin.f64  = out.buffer.hsin.f64 .writer();
        out.info.txt  = out.buffer.info.txt .writer();
        return &out;
    }

    pub fn deinit(self: *Output) !void {
        try self.buffer.data.json.flush();
        try self.buffer.data.f64.flush();
        try self.buffer.hsin.json.flush();
        try self.buffer.hsin.f64.flush();
        try self.buffer.info.txt.flush();
        self.file.data.json.close();
        self.file.data.f64.close();
        self.file.hsin.json.close();
        self.file.hsin.f64.close();
        self.file.info.txt.close();
        self.dir.close();
    }

    /// Creates file with given name prefix and suffix in given directory.
    /// Will fail if file already exists.
    fn createFile(allocator: mem.Allocator, outdir: fs.Dir, name: []const u8, suf: []const u8) !fs.File {
        const path = try mem.join(allocator, "-", &[_][]const u8{ name, suf });
        // the .exclusive = true is so we faile if the file already exist
        return outdir.createFile(path, .{ .exclusive = true }) catch |err| {
            stderr("failed to create file: '{s}'\n", .{path});
            return err;
        };
    }
};

inline fn square(x: f64) f64 { return math.pow(f64, x, 2); }

// https://en.wikipedia.org/wiki/Haversine_formula
fn haversine(lon1: f64, lat1: f64, lon2: f64, lat2: f64) f64 {
    const earth_radius = 6372.8; // that's an averrage - there is no one eart radius
    const dlat = math.degreesToRadians(lat2 - lat1);
    const dlon = math.degreesToRadians(lon2 - lon1);
    const rlat1 = math.degreesToRadians(lat1);
    const rlat2 = math.degreesToRadians(lat2);
    const tmp = square(@sin(dlat/2.0)) + @cos(rlat1) * @cos(rlat2) * square(@sin(dlon/2.0));
    return earth_radius * 2.0 * math.asin(math.sqrt(tmp));
}

test { // zig test ./generate-data.zig
    _ = square;
    _ = haversine;
}
