//! token streamer

const std = @import("std");
const print = std.debug.print;
const LexicalState = @import("tokenizer.zig").LexicalState;
const KEYWORDS = "var if else";

/// token types
pub const TokenKinds = enum {
    id,
    kw,
    punc,
    op,
    number,
    eof,
    str,
};

/// token object with type and value
pub const Token = struct {
    kind: TokenKinds,
    value: []u8,
};

/// streamer responsible for processing FSM states into token objects
pub const Streamer = struct {
    allocator: std.mem.Allocator,
    data: *const []u8,
    current: usize = 0,
    token_map: *const std.ArrayListAligned(usize, null),

    pub fn new(allocator: std.mem.Allocator, data: *const []u8, token_map: *const std.ArrayListAligned(usize, null)) !*@This() {
        const streamer: @This() = .{
            .allocator = allocator,
            .data = data,
            .token_map = token_map,
        };
        const ptr = try allocator.create(@This());
        ptr.* = streamer;
        return ptr;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.destroy(self);
    }

    pub fn peek(self: *@This()) Token {
        const start: usize = self.*.token_map.*.items[self.*.current];
        const size: usize = self.*.token_map.*.items[self.*.current + 1];
        const kind: LexicalState = @enumFromInt(self.*.token_map.*.items[self.*.current + 2]);
        const value = self.*.data.*[start .. start + size];
        const token_kind: TokenKinds = switch (kind) {
            LexicalState.eof => TokenKinds.eof,
            LexicalState.id => id_block: {
                const ix = std.mem.indexOf(u8, KEYWORDS, value);
                if (ix) |_| {
                    break :id_block TokenKinds.kw;
                } else {
                    break :id_block TokenKinds.id;
                }
            },
            LexicalState.number => TokenKinds.number,
            LexicalState.operator => TokenKinds.op,
            LexicalState.punctuation => TokenKinds.punc,
            LexicalState.string => TokenKinds.str,
            else => unreachable,
        };
        const token = Token{ .kind = token_kind, .value = value };
        return token;
    }

    pub fn consume(self: *@This()) Token {
        const p = self.peek();
        self.*.current += 3;
        return p;
    }
};
