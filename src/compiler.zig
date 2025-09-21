const std = @import("std");
const process = std.process;
const log = std.log;
const debug = std.debug;
const mem = std.mem;
const heap = std.heap;
const fs = std.fs;
const fs_path = fs.path;
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const x86_64 = @import("x86_64.zig");
const tac = @import("tac.zig");

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
    OutOfMemory,
};

pub const CompilerParams = struct {
    stop_after_lexer: bool = false,
    stop_after_parser: bool = false,
    stop_after_codegen: bool = false,
    stop_after_tacky: bool = false,
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
    // const path_without_ext = removeCExt(path);
    const tokens = try lexer.tokenize(src);
    // lexer.printTokens(tokens);
    if (compiler_params.stop_after_lexer) {
        return;
    }

    const ast = try parser.parse(tokens, src);
    // parser.printAst(ast, 0);
    if (compiler_params.stop_after_parser) {
        return;
    }

    const tac_prog = try tac.astToTac(ast);
    tac.printTac(&tac_prog);
    if (compiler_params.stop_after_tacky) {
        return;
    }

    // const x64program = try x86_64.astToX64(&ast);

    // // x86_64.printAsm(x64program);
    // const asm_code = try x86_64.emitAsm(x64program);
    // writeFile("./tmp.s", asm_code);
    // if (compiler_params.stop_after_codegen) {
    //     return;
    // }
    //
    // spawnGCC("./tmp.s", path_without_ext);
    //
    // deleteFile("./tmp.s");
}

fn deleteFile(path: String) void {
    if (fs.cwd().deleteFile(path)) {
        return;
    } else |_| {
        return;
    }
}

fn removeCExt(path: String) String {
    if (mem.endsWith(u8, path, ".c")) {
        return path[0..path.len - 2];
    } else {
        return path;
    }
}

fn spawnGCC(asm_path: String, out_path: String) void {
    const args = [_][]const u8{"gcc", asm_path, "-o", out_path};
    var gcc_process = process.Child.init(&args, gpa);
    if (gcc_process.spawnAndWait()) |_| {
        return;
    } else |err| {
        log.err("unable to spawn gcc, reason: {}", .{err});
    }
    process.exit(1);
}

// fn addCExt(path: String) String {
//     if (mem.eql(u8, path[path.len-2..path.len], ".c")) {
//         return path;
//     } else {
//         const buff = temp_arena.alloc(u8, path.len + 2) catch unreachable;
//         @memcpy(buff[0..path.len], path);
//         buff[buff.len - 2] = '.';
//         buff[buff.len - 1] = 'c';
//         return buff;
//     }
// }

fn writeFile(path: String, data: []const u8) void {
    if (fs.cwd().createFile(path, .{})) |file| {
        defer file.close();
        var write_buffer: [1024]u8 = undefined;
        var writer = file.writer(&write_buffer);
        if (writer.interface.writeAll(data)) {
            if (writer.interface.flush()) {
                return;
            } else |err| {
                log.err("unable to write file '{s}'; reason: {}", .{path, err});
            }
        } else |err| {
            log.err("unable to write file '{s}'; reason: {}", .{path, err});
        }
    } else |err| {
        log.err("unable to create file '{s}'; reason: {}", .{path, err});
    }
    process.exit(1);
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
