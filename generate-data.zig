///usr/bin/env zig run -fno-llvm -fno-lld "$0" -- "$@"; exit
const std = @import("std");
const math = std.math;
const debug = std.debug;

/// outputs:
/// 1. output-data.json - the JSON output with the latitude and longitude paris
/// 2. output-data.f64  - binary file with the same floats as in output.json
/// 3. output-hsin.json - Haversine distance for each pair as a JSON
/// 4. output-hsin.f64  - Haversine distance for each pair as binary floats
/// 5. output-info.txt  - general info about generated data,
///                       parameters provided to the generator,
///                       amout of data produces, expected Haversine sum etc.
pub fn main() !void {
    var stdout_bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    defer stdout_bw.flush() catch unreachable;
    const stdout = stdout_bw.writer();
    _ = stdout;

    for (1..10) |i| { debug.print("i: {}\n", .{i}); }

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

}


fn square(x: f64) f64 { return math.pow(f64, x, 2); }

// https://en.wikipedia.org/wiki/Haversine_formula
fn haversine(lon0: f64, lat0: f64, lon1: f64, lat1: f64) f64 {
    const earth_radius = 6372.8; // that's an averrage
    const dlat = math.degreesToRadians(lat1 - lat0);
    const dlon = math.degreesToRadians(lon1 - lon0);
    const rlat0 = math.degreesToRadians(lat0);
    const rlat1 = math.degreesToRadians(lat1);
    const a = square(@sin(dlat/2.0)) + @cos(rlat0) * @cos(rlat1) * square(@sin(dlon/2.0));
    const c = 2.0*math.asin(math.sqrt(a));
    return earth_radius * c;
}

test { // zig test ./generate-data.zig
    _ = square;
    _ = haversine;
}
