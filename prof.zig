const std = @import("std");

pub fn Profiler(comptime AreasEnum: type) type {
    return struct {
        init_time:   u64 = 0,
        areas_sums:  [areas_count]u64 = [_]u64{0} ** areas_count,
        areas_start: [areas_count]u64 = [_]u64{0} ** areas_count,
        areas_count: [areas_count]u64 = [_]u64{0} ** areas_count,

        const Self = @This();
        const areas_count = @typeInfo(AreasEnum).Enum.fields.len;
        const AreaPercent = struct {
            area:    AreasEnum,
            percent: f64,
            cycles:  u64,

            pub fn lessThan(_: void, lhs: AreaPercent, rhs: AreaPercent) bool {
                return lhs.percent > rhs.percent;
            }
        };

        pub fn init(self: *Self) void {
            self.init_time = rdtsc();
        }

        pub fn sum(self: *Self, writer: anytype) !void {
            var buf = std.io.bufferedWriter(writer);
            const bufw = buf.writer();
            var percents: [areas_count]AreaPercent = undefined;
            const total: f64 = @floatFromInt(rdtsc() - self.init_time);
            for (self.areas_sums, 0..) |a, i| {
                const f: f64 = @floatFromInt(a);
                const p = (f*100.0)/total;
                percents[i] = .{
                    .area = @enumFromInt(i),
                    .percent = p,
                    .cycles = a,
                };
            }
            std.mem.sort(AreaPercent, &percents, {}, AreaPercent.lessThan);
            try bufw.print("profiler summary:\n", .{});
            for (percents) |p| {
                try bufw.print("  {s}: {d:.4}% [cycles: {d}]\n", .{@tagName(p.area), p.percent, p.cycles});
            }
            try buf.flush();
        }

        pub inline fn start(self: *Self, area: AreasEnum) void {
            const i = @intFromEnum(area);
            if (self.areas_start[i] == 0) {
                self.areas_start[i] = rdtsc();
            }
            self.areas_count[i] += 1;
        }

        pub inline fn end(self: *Self, area: AreasEnum) void {
            const i = @intFromEnum(area);
            std.debug.assert(self.areas_count[i] > 0);
            self.areas_count[i] -= 1;
            if (self.areas_count[i] == 0) {
                self.areas_sums[i] += rdtsc() - self.areas_start[i];
                self.areas_start[i] = 0;
            }
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
            self.profiler.start(area); defer self.profiler.end(area);
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


