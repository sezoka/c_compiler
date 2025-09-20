const lexer = @import("lexer.zig");
const std = @import("std");
const log = std.log;
const debug = std.debug;
const meta = std.meta;
const compiler = @import("compiler.zig");
const chelp = @import("c_helpers.zig");

pub const Program = struct {
    func_definition: Function,
};

pub const Function = struct {
    name: compiler.String,
    body: *Stmt,
};

pub const Stmt = struct {
    vart: StmtVart,
    loc: compiler.Location,
};

pub const StmtVart = union(enum) {
    return_: *Expr,
};

pub const ExprVart = union(enum) {
    constant: Value,
};

pub const Expr = struct {
    vart: ExprVart,
    loc: compiler.Location,
};

pub const Value = union(enum) {
    int: chelp.Int,
};

pub const Parser = struct {
    tokens: []lexer.Token,
    pos: u32,
    src: compiler.String,
    loc: compiler.Location,
};

fn peek(p: *Parser) *lexer.Token {
    if (p.pos < p.tokens.len) {
        return &p.tokens[p.pos];
    } else {
        return &p.tokens[p.tokens.len - 1];
    }
}

fn next(p: *Parser) *lexer.Token {
    if (p.pos < p.tokens.len) {
        const curr = &p.tokens[p.pos];
        p.loc = curr.loc;
        if (curr.vart != .eof) {
            p.pos += 1;
        }
        return curr;
    } else {
        return &p.tokens[p.tokens.len - 1];
    }
}

pub fn parse(tokens: []lexer.Token, src: compiler.String) !Program {
    var parser: Parser = .{
        .tokens = tokens,
        .pos = 0,
        .src = src,
        .loc = .{.start = 0, .end = 0, .line = 0},
    };
    const program = try parseProgram(&parser);
    if (peek(&parser).vart != .eof) {
        log.err("too many things in global scope", .{});
        return error.CompilerError;
    }
    return program;
}

fn parseProgram(p: *Parser) !Program {
    return .{
        .func_definition = try parseFunction(p),
    };
}

fn parseFunction(p: *Parser) !Function {
    _ = try expect(p, .kw_int);
    const ident = try expect(p, .ident);
    _ = try expect(p, .left_paren);
    _ = try expect(p, .kw_void);
    _ = try expect(p, .right_paren);
    _ = try expect(p, .left_brace);
    const body = try parseStmt(p);
    _ = try expect(p, .right_brace);
    return .{
        .name = ident.vart.ident,
        .body = body,
    };
}

fn getLoc(p: *Parser) compiler.Location {
    return p.loc;
}

fn parseStmt(p: *Parser) !*Stmt {
    const loc = getLoc(p);
    if (matches(p, .kw_return)) {
        const ret_expr = try parseExpr(p);
        _ = try expect(p, .semicolon);
        return makeStmt(p, loc, .{ .return_ = ret_expr });
    }
    unreachable;
}

fn parseExpr(p: *Parser) !*Expr {
    return parsePrimary(p);
}

fn parsePrimary(p: *Parser) !*Expr {
    const tok = next(p);
    switch (tok.vart) {
        .const_int => |int| {
            return makeExpr(p, tok.loc, .{ .constant = .{ .int = int } });
        },
        else => |tv| {
            log.err("parser: unexpected token '{any}'", .{tv});
            return error.CompilerError;
        }
    }
}

fn matches(p: *Parser, tv: lexer.TokenKind) bool {
    if (peek(p).vart == tv) {
        _ = next(p);
        return true;
    } else {
        return false;
    }
}

fn makeStmt(p: *Parser, start_loc: compiler.Location, vart: StmtVart) !*Stmt {
    const stmt = try compiler.arena.create(Stmt);
    const end_loc = getLoc(p);
    var loc = start_loc;
    loc.end = end_loc.end;
    stmt.vart = vart;
    stmt.loc = loc;
    return stmt;

}

fn makeExpr(p: *Parser, start_loc: compiler.Location, vart: ExprVart) !*Expr {
    const expr = try compiler.arena.create(Expr);
    const end_loc = getLoc(p);
    var loc = start_loc;
    loc.end = end_loc.end;
    expr.vart = vart;
    expr.loc = loc;
    return expr;
}


fn expect(p: *Parser, tok_tag: meta.Tag(lexer.TokenVart)) !*lexer.Token {
    const tok = peek(p);
    if (tok_tag == tag(tok.vart)) {
        return next(p);
    } else {
        log.err("expect '{s}', but got '{s}'", .{@tagName(tok_tag), @tagName(tok.vart)});
        return error.CompilerError;
    }
}

fn tag(v: anytype) meta.Tag(@TypeOf(v)) {
    return meta.activeTag(v);
}

pub fn printAst(program: Program, indent: u32) void {
    debug.print("Program(\n", .{});
    printIndent(indent + 1); debug.print("Function(\n", .{});
    printIndent(indent + 2); debug.print("name={s}\n", .{program.func_definition.name});
    printIndent(indent + 2); debug.print("body=", .{});
    printStmt(program.func_definition.body, indent + 2);
    printIndent(indent + 2); debug.print("\n", .{});
    printIndent(indent + 1); debug.print(")\n", .{});
    debug.print(")\n\n", .{});
}

fn printStmt(stmt: *Stmt, indent: u32) void {
    switch (stmt.vart) {
        .return_ => |return_expr| {
            debug.print("Return(\n", .{});
            printExpr(return_expr, indent+1);
            printIndent(indent); debug.print(")", .{});
        }
    }
}

fn printExpr(expr: *Expr, indent: u32) void {
    switch (expr.vart) {
        .constant => |c| {
            printIndent(indent); debug.print("Constant(", .{});
            switch (c) {
                .int => |int| {
                    debug.print("{d}", .{int});
                }
            }
            debug.print(")\n", .{});
        }
    }
}

fn printIndent(indent: u32) void {
    for (0..indent) |_| {
        debug.print("  ", .{});
    }
}
