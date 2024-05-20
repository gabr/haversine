const std = @import("std");

pub fn Profiler(comptime AreasEnum: type) type {
    return struct {
        tinit:  u64,
        tstart: u64 = 0,
        areas: [areas_count]u64 = [_]u64{0} ** areas_count,

        const Self = @This();
        const areas_count = @typeInfo(AreasEnum).Enum.fields.len;
        const AreaPercent = struct { area: AreasEnum, percent: f64, };

        fn lessThan(_: void, lhs: AreaPercent, rhs: AreaPercent) bool {
            return lhs.percent > rhs.percent;
        }

        pub fn init() Self {
            return .{ .tinit = rdtsc() };
        }

        pub fn sum(self: *Self, writer: anytype) !void {
            var buf = std.io.bufferedWriter(writer);
            const bufw = buf.writer();
            var percents: [areas_count]AreaPercent = undefined;
            const total: f64 = @floatFromInt(rdtsc() - self.tinit);
            var rest: f64 = 100.0;
            for (self.areas, 0..) |a, i| {
                const f: f64 = @floatFromInt(a);
                const p = (f*100.0)/total;
                rest -= p;
                percents[i] = .{
                    .area = @enumFromInt(i),
                    .percent = p,
                };
            }
            std.mem.sort(AreaPercent, &percents, {}, lessThan);
            try bufw.print("profiler summary:\n", .{});
            for (percents) |p| {
                try bufw.print("  {s}: {d:.2}%\n", .{@tagName(p.area), p.percent});
            }
            try bufw.print("  rest: {d:.2}%\n", .{rest});
            try buf.flush();
        }

        pub inline fn start(self: *Self) void {
            self.tstart = rdtsc();
        }

        pub inline fn end(self: *Self, area: AreasEnum) void {
            self.areas[@intFromEnum(area)] += rdtsc() - self.tstart;
        }
    };
}

pub fn ProfiledReader(
    comptime ReaderType: type,
    comptime AreasEnum: type,
    area: AreasEnum,
) type {
    return struct {
        inner_reader: ReaderType,
        profiler: *Profiler(AreasEnum),

        pub const Error = ReaderType.Error;
        pub const Reader = std.io.Reader(*Self, Error, read);

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            self.profiler.start(); defer self.profiler.end(area);
            return try self.inner_reader.read(dest);
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

/// read CPU clocks
inline fn rdtsc() u64 {
    // https://www.felixcloutier.com/x86/rdtsc
    // https://www.felixcloutier.com/x86/rdtscp
    return asm (
        \\ rdtsc
        \\ sal $32, %%rdx
        \\ or %%rax, %%rdx
        : [ret] "={rdx}" (-> u64),
        :
        : "rax", "rdx");
}


