const std = @import("std");
const debug = std.debug;
const log = std.log;
const meta = std.meta;
const fmt = std.fmt;
const chelp = @import("c_helpers.zig");
const compiler = @import("compiler.zig");

const keywords_map: std.StaticStringMap(TokenVart) = .initComptime(.{
    .{"return", .kw_return},
    .{"int", .kw_int},
    .{"void", .kw_void},
});

pub const Token = struct {
    vart: TokenVart,
    loc: compiler.Location,
    lexeme: compiler.String,
};

pub const TokenKind = meta.Tag(TokenVart);

pub const TokenVart = union(enum) {
    kw_int,
    ident: compiler.String,
    left_paren,
    kw_void,
    right_paren,
    left_brace,
    right_brace,
    kw_return,
    semicolon,
    const_int: chelp.Int,
    const_double: chelp.Double,
    eof,
};

const Tokenizer = struct {
    src: compiler.String,
    line: u32,
    pos: u32,
    start: u32,
};

pub fn tokenize(src: compiler.String) ![]Token {
    var tokens = std.ArrayList(Token){};
    defer tokens.deinit(compiler.gpa);

    var tokenizer: Tokenizer = .{
        .start = 0,
        .pos = 0,
        .src = src,
        .line = 1,
    };

    while (nextToken(&tokenizer)) |token| {
        try tokens.append(compiler.gpa, token);
        if (token.vart == .eof) {
            return try compiler.arena.dupe(Token, tokens.items);
        }
    }

    return error.CompilerError;
}

fn peek(t: *Tokenizer) u8 {
    if (t.pos < t.src.len) {
        return t.src[t.pos];
    } else {
        return 0;
    }
}

fn peekNext(t: *Tokenizer) u8 {
    if (t.pos + 1 < t.src.len) {
        return t.src[t.pos + 1];
    } else {
        return 0;
    }
}

fn next(t: *Tokenizer) u8 {
    if (t.pos < t.src.len) {
        const c = t.src[t.pos];
        if (c == '\n') {
            t.line += 1;
        }
        t.pos += 1;
        return c;
    } else {
        return 0;
    }
}

fn skipWhitespace(t: *Tokenizer) void {
    while (chelp.isSpace(peek(t)) or peek(t) == '/') {
        if (peek(t) == '/') {
            if (peekNext(t) == '/') {
                while (peek(t) != '\n') {
                    _ = next(t);
                }
            } else if (peekNext(t) == '*') {
                while (peek(t) != '*' or peekNext(t) != '/') {
                    _ = next(t);
                }
            }
        }
        _ = next(t);
    }
}

fn makeLoc(t: *Tokenizer) compiler.Location {
    return .{
        .start = t.start,
        .end = t.pos,
        .line = t.line,
    };
}

fn makeToken(t: *Tokenizer, vart: TokenVart) Token {
    return .{
        .loc = makeLoc(t),
        .vart = vart,
        .lexeme = getLexeme(t),
    };
}

fn nextToken(t: *Tokenizer) ?Token {
    skipWhitespace(t);

    t.start = t.pos;

    const c = next(t);
    switch (c) {
        '(' => return makeToken(t, .left_paren),
        ')' => return makeToken(t, .right_paren),
        '{' => return makeToken(t, .left_brace),
        '}' => return makeToken(t, .right_brace),
        ';' => return makeToken(t, .semicolon),
        0 => return makeToken(t, .eof),
        else => {
            if (isFirstIdentChar(c)) {
                return readIdent(t);
            } else if (isDigit(c)) {
                return readNumber(t);
            } else {
                log.err("lexer: unexpected character '{c}'", .{c});
                return null;
            }
        }
    }

    return null;
}

fn readNumber(t: *Tokenizer) ?Token {
    while (isDigit(peek(t))) {
        _ = next(t);
    }
    if (isIdentChar(peek(t))) { 
        log.err("lexer: identifier can't start with digit", .{});
        return null;
    }
    var is_double = false;
    if (peek(t) == '.') {
        is_double = true;
        _ = next(t);
    }
    while (isDigit(peek(t))) {
        _ = next(t);
    }
    if (isIdentChar(peek(t))) { 
        log.err("lexer: identifier can't start with digit", .{});
        return null;
    }
    const lexeme = getLexeme(t);
    if (is_double) {
        // TODO: validate that it is correct double value
        if (fmt.parseFloat(chelp.Double, lexeme)) |double| {
            return makeToken(t, .{ .const_double = double });
        } else |_| {
            log.err("lexer: can't represent '{s}' as double", .{lexeme});
            return null;
        }
    } else {
        if (fmt.parseInt(chelp.Int, lexeme, 10)) |int| {
            return makeToken(t, .{ .const_int = int });
        } else |_| {
            log.err("lexer: can't represent '{s}' as int", .{lexeme});
            return null;
        }

    }
    return undefined;
}

fn readIdent(t: *Tokenizer) Token {
    while (isIdentChar(peek(t))) {
        _ = next(t);
    }

    const lexeme = getLexeme(t);
    if (keywords_map.get(lexeme)) |kw_vart| {
        return makeToken(t, kw_vart);
    } else {
        return makeToken(t, .{.ident = lexeme});
    }
}

fn getLexeme(t: *Tokenizer) compiler.String {
    return t.src[t.start..t.pos];
}

fn isIdentChar(c: u8) bool {
    return isFirstIdentChar(c) or isDigit(c);
}

fn isDigit(c: u8) bool {
    return '0' <= c and c <= '9';
}

fn isFirstIdentChar(c: u8) bool {
    return switch (c) {
        'a'...'z', 'A'...'Z', '_' => true,
        else => return false,
    };
}

pub fn printTokens(tokens: []Token) void {
    for (tokens) |token| {
        debug.print(" '{s}' [{s}]", .{token.lexeme, @tagName(token.vart)});
        debug.print(" {any}", .{token.loc.line});
        debug.print("\n", .{});
    }
}
