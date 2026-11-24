const std = @import("std");
const dns = @import("dnz");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var prng = std.Random.DefaultPrng.init(1);
    const rand = prng.random();

    var buf: [512]u8 = undefined;
    var fa = std.heap.FixedBufferAllocator.init(&buf);

    const addr = try std.Io.net.IpAddress.parse("0.0.0.0", 0);
    const sock = try addr.bind(io, .{
        .mode = .dgram,
    });

    defer sock.close(io);
    const google = try std.Io.net.IpAddress.parse("8.8.8.8", 53);
    const query = try dns.query.build_query(
        fa.allocator(),
        "example.com",
        1,
        rand,
    );

    try sock.send(
        io,
        &google,
        query,
    );

    var response_buf: [1024]u8 = undefined;

    const msg = try sock.receive(io, &response_buf);

    dns.utils.printBytes(msg.data);
}
