const std = @import("std");
const expect = std.testing.expect;
const DNSHeader = @import("header.zig").DNSHeader;

pub fn encode_name(allocator: std.mem.Allocator, domain_name: []const u8) ![]u8 {
    var split_domain = std.mem.splitScalar(u8, domain_name, '.');
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

pub fn printBytes(bytes: []const u8) void {
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

const DecodeError = error{
    MalformedDomainName,
};

pub fn decode_name(allocator: std.mem.Allocator, encoded_name: []const u8) ![]u8 {
    const max_name_size: usize = 255;
    var decoded = try allocator.alloc(u8, max_name_size);
    // defer allocator.free(decoded);

    var written_bits: usize = 0;
    var len = encoded_name[written_bits];
    std.debug.print("len {x}\n: ", .{len});
    while (len != 0) : (written_bits += len) {
        if ((len & 0b1100_0000) == 0) {
            // decoded[written_bits] = try allocator.alloc(u8, len);
            @memcpy(decoded[written_bits..len], encoded_name[written_bits + 1 .. written_bits + len + 1]);

            decoded[written_bits + 1] = '.';
            written_bits += len + 1;

            len = encoded_name[written_bits];
        } else {
            break;
        }
    }

    decoded = try allocator.realloc(decoded, written_bits);

    // const decoded = try std.mem.join(allocator, ".", parts);
    // for (parts) |part| {
    //     allocator.free(part);
    // }

    return decoded;
}

test "decode_name" {
    const allocator = std.testing.allocator;
    const message = "\x06google\x03com\x00";

    const decoded = try decode_name(
        allocator,
        message,
    );
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("google.com", decoded);
    // try std.testing.expectEqual(@as(usize, 12), offset);
}

// test "decode_name follows pointer" {
//     const allocator = std.testing.allocator;
//     // offset 0: google.com, offset 12: pointer to 0
//     const message = "\x06google\x03com\x00" ++ "\xc0\x00";
//     var offset: usize = 12;
//
//     const decoded = try decode_name(allocator, message, &offset);
//     defer allocator.free(decoded);
//
//     try std.testing.expectEqualStrings("google.com", decoded);
//     // a pointer ends the name: only its 2 bytes are consumed
//     try std.testing.expectEqual(@as(usize, 14), offset);
// }
//
// test "decode_name labels followed by pointer" {
//     const allocator = std.testing.allocator;
//     // offset 12: www + pointer to 0
//     const message = "\x06google\x03com\x00" ++ "\x03www\xc0\x00";
//     var offset: usize = 12;
//
//     const decoded = try decode_name(allocator, message, &offset);
//     defer allocator.free(decoded);
//
//     try std.testing.expectEqualStrings("www.google.com", decoded);
//     try std.testing.expectEqual(@as(usize, 18), offset);
// }
//
// test "decode_name pointer into middle of name" {
//     const allocator = std.testing.allocator;
//     // offset 7 is the "com" label; offset 12: mail + pointer to 7
//     const message = "\x06google\x03com\x00" ++ "\x04mail\xc0\x07";
//     var offset: usize = 12;
//
//     const decoded = try decode_name(allocator, message, &offset);
//     defer allocator.free(decoded);
//
//     try std.testing.expectEqualStrings("mail.com", decoded);
//     try std.testing.expectEqual(@as(usize, 19), offset);
// }
//
// test "decode_name pointer to pointer" {
//     const allocator = std.testing.allocator;
//     // offset 12: www + pointer to 0, offset 18: pointer to 12
//     const message = "\x06google\x03com\x00" ++ "\x03www\xc0\x00" ++ "\xc0\x0c";
//     var offset: usize = 18;
//
//     const decoded = try decode_name(allocator, message, &offset);
//     defer allocator.free(decoded);
//
//     try std.testing.expectEqualStrings("www.google.com", decoded);
//     try std.testing.expectEqual(@as(usize, 20), offset);
// }
//
// test "decode_name rejects pointer past end of message" {
//     const allocator = std.testing.allocator;
//     const message = "\x06google\x03com\x00" ++ "\xc0\x20";
//     var offset: usize = 12;
//
//     try std.testing.expectError(error.MalformedDomainName, decode_name(allocator, message, &offset));
// }
//
// test "decode_name rejects truncated pointer" {
//     const allocator = std.testing.allocator;
//     // pointer is missing its second byte
//     const message = "\x03www\xc0";
//     var offset: usize = 0;
//
//     try std.testing.expectError(error.MalformedDomainName, decode_name(allocator, message, &offset));
// }
//
// test "decode_name rejects pointer to itself" {
//     const allocator = std.testing.allocator;
//     const message = "\xc0\x00";
//     var offset: usize = 0;
//
//     try std.testing.expectError(error.MalformedDomainName, decode_name(allocator, message, &offset));
// }
//
// test "decode_name rejects pointer loop" {
//     const allocator = std.testing.allocator;
//     // offset 0 -> 4 -> 0 -> ...
//     const message = "\x01a\xc0\x04" ++ "\x01b\xc0\x00";
//     var offset: usize = 0;
//
//     try std.testing.expectError(error.MalformedDomainName, decode_name(allocator, message, &offset));
// }
//
// test "decode_name rejects reserved label type" {
//     const allocator = std.testing.allocator;
//     // 0x80 has only the top bit set: reserved, not a 128-byte label,
//     // even though 128 bytes follow it
//     const message = "\x80" ++ @as([128]u8, @splat('a')) ++ "\x00";
//     var offset: usize = 0;
//
//     try std.testing.expectError(error.MalformedDomainName, decode_name(allocator, message, &offset));
// }
//
// // 3 x 63-byte labels + a 61-byte label + terminator = 255 bytes on the wire
// const label63 = "\x3f" ++ @as([63]u8, @splat('a'));
// const name255 = label63 ++ label63 ++ label63 ++ "\x3d" ++ @as([61]u8, @splat('a')) ++ "\x00";
//
// test "decode_name accepts 255-byte name" {
//     const allocator = std.testing.allocator;
//     const a63: [63]u8 = @splat('a');
//     const expected = a63 ++ "." ++ a63 ++ "." ++ a63 ++ "." ++ @as([61]u8, @splat('a'));
//     var offset: usize = 0;
//
//     const decoded = try decode_name(allocator, name255, &offset);
//     defer allocator.free(decoded);
//
//     try std.testing.expectEqualStrings(expected, decoded);
//     try std.testing.expectEqual(@as(usize, 255), offset);
// }
//
// test "decode_name rejects name over 255 bytes" {
//     const allocator = std.testing.allocator;
//     // last label is 62 bytes instead of 61: 256 bytes on the wire
//     const message = label63 ++ label63 ++ label63 ++ "\x3e" ++ @as([62]u8, @splat('a')) ++ "\x00";
//     var offset: usize = 0;
//
//     try std.testing.expectError(error.MalformedDomainName, decode_name(allocator, message, &offset));
// }
//
// test "decode_name rejects name over 255 bytes via pointer" {
//     const allocator = std.testing.allocator;
//     // "a" + pointer to the 255-byte name: 2 + 255 = 257 bytes once expanded
//     const message = name255 ++ "\x01a\xc0\x00";
//     var offset: usize = name255.len;
//
//     try std.testing.expectError(error.MalformedDomainName, decode_name(allocator, message, &offset));
// }

test "encode DNS name" {
    const allocator = std.testing.allocator;
    const expected = "\x06google\x03com\x00";
    const name = "google.com";

    const encoded_name = try encode_name(allocator, name);
    defer allocator.free(encoded_name);

    try expect(std.mem.eql(
        u8,
        expected,
        encoded_name,
    ));
}
