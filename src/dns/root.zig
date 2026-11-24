pub const DNSHeader = @import("header.zig").DNSHeader;
pub const DNSQuestion = @import("question.zig").DNSQuestion;
pub const utils = @import("utils.zig");
pub const TYPE_A = @import("question.zig").TYPE_A;
pub const CLASS_IN = @import("question.zig").CLASS_IN;
pub const query = @import("query.zig");
pub const DNSRecord = @import("record.zig").DNSRecord;

test {
    _ = @import("header.zig");
    _ = @import("question.zig");
    _ = @import("utils.zig");
    _ = @import("query.zig");
    _ = @import("record.zig");
}
