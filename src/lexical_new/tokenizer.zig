const std = @import("std");
const State = @import("states.zig").State;

const NUM: []const u8 = "0123456789";
const ALPHA_UPPER: []const u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const ALPHA_LOWER: []const u8 = "abcdefghijklmnopqrstuvwxyz";
const HEX: []const u8 = "0123456789ABCDEFabcdef";
const BUFFER_SIZE: usize = 1024;

pub const Tokenizer = struct {
    allocator: *std.mem.Allocator,
    content: []u8,
    index: usize = 0,
    state: State = State.default,
    cur_line: usize = 1,
    cur_col: usize = 1,
    buffer: []u8,
    buffer_index: usize = 0,

    // Flags
    ipv4_completed: bool = false,
    ipv6_completed: bool = false,
    integer_should_be_ipv6: bool = false,

    pub fn init(allocator: *std.mem.Allocator, content: []u8) !*@This() {
        const buffer_ptr = try allocator.alloc(u8, BUFFER_SIZE);
        for (0..BUFFER_SIZE) |i| {
            buffer_ptr[i] = 0;
        }
        const res = Tokenizer{
            .content = content,
            .allocator = allocator,
            .buffer = buffer_ptr,
        };
        const ptr = try allocator.create(Tokenizer);
        ptr.* = res;
        return ptr;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.buffer);
    }

    pub fn reset_buffer(self: *@This()) void {
        self.buffer_index = 0;
        for (0..BUFFER_SIZE) |i| {
            self.buffer[i] = 0;
        }
    }

    pub fn append_buffer(self: *@This(), c: u8) void {
        self.buffer[self.buffer_index] = c;
        self.buffer_index += 1;
    }

    pub fn peek(self: *@This()) ?u8 {
        if (self.index >= self.content.len) {
            return null;
        }
        return self.content[self.index];
    }

    pub fn consume(self: *@This(), skip: bool) void {
        const c = self.peek().?;
        if (c == '\n') {
            self.cur_line += 1;
            self.cur_col = 1;
        } else {
            self.cur_col += 1;
        }
        if (!skip) {
            self.append_buffer(c);
        }
        self.index += 1;
    }

    pub fn flush_token(self: *@This(), end: bool) void {
        // TODO flushing
        std.debug.print("{s}\t{s}\n", .{ @tagName(self.state), self.buffer });
        self.reset_buffer();
        if (!end) {
            self.state = State.default;
        } else {
            self.state = State.eof;
            self.reset_buffer();
        }
        self.next();
    }

    pub fn panic(self: *@This()) void {
        self.state = State.err;
        self.next();
    }

    pub fn process(self: *@This()) void {
        self.next();
    }

    fn next(self: *@This()) void {
        if (self.state == State.eof) {
            // TODO EOF
            return;
        }
        const maybe_peeked = self.peek();
        if (maybe_peeked) |peeked| {
            switch (self.state) {
                State.default => {
                    if (is_digit(peeked)) {
                        self.state = State.integer;
                        self.consume(false);
                        self.next();
                    } else if (is_id(peeked, true)) {
                        self.state = State.id;
                        self.consume(false);
                        self.next();
                    } else if (peeked == '\"') {
                        self.state = State.string;
                        self.consume(false);
                        self.next();
                    } else if (is_newline(peeked) or is_whitespace(peeked)) {
                        // skip
                        self.consume(true);
                        self.next();
                    } else {
                        self.panic();
                    }
                },
                State.integer => {
                    if (is_digit(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == ':') {
                        self.state = State.ipv6_1;
                        self.consume(false);
                        self.next();
                    } else if (is_hex(peeked)) {
                        self.integer_should_be_ipv6 = true;
                        self.consume(false);
                        self.next();
                    } else if (peeked == '.') {
                        self.state = State.float;
                        self.consume(false);
                        self.next();
                    } else {
                        if (self.integer_should_be_ipv6) {
                            self.panic();
                        }
                        self.flush_token(false);
                    }
                },
                State.float => {
                    if (is_digit(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == '.') {
                        self.state = State.ipv4_in;
                        self.consume(false);
                        self.next();
                    } else {
                        self.flush_token(false);
                    }
                },
                State.ipv4_in => {
                    if (is_digit(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == '.') {
                        self.state = State.ipv4;
                        self.consume(false);
                        self.next();
                    } else {
                        self.panic();
                    }
                },
                State.ipv4 => {
                    if (is_digit(peeked)) {
                        self.ipv4_completed = true;
                        self.consume(false);
                        self.next();
                    } else {
                        if (!self.ipv4_completed) {
                            self.panic();
                        }
                        self.ipv4_completed = false;
                        self.flush_token(false);
                    }
                },
                State.id => {
                    if (is_id(peeked, false)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == ':') {
                        // TODO Check if first part is valid hex
                        self.state = State.ipv6_1;
                        self.consume(false);
                        self.next();
                    } else {
                        self.flush_token(false);
                    }
                },
                State.ipv6_1 => {
                    if (is_hex(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == ':') {
                        self.state = State.ipv6_2;
                        self.consume(false);
                        self.next();
                    } else {
                        self.panic();
                    }
                },
                State.ipv6_2 => {
                    if (is_hex(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == ':') {
                        self.state = State.ipv6_3;
                        self.consume(false);
                        self.next();
                    } else {
                        self.panic();
                    }
                },
                State.ipv6_3 => {
                    if (is_hex(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == ':') {
                        self.state = State.ipv6_4;
                        self.consume(false);
                        self.next();
                    } else {
                        self.panic();
                    }
                },
                State.ipv6_4 => {
                    if (is_hex(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == ':') {
                        self.state = State.ipv6_5;
                        self.consume(false);
                        self.next();
                    } else {
                        self.panic();
                    }
                },
                State.ipv6_5 => {
                    if (is_hex(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == ':') {
                        self.state = State.ipv6_6;
                        self.consume(false);
                        self.next();
                    } else {
                        self.panic();
                    }
                },
                State.ipv6_6 => {
                    if (is_hex(peeked)) {
                        self.consume(false);
                        self.next();
                    } else if (peeked == ':') {
                        self.state = State.ipv6;
                        self.consume(false);
                        self.next();
                    } else {
                        self.panic();
                    }
                },
                State.ipv6 => {
                    if (is_hex(peeked)) {
                        self.ipv6_completed = true;
                        self.consume(false);
                        self.next();
                    } else {
                        if (!self.ipv6_completed) {
                            self.panic();
                        }
                        self.ipv6_completed = false;
                        self.flush_token(false);
                    }
                },
                State.string => {
                    if (peeked == '\\') {
                        self.state = State.escaped;
                        self.consume(false);
                        self.next();
                    } else if (peeked == '\"') {
                        self.consume(false);
                        self.flush_token(false);
                    } else {
                        self.consume(false);
                        self.next();
                    }
                },
                State.escaped => {
                    self.state = State.string;
                    self.consume(false);
                    self.next();
                },
                State.op_not => {},
                State.op_neql => {},
                State.op_plus => {},
                State.op_pluseql => {},
                State.op_plusplus => {},
                State.op_minus => {},
                State.op_minuseql => {},
                State.op_minusminus => {},
                State.op_mult => {},
                State.op_multeql => {},
                State.op_div => {},
                State.op_diveql => {},
                State.op_assign => {},
                State.op_eql => {},
                State.op_less => {},
                State.op_lesseql => {},
                State.op_shiftleft => {},
                State.op_great => {},
                State.op_greateql => {},
                State.op_shiftright => {},
                State.comment => {},
                State.pun_prntopen => {},
                State.pun_prntclose => {},
                State.pun_curopen => {},
                State.pun_curclose => {},
                State.pun_brkopen => {},
                State.pun_brkclose => {},
                State.pun_semi => {},
                State.pun_comma => {},
                State.err => {
                    const stderr = std.io.getStdErr();
                    const msg = std.fmt.allocPrint(self.allocator.*, "invalid character at line {d} col {d} ({d}:{d})", .{ self.cur_line, self.cur_col, self.cur_line, self.cur_col }) catch "memory error";
                    stderr.writeAll(msg) catch |e| {
                        @panic(@errorName(e));
                    };
                    self.allocator.free(msg);
                    std.process.exit(1);
                },
                else => unreachable,
            }
        } else {
            self.flush_token(true);
            self.state = State.eof;
            self.next();
        }
    }

    fn is_in_set(c: u8, comptime set: []const u8) bool {
        const temp: [1]u8 = [_]u8{c};
        return std.mem.indexOf(u8, set, &temp) != null;
    }

    fn is_digit(c: u8) bool {
        return is_in_set(c, NUM);
    }

    fn is_dot(c: u8) bool {
        return c == '.';
    }

    fn is_id(c: u8, first: bool) bool {
        var res = is_in_set(c, ALPHA_UPPER) or is_in_set(c, ALPHA_LOWER) or c == '_';
        if (!first) {
            res = res or is_in_set(c, NUM);
        }
        return res;
    }

    fn is_hex(c: u8) bool {
        return is_in_set(c, HEX);
    }

    fn is_whitespace(c: u8) bool {
        return c == ' ' or c == '\t';
    }

    fn is_newline(c: u8) bool {
        return c == '\n' or c == '\r';
    }
};
