const std = @import("std");
const common = @import("common.zig");
const constants = @import("constants.zig");
const parser = @import("parser.zig");

pub const IrProgram = struct {
    func_def: IrFuncDef,
};

pub const IrFuncDef = struct {
    name: []const u8,
    instrs: []const IrInstr,
};

pub const IrInstr = union(enum) {
    mov: IrMov,
    ret,
};

pub const IrMov = struct {
    src: IrOperand,
    dst: IrOperand,
};

pub const IrOperand = union(enum) {
    imm: constants.Int,
    register,
};

const InstrsBuff = std.ArrayList(IrInstr);

const Conv = struct {
    ctx: common.Ctx,
};

pub fn convert_ast_to_ir(ctx: common.Ctx, prog: *parser.AstProgram) !IrProgram {
    var c = Conv{
        .ctx = ctx,
    };

    return try convert_program(&c, prog);
}

fn convert_program(c: *Conv, prog: *parser.AstProgram) !IrProgram {
    return .{ .func_def = try convert_func_def(c, &prog.func_def) };
}

fn convert_func_def(c: *Conv, func_def: *parser.AstFuncDef) !IrFuncDef {
    var instrs_ir = InstrsBuff.init(c.ctx.ally);
    try convert_stmt(c, &instrs_ir, &func_def.body);
    return .{ .name = func_def.name, .instrs = instrs_ir.items };
}

fn convert_stmt(c: *Conv, buff: *InstrsBuff, stmt: *parser.AstStmt) !void {
    switch (stmt.*) {
        .return_stmt => |ret_expr| {
            const op = try convert_expr(c, buff, &ret_expr);
            try buff.append(.{ .mov = .{ .src = op, .dst = .register } });
            try buff.append(.ret);
        },
    }
}

// fn convert_operand(c: *Conv, buff: *InstrsBuff, stmt: *parser.AstStmt) !void {}

fn convert_expr(c: *Conv, buff: *InstrsBuff, expr: *const parser.AstExpr) !IrOperand {
    _ = buff;
    _ = c;
    switch (expr.*) {
        .int_literal => |int_literal| {
            return .{ .imm = int_literal };
        },
    }
}

fn make_instructions(c: *Conv, instrs: []IrInstr) ![]IrInstr {
    var heap_instrs = try c.ctx.ally.alloc(IrInstr, instrs.len);
    @memcpy(&heap_instrs, &instrs);
    return heap_instrs;
}
