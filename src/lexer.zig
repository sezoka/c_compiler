const std = @import("std");
const constants = @import("constants.zig");
const common = @import("common.zig");
const log = @import("log.zig");

pub const TokenVart = union(enum) {
    ident: []const u8,
    int_literal: constants.Int,
    kw_int,
    kw_void,
    kw_return,
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    semicolon,
    eof,
};

pub const Token = struct {
    vart: TokenVart,
    line: u32,
    col: u32,
};

const Lexer = struct {
    i: usize,
    src: []const u8,
    ctx: common.Ctx,
    line: u32,
    col: u32,
    start_i: usize,
    start_line: u32,
    start_col: u32,
};

pub fn get_tokens(ctx: common.Ctx, src: []const u8) ![]Token {
    var l = Lexer{
        .i = 0,
        .src = src,
        .ctx = ctx,
        .line = 1,
        .col = 1,
        .start_line = 1,
        .start_col = 1,
        .start_i = 0,
    };
    var tokens = std.ArrayList(Token).init(ctx.ally);

    while (true) {
        const tok = try next_token(&l);
        try tokens.append(tok);
        if (tok.vart == .eof) {
            break;
        }
    }

    return tokens.items;
}

fn next_token(l: *Lexer) !Token {
    skip_whitespace(l);

    l.start_line = l.line;
    l.start_col = l.col;
    l.start_i = l.i;

    if (is_at_end(l)) {
        return make_token(l, .eof);
    }

    const c = advance(l);
    switch (c) {
        '{' => return make_token(l, .left_brace),
        '}' => return make_token(l, .right_brace),
        '(' => return make_token(l, .left_paren),
        ')' => return make_token(l, .right_paren),
        ';' => return make_token(l, .semicolon),
        0 => return make_token(l, .eof),
        else => {
            if (std.ascii.isAlphabetic(c) or c == '_') {
                return read_ident(l);
            }
            if (std.ascii.isDigit(c)) {
                return read_number(l);
            }
        },
    }

    return err(l, "unexpected character '{c}'", .{c});
}

fn read_number(l: *Lexer) !Token {
    while (!is_at_end(l) and !std.ascii.isWhitespace(peek(l)) and peek(l) != ';') {
        _ = advance(l);
    }
    const lex = get_lexeme(l);
    const int = std.fmt.parseInt(constants.Int, lex, 10) catch |e| {
        if (e == error.InvalidCharacter) {
            return err(l, "invalid number literal '{s}'", .{lex});
        } else {
            return err(l, "value '{s}' to large for type 'int'", .{lex});
        }
    };
    return make_token(l, .{ .int_literal = int });
}

fn read_ident(l: *Lexer) Token {
    while (!is_at_end(l) and (std.ascii.isAlphabetic(peek(l)) or peek(l) == '_' or std.ascii.isDigit(peek(l)))) {
        _ = advance(l);
    }
    const lexeme = get_lexeme(l);
    return make_token(l, .{ .ident = lexeme });
}

fn is_at_end(l: *Lexer) bool {
    return l.src.len <= l.i;
}

fn make_token(l: *Lexer, vart: TokenVart) Token {
    return .{ .vart = vart, .line = l.line, .col = l.col };
}

fn skip_whitespace(l: *Lexer) void {
    while (true) {
        switch (peek(l)) {
            '\n', '\r', '\t', ' ' => _ = advance(l),
            '/' => {
                if (peek_next(l) == '/') {
                    while (!is_at_end(l) and peek(l) != '\n') {
                        _ = advance(l);
                    }
                    _ = advance(l);
                } else if (peek_next(l) == '*') {
                    while (!is_at_end(l) and !(peek(l) == '*' and peek_next(l) == '/')) {
                        _ = advance(l);
                    }
                    _ = advance(l);
                    _ = advance(l);
                } else {
                    return;
                }
            },
            else => return,
        }
    }
}

fn peek(l: *Lexer) u8 {
    return if (is_at_end(l)) 0 else l.src[l.i];
}

fn peek_next(l: *Lexer) u8 {
    return if (l.i + 1 < l.src.len) l.src[l.i + 1] else 0;
}

fn advance(l: *Lexer) u8 {
    if (l.i < l.src.len) {
        const c = l.src[l.i];
        l.i += 1;
        if (c == '\n') {
            l.line += 1;
            l.col = 0;
        }
        l.col += 1;
        return c;
    } else {
        return 0;
    }
}

fn get_lexeme(l: *Lexer) []const u8 {
    return l.src[l.start_i..l.i];
}

fn err(l: *Lexer, comptime fmt: []const u8, args: anytype) error{LexerError} {
    log.err(fmt, args, "LexerError", l.start_line, l.start_col);
    return error.LexerError;
}

// fn err_token(l: *Lexer) error{LexerError} {
//     log.err("unexpected token '{}'", .{get_lexeme(l)}, "LexerError", l.start_line, l.start_col);
//     return error.LexerError;
// }
