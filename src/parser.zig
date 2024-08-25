const std = @import("std");
const log = @import("log.zig");
const lexer = @import("lexer.zig");
const constants = @import("constants.zig");
const common = @import("common.zig");

pub const AstNode = struct {
    vart: AstVart,
};

pub const AstVart = union(enum) {
    program: *AstNode,
    function: FunctionNode,
    return_stmt: *AstNode,
    int_literal: constants.Int,
};

pub const FunctionNode = struct {
    name: []const u8,
    body: *AstNode,
};

pub const Parser = struct {
    ctx: common.Ctx,
    tokens: []lexer.Token,
    i: usize,
};

pub fn parse(ctx: common.Ctx, tokens: []lexer.Token) !AstNode {
    var p = Parser{
        .ctx = ctx,
        .tokens = tokens,
        .i = 0,
    };

    const func_def = try parse_func_def(&p);

    if (peek(&p).vart != .eof) {
        return err(&p, "expected end of file but got '{s}'", .{peek(&p).lexeme});
    }

    return .{ .vart = .{ .program = func_def } };
}

fn make_node(p: *Parser, vart: AstVart) !*AstNode {
    const node = try p.ctx.ally.create(AstNode);
    node.* = .{
        .vart = vart,
    };
    return node;
}

fn parse_stmt(p: *Parser) !*AstNode {
    if (peek(p).vart == .kw_return) {
        _ = next(p);
        const expr = try parse_expr(p);
        try expect(p, .semicolon, "expect ';' after return value, but got '{s}'", .{peek(p).lexeme});
        return make_node(p, .{ .return_stmt = expr });
    }
    return err(p, "unexpected token '{s}'", .{peek(p).lexeme});
}

fn parse_func_def(p: *Parser) !*AstNode {
    try expect(p, .kw_int, "expect 'int', but got '{s}'", .{peek(p).lexeme});
    const ident = (try expect_vart(p, .ident, "expect identifier after retyrn type, but got '{s}'", .{peek(p).lexeme}));
    try expect(p, .left_paren, "expect '(' after function name", .{});
    try expect(p, .kw_void, "expect 'void' as function param, but got '{s}'", .{peek(p).lexeme});
    try expect(p, .right_paren, "expect ')' after function params list", .{});
    try expect(p, .left_brace, "expect '{{' before function body", .{});
    const body = try parse_stmt(p);
    try expect(p, .right_brace, "expect '}}' after function body", .{});

    return make_node(p, .{ .function = .{
        .name = ident.ident,
        .body = body,
    } });
}

fn parse_expr(p: *Parser) !*AstNode {
    const tok = next(p);
    if (tok.vart == .int_literal) {
        return make_node(p, .{ .int_literal = tok.vart.int_literal });
    }
    return err(p, "unexpected token '{s}'", .{peek(p).lexeme});
}

fn expect(p: *Parser, tok_vart: lexer.TokenTag, comptime fmt: []const u8, args: anytype) !void {
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
