const std = @import("std");
const expect = std.testing.expect;
const token = @import("token.zig");
const Token = token.Token;
const TokenTag = token.TokenTag;

// Returns the relevant tokenTag of non-number symbols
fn matchChar(c: u8) ?TokenTag {
    return switch (c) {
        '+' => TokenTag.Plus,
        '-' => TokenTag.Minus,
        '*' => TokenTag.Star,
        '/' => TokenTag.Slash,
        '^' => TokenTag.Caret,
        '(' => TokenTag.LParen,
        ')' => TokenTag.RParen,
        ',' => TokenTag.Comma,
        else => null,
    };
}

pub fn tokenize(allocator: std.mem.Allocator, input: []const u8) ![]Token {
    var tokenList = std.ArrayList(Token).empty;
    defer tokenList.deinit(allocator);
    // Loop over input and ad each existant token to the output arraylist
    var i: usize = 0;
    while (i < input.len) {
        const c = input[i];
        // Space
        if (std.ascii.isWhitespace(c)) {
            i += 1;
            continue;
        }

        // Numbers/values
        if (std.ascii.isDigit(c)) {
            const start = i;
            while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            if (i < input.len and input[i] == '.') {
                i += 1;

                // At least one digit must follow the dot
                if (i >= input.len or !std.ascii.isDigit(input[i])) {
                    return error.InvalidFloat;
                }

                while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            }
            const slice = input[start..i];
            try tokenList.append(allocator, Token{
                .tag = .Number,
                .lexeme = slice, // ← needs slice, not `c`
                .value = try std.fmt.parseFloat(f64, slice),
            });
            continue;
        }

        // Units
        if (std.ascii.isAlphabetic(c)) {
            const start = i;
            const previous = tokenList.getLastOrNull();

            // Units must be after number or )
            if (previous == null or (previous.?.tag != .Number and previous.?.tag != .LParen)) {
                return error.InvalidUnitPlace;
            }

            // Bare
            while (i < input.len and !std.ascii.isAlphabetic(input[i])) : (i += 1) {}

            // After letters, must be an operator.
            if (i < input.len and !std.ascii.isWhitespace(input[i])) {}

            continue;
        }

        // Non-number -> whitespace or symbol
        if (matchChar(c)) |tag| {
            try tokenList.append(allocator, Token{
                .tag = tag,
                .lexeme = input[i .. i + 1], // ← needs slice, not `c`
            });
            i += 1;
            continue;
        }
        return error.UnrecognizedCharacter;
    }
    try tokenList.append(allocator, Token{
        .tag = .End,
        .lexeme = "",
    });
    return try tokenList.toOwnedSlice(allocator);
}

test "matchString test" {
    const c: u8 = '+';
    try expect(matchChar(c) == TokenTag.Plus);
}

test "unknown char returns null test" {
    const c: u8 = '@';
    try expect(matchChar(c) == null);
}

test "basic Tokenizer test" {
    const allocator = std.testing.allocator;
    const input_string: []const u8 = "1.5 + 3";
    const tokens = try tokenize(allocator, input_string);
    defer allocator.free(tokens);
    try expect(tokens.len == 4);
    try expect(tokens[0].tag == .Number);
    try expect(tokens[1].tag == .Plus);
    try expect(tokens[2].tag == .Number);
    try expect(tokens[0].value == 1.5);
    try expect(tokens[3].tag == .End);
}
