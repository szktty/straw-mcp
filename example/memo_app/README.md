# MemoApp Project

This project is a demo application using the MCP protocol. It consists of two components: a Flutter application with create, edit, and delete memo functionality, and a command-line tool that connects with Claude Desktop via the MCP protocol.

## Structure

- **app/** - Flutter desktop application
- **mcp_server/** - MCP command line tool

## Setup and Execution

### Flutter Application (MemoApp)

```bash
# Navigate to the app directory
cd app

# Install dependencies
flutter pub get

# Run the app
flutter run -d macos  # for macOS
# or
flutter run -d windows  # for Windows
```

### MCP Server (MemoMCP)

```bash
# Navigate to the MCP server directory
cd mcp_server

# Install dependencies
dart pub get

# Run in development mode
dart bin/mcp_server.dart --api-url=http://localhost:8080/api

# Compile to executable
dart compile exe bin/mcp_server.dart -o bin/mcp_server
```

## Integration with Claude Desktop

Add the following to the Claude Desktop configuration file (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "memo": {
      "command": "/absolute/path/to/mcp_server/bin/mcp_server",
      "args": ["--api-url=http://localhost:8080/api"]
    }
  }
}
```

## License

This project is released under the Apache License 2.0.
