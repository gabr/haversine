const std  = @import("std");
const math = std.math;

inline fn square(x: f64) f64 { return math.pow(f64, x, 2); }

// https://en.wikipedia.org/wiki/Haversine_formula
pub fn haversine(lon1: f64, lat1: f64, lon2: f64, lat2: f64) f64 {
    const earth_radius = 6372.8; // that's an averrage - there is no one eart radius
    const dlat = math.degreesToRadians(lat2 - lat1);
    const dlon = math.degreesToRadians(lon2 - lon1);
    const rlat1 = math.degreesToRadians(lat1);
    const rlat2 = math.degreesToRadians(lat2);
    const tmp = square(@sin(dlat/2.0)) + @cos(rlat1) * @cos(rlat2) * square(@sin(dlon/2.0));
    return earth_radius * 2.0 * math.asin(math.sqrt(tmp));
}
