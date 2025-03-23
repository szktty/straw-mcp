# MemoMCP Server

An MCP server that integrates MemoApp with Claude Desktop.

## Features

- Enables memo creation, listing, and deletion operations from Claude Desktop
- Supports AI assistant in memo management through integration with MemoApp

## Provided Tools

This server provides the following tools:

- **create-memo**: Creates a new memo
- **list-memos**: Retrieves a list of saved memos
- **delete-memo**: Deletes a memo with the specified ID

## Provided Resources

This server provides the following resources:

- **memo://list**: Memo list (in text format)

## Usage

### Prerequisites

- Dart SDK (3.7.0 or higher)
- MemoApp (with available API endpoint)
- Claude Desktop (MCP-enabled version)

### Installation

```bash
# Install dependencies
dart pub get
```

### Execution

```bash
# Run in development mode
dart bin/mcp_server.dart --api-url=http://localhost:8888/api

# Or using Makefile
make run API_URL=http://localhost:8888/api
```

### Build

```bash
# Compile to executable
make build

# Run
make start API_URL=http://localhost:8888/api
```

## Integration with Claude Desktop

Edit Claude Desktop's configuration file (`claude_desktop_config.json`) and add the following:

```json
{
  "mcpServers": {
    "memo": {
      "command": "/absolute/path/to/memo_mcp",
      "args": ["--api-url=http://localhost:8888/api"]
    }
  }
}
```

Configuration file location:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

## Testing

You can use the following commands to test the MCP server:

```bash
# Run unit tests
make test

# Run tool tests (using mock API server)
make test-tools

# Run interactive manual testing
make manual-test
```

### Manual Testing

The `make manual-test` command provides an interactive testing interface.
You can use this tool to manually test the MCP server's tools and resources.

Main features:

1. Get memo list
2. Create a new memo
3. Delete a memo
4. Read resources
5. Get tool and resource listings

Test results are automatically saved to a log file.

### Tool Testing

The `make test-tools` command runs automated tests.
These tests use a mock API server to verify that the MCP server's tools and resources function correctly.

## Command Line Options

```
Usage: memo_mcp [options]

Options:
  -a, --api-url=<URL>          MemoApp API endpoint URL
                               (default: http://localhost:8888/api)
  -l, --log-level=<level>      Log level
                               (default: info)
  -p, --ping-interval=<sec>    Ping interval to API server
                               (default: 30)
  -h, --help                   Display help
```

## Troubleshooting

### Cannot connect to API server

Make sure MemoApp is running and the API endpoint is correctly configured.
By default, it attempts to connect to `http://localhost:8888/api`.

### Not recognized by Claude Desktop

Ensure that the Claude Desktop configuration file is correctly set up.
In particular, verify that the absolute path is specified correctly.

### Errors occur when calling tools

Use the manual test tool (`make manual-test`) to verify tool operation.
Detailed error messages and logs will be generated.