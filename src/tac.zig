const std = @import("std");
const constants = @import("constants.zig");
const common = @import("common.zig");
const parser = @import("parser.zig");

const TacProgram = struct {
    func_def: TacFuncDef,
};

const TacFuncDef = struct {
    func: TacFunc,
};

const TacFunc = struct {
    ident: []const u8,
    body: []TacInstr,
};

const TacInstr = union(enum) {
    ret: TacVal,
    unary: TacUnary,
};

const TacUnary = struct {
    op: TacUnaryOp,
    src: TacVal,
    dst: TacVal,
};

const TacVal = union(enum) {
    constant: i32,
    variable: []const u8,
};

const TacUnaryOp = enum {
    invert,
    negate,
};

const Converter = struct {
    ctx: common.Ctx,
    tmp_cnt: u32,
};

pub fn convert_ast_to_tac_ir(ctx: common.Ctx, ast: parser.AstProgram) !TacProgram {
    var con = Converter{
        .ctx = ctx,
        .tmp_cnt = 0,
    };

    return try convert_program(&con, ast);
}

fn convert_program(con: *Converter, program: parser.AstProgram) !TacProgram {
    const func_def = try convert_func_def(con, program.func_def);
    return .{ .func_def = func_def };
}

fn convert_func_def(con: *Converter, func_def: parser.AstFuncDef) !TacFuncDef {
    var instrs_arr = std.ArrayList(TacInstr).init(con.ctx.temp_ally);
    defer instrs_arr.deinit();
    try convert_stmt(con, func_def.body, &instrs_arr);
    const instrs = try con.ctx.ally.alloc(TacInstr, instrs_arr.items.len);
    @memcpy(instrs, instrs_arr.items);
    return .{ .func = .{ .body = instrs, .ident = func_def.name } };
}

fn convert_stmt(con: *Converter, stmt: parser.AstStmt, instrs: *std.ArrayList(TacInstr)) !void {
    switch (stmt) {
        .return_stmt => |expr| {
            const ret_val = try convert_expr(con, expr, instrs);
            try instrs.append(.{ .ret = ret_val });
        },
    }
}

fn convert_expr(con: *Converter, expr: parser.AstExpr, instrs: *std.ArrayList(TacInstr)) !TacVal {
    switch (expr) {
        .unary => |unary| {
            const src = try convert_expr(con, unary.expr.*, instrs);
            const dst = try make_tmp(con);
            const op: TacUnaryOp = switch (unary.op) {
                .negate => .negate,
                .invert => .invert,
            };
            try instrs.append(.{ .unary = .{
                .src = src,
                .dst = dst,
                .op = op,
            } });
            return dst;
        },
        .int_literal => |int| return .{ .constant = int },
    }
}

fn make_tmp(con: *Converter) !TacVal {
    const tmp = try std.fmt.allocPrint(con.ctx.ally, "tmp.{d}", .{con.tmp_cnt});
    con.tmp_cnt += 1;
    return .{ .variable = tmp };
}
