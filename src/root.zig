const std = @import("std");
const zeit = @import("zeit");

const stderr = std.io.getStdErr();
var bw = std.io.bufferedWriter(stderr.writer());
const writer = bw.writer();
const plain_datetime_fmt = "%Y-%m-%dT%H:%M:%S";
const plain_micros_fmt = ".{d:0>6}Z";

const json_writer = struct {
    pub const Error = std.fs.File.WriteError || error{ Overflow, InvalidFormat, UnsupportedSpecifier, UnknownSpecifier };
    pub inline fn writeAll(_: @This(), bytes: []const u8) Error!void {
        return std.json.encodeJsonStringChars(bytes, .{}, writer);
    }
    pub inline fn print(self: @This(), bytes: []const u8, args: anytype) Error!void {
        return std.fmt.format(self, bytes, args);
    }
    pub inline fn writeByte(_: @This(), byte: u8) Error!void {
        return writer.writeByte(byte);
    }
    pub inline fn writeByteNTimes(_: @This(), byte: u8, times: usize) Error!void {
        return writer.writeByteNTimes(byte, times);
    }
    pub inline fn writeBytesNTimes(_: @This(), bytes: []const u8, times: usize) Error!void {
        return writer.writeBytesNTimes(bytes, times);
    }
}{};

const OutputFormat = enum { tty_bw, tty_color, json };
var output_format: ?OutputFormat = null;

pub fn AutoLogger(comptime service_name: []const u8) type {
    return struct {
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
            (switch (output_format.?) {
                .tty_color => color_log(service_name, message_level, scope, format, args),
                .tty_bw => bw_log(service_name, message_level, scope, format, args),
                .json => json_log(service_name, message_level, scope, format, args),
            }) catch unreachable;
        }
    };
}

fn write_timestamp(comptime datetime_fmt: [:0]const u8, comptime micros_fmt: []const u8) !void {
    const now = try zeit.instant(.{});
    try now.time().strftime(writer, datetime_fmt);
    const usec: u32 = @intCast(@divFloor(@mod(now.timestamp, 1_000_000_000), 1_000));
    try std.fmt.format(writer, micros_fmt, .{usec});
}

fn color_log(
    comptime _: []const u8,
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
        .warn => "33mWARNING",
        .err => "1;31mERROR",
    };
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend {
        try write_timestamp(
            LOUD_BLUE ++ "%Y-%m-%d" ++ DIM_WHITE ++ "T" ++ BLUE ++ "%H:%M:%S",
            DIM_WHITE ++ "." ++ DIM_BLUE ++ "{d:0>6}" ++ DIM_WHITE ++ "Z ",
        );
        if (scope != .default)
            try std.fmt.format(writer, "{s}" ++ DIM_WHITE ++ "(" ++ WHITE ++ "{s}" ++ DIM_WHITE ++ "): ", .{ message_level_text, @tagName(scope) })
        else
            try std.fmt.format(writer, "{s}" ++ DIM_WHITE ++ ": ", .{message_level_text});
        try std.fmt.format(writer, RESET ++ format ++ "\n", args);
        try bw.flush();
    }
}

fn bw_log(
    comptime _: []const u8,
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) !void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend {
        try write_timestamp(plain_datetime_fmt, plain_micros_fmt ++ " ");
        if (scope != .default)
            try std.fmt.format(writer, "{s}({s}): ", .{ comptime message_level.asText(), @tagName(scope) })
        else
            try std.fmt.format(writer, "{s}: ", .{comptime message_level.asText()});
        try std.fmt.format(writer, format, args);
        try writer.writeAll("\n");
        try bw.flush();
    }
}

fn json_log(
    comptime service_name: []const u8,
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) !void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend {
        try writer.writeAll("{\"@timestamp\":\"");
        try write_timestamp(plain_datetime_fmt, plain_micros_fmt);
        try std.fmt.format(
            writer,
            "\",\"log.level\":\"{s}\",\"log.logger\":\"{s}\",\"service.name\":\"{s}\",\"message\":\"",
            .{ comptime message_level.asText(), @tagName(scope), service_name },
        );
        try std.fmt.format(json_writer, format, args);
        try writer.writeAll("\"}\n");
        try bw.flush();
    }
}
