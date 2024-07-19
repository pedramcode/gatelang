//! awesome zig project

const std = @import("std");
const print = std.debug.print;
// const Tokenizer = @import("lexical/tokenizer.zig").Tokenizer;
// const Streamer = @import("lexical/streamer.zig").Streamer;
// const TokenKinds = @import("lexical/streamer.zig").TokenKinds;
// const Parser = @import("parser/syntax_tree.zig").Parser;
// const mecha = @import("mecha");
const Tokenizer = @import("lexical_new/tokenizer.zig").Tokenizer;

/// Main function
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const path = "samples/sample001.txt";
    const file = try std.fs.cwd().openFile(path, .{});
    const stat = try file.stat();
    const data = try std.fs.cwd().readFileAlloc(allocator, path, stat.size);
    defer allocator.free(data);

    const tok = try Tokenizer.init(&allocator, data);
    defer tok.deinit();
    tok.process();

    // // pass character stream into FSM
    // const tok = try Tokenizer.new(allocator, &data);
    // defer tok.deinit();
    // tok.process();
    // const tokens = tok.tokens();

    // // create tokens stream out of FSM output state
    // const streamer = try Streamer.new(allocator, &data, tokens);
    // defer streamer.deinit();

    // // the parser
    // const parser = try Parser.new(allocator, streamer);
    // defer parser.deinit();
    // const ass = try parser.assignment();
    // print("{s} = {d}", .{ ass.assign.id, ass.assign.value.number.integer.value });
}
