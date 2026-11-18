const std = @import("std");
const expect = std.testing.expect;

const DNSHeader = struct {
    id: u16,
    flags: u16,
    num_questions: u16 = 0,
    num_answers: u16 = 0,
    num_authorities: u16 = 0,
    num_addtionals: u16 = 0,

    pub fn to_bytes(self: DNSHeader) [12]u8 {
        const struct_info = @typeInfo(DNSHeader).@"struct";
        var buf: [12]u8 = undefined;
        inline for (struct_info.field_names, 0..) |field, index| {
            const value = @field(self, field);
            const offset = index * 2;

            std.mem.writeInt(u16, buf[offset..][0..2], value, .big);
        }

        return buf;
    }
};

const DNSQuestion = struct {
    name: []const u8,
    type_: u16,
    class_: u16,

    pub fn encode_name(self: DNSQuestion, allocator: std.mem.Allocator) ![]u8 {
        var split_domain = std.mem.splitScalar(u8, self.name, '.');
        var size: usize = 1;
        while (split_domain.next()) |part| {
            size += 1 + part.len;
        }

        split_domain.reset();
        var buf = try allocator.alloc(u8, size);
        var offset: usize = 0;
        while (split_domain.next()) |part| {
            buf[offset] = @intCast(part.len);
            offset += 1;
            @memcpy(buf[offset..][0..part.len], part);
            offset += part.len;
        }

        buf[offset] = 0;
        return buf;
    }

    pub fn to_bytes(self: DNSQuestion, allocator: std.mem.Allocator) ![]u8 {
        const struct_info = @typeInfo(DNSQuestion).@"struct";
        var buf: [4]u8 = undefined;

        inline for (struct_info.field_names[1..], 0..) |field, index| {
            const value = @field(self, field);
            const offset = index * 2;

            std.mem.writeInt(u16, buf[offset..][0..2], value, .big);
        }
        const encoded_name = try self.encode_name(allocator);
        var result_buf = try allocator.alloc(u8, encoded_name.len + 4);

        @memcpy(result_buf[0..encoded_name.len], encoded_name);
        @memcpy(result_buf[encoded_name.len..][0..4], &buf);

        return result_buf;
    }
};

fn printBytes(bytes: []const u8) void {
    std.debug.print("b'", .{});

    for (bytes) |byte| {
        if (byte >= 32 and byte <= 126 and byte != '\\' and byte != '\'') {
            std.debug.print("{c}", .{byte});
        } else {
            std.debug.print("\\x{x:0>2}", .{byte});
        }
    }

    std.debug.print("'\n", .{});
}

pub fn main() !void {
    var buf: [512]u8 = undefined;
    var fa = std.heap.FixedBufferAllocator.init(&buf);

    const header = DNSHeader{
        .id = 0x1314,
        .flags = 0,
        .num_questions = 1,
    };

    const question = DNSQuestion{
        .name = "example.com",
        .type_ = 1,
        .class_ = 1,
    };

    const question_bytes = try question.to_bytes(fa.allocator());
    defer fa.allocator().free(question_bytes);
    printBytes(&header.to_bytes());
    printBytes(question_bytes);
}

test "encode DNS name" {
    const allocator = std.testing.allocator;
    const expected = "\x06google\x03com\x00";
    const question = DNSQuestion{
        .name = "google.com",
        .type_ = 1,
        .class_ = 1,
    };

    const encoded_name = try question.encode_name(allocator);
    defer allocator.free(encoded_name);

    try expect(std.mem.eql(
        u8,
        expected,
        encoded_name,
    ));
}
