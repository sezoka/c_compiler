const std = @import("std");
const log = @import("log.zig");
const lexer = @import("lexer.zig");
const constants = @import("constants.zig");
const common = @import("common.zig");

pub const AstProgram = struct {
    func_def: AstFuncDef,
};

pub const AstStmt = union(enum) {
    return_stmt: AstExpr,
};

pub const AstExpr = union(enum) {
    int_literal: constants.Int,
    unary: struct { op: UnaryOp, expr: *AstExpr },
};

const UnaryOp = enum {
    invert,
    negate,
};

pub const AstFuncDef = struct {
    name: []const u8,
    body: AstStmt,
};

pub const Parser = struct {
    ctx: common.Ctx,
    tokens: []lexer.Token,
    i: usize,
};

pub fn parse(ctx: common.Ctx, tokens: []lexer.Token) !AstProgram {
    var p = Parser{
        .ctx = ctx,
        .tokens = tokens,
        .i = 0,
    };

    const program = try parse_program(&p);

    if (peek(&p).vart != .eof) {
        return err(&p, "expected end of file but got '{s}'", .{peek(&p).lexeme});
    }

    return program;
}

fn parse_program(p: *Parser) !AstProgram {
    const func_def = try parse_func_def(p);
    return .{ .func_def = func_def };
}

fn parse_func_def(p: *Parser) !AstFuncDef {
    try consume(p, .kw_int, "expect 'int', but got '{s}'", .{peek(p).lexeme});
    const ident = (try expect_vart(p, .ident, "expect identifier after retyrn type, but got '{s}'", .{peek(p).lexeme}));
    try consume(p, .left_paren, "expect '(' after function name", .{});
    try consume(p, .kw_void, "expect 'void' as function param, but got '{s}'", .{peek(p).lexeme});
    try consume(p, .right_paren, "expect ')' after function params list", .{});
    try consume(p, .left_brace, "expect '{{' before function body", .{});
    const body = try parse_stmt(p);
    try consume(p, .right_brace, "expect '}}' after function body", .{});

    return .{
        .name = ident.ident,
        .body = body,
    };
}

fn parse_stmt(p: *Parser) !AstStmt {
    if (peek(p).vart == .kw_return) {
        _ = next(p);
        const expr = try parse_expr(p);
        try consume(p, .semicolon, "expect ';' after return value, but got '{s}'", .{peek(p).lexeme});
        return .{ .return_stmt = expr };
    }
    return err(p, "unexpected token '{s}'", .{peek(p).lexeme});
}

fn parse_expr(p: *Parser) !AstExpr {
    if (matches(p, .left_paren)) {
        const expr = try parse_expr(p);
        try consume(p, .right_paren, "expect ')' after expression, but got '{s}'", .{peek(p).lexeme});
        return expr;
    }

    if (matches_any_vart(p, &.{ .minus, .tilde })) |t| {
        const expr = try parse_expr(p);
        const expr_ptr = try p.ctx.ally.create(AstExpr);
        expr_ptr.* = expr;
        const op: UnaryOp = switch (t) {
            .minus => .negate,
            .tilde => .invert,
            else => unreachable,
        };
        return .{ .unary = .{ .op = op, .expr = expr_ptr } };
    }

    if (matches_vart(p, .int_literal)) |tok_vart| {
        return .{ .int_literal = tok_vart.int_literal };
    }

    return err(p, "unexpected token '{s}'", .{peek(p).lexeme});
}

fn matches_any_vart(p: *Parser, comptime varts: []const lexer.TokenTag) ?lexer.TokenTag {
    const tok = peek(p);
    for (varts) |vart| {
        if (vart == tok.vart) {
            _ = next(p);
            return vart;
        }
    }
    return null;
}

fn matches(p: *Parser, comptime vart: lexer.TokenTag) bool {
    if (vart == peek(p).vart) {
        _ = next(p);
        return true;
    }
    return false;
}

fn matches_vart(p: *Parser, comptime vart: lexer.TokenTag) ?lexer.TokenVart {
    const tok = peek(p);
    if (vart == tok.vart) {
        _ = next(p);
        return tok.vart;
    }
    return null;
}

fn consume(p: *Parser, tok_vart: lexer.TokenTag, comptime fmt: []const u8, args: anytype) !void {
    if (peek(p).vart != tok_vart)
        return err(p, fmt, args);
    _ = next(p);
}

fn expect_vart(p: *Parser, tok_vart: lexer.TokenTag, comptime fmt: []const u8, args: anytype) !lexer.TokenVart {
    if (peek(p).vart != tok_vart)
        return err(p, fmt, args);
    return next(p).vart;
}

fn peek(p: *Parser) lexer.Token {
    return p.tokens[p.i];
}

fn next(p: *Parser) lexer.Token {
    if (p.tokens[p.i].vart == .eof) {
        return p.tokens[p.i];
    }
    p.i += 1;
    return p.tokens[p.i - 1];
}

fn err(p: *Parser, comptime fmt: []const u8, args: anytype) error{LexerError} {
    log.err(fmt, args, "ParseError", peek(p).line, peek(p).col);
    return error.LexerError;
}

fn tag(tok_vart: lexer.TokenVart) lexer.TokenTag {
    return std.meta.activeTag(tok_vart);
}
