const std = @import("std");
const lexer = @import("lexer.zig");
const common = @import("common.zig");
const parser = @import("parser.zig");
const asm_ast = @import("asm_ast.zig");
const codegen = @import("codegen.zig");

const CompilerOptions = struct {
    only_lex: bool,
    only_parse: bool,
    only_codegen: bool,
};

pub fn main() u8 {
    var options = CompilerOptions{ .only_lex = false, .only_parse = false, .only_codegen = false };

    var args_iter = std.process.args();
    _ = args_iter.next();

    var src_path: ?[]const u8 = null;

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--lex")) {
            options.only_lex = true;
        } else if (std.mem.eql(u8, arg, "--parse")) {
            options.only_parse = true;
        } else if (std.mem.eql(u8, arg, "--codegen")) {
            options.only_codegen = true;
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

    var ast = parser.parse(ctx, tokens) catch return 3;

    if (options.only_parse) {
        return 0;
    }

    const ir = asm_ast.convert_ast_to_ir(ctx, &ast) catch return 4;

    const asm_code = codegen.emit_program(ctx, ir) catch return 5;

    var basename = std.fs.path.basename(src_path.?);
    basename = basename[0..(basename.len - std.fs.path.extension(basename).len)];

    const out_asm_path = std.mem.concat(ally, u8, &.{
        std.fs.path.dirname(src_path.?).?,
        "/",
        basename,
        ".s",
    }) catch return 6;

    const out_path = std.mem.concat(ally, u8, &.{
        std.fs.path.dirname(src_path.?).?,
        "/",
        basename,
    }) catch return 6;

    std.fs.cwd().writeFile(.{
        .sub_path = out_asm_path,
        .data = asm_code,
    }) catch return 7;

    std.debug.print("{s}\n", .{asm_code});
    const c_args = [_][]const u8{ "gcc", out_asm_path, "-o", out_path };

    var gcc = std.process.Child.init(&c_args, ally);
    _ = gcc.spawnAndWait() catch return 8;

    return 0;
}
