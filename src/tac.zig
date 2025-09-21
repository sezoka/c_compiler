const std = @import("std");
const fmt = std.fmt;
const debug = std.debug;
const compiler = @import("compiler.zig");
const chelp = @import("c_helpers.zig");
const parser = @import("parser.zig");


const Program = struct {
    func_def: FuncDef,
};

const FuncDef = struct {
    name: compiler.String,
    body: []Instruction,
};

const Instruction = union(enum) {
    return_: Value,
    unary: Unary,
};

const Value = union(enum) {
    constant: chelp.Int,
    variable: compiler.String,
};

const Unary = struct {
    op: UnaryOp,
    src: Value,
    dst: Value,
};

const UnaryOp = enum {
    complement,
    negate,
};

const Tacky = struct {
    temp_id: u32,
};

pub fn astToTac(ast: parser.Program) !Program {
    var tac: Tacky = .{
        .temp_id = 0,
    };
    return try convertProgram(&tac, ast);
}

const InstructionsList = std.ArrayList(Instruction);

fn convertProgram(t: *Tacky, prog: parser.Program) !Program {
    return Program {
        .func_def = try convertFunction(t, prog.func_definition),
    };
}

fn convertFunction(t: *Tacky, func: parser.Function) !FuncDef {
    var instrs: InstructionsList = .{};
    defer instrs.deinit(compiler.gpa);

    try convertStmt(t, func.body, &instrs);

    return FuncDef {
        .name = func.name,
        .body = try compiler.arena.dupe(Instruction, instrs.items),
    };
}

fn convertStmt(t: *Tacky, stmt: *parser.Stmt, instrs: *InstructionsList) !void {
    switch (stmt.vart) {
        .return_ => |expr| {
            const val = try convertExpr(t, expr, instrs);
            try instrs.append(compiler.gpa, Instruction{
                .return_ = val,
            });
        }
    }
}

fn convertExpr(t: *Tacky, expr: *parser.Expr, instrs: *InstructionsList) !Value {
    switch (expr.vart) {
        .constant => |val| {
            switch (val) {
                .int => |int| {
                    return Value{ .constant = int };
                }
            }
        },
        .unary => |unary| {
            const src = try convertExpr(t, unary.expr, instrs);
            const dst = try makeTempVar(t);
            const op: UnaryOp = switch (unary.op) {
                .complement => .complement,
                .negate => .negate,
            };

            try instrs.append(compiler.gpa, Instruction{
                .unary = .{
                    .op = op,
                    .src = src,
                    .dst = dst,
                }
            });

            return dst;
        }
    }
}

fn makeTempVar(t: *Tacky) !Value {
    const tmp_name = try fmt.allocPrint(compiler.arena, "tmp.{d}", .{t.temp_id});
    t.temp_id += 1;
    return Value{ .variable = tmp_name };
}

pub fn printTac(prog: *const Program) void {
    debug.print("Program(\n", .{});
    printFunc(&prog.func_def);
    debug.print(")\n", .{});
}

fn printFunc(func: *const FuncDef) void {
    debug.print("  {s}(\n", .{func.name});
    for (func.body) |instr| {
        switch (instr) {
            .return_ => |val| {
                debug.print("    return\t", .{});
                printVal(val);
                debug.print("\n", .{});
            },
            .unary => |unary| {
                switch (unary.op) {
                    .negate => debug.print("    unary(-)\t", .{}),
                    .complement => debug.print("    unary(~)\t", .{}),
                }
                printVal(unary.dst);
                debug.print(" ", .{});
                printVal(unary.src);
                debug.print("\n", .{});
            }
        }
    }
    debug.print("  )\n", .{});
}

fn printVal(val: Value) void {
    switch (val) {
        .constant => |int| debug.print("{d}", .{int}),
        .variable => |v| debug.print("{s}", .{v}),
    }
}
