const std = @import("std");
const lexer = @import("lexer.zig");
const common = @import("common.zig");

const CompilerOptions = struct {
    only_lex: bool,
};

pub fn main() u8 {
    var options = CompilerOptions{ .only_lex = false };

    var args_iter = std.process.args();
    _ = args_iter.next();

    var src_path: ?[]const u8 = null;

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--lex")) {
            options.only_lex = true;
        } else {
            std.debug.assert(src_path == null);
            src_path = arg;
        }
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();

    const ally = arena.allocator();
    const temp_ally = temp_arena.allocator();

    const ctx = common.Ctx{ .ally = ally, .temp_ally = temp_ally };

    std.debug.assert(src_path != null);
    const file_src = std.fs.cwd().readFileAlloc(ally, src_path.?, 102400) catch return 1;

    const tokens = lexer.get_tokens(ctx, file_src) catch return 2;
    for (tokens) |token| {
        if (token.vart == .ident) {
            std.debug.print("{s}\n", .{token.vart.ident});
        } else {
            std.debug.print("{any}\n", .{token});
        }
    }

    if (options.only_lex) {
        return 0;
    }

    return 0;
}
