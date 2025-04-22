const std = @import("std");
const ecs = @import("ecs-log-formatter");

pub const std_options: std.Options = std.Options{
    .logFn = ecs.log,
};

pub fn main() !void {
    ecs.service_name = "example-service";
    std.log.info("Example Service starting up", .{});
    try runServer();
}

fn runServer() !void {
    const log = std.log.scoped(.server);
    const port = 80;
    log.info("Listening on port {d}", .{port});
    return error.serverNotImplemented;
}
