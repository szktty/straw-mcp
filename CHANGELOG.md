## develop

- Reimplement server and transport classes.
  - Add `Transport` interface.
  - Replace `ProtocolHandler` class with `Server` class.
  - Replace `StreamServer` class with `StreamServerTransport` class and `StdioServerTransport` class.
  - Replace `SseServer` class with `SseServerTransport` class.
- Add `LoggingNotification` class.
- Add `LoggingLevel` enum.
- Add `name` property to `CallToolRequest`.
- Remove `NotificationParams` class.
- Restruct `JsonRpcNotification` class.
- `Tool` constructor validates `name`.
- Rename `Tool.parameters` property to `Tool.inputSchema`.
- Remove `ToolOption` type.
- Remove `ToolParameterOption` type.
- Remove `serveStdio` function. Use `Server.start` method with `StdioServerTransport` object instead.
- Remove `serveSse` function. Use `Server.start` method with `SseServerTransport` object instead.
- Remove `newToolResultText` function. Use `CallToolResult.text` method instead.
- Remove `newToolResultError` function. Use `CallToolResult.error` method instead.
- Remove `newTool` function.
- Remove `withDescription` function.
- Remove `withString` function.
- Remove `withNumber` function.
- Remove `withBoolean` function.
- Remove `required` function.
- Remove `description` function.
- Remove `enumValues` function.
- Remove `defaultValue` function.

## 0.5.0

- Initial version.
