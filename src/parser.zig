const std = @import("std");
const expect = std.testing.expect;
const token = @import("token.zig");
const Token = token.Token;
const TokenTag = token.TokenTag;

pub const Expr = union(enum) {
    Number: f64,
    Unary: struct {
        op: TokenTag,
        child: *Expr,
    },
    Binary: struct {
        op: TokenTag,
        left: *Expr,
        right: *Expr,
    },
};

const ParserError = error{
    UnexpectedToken,
    ExpectedClosingParen,
    UnexpectedEndOfInput,
    ExpectedEndOfInput,
} || std.mem.Allocator.Error;

fn parsePrimary(tokens: []const Token, i: *usize, allocator: std.mem.Allocator) ParserError!*Expr {
    switch (tokens[i.*].tag) {
        .Number => {
            const expr = try allocator.create(Expr);
            expr.* = Expr{ .Number = tokens[i.*].value.? };
            i.* += 1;
            return expr;
        },
        .Plus => {
            i.* += 1;
            const child = try parsePrimary(tokens, i, allocator);
            const expr = try allocator.create(Expr);
            expr.* = Expr{ .Unary = .{ .op = .Plus, .child = child } };
            return expr;
        },
        .Minus => {
            i.* += 1;
            const child = try parsePrimary(tokens, i, allocator);
            const expr = try allocator.create(Expr);
            expr.* = Expr{ .Unary = .{ .op = .Minus, .child = child } };
            return expr;
        },
        .LParen => {
            i.* += 1;
            const exprInsideResult = parseExpression(tokens, i, allocator);
            const exprInside = exprInsideResult catch |err| {
                return err;
            };
            if (i.* == tokens.len or tokens[i.*].tag != .RParen) {
                freeExpr(allocator, exprInside);
                return error.ExpectedClosingParen;
            }
            i.* += 1;
            return exprInside;
        },
        .End => return error.UnexpectedEndOfInput,
        else => return error.UnexpectedToken,
    }
}

fn parseFactor(tokens: []const Token, i: *usize, allocator: std.mem.Allocator) ParserError!*Expr {
    const expr1 = try parsePrimary(tokens, i, allocator);
    if (i.* < tokens.len and tokens[i.*].tag == TokenTag.Caret) {
        i.* += 1;
        const expr2 = parseFactor(tokens, i, allocator) catch |err| {
            freeExpr(allocator, expr1);
            return err;
        };
        const expr = allocator.create(Expr) catch |err| {
            freeExpr(allocator, expr1);
            return err;
        };
        expr.* = Expr{ .Binary = .{ .op = .Caret, .left = expr1, .right = expr2 } };
        return expr;
    }
    return expr1;
}

fn parseTerm(tokens: []const Token, i: *usize, allocator: std.mem.Allocator) ParserError!*Expr {
    var expr = try parseFactor(tokens, i, allocator);
    while (i.* < tokens.len and (tokens[i.*].tag == .Slash or tokens[i.*].tag == .Star)) {
        const op = tokens[i.*].tag;
        i.* += 1;
        const right = parseFactor(tokens, i, allocator) catch |err| {
            freeExpr(allocator, expr);
            return err;
        };

        const new_expr = allocator.create(Expr) catch |err| {
            freeExpr(allocator, expr);
            freeExpr(allocator, right);
            return err;
        };
        new_expr.* = Expr{ .Binary = .{ .op = op, .left = expr, .right = right } };
        expr = new_expr;
    }
    return expr;
}

pub fn parseExpression(tokens: []const Token, i: *usize, allocator: std.mem.Allocator) ParserError!*Expr {
    var expr = try parseTerm(tokens, i, allocator);
    while (i.* < tokens.len and (tokens[i.*].tag == .Plus or tokens[i.*].tag == .Minus)) {
        const op = tokens[i.*].tag;
        i.* += 1;
        const right = parseTerm(tokens, i, allocator) catch |err| {
            freeExpr(allocator, expr);
            return err;
        };

        const new_expr = allocator.create(Expr) catch |err| {
            freeExpr(allocator, expr);
            freeExpr(allocator, right);
            return err;
        };
        new_expr.* = Expr{ .Binary = .{ .op = op, .left = expr, .right = right } };
        expr = new_expr;
    }
    return expr;
}

pub fn freeExpr(allocator: std.mem.Allocator, expr: *Expr) void {
    switch (expr.*) {
        .Number => {},
        .Unary => |u| {
            freeExpr(allocator, u.child);
        },
        .Binary => |b| {
            freeExpr(allocator, b.left);
            freeExpr(allocator, b.right);
        },
    }
    allocator.destroy(expr);
}

// TESTS
// Primary
test "Primary Number" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{
        Token{ .tag = .Number, .value = 13, .lexeme = "13" },
    };

    const expr = try parsePrimary(&tokens, &i, allocator);
    defer freeExpr(allocator, expr);

    switch (expr.*) {
        .Number => |n| try expect(n == 13),
        else => return error.TestExpectedNumber,
    }
    try expect(i == 1);
}

test "Primary Unary +" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{ Token{ .tag = .Plus, .lexeme = "+" }, Token{ .tag = .Number, .value = 313, .lexeme = "313" } };

    const expr = try parsePrimary(&tokens, &i, allocator);
    defer freeExpr(allocator, expr);

    switch (expr.*) {
        .Unary => |u| {
            try expect(u.op == TokenTag.Plus);

            switch (u.child.*) {
                .Number => |n| try expect(n == 313),
                else => return error.TestExpectedNumber,
            }
        },
        else => return error.TestExpectedUnary,
    }
    try expect(i == 2);
}

test "Primary Unary -" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{
        Token{ .tag = .Minus, .lexeme = "-" },
        Token{ .tag = .Number, .value = 313, .lexeme = "313" },
    };

    const expr = try parsePrimary(&tokens, &i, allocator);
    defer freeExpr(allocator, expr);

    switch (expr.*) {
        .Unary => |u| {
            try expect(u.op == TokenTag.Minus);

            switch (u.child.*) {
                .Number => |n| try expect(n == 313),
                else => return error.TestExpectedNumber,
            }
        },
        else => return error.TestExpectedUnary,
    }
    try expect(i == 2);
}

test "Primary Paren. expr" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{
        Token{ .tag = .LParen, .lexeme = "(" },
        Token{ .tag = .Minus, .lexeme = "-" },
        Token{ .tag = .Number, .value = 313, .lexeme = "313" },
        Token{ .tag = .RParen, .lexeme = ")" },
    };

    const expr = try parsePrimary(&tokens, &i, allocator);
    defer freeExpr(allocator, expr);

    switch (expr.*) {
        .Unary => |u| {
            try expect(u.op == TokenTag.Minus);

            switch (u.child.*) {
                .Number => |n| try expect(n == 313),
                else => return error.TestExpectedNumber,
            }
        },
        else => return error.TestExpectedUnary,
    }
    try expect(i == 4);
}

test "Primary Paren no close" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{
        Token{ .tag = .LParen, .lexeme = "(" },
        Token{ .tag = .Minus, .lexeme = "-" },
        Token{ .tag = .Number, .value = 313, .lexeme = "313" },
    };

    const result = parsePrimary(&tokens, &i, allocator);
    try std.testing.expectError(error.ExpectedClosingParen, result);
}

test "Primary wrong token" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{
        Token{ .tag = .Caret, .lexeme = "^" },
        Token{ .tag = .Minus, .lexeme = "-" },
        Token{ .tag = .Number, .value = 313, .lexeme = "313" },
    };

    try std.testing.expectError(error.UnexpectedToken, parsePrimary(&tokens, &i, allocator));
}

// Factor
test "Factor only primary" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{
        Token{ .tag = .Number, .value = 313, .lexeme = "313" },
        Token{ .tag = .Minus, .lexeme = "-" },
        Token{ .tag = .Number, .value = 313, .lexeme = "313" },
    };

    const expr = try parseFactor(&tokens, &i, allocator);
    defer freeExpr(allocator, expr);

    switch (expr.*) {
        .Number => |n| try expect(n == 313),
        else => return error.TestExpectedNumber,
    }
    try expect(i == 1);
}

test "Factor proper recurse" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{
        Token{ .tag = .Number, .value = 2, .lexeme = "313" },
        Token{ .tag = .Caret, .lexeme = "^" },
        Token{ .tag = .Number, .value = 3, .lexeme = "313" },
        Token{ .tag = .Caret, .lexeme = "^" },
        Token{ .tag = .Number, .value = 4, .lexeme = "313" },
    };

    const expr = try parseFactor(&tokens, &i, allocator);
    defer freeExpr(allocator, expr);

    switch (expr.*) {
        .Binary => |b| {
            try expect(b.op == .Caret);

            switch (b.left.*) {
                .Number => |n| try expect(n == 2),
                else => return error.TestExpectedNumber,
            }
            switch (b.right.*) {
                .Binary => |b1| {
                    try expect(b1.op == .Caret);

                    switch (b1.left.*) {
                        .Number => |n1| try expect(n1 == 3),
                        else => return error.TestExpectedNumber,
                    }

                    switch (b1.right.*) {
                        .Number => |n2| try expect(n2 == 4),
                        else => return error.TestExpectedNumber,
                    }
                },
                else => return error.TestExpectedBinary,
            }
        },
        else => return error.TestExpectedBinary,
    }

    try expect(i == 5);
}

// Term
test "Term simple" {
    const allocator = std.testing.allocator;
    var i: usize = 0;
    const tokens = [_]Token{
        Token{ .tag = .Number, .value = 2, .lexeme = "2" },
        Token{ .tag = .Slash, .lexeme = "/" },
        Token{ .tag = .Number, .value = 5, .lexeme = "5" },
        Token{ .tag = .Star, .lexeme = "*" },
        Token{ .tag = .Number, .value = 3, .lexeme = "3" },
    };

    const expr = try parseTerm(&tokens, &i, allocator);
    defer freeExpr(allocator, expr);

    switch (expr.*) {
        .Binary => |b| {
            try expect(b.op == .Star);
            switch (b.left.*) {
                .Binary => |b1| {
                    try expect(b1.op == .Slash);
                    switch (b1.left.*) {
                        .Number => |n| try expect(n == 2),
                        else => return error.TestExpectedNumber,
                    }
                    switch (b1.right.*) {
                        .Number => |n1| try expect(n1 == 5),
                        else => return error.TestExpectedNumber,
                    }
                },
                else => return error.TestExpectedBinary,
            }
            switch (b.right.*) {
                .Number => |n2| try expect(n2 == 3),
                else => return error.TestExpectedNumber,
            }
        },
        else => return error.TestExpectedBinary,
    }
    try expect(i == 5);
}

// Expression
