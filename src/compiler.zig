const std = @import("std");
const process = std.process;
const log = std.log;
const debug = std.debug;
const mem = std.mem;
const heap = std.heap;
const fs = std.fs;
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");

const kilobyte = 1024;
const megabyte = kilobyte * 1024;
const gigabyte = gigabyte * 1024;

pub const String = []const u8;
pub const Location = struct {
    start: u32,
    end: u32,
    line: u32,
};

var gpa_state = heap.DebugAllocator(.{}){};
var arena_state = heap.ArenaAllocator.init(gpa_state.allocator());
var temp_arena_state = heap.ArenaAllocator.init(gpa_state.allocator());
pub const gpa = gpa_state.allocator();
pub const arena = arena_state.allocator();
pub const temp_arena = temp_arena_state.allocator();

pub const CompilerError = error {
    CompilerError,
};

pub const CompilerParams = struct {
    stop_after_lexer: bool = false,
    stop_after_parser: bool = false,
    stop_after_codegen: bool = false,
};

var compiler_params: CompilerParams = undefined;

fn deinitAllocators() void {
    temp_arena_state.deinit();
    arena_state.deinit();
    _ = gpa_state.deinit();
}

pub fn run(src_path: String, params: CompilerParams) !void {
    defer deinitAllocators();
    compiler_params = params;

    try readAndParseFile(src_path);
}

fn readAndParseFile(path: String) !void {
    const src = readFile(path);
    const tokens = try lexer.tokenize(src);
    lexer.printTokens(tokens);
    if (compiler_params.stop_after_lexer) {
        return;
    }

    const ast = try parser.parse(tokens, src);
    std.debug.print("{any}\n", .{ast});
    parser.printAst(ast, 0);
    if (compiler_params.stop_after_parser) {
        return;
    }
}

fn readFile(path: String) String {
    if (fs.cwd().openFile(path, .{})) |file| {
        defer file.close();
        var reader_buffer: [1024]u8 = undefined;
        var reader = file.reader(&reader_buffer);
        if (reader.getSize()) |file_size| {
            const file_buff = arena.alloc(u8, file_size) catch unreachable;
            if (reader.read(file_buff)) |readed_file_size| {
                debug.assert(file_size == readed_file_size);
                return file_buff;
            } else |err| {
                log.err("unable to read file '{s}'; reason: {}", .{path, err});
            }
        } else |err| {
            log.err("unable to read file '{s}'; reason: {}", .{path, err});
        }
    } else |err| {
        log.err("unable to open file '{s}'; reason: {}", .{path, err});
    }
    process.exit(1);
}
