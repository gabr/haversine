///usr/bin/env nasm -f elf64 ${0:0:-4}.asm -o asm.o && zig build-exe -O ReleaseFast -fPIC -freference-trace asm.o "$0" && rm ${0:0:-4}.o && ./${0:0:-4} "$@"; exit
const std    = @import("std");
const debugp = std.debug.print;
const assert = std.debug.assert;
const prof   = @import("prof.zig");

// generate that many enums - max 64
const enums_count = 64;
const ProfArea = result: {
    assert(enums_count <= 64);
    var decls = [_]std.builtin.Type.Declaration{};
    var fields: [enums_count]std.builtin.Type.EnumField = undefined;
    for (1..fields.len+1) |f| {
        var d = f;
        var name: [4]u8 = .{ 'b', '0', '0', 0 };
        name[2] = @as(u8,'0') + @rem(d,10); d = @divTrunc(d,10);
        if (d>0) name[1] = @as(u8,'0') + @rem(d,10);
        fields[f-1] = .{ .name = @ptrCast(&name), .value = f-1, };
    }
    break :result @Type(.{
        .Enum = .{
            .tag_type = std.math.IntFittingRange(0, fields.len - 1),
            .fields = &fields,
            .decls = &decls,
            .is_exhaustive = true,
        },
    });
};
const profEnabled = true;
var gprof: prof.Profiler(profEnabled, ProfArea) = .{};

const CacheTestFn = fn (n: u64, data: [*]u8, mask: u64) callconv(.C) void;
extern "asm" fn cacheTest1(n: u64, data: [*]u8, mask: u64) void;
extern "asm" fn cacheTest2(n: u64, data: [*]u8, mask: u64) void;
extern "asm" fn cacheTest3(n: u64, data: [*]u8, mask: u64) void;
extern "asm" fn cacheTest4(n: u64, data: [*]u8, mask: u64) void;
extern "asm" fn cacheTest5(n: u64, data: [*]u8, mask: u64) void;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    const data = try allocator.alloc(u8, (1024*1024*1024));
    for (data) |*d| { d.* = 1; } // toch all the data and set to something different than 0
    try testFn("cacheTest1", data, cacheTest1);
    try testFn("cacheTest2", data, cacheTest2);
    try testFn("cacheTest3", data, cacheTest3);
    try testFn("cacheTest4", data, cacheTest4);
    try testFn("cacheTest5", data, cacheTest5);
}

fn testFn(name: []const u8, data: []u8, func: CacheTestFn) !void {
    var mask: u64 = 0;
    const n: u64 = @intCast(data.len);
    debugp("testing: {s}\n", .{name});
    try gprof.init();
    inline for (@typeInfo(ProfArea).Enum.fields) |f| {
        gprof.area_data[f.value] += n;
        const area: ProfArea = @enumFromInt(f.value);
        //debugp("{s} start ...", .{f.name});
        mask = (mask << 1) | 0x1;
        //debugp("{d}", .{mask});
        gprof.start(area);
        func(n, data.ptr, mask);
        gprof.end(area);
        //debugp(" end\n", .{});
    }
    try gprof.sum(std.io.getStdErr().writer(), false);
}
