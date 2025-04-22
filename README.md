# ECS Log Formatter

This log formatter makes logs pleasing to humans or Amazon Elastic Container Service, depending on context.

When run in a terminal, it outputs logs in human-friendly format. If ANSI colors are available, they will be used.

Otherwise, logs are formatted as JSON compatible with [Amazon ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-logging-monitoring.html), for example:

```json
{"@timestamp":"2025-01-10T21:01:22.621014Z","log.level":"INFO","log.logger":"server","service":{"name":"log-demonstration-service"},"message":"Server listening on port 8080"}
```

## Example use

```zig
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
```

Running this in terminal gives:

```sh
$ zig build run
2025-01-13T12:16:50.838320Z INFO: Example Service starting up
2025-01-13T12:16:50.838446Z INFO(server): Listening on port 80
2025-01-13T12:16:50.838461Z ERROR: serverNotImplemented
```

Running in Kubernetes, or any other scenario where the program's `stderr` is not going to the terminal:

```sh
$ zig build run |& cat
{"@timestamp":"2025-01-13T12:17:59.733780Z","log.level":"INFO","log.logger":"default","service.name":"example-service","message":"Example Service starting up"}
{"@timestamp":"2025-01-13T12:17:59.733868Z","log.level":"INFO","log.logger":"server","service.name":"example-service","message":"Listening on port 80"}
{"@timestamp":"2025-01-13T12:17:59.733877Z","log.level":"ERROR","log.logger":"default","service.name":"example-service","message":"serverNotImplemented"}
```
