//! syntax tree generator

const std = @import("std");
const StreamerObj = @import("../lexical/streamer.zig");
const Streamer = StreamerObj.Streamer;
const TokenKinds = StreamerObj.TokenKinds;
const Token = StreamerObj.Token;

/// assignment
pub const AssignNode = struct {
    id: []u8,
    value: *ASTNode,
};

/// binary operation
pub const BinOpNode = struct {
    left: *ASTNode,
    right: *ASTNode,
    op: []u8,
};

/// number literals
pub const IntegerNode = struct {
    value: i32,
};
pub const FloatNode = struct {
    value: f32,
};
pub const NumberNode = union(enum) {
    integer: IntegerNode,
    float: FloatNode,
};

/// ASTNode is a general node that could be any node
pub const ASTNode = union(enum) {
    assign: AssignNode,
    bin_op: BinOpNode,
    number: NumberNode,
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    streamer: *Streamer,
    current_token: ?Token = null,

    pub fn new(allocator: std.mem.Allocator, streamer: *Streamer) !*@This() {
        const obj = Parser{
            .allocator = allocator,
            .streamer = streamer,
        };
        const ptr = try allocator.create(@This());
        ptr.* = obj;
        return ptr;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.destroy(self);
    }

    fn eat(self: *@This(), token_kind: TokenKinds, value: ?[]const u8) void {
        if (self.streamer.peek().kind == token_kind) {
            if (value) |v| {
                if (!std.mem.eql(u8, self.streamer.peek().value, v)) {
                    @panic("invalid syntax");
                } else {
                    self.current_token = self.streamer.consume();
                }
            } else {
                self.current_token = self.streamer.consume();
            }
        } else {
            @panic("invalid syntax");
        }
    }

    pub fn assignment(self: *@This()) !*ASTNode {
        self.eat(TokenKinds.kw, "var");
        self.eat(TokenKinds.id, null);
        const node = ASTNode{
            .assign = AssignNode{
                .id = self.current_token.?.value,
                .value = r: {
                    self.eat(TokenKinds.op, "=");
                    break :r try self.expr();
                },
            },
        };
        const ptr = try self.allocator.create(@TypeOf(node));
        ptr.* = node;
        return ptr;
    }

    pub fn expr(self: *@This()) !*ASTNode {
        self.eat(TokenKinds.number, null);
        const val = try std.fmt.parseInt(u8, self.current_token.?.value, 10);
        const node = ASTNode{
            .number = NumberNode{
                .integer = IntegerNode{
                    .value = val,
                },
            },
        };
        const ptr = try self.allocator.create(@TypeOf(node));
        ptr.* = node;
        return ptr;
    }
};
