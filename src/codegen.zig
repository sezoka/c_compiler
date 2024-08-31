const std = @import("std");
const common = @import("common.zig");
const asm_ast = @import("asm_ast.zig");

const Emitter = struct {
    buff: std.ArrayList(u8),
};

pub fn emit_program(ctx: common.Ctx, program: asm_ast.IrProgram) ![]u8 {
    var emitter = Emitter{
        .buff = std.ArrayList(u8).init(ctx.ally),
    };

    try emit_func_def(&emitter, program.func_def);

    try emitter.buff.appendSlice("\n    .section .note.GNU-stack,\"\",@progbits\n");

    return emitter.buff.items;
}

fn append(e: *Emitter, comptime fmt: []const u8, args: anytype) !void {
    try e.buff.writer().print(fmt, args);
}

fn emit_func_def(e: *Emitter, func_def: asm_ast.IrFuncDef) !void {
    try append(e, "    .global {s}\n", .{func_def.name});
    try append(e, "{s}:\n", .{func_def.name});
    for (func_def.instrs) |instr| {
        try emit_instr(e, instr);
    }
}

fn emit_instr(e: *Emitter, instr: asm_ast.IrInstr) !void {
    switch (instr) {
        .mov => |mov| {
            try append(e, "    movl ", .{});
            try emit_operand(e, mov.src);
            try append(e, ",", .{});
            try emit_operand(e, mov.dst);
            try append(e, "\n", .{});
        },
        .ret => {
            try append(e, "    ret\n", .{});
        },
    }
}

fn emit_operand(e: *Emitter, op: asm_ast.IrOperand) !void {
    switch (op) {
        .imm => |int| try append(e, "${d}", .{int}),
        .register => try append(e, "%eax", .{}),
    }
}
