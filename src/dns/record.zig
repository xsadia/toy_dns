const std = @import("std");
const utils = @import("utils.zig");

pub const DNSRecord = struct {
    name: []const u8,
    type_: u16,
    class_: u16,
    ttl: u32,
    data: []const u8,

    pub fn parse(allocator: std.mem.Allocator, data: []const u8) !DNSRecord {
        var name_len: usize = 0;
        while (data[name_len] != 0) : (name_len += 1) {}

        const encoded_name = data[0 .. name_len + 1];
        const decoded_name = try utils.decode_name(allocator, encoded_name);

        const rest = data[name_len + 1 ..];
        const rlen = std.mem.readInt(u16, rest[8..10], .big);
        const rdata = try allocator.alloc(u8, rlen);

        @memcpy(rdata, rest[10 .. 10 + rlen]);

        return DNSRecord{
            .name = decoded_name,
            .type_ = std.mem.readInt(u16, rest[0..2], .big),
            .class_ = std.mem.readInt(u16, rest[2..4], .big),
            .ttl = std.mem.readInt(u32, rest[4..8], .big),
            .data = rdata,
        };
    }
};

test "parse" {
    const allocator = std.testing.allocator;
    // name, type A (1), class IN (1), TTL 3600 (u32), rdlength 4, rdata 142.250.80.78
    const input = "\x06google\x03com\x00" ++
        "\x00\x01" ++
        "\x00\x01" ++
        "\x00\x00\x0e\x10" ++
        "\x00\x04" ++
        "\x8e\xfa\x50\x4e";

    var offset: usize = 0;
    const record = try DNSRecord.parse(allocator, input, &offset);
    defer allocator.free(record.name);
    defer allocator.free(record.data);

    try std.testing.expectEqualStrings("google.com", record.name);
    try std.testing.expectEqual(@as(u16, 1), record.type_);
    try std.testing.expectEqual(@as(u16, 1), record.class_);
    try std.testing.expectEqual(@as(u32, 3600), record.ttl);
    try std.testing.expectEqualSlices(u8, "\x8e\xfa\x50\x4e", record.data);
    try std.testing.expectEqual(input.len, offset);
}

test "parse compressed answers in a response" {
    const allocator = std.testing.allocator;
    const header = "\x12\x34\x81\x80" ++ // id, flags: standard response, no error
        "\x00\x01\x00\x02\x00\x00\x00\x00"; // 1 question, 2 answers
    const question = "\x06google\x03com\x00" ++ "\x00\x01\x00\x01"; // name at offset 12
    const answer1 = "\xc0\x0c" ++ // pointer to google.com
        "\x00\x01\x00\x01\x00\x00\x0e\x10\x00\x04" ++
        "\x8e\xfa\x50\x4e";
    const answer2 = "\x03www\xc0\x0c" ++ // www + pointer to google.com
        "\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04" ++
        "\x01\x02\x03\x04";
    const message = header ++ question ++ answer1 ++ answer2;

    var offset: usize = header.len + question.len;

    const first = try DNSRecord.parse(allocator, message, &offset);
    defer allocator.free(first.name);
    defer allocator.free(first.data);

    try std.testing.expectEqualStrings("google.com", first.name);
    try std.testing.expectEqual(@as(u16, 1), first.type_);
    try std.testing.expectEqual(@as(u16, 1), first.class_);
    try std.testing.expectEqual(@as(u32, 3600), first.ttl);
    try std.testing.expectEqualSlices(u8, "\x8e\xfa\x50\x4e", first.data);
    try std.testing.expectEqual(header.len + question.len + answer1.len, offset);

    const second = try DNSRecord.parse(allocator, message, &offset);
    defer allocator.free(second.name);
    defer allocator.free(second.data);

    try std.testing.expectEqualStrings("www.google.com", second.name);
    try std.testing.expectEqual(@as(u16, 1), second.type_);
    try std.testing.expectEqual(@as(u16, 1), second.class_);
    try std.testing.expectEqual(@as(u32, 60), second.ttl);
    try std.testing.expectEqualSlices(u8, "\x01\x02\x03\x04", second.data);
    try std.testing.expectEqual(message.len, offset);
}

test "parse rejects malformed name" {
    const allocator = std.testing.allocator;
    // message ends inside the "com" label
    const input = "\x06google\x03co";
    var offset: usize = 0;

    try std.testing.expectError(error.MalformedDomainName, DNSRecord.parse(allocator, input, &offset));
}
