const std = @import("std");

pub fn Profiler(comptime AreasEnum: type) type {
    return struct {
        init_cycles:   u64  = 0,
        init_os_time:  i128 = 0,
        enabled:       bool = true,
        areas_sums:    [areas_count]u64 = [_]u64{0} ** areas_count,
        areas_start:   [areas_count]u64 = [_]u64{0} ** areas_count,
        areas_count:   [areas_count]u64 = [_]u64{0} ** areas_count,

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
            self.init_cycles = rdtsc();
            self.init_os_time = std.time.nanoTimestamp();
        }

        pub fn sum(self: *Self, writer: anytype) !void {
            var buf = std.io.bufferedWriter(writer);
            const bufw = buf.writer();
            var percents: [areas_count]AreaPercent = undefined;
            const total_cycles: f64 = @floatFromInt(rdtsc() - self.init_cycles);
            const total_time = std.time.nanoTimestamp() - self.init_os_time;
            const total_ms = @as(f128, @floatFromInt(total_time))/@as(f128, @floatFromInt(std.time.ns_per_ms));
            const ms_per_cycle: f128 = total_cycles/total_ms;
            for (self.areas_sums, 0..) |a, i| {
                const f: f64 = @floatFromInt(a);
                const p = (f*100.0)/total_cycles;
                percents[i] = .{
                    .area = @enumFromInt(i),
                    .percent = p,
                    .cycles = a,
                };
            }
            std.mem.sort(AreaPercent, &percents, {}, AreaPercent.lessThan);
            try bufw.print("profiler summary:\n", .{});
            // construct in compile time the length of the first enum label column
            const area_name_width = comptime result: {
                var longest: usize = 0;
                for (@typeInfo(AreasEnum).Enum.fields) |f| {
                    if (f.name.len > longest) longest = f.name.len;
                }
                longest += 2; // padding
                var b = [_]u8 {0} ** 255;
                var i: usize = b.len-1;
                while (longest > 0) {
                    b[i] = @rem(longest, 10) + @as(u8, '0'); i -= 1;
                    longest = @divTrunc(longest, 10);
                }
                break :result b[i+1..];
            };
            for (percents) |p| {
                try bufw.print("  {s: <" ++ area_name_width ++ "} {d: >8.4}% [cycles: {d}] (aprox time: {d:.4}ms)\n",
                    .{@tagName(p.area), p.percent, p.cycles, @as(f128, @floatFromInt(p.cycles))/ms_per_cycle});
            }
            try bufw.print("  ------------------------------------\n", .{});
            try bufw.print("  total cycles: {d}\n",         .{total_cycles});
            try bufw.print("  total wall time: {d:.4}ms ({d:.2}s)\n", .{total_ms, total_ms/std.time.ms_per_s});
            try bufw.print("  ------------------------------------\n", .{});
            try buf.flush();
        }

        pub inline fn start(self: *Self, area: AreasEnum) void {
            if (!self.enabled) return;
            const i = @intFromEnum(area);
            if (self.areas_start[i] == 0) {
                self.areas_start[i] = rdtsc();
            }
            self.areas_count[i] += 1;
        }

        pub inline fn end(self: *Self, area: AreasEnum) void {
            if (!self.enabled) return;
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

pub fn ProfiledBufferedReader(
    comptime buffer_size:   usize,
    comptime ReaderType:    type,
    comptime AreasEnum:     type,
    comptime buffered_area: AreasEnum,
    comptime io_area:       AreasEnum,
) type {
    return struct {
        inner_reader: ReaderType,
        profiler: *Profiler(AreasEnum),
        buf: [buffer_size]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        pub const Error = ReaderType.Error;
        pub const Reader = std.io.Reader(*Self, Error, read);

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            self.profiler.start(buffered_area); defer self.profiler.end(buffered_area);
            var dest_index: usize = 0;

            while (dest_index < dest.len) {
                const written = @min(dest.len - dest_index, self.end - self.start);
                @memcpy(dest[dest_index..][0..written], self.buf[self.start..][0..written]);
                if (written == 0) {
                    // buf empty, fill it
                    self.profiler.end(buffered_area);
                    self.profiler.start(io_area);
                    const n = try self.inner_reader.read(self.buf[0..]);
                    self.profiler.end(io_area);
                    self.profiler.start(buffered_area);
                    if (n == 0) {
                        // reading from the inner stream returned nothing
                        // so we have nothing left to read.
                        return dest_index;
                    }
                    self.start = 0;
                    self.end = n;
                }
                self.start += written;
                dest_index += written;
            }
            return dest.len;
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


