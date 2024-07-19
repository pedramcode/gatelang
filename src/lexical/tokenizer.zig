//! lexical analyzer

const std = @import("std");
const print = std.debug.print;

/// the lexical state
pub const LexicalState = enum(u8) { default, eof, number, newline, whitespace, punctuation, string, id, operator, comment };

/// main tokenizer structure
pub const Tokenizer = struct {
    result: std.ArrayList(usize),
    allocator: std.mem.Allocator,
    data: *const []u8,
    index: usize = 0,
    state: LexicalState = LexicalState.default,
    buffer_size: usize = 0,
    is_escaped: bool = false,
    is_dotted_number: bool = false,
    read_op_size: usize = 0,
    current_line: usize = 1,
    current_col: usize = 1,
    token_len: usize = 0,

    pub fn new(allocator: std.mem.Allocator, data: *const []u8) !*@This() {
        const res = .{
            .data = data,
            .allocator = allocator,
            .result = std.ArrayList(usize).init(allocator),
        };
        const ptr = try allocator.create(@This());
        ptr.* = res;
        return ptr;
    }

    pub fn deinit(self: *@This()) void {
        self.*.result.deinit();
        self.*.allocator.destroy(self);
    }

    fn flush_token(self: *@This()) void {
        if (self.*.state != LexicalState.whitespace and self.*.state != LexicalState.newline) {
            self.*.result.append(self.*.index - self.*.token_len) catch |e| {
                print("out of memory: {?}", .{e});
            };
            self.*.result.append(self.*.token_len) catch |e| {
                print("out of memory: {?}", .{e});
            };
            self.*.result.append(@intFromEnum(self.*.state)) catch |e| {
                print("out of memory: {?}", .{e});
            };
        }
        self.*.token_len = 0;
    }

    pub fn tokens(self: *@This()) *std.ArrayList(usize) {
        return &self.*.result;
    }

    fn peek(self: *@This()) ?u8 {
        if (self.data.len <= self.*.index) {
            return null;
        }
        return self.data.*[self.*.index];
    }

    fn consume(self: *@This()) u8 {
        const val = self.data.*[self.*.index];
        self.*.index += 1;
        return val;
    }

    pub fn next(self: *@This()) void {
        self.*.token_len += 1;
        _ = self.*.consume();
        self.*.current_col += 1;
        self.*.lex();
    }

    pub fn reset_state(self: *@This()) void {
        self.flush_token();
        self.*.state = LexicalState.default;
        self.*.lex();
    }

    pub fn process(self: *@This()) void {
        self.lex();
    }

    fn lex(self: *@This()) void {
        switch (self.*.state) {
            LexicalState.default => {
                const p = self.peek();
                if (p) |val| {
                    if (is_digit(val)) {
                        self.*.state = LexicalState.number;
                        self.*.next();
                    } else if (is_newline(val)) {
                        if (val == '\n') {
                            self.*.current_line += 1;
                            self.*.current_col = 1;
                        }
                        self.*.state = LexicalState.newline;
                        self.*.next();
                    } else if (val == '~') {
                        self.*.state = LexicalState.comment;
                        _ = self.*.consume();
                        self.*.lex();
                    } else if (is_ws(val)) {
                        self.*.state = LexicalState.whitespace;
                        self.*.next();
                    } else if (is_punctuation(val)) {
                        self.*.state = LexicalState.punctuation;
                        self.*.next();
                    } else if (is_id(val)) {
                        self.*.state = LexicalState.id;
                        self.*.next();
                    } else if (is_operator(val)) {
                        self.*.read_op_size += 1;
                        self.*.state = LexicalState.operator;
                        self.*.next();
                    } else if (val == '\"') {
                        self.*.state = LexicalState.string;
                        self.*.next();
                    } else {
                        print("invalid character at {d}:{d}\n", .{ self.*.current_line, self.*.current_col });
                        std.process.exit(1);
                    }
                } else {
                    self.flush_token();
                    self.*.state = LexicalState.eof;
                    self.*.lex();
                }
            },
            LexicalState.comment => {
                const p = self.peek();
                if (p) |val| {
                    if (val == '\n') {
                        self.*.state = LexicalState.default;
                        self.*.lex();
                    } else {
                        _ = self.consume();
                        self.*.lex();
                    }
                } else {
                    self.*.state = LexicalState.default;
                    self.*.lex();
                }
            },
            LexicalState.number => {
                const p = self.peek();
                if (p) |val| {
                    if (is_digit(val)) {
                        self.*.next();
                    } else if (val == '.' and !self.*.is_dotted_number) {
                        self.*.is_dotted_number = true;
                        self.*.next();
                    } else {
                        self.*.is_dotted_number = false;
                        self.*.reset_state();
                    }
                } else {
                    self.*.is_dotted_number = false;
                    self.*.reset_state();
                }
            },
            LexicalState.string => {
                const p = self.peek();
                if (p) |val| {
                    if (val == '\"' and !self.*.is_escaped) {
                        _ = self.*.consume();
                        self.*.token_len += 1;
                        self.*.current_col += 1;
                        self.*.reset_state();
                    } else if (val == '\\') {
                        self.*.is_escaped = true;
                        self.*.next();
                    } else {
                        self.*.is_escaped = false;
                        self.*.next();
                    }
                } else {
                    self.*.reset_state();
                }
            },
            LexicalState.id => {
                const p = self.peek();
                if (p) |val| {
                    if (is_digit(val) or is_id(val)) {
                        self.*.next();
                    } else {
                        self.*.reset_state();
                    }
                } else {
                    self.*.reset_state();
                }
            },
            LexicalState.operator => {
                const p = self.peek();
                if (p) |val| {
                    if (is_operator(val) and self.*.read_op_size <= 1) {
                        self.*.read_op_size += 1;
                        self.*.next();
                    } else {
                        self.*.read_op_size = 0;
                        self.*.reset_state();
                    }
                } else {
                    self.*.read_op_size = 0;
                    self.*.reset_state();
                }
            },
            LexicalState.newline, LexicalState.punctuation, LexicalState.whitespace => {
                self.*.reset_state();
            },
        }
    }

    fn is_digit(char: usize) bool {
        for ('0'..'9' + 1) |n| {
            if (n == char) {
                return true;
            }
        }
        return false;
    }

    fn is_newline(char: usize) bool {
        return char == '\r' or char == '\n';
    }

    fn is_ws(char: usize) bool {
        return char == ' ' or char == '\t';
    }

    fn is_id(char: usize) bool {
        if (char == '_') {
            return true;
        }
        for ('A'..'z' + 1) |n| {
            if (n == char) {
                return true;
            }
        }
        return false;
    }

    fn is_punctuation(char: usize) bool {
        const puncs = "{}[],;()";
        for (puncs) |p| {
            if (p == char) {
                return true;
            }
        }
        return false;
    }

    fn is_operator(char: usize) bool {
        const ops = "=<>+-*/";
        for (ops) |p| {
            if (p == char) {
                return true;
            }
        }
        return false;
    }
};
