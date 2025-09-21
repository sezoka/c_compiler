const std = @import("std");
const debug = std.debug;
const compiler = @import("compiler.zig");
const parser = @import("parser.zig");
const chelp = @import("c_helpers.zig");

const Program = struct {
    func_def: Function,
};

const Function = struct {
    name: compiler.String,
    instructions: []Instruction,
};

const Instruction = union(enum) {
    ret,
    mov: Mov,
};

const Mov = struct {
    src: Operand,
    dst: Operand,
};

const Operand = union(enum) {
    imm: chelp.Int,
    register,
};

const InstructionsList = std.ArrayList(Instruction);

pub fn astToX64(prog: *const parser.Program) !Program {
    return convertProgram(prog);
}

fn convertProgram(prog: *const parser.Program) !Program {
    return Program {
        .func_def = try convertFunction(&prog.func_definition),
    };
}

fn convertFunction(func: *const parser.Function) !Function {
    var instructions = std.ArrayList(Instruction){};
    defer instructions.deinit(compiler.gpa);
    try convertStmt(func.body, &instructions);

    return Function {
        .name = func.name,
        .instructions = try compiler.arena.dupe(Instruction, instructions.items),
    };
}

fn convertStmt(stmt: *parser.Stmt, instructions: *InstructionsList) !void {
    switch (stmt.vart) {
        .return_ => |expr| {
            const mov = Mov {
                .src = try convertExpr(expr, instructions),
                .dst = .register,
            };
            try instructions.append(compiler.gpa, .{ .mov = mov });
            try instructions.append(compiler.gpa, .ret);
        },
    }
}

fn convertExpr(expr: *parser.Expr, instructions: *InstructionsList) !Operand {
    _ = instructions;

    switch (expr.vart){ 
        .constant => |val| {
            switch (val) {
                .int => {
                    return convertValue(val);
                }
            }
        },
        else => unreachable,
    }
}

fn convertValue(val: parser.Value) Operand {
    switch (val) {
        .int => |int| {
            return .{ .imm = int };
        }
    }
}

pub fn printAsm(prog: Program) void {
    debug.print("fn {s}:\n", .{prog.func_def.name});
    for (prog.func_def.instructions) |instr| {
        debug.print("  ", .{});
        switch (instr) {
            .ret => debug.print("ret", .{}),
            .mov => |mov| {
                debug.print("mov ", .{});
                printOperand(mov.src);
                debug.print(" ", .{});
                printOperand(mov.dst);
            },
        }
        debug.print("\n", .{});
    }
}

pub fn printOperand(op: Operand) void {
    switch (op) {
        .imm => |v| debug.print("{d}", .{v}),
        .register => debug.print("eax", .{}),
    }
}


const Emitter = struct {
    buff: std.ArrayList(u8),
};

pub fn emitAsm(prog: Program) !compiler.String {
    var emitter: Emitter = .{
        .buff = .{},
    };
    defer emitter.buff.deinit(compiler.gpa);
    try emitFunc(&emitter, prog.func_def);
    try emitter.buff.appendSlice(compiler.gpa, ".section .note.GNU-stack,\"\",@progbits\n");

    return compiler.arena.dupe(u8, emitter.buff.items);
}

fn emitFunc(e: *Emitter, func: Function) !void {
    try e.buff.print(compiler.gpa, "\t.globl {s}\n", .{func.name});
    try e.buff.print(compiler.gpa, "{s}:\n", .{func.name});
    for (func.instructions) |instr| {
        try emitInstr(e, instr);
    }
}

fn emitInstr(e: *Emitter, instr: Instruction) !void {
    switch (instr) {
        .ret => {
            try e.buff.appendSlice(compiler.gpa, "\tret\n");
        },
        .mov => |mov| {
            try e.buff.appendSlice(compiler.gpa, "\tmovl ");
            try emitOperand(e, mov.src);
            try e.buff.appendSlice(compiler.gpa, ", ");
            try emitOperand(e, mov.dst);
            try e.buff.appendSlice(compiler.gpa, "\n");
        }
    }
}

fn emitOperand(e: *Emitter, op: Operand) !void {
    switch (op) {
        .register => {
            try e.buff.appendSlice(compiler.gpa, "%eax");
        },
        .imm => |int| {
            try e.buff.print(compiler.gpa, "${d}", .{int});
        }
    }
}
