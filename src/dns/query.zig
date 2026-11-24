const std = @import("std");
const expect = std.testing.expect;
const utils = @import("utils.zig");
const DNSHeader = @import("header.zig").DNSHeader;
const DNSQuestion = @import("question.zig").DNSQuestion;

pub const TYPE_A = 1;
pub const CLASS_IN = 1;

pub fn build_query(allocator: std.mem.Allocator, domain_name: []const u8, record_type: u16, random: std.Random) ![]u8 {
    const encoded_name = try utils.encode_name(allocator, domain_name);
    defer allocator.free(encoded_name);

    const id = random.int(u16);
    const recursion_desired = 1 << 8;

    const header = DNSHeader{
        .id = id,
        .num_questions = 1,
        .flags = recursion_desired,
    };

    const question = DNSQuestion{
        .name = encoded_name,
        .type_ = record_type,
        .class_ = CLASS_IN,
    };

    const header_bytes = header.to_bytes();
    const question_bytes = try question.to_bytes(allocator);
    defer allocator.free(question_bytes);
    var buf = try allocator.alloc(u8, header_bytes.len + question_bytes.len);

    @memcpy(buf[0..][0..header_bytes.len], header_bytes[0..]);
    @memcpy(buf[header_bytes.len..][0..question_bytes.len], question_bytes[0..]);

    return buf;
}

const FixedBytes = struct {
    bytes: []const u8,
    pos: usize = 0,

    fn fill(self: *FixedBytes, buf: []u8) void {
        for (buf) |*b| {
            b.* = self.bytes[self.pos % self.bytes.len];
            self.pos += 1;
        }
    }
};

test "build_query" {
    const allocator = std.testing.allocator;
    const expected = "D\xcb\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01";

    var fake = FixedBytes{ .bytes = &.{ 0xcb, 0x44 } };
    const random = std.Random.init(&fake, FixedBytes.fill);

    const query = try build_query(
        allocator,
        "example.com",
        TYPE_A,
        random,
    );
    defer allocator.free(query);

    if (!std.mem.eql(u8, expected, query)) {
        std.debug.print("Expected: ", .{});
        utils.printBytes(expected);

        std.debug.print("Got: ", .{});
        utils.printBytes(query);

        try expect(false);
    }
}
