///usr/bin/env nasm -f elf64 ${0:0:-4}.asm -o asm.o && zig build-exe -O ReleaseFast -fPIC -freference-trace asm.o "$0" && rm ${0:0:-4}.o && ./${0:0:-4} "$@"; exit
const std    = @import("std");
const debugp = std.debug.print;
const prof   = @import("prof.zig");

// generate 64 enums
const ProfArea = result: {
    var decls = [_]std.builtin.Type.Declaration{};
    var fields: [64]std.builtin.Type.EnumField = undefined;
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

extern "asm" fn cacheTest(n: u64, data: [*]u8, mask: u64) void;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    const data = try allocator.alloc(u8, (1024*1024*1024));
    const n: u64 = @intCast(data.len);
    var mask: u64 = 0;
    for (data) |*d| { d.* = 1; } // toch all the data and set to something different than 0
    inline for (@typeInfo(ProfArea).Enum.fields) |f| { gprof.area_data[f.value] += n; }
    try gprof.init();
    inline for (@typeInfo(ProfArea).Enum.fields) |f| {
        const area: ProfArea = @enumFromInt(f.value);
        debugp("{s} start ...", .{f.name});
        mask = (mask << 1) | 0x1;
        debugp("{d}", .{mask});
        gprof.start(area);
        cacheTest(n, data.ptr, mask);
        gprof.end(area);
        debugp(" end\n", .{});
    }
    try gprof.sum(std.io.getStdErr().writer(), false);
}
