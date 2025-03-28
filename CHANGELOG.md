## develop

- Reimplement server and transport classes.
  - Add `Transport` interface.
  - Replace `ProtocolHandler` class with `Server` class.
  - Replace `StreamServer` class with `StreamServerTransport` class and `StdioServerTransport` class.
  - Replace `SseServer` class with `SseServerTransport` class.
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
