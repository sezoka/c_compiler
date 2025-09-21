const std = @import("std");
const process = std.process;
const mem = std.mem;
const heap = std.heap;
const log = std.log;
const compiler = @import("compiler.zig");

pub fn main() !void {
    var args_iter = process.args();
    var params: compiler.CompilerParams = .{};
    var maybe_source_path: ?compiler.String = null;

    _ = args_iter.next(); // skip exe path
    while (args_iter.next()) |arg| {
        if (mem.eql(u8, arg, "--lex")) {
            params.stop_after_lexer = true;
        } else if (mem.eql(u8, arg, "--parse")) {
            params.stop_after_parser = true;
        } else if (mem.eql(u8, arg, "--codegen")) {
            params.stop_after_codegen = true;
        } else if (mem.eql(u8, arg, "--tacky")) {
            params.stop_after_tacky = true;
        } else {
            if (maybe_source_path == null) {
                maybe_source_path = arg;
            } else {
                log.err("unexpected command line argument '{s}'", .{arg});
                return;
            }
        }
    }
    
    if (maybe_source_path) |source_path|  {
        compiler.run(source_path, params) catch |err| switch (err) {
            error.OutOfMemory => log.err("out of memory", .{}),
            error.CompilerError => {process.exit(1);},
        };
    } else {
        log.info("expected source path", .{});
    }
}
