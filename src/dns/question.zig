const std = @import("std");
const utils = @import("utils.zig");
const expect = std.testing.expect;

pub const DNSQuestion = struct {
    name: []const u8,
    type_: u16,
    class_: u16,

    pub fn to_bytes(self: DNSQuestion, allocator: std.mem.Allocator) ![]u8 {
        var buf: [4]u8 = undefined;

        std.mem.writeInt(u16, buf[0..][0..2], self.type_, .big);
        std.mem.writeInt(u16, buf[2..][0..2], self.class_, .big);

        var result_buf = try allocator.alloc(u8, self.name.len + 4);

        @memcpy(result_buf[0..self.name.len], self.name);
        @memcpy(result_buf[self.name.len..][0..4], &buf);

        return result_buf;
    }

    pub fn parse(allocator: std.mem.Allocator, data: []const u8) !DNSQuestion {
        const decoded_name = try utils.decode_name(allocator, data[0 .. data.len - 4]);
        const rest = data[data.len - 4 ..];

        return DNSQuestion{
            .name = decoded_name,
            .type_ = std.mem.readInt(u16, rest[0..2], .big),
            .class_ = std.mem.readInt(u16, rest[2..4], .big),
        };
    }
};

test "parse" {
    const allocator = std.testing.allocator;
    const input = "\x06google\x03com\x00\x00\x01\x00\x01";
    const expected = DNSQuestion{
        .name = "google.com",
        .type_ = 1, // A record
        .class_ = 1, // IN (Internet)
    };

    const question = try DNSQuestion.parse(allocator, input);
    defer allocator.free(question.name);

    try std.testing.expectEqualDeep(expected, question);
}

test "Question to_bytes" {
    const allocator = std.testing.allocator;
    const expected = "\x07example\x03com\x00\x00\x01\x00\x01";
    const name = try utils.encode_name(allocator, "example.com");
    defer allocator.free(name);

    const question = DNSQuestion{
        .name = name,
        .type_ = 1,
        .class_ = 1,
    };

    const question_bytes = try question.to_bytes(allocator);
    defer allocator.free(question_bytes);

    try expect(std.mem.eql(u8, expected, question_bytes));
}
