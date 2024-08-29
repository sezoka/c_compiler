const common = @import("common.zig");
const constants = @import("constants.zig");
const parser = @import("parser.zig");

pub const IrNode = struct {
    ir_vart: IrVart,
};

pub const IrVart = union(enum) {
    program: IrFunctionDefinition,
    imm: constants.Int,
    instructions: []IrInstr,
    func_def: IrFunctionDefinition,
    instr: IrInstr,
};

const IrFunctionDefinition = struct {
    name: []const u8,
    instructions: *IrNode,
};

const IrInstr = union(enum) {
    mov: MovInstr,
    ret,
};

const MovInstr = struct {
    src: IrOperand,
    dst: IrOperand,
};

const IrOperand = union(enum) {
    imm: constants.Int,
    register,
};

const Converter = struct {
    ctx: common.Ctx,
};

pub fn convert_to_ir(ctx: common.Ctx, ast: *parser.AstNode) !*IrNode {
    var c = Converter{ .ctx = ctx };
    return convert_node(&c, ast);
}

fn convert_program(c: *Converter, func_def: *parser.AstNode) !IrFunctionDefinition {
    const func_def = try convert_func_def(c, func_def);
    return funcd_def;
}

fn convert_func_def(c: *Converter, func_def: *parser.AstNode) !IrFunctionDefinition {
}

fn convert_node(c: *Converter, node: *parser.AstNode) !*IrNode {
    switch (node.vart) {
        .program => |func_def| {
            const func_def_ir = try convert_node(c, func_def);
            return make_ir_node(c, .{ .program = func_def_ir });
        },
        // .function => |function| {
        //     const body_ir = try convert_node(c, function.body);
        //     return make_ir_node(c, .{ .func_def = .{
        //         .name = function.name,
        //         .instructions = body_ir,
        //     } });
        // },
        // .return_stmt => |ret_expr| {
        //     const ret_expr_ir = try convert_node(c, ret_expr);
        //     const instrs = try make_instructions(c, &.{
        //         init_ir_node(.{ .instr = .{ .mov = .{
        //             .src = .{ .imm = ret_expr_ir },
        //             .dst = .register,
        //         } } }),
        //         init_ir_node(.ret),
        //     });
        //     return make_ir_node(c, .{ .instructions = instrs });
        // },
        // .int_literal => |int| return make_ir_node(c, .{ .imm = int }),
    }
}

fn make_instructions(c: *Converter, instrs: []IrInstr) ![]IrInstr {
    const heap_instrs = try c.ctx.ally.alloc(IrInstr, instrs.len);
    @memcpy(heap_instrs, instrs);
}

fn make_ir_node(c: *Converter, vart: IrVart) !*IrNode {
    const node = try c.ctx.ally.create(IrNode);
    node.* = vart;
    return node;
}

fn init_ir_node(vart: IrVart) !*IrNode {
    return .{ .vart = vart };
}
