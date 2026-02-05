pub const TokenTag = enum {
    Number,
    Indent,
    Plus,
    Minus,
    Star,
    Slash,
    Caret,
    LParen,
    RParen,
    Comma,
    End,
};

pub const Token = struct {
    tag: TokenTag,
    // For Number, store value; for Ident, store slice
    value: ?f64 = null,
    lexeme: []const u8,
};
