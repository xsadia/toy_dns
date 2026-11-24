const std = @import("std");
const expect = std.testing.expect;

pub const DNSHeader = struct {
    id: u16,
    flags: u16,
    num_questions: u16 = 0,
    num_answers: u16 = 0,
    num_authorities: u16 = 0,
    num_additionals: u16 = 0,

    pub fn to_bytes(self: DNSHeader) [12]u8 {
        var buf: [12]u8 = undefined;

        std.mem.writeInt(u16, buf[0..][0..2], self.id, .big);
        std.mem.writeInt(u16, buf[2..][0..2], self.flags, .big);
        std.mem.writeInt(u16, buf[4..][0..2], self.num_questions, .big);
        std.mem.writeInt(u16, buf[6..][0..2], self.num_answers, .big);
        std.mem.writeInt(u16, buf[8..][0..2], self.num_authorities, .big);
        std.mem.writeInt(u16, buf[10..][0..2], self.num_additionals, .big);

        return buf;
    }

    pub fn parse(data: []const u8) DNSHeader {
        const header = DNSHeader{
            .id = std.mem.readInt(u16, data[0..2], .big),
            .flags = std.mem.readInt(u16, data[2..4], .big),
            .num_questions = std.mem.readInt(u16, data[4..6], .big),
            .num_answers = std.mem.readInt(u16, data[6..8], .big),
            .num_authorities = std.mem.readInt(u16, data[8..10], .big),
            .num_additionals = std.mem.readInt(u16, data[10..12], .big),
        };

        return header;
    }
};

test "parse" {
    const input = "\xc2\x9b\x81\x80\x00\x01\x00\x02\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01\xc0\x0c\x00\x01\x00\x01\x00\x00\x01,\x00\x04h\x14\x17\x9a\xc0\x0c\x00\x01\x00\x01\x00\x00\x01,\x00\x04\xacB\x93\xf3";

    const expected = DNSHeader{
        .id = 0xc29b,
        .flags = 0x8180,
        .num_questions = 1,
        .num_answers = 2,
        .num_authorities = 0,
        .num_additionals = 0,
    };

    try expect(std.meta.eql(expected, DNSHeader.parse(input)));
}

test "Header to_bytes" {
    const expected = "\x13\x14\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00";

    const header = DNSHeader{
        .id = 0x1314,
        .flags = 0,
        .num_questions = 1,
    };

    const header_bytes = header.to_bytes();

    try expect(std.mem.eql(u8, &header_bytes, expected));
}
