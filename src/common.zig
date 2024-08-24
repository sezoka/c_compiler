const std = @import("std");

pub const Ctx = struct {
    temp_ally: std.mem.Allocator,
    ally: std.mem.Allocator,
};
