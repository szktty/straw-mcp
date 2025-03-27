## develop

- Reimplement server and transport classes.
  - `ProtocolHandler` class as `Server` class.
  - `StreamServer` class as `StreamServerTransport` class and `StdioServerTransport` class.
  - `SseServer` class as `SseServerTransport` class.
- Add `LoggingNotification` class.
- Add `LoggingLevel` enum.
- Add `withArray` function.
- Add `withObject` function.
- Add `name` property to `CallToolRequest`.
- Remove `NotificationParams` class.
- Restruct `JsonRpcNotification` class.
- `Tool` constructor validates `name`.
- Rename `Tool.parameters` to `Tool.inputSchema`.
- Remove `serveStdio` function. Use `Server.start()` with `StdioServerTransport` object instead.
- Remove `serveSse` function. Use `Server.start()` with `SseServerTransport` object instead.

## 0.5.0

- Initial version.
