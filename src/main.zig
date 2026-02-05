const std = @import("std");
const Allocator = std.heap.Allocator;
const token = @import("token.zig");
const Token = token.Token;
const TokenTag = token.TokenTag;
const parser = @import("parser.zig");
const lexer = @import("lexer.zig");
const evaluator = @import("evaluator.zig");

// REPL and main loop
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_alloc = gpa.allocator();

    // Prepare stdio-backed reader/writer + their buffers
    var in_buf: [1024]u8 = undefined;
    var out_buf: [1024]u8 = undefined;
    var err_buf: [1024]u8 = undefined;

    var stdin = std.fs.File.stdin().reader(&in_buf);
    var stdout = std.fs.File.stdout().writer(&out_buf);
    var stderr = std.fs.File.stderr().writer(&err_buf);
    const r = &stdin.interface;
    const w = &stdout.interface;
    const err_w = &stderr.interface;

    const interactive = std.fs.File.stdin().isTty() and std.fs.File.stdout().isTty();

    while (true) {
        if (interactive) {
            try w.print("> ", .{}); // prompt
            try w.flush();
        }

        const line = r.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.StreamTooLong => {
                _ = try err_w.write("Input line too long\n");
                try err_w.flush();
                continue;
            },
            error.EndOfStream => break, // clean EOF (Ctrl+D)
            else => {
                _ = try err_w.print("Input error: {}\n", .{err});
                try err_w.flush();
                continue;
            },
        };

        if (line.len == 0) continue;

        var arena = std.heap.ArenaAllocator.init(gpa_alloc);
        defer arena.deinit();
        const allocator = arena.allocator();

        // Lexer
        const tokens = lexer.tokenize(allocator, line) catch |err| {
            _ = try err_w.print("Lexer error {}\n", .{err});
            try err_w.flush();
            continue;
        };
        defer allocator.free(tokens);

        // Parser
        var i: usize = 0;
        const expr = parser.parseExpression(tokens, &i, allocator) catch |err| {
            _ = try err_w.print("Parser error {}\n", .{err});
            try err_w.flush();
            continue;
        };
        defer parser.freeExpr(allocator, expr);

        // Eval
        const result = evaluator.eval(expr) catch |err| {
            _ = try err_w.print("Eval error {}\n", .{err});
            try err_w.flush();
            continue;
        };

        try w.print("= {}\n", .{result});
        try w.flush();
    }
}
