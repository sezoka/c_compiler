const std = @import("std");

pub fn err(comptime fmt: []const u8, args: anytype, comptime err_name: []const u8, line: ?u32, col: ?u32) void {
    std.debug.assert((line != null and col != null) or (line == null and col == null));
    if (line == null) {
        std.debug.print(err_name ++ ": " ++ fmt ++ "\n", args);
    } else {
        std.debug.print("[{d}:{d}]" ++ err_name ++ ": " ++ fmt ++ "\n", .{ line.?, col.? } ++ args);
    }
}
