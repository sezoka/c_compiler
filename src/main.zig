const std = @import("std");
const lexer = @import("lexer.zig");
const common = @import("common.zig");
const parser = @import("parser.zig");
// const asm_ast = @import("asm_ast.zig");

const CompilerOptions = struct {
    only_lex: bool,
    only_parse: bool,
};

pub fn main() u8 {
    var options = CompilerOptions{ .only_lex = false, .only_parse = false };

    var args_iter = std.process.args();
    _ = args_iter.next();

    var src_path: ?[]const u8 = null;

    while (args_iter.next()) |arg| {
        std.debug.print("{s}\n", .{arg});
        if (std.mem.eql(u8, arg, "--lex")) {
            options.only_lex = true;
        } else if (std.mem.eql(u8, arg, "--parse")) {
            options.only_parse = true;
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

    if (options.only_lex) {
        return 0;
    }

    const ast = parser.parse(ctx, tokens) catch return 3;

    if (options.only_parse) {
        return 0;
    }

    // const ir = asm_ast.convert_to_ir(ctx, &ast);

    std.debug.print("{any}\n", .{ast});

    return 0;
}
