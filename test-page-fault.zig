///usr/bin/env zig build-exe -fno-strip -O ReleaseFast "$0"; exit
// A simple program to test file read bandwidth
// example run: sudo ./test-page-fault &> pf.csv
const std        = @import("std");
const debugp     = std.debug.print;
const page_size  = std.mem.page_size;
const page_fault = @import("page-fault.zig");

var pagef_fd: std.os.linux.fd_t = -1;
var  pagef_start: usize = 0;
var minflt_start: isize = 0;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    pagef_fd = try page_fault.init();
    debugp("i, page, pagef, minflt, majflt\n", .{});
    pagef_start = page_fault.read(pagef_fd);
    minflt_start = std.posix.getrusage(0).minflt;
    var buf = try allocator.alloc(u8, page_size * 1000);
    var i: usize = 0; while (i < buf.len) : (i += page_size) { buf[i] = 1; report(i); }
    //var i: usize = buf.len - 1; while (i >= page_size) : (i -= page_size) { buf[i] = 1; report(i); }
}

inline fn report(i: usize) void {
    const page = @divTrunc(i, page_size);
    const pagef = page_fault.read(pagef_fd);
    const rusage = std.posix.getrusage(0);
    debugp("{d}, {d}, {d}, {d}, {d}\n", .{
        i,
        page,
        pagef         -  pagef_start,
        rusage.minflt - minflt_start,
        rusage.majflt
    });
}
