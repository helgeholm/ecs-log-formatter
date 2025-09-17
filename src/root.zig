const std = @import("std");

const zeit = @import("zeit");

const plain_datetime_fmt = "%Y-%m-%dT%H:%M:%S";
const plain_micros_fmt = ".{d:0>6}Z";

// Must be set by client code. Used for service.name field.
pub var service_name: []const u8 = "";

const OutputFormat = enum {
    tty_bw,
    tty_color,
    json,
};
var output_format: ?OutputFormat = null;

var stderr_buffer: [1024]u8 = undefined;
const stderr = std.fs.File.stderr();
var stderr_writer = stderr.writer(&stderr_buffer);
const writer: *std.Io.Writer = &stderr_writer.interface;

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (output_format == null) {
        output_format = if (stderr.isTty())
            if (stderr.getOrEnableAnsiEscapeSupport()) .tty_color else .tty_bw
        else
            .json;
    }

    (switch (output_format orelse .json) {
        .tty_color => color_log(message_level, scope, format, args),
        .tty_bw => bw_log(message_level, scope, format, args),
        .json => json_log(message_level, scope, format, args),
    }) catch unreachable;
}

fn write_timestamp(
    timewriter: *std.Io.Writer,
    comptime datetime_fmt: [:0]const u8,
    comptime micros_fmt: []const u8,
) !void {
    const now = try zeit.instant(.{});
    try now.time().strftime(timewriter, datetime_fmt);
    const usec: u32 = @intCast(@divFloor(@mod(now.timestamp, 1_000_000_000), 1_000));
    try timewriter.print(micros_fmt, .{usec});
}

fn color_log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) !void {
    const E = "\x1b[";
    const DIM_BLUE = E ++ "2;34m";
    const BLUE = E ++ "22;34m";
    const LOUD_BLUE = E ++ "22;1;34m";
    const WHITE = E ++ "22;39m";
    const DIM_WHITE = E ++ "2;39m";
    const RESET = E ++ "0m";
    const message_level_text = E ++ "22;" ++ switch (message_level) {
        .debug => "36mDEBUG",
        .info => "39mINFO",
        .warn => "33mWARN",
        .err => "1;31mERROR",
    };
    try write_timestamp(
        writer,
        LOUD_BLUE ++ "%Y-%m-%d" ++ DIM_WHITE ++ "T" ++ BLUE ++ "%H:%M:%S",
        DIM_WHITE ++ "." ++ DIM_BLUE ++ "{d:0>6}" ++ DIM_WHITE ++ "Z ",
    );
    if (scope != .default)
        try writer.print(
            "{s}" ++ DIM_WHITE ++ "(" ++ WHITE ++ "{s}" ++ DIM_WHITE ++ "): ",
            .{ message_level_text, @tagName(scope) },
        )
    else
        try writer.print("{s}" ++ DIM_WHITE ++ ": ", .{message_level_text});
    try writer.print(RESET ++ format ++ "\n", args);
    try writer.flush();
}

fn bw_log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) !void {
    try write_timestamp(writer, plain_datetime_fmt, plain_micros_fmt ++ " ");
    if (scope != .default)
        try writer.print("{s}({s}): ", .{ comptime message_level.asText(), @tagName(scope) })
    else
        try writer.print("{s}: ", .{comptime message_level.asText()});
    try writer.print(format, args);
    try writer.writeAll("\n");
    try writer.flush();
}

fn json_log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) !void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    var buf: [256]u8 = undefined;
    const message = try std.fmt.bufPrint(&buf, format, args);

    var timebuf: [27]u8 = undefined;
    var timewriter = std.Io.Writer.fixed(&timebuf);
    try write_timestamp(
        &timewriter,
        plain_datetime_fmt,
        plain_micros_fmt,
    );

    var json_writer = std.json.Stringify{ .writer = writer };
    try json_writer.write(.{
        .@"@timestamp" = timebuf[0..],
        .log = .{
            .level = comptime message_level.asText(),
            .logger = scope,
        },
        .service = .{
            .name = service_name,
        },
        .message = message,
    });
    try writer.writeAll("\n");

    try writer.flush();
}
