# StrawMCP SDK Examples

This directory contains various examples demonstrating how to use the StrawMCP SDK (Dart MCP SDK). Each example showcases different aspects of the MCP protocol and implementation approaches.

## List of Examples

### example.dart

A simple MCP echo server and client example that works in a single file.

```bash
# Run both server and client simultaneously
dart run example.dart

# Run server only
dart run example.dart --server

# Run client only (server required)
dart run example.dart --client
```

### claude_desktop

Sample implementation of an MCP server designed to integrate with the Claude Desktop application.

For details, please refer to the README in the `claude_desktop` directory.

### memo_app

An example of an MCP server implementation integrated with a Flutter application, providing memo management functionality.

For details, please refer to the README in the `memo_app` directory.

### sse

Implementation example of an MCP server and client using Server-Sent Events (SSE).

```bash
# Start the server
dart run sse_server.dart

# Run the client (server required)
dart run sse_client.dart
```

### stdio

Implementation example of an MCP server and client using standard input/output (stdio).

```bash
# Start the server
dart run stdio_server.dart

# Run the client in a separate process
dart run stdio_client.dart

# Or connect them via pipe
dart run stdio_server.dart | dart run stdio_client.dart
```