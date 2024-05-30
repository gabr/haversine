/// This code allows you to measure page faults BUT REQUIRES SUDO!
/// To get page faults without sudo call: std.posix.getrusage(0)
const std = @import("std");
const linux = std.os.linux;

// https://stackoverflow.com/a/23308694

const err = std.math.maxInt(usize);
var perf_event_attr: linux.perf_event_attr = .{
    .type = linux.PERF.TYPE.SOFTWARE,
    .config = @intCast(@intFromEnum(linux.PERF.COUNT.SW.PAGE_FAULTS)),
    .flags = .{ .exclude_kernel = true, },
};

pub fn init() !linux.fd_t {
    // register performance counter
    const fd = try std.posix.perf_event_open(
        &perf_event_attr,
         0, // PID - 0 is the current process
        -1, // CPU - all cpus
        -1, // gropu_fd
         0, // flags
    );
    // start counting page faults
    if (linux.ioctl(fd, linux.PERF.EVENT_IOC.RESET,  0) == err) return error.PerfEventIocResetFailed;
    if (linux.ioctl(fd, linux.PERF.EVENT_IOC.ENABLE, 0) == err) return error.PerfEventIocEnableFailed;
    return fd;
}

pub inline fn read(fd: linux.fd_t) u64 {
    var res: u64 = 0;
    const read_count = linux.read(fd, std.mem.asBytes(&res), @sizeOf(@TypeOf(res)));
    if (read_count == err) @panic("reading page faults count failed");
    return res;
}
