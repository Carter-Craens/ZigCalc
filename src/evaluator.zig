const std = @import("std");
const expect = std.testing.expect;
const Token = @import("token.zig").Token;
const TokenTag = @import("token.zig").TokenTag;
const parse = @import("parser.zig").parseExpression();
const freeExpr = @import("parser.zig").freeExpr;
const Expr = @import("parser.zig").Expr;

pub const EvalError = error{
    DivisionByZero,
    UnexpectedTokenTag,
} || std.mem.Allocator.Error;

pub fn eval(expr: *const Expr) EvalError!f64 {
    switch (expr.*) {
        .Number => |n| return n,
        .Binary => |b| {
            const left_child = try eval(b.left);
            const right_child = try eval(b.right);
            switch (b.op) {
                .Plus => return left_child + right_child,
                .Minus => return left_child - right_child,
                .Slash => {
                    if (right_child == 0) return error.DivisionByZero;
                    return left_child / right_child;
                },
                .Star => return left_child * right_child,
                .Caret => return std.math.pow(f64, left_child, right_child),
                else => return error.UnexpectedTokenTag,
            }
        },
        .Unary => |u| {
            switch (u.op) {
                .Minus => return -(try eval(u.child)),
                .Plus => return try eval(u.child),
                else => return error.UnexpectedTokenTag,
            }
        },
    }
}

test "Number Eval" {
    const allocator = std.testing.allocator;
    const n_exp = try allocator.create(Expr);

    n_exp.* = Expr{ .Number = 42.0 };

    try expect(try eval(n_exp) == 42.0);
    freeExpr(allocator, n_exp);
}

test "Binary Eval" {
    const allocator = std.testing.allocator;
    const b_exp = try allocator.create(Expr);
    const c1_exp = try allocator.create(Expr);
    const c2_exp = try allocator.create(Expr);

    c1_exp.* = Expr{ .Number = 2.0 };
    c2_exp.* = Expr{ .Number = 3.0 };
    b_exp.* = Expr{ .Binary = .{
        .op = .Star,
        .left = c1_exp,
        .right = c2_exp,
    } };

    try expect(try eval(b_exp) == 6.0);
    freeExpr(allocator, b_exp);
}

test "Unary Eval" {
    const allocator = std.testing.allocator;
    const u_exp = try allocator.create(Expr);
    const c1_exp = try allocator.create(Expr);

    c1_exp.* = Expr{ .Number = 7.5 };
    u_exp.* = Expr{ .Unary = .{
        .op = .Minus,
        .child = c1_exp,
    } };

    try expect(try eval(u_exp) == -7.5);
    freeExpr(allocator, u_exp);
}

test "Division by 0 error" {
    const allocator = std.testing.allocator;
    const b_exp = try allocator.create(Expr);
    const c1_exp = try allocator.create(Expr);
    const c2_exp = try allocator.create(Expr);

    c1_exp.* = Expr{ .Number = 2.0 };
    c2_exp.* = Expr{ .Number = 0.0 };
    b_exp.* = Expr{ .Binary = .{
        .op = .Slash,
        .left = c1_exp,
        .right = c2_exp,
    } };

    try std.testing.expectError(error.DivisionByZero, eval(b_exp));
    freeExpr(allocator, b_exp);
}

test "Wrong token error" {
    const allocator = std.testing.allocator;
    const b_exp = try allocator.create(Expr);
    const c1_exp = try allocator.create(Expr);
    const c2_exp = try allocator.create(Expr);

    c1_exp.* = Expr{ .Number = 2.0 };
    c2_exp.* = Expr{ .Number = 0.0 };
    b_exp.* = Expr{ .Binary = .{
        .op = .Indent,
        .left = c1_exp,
        .right = c2_exp,
    } };

    try std.testing.expectError(error.UnexpectedTokenTag, eval(b_exp));
    freeExpr(allocator, b_exp);
}
