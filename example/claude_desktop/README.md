# Claude Desktop MCP Server Sample

This directory contains sample code for creating an MCP server for Claude Desktop using the Dart MCP SDK.

## Overview

This sample consists of two main files:

- `claude_desktop_server.dart` - Implementation example of an MCP server that works with Claude Desktop
- `claude_desktop_client.dart` - Client implementation example for testing the server

## Features

The server provides the following categories of features:

1. **Text Manipulation Tools**
   - `text_count` - Calculates word count, character count, and line count of text
   - `text_format` - Converts text to uppercase, lowercase, title case, etc.
   - `text_split` - Splits text by a specified delimiter

2. **Mathematical Tools**
   - `calculator` - Evaluates mathematical expressions
   - `statistics` - Calculates statistical information (mean, median, etc.) for lists of numbers

3. **Utility Tools**
   - `date_time` - Gets current date and time
   - `random_generator` - Generates random numbers, UUIDs, or strings
   - `json_tools` - Formats, validates, and queries JSON data

4. **System Information Resource**
   - `resource://system/info` - Provides system information

## Usage

### Building the Binary

Run the following commands in the example/claude_desktop directory to build the binary:

```bash
# Create bin directory if it doesn't exist
mkdir -p bin

# Compile
dart compile exe claude_desktop_server.dart -o bin/claude_desktop_server
```

### Setting up in Claude Desktop

For Claude Desktop configuration, please refer to the official documentation. To configure the MCP server, specify the path to the compiled binary (the one compiled from `claude_desktop_server.dart`) as follows:

```json
{
  "mcpServers": {
    "dart-mcp-server": {
      "command": "/absolute/path/to/bin/claude_desktop_server",
      "args": []
    }
  }
}
```

In this configuration example, replace `/absolute/path/to/bin/claude_desktop_server` with the absolute path to the binary you compiled earlier. For example, on macOS it might look like `/Users/username/path/to/example/claude_desktop/bin/claude_desktop_server`.

### Log Files

The server generates log files in the `logs` directory located in the same directory as the binary. For example, if the binary is at `bin/claude_desktop_server`, the log files will be created in the `bin/logs` directory.

The log files include:
- `mcp_server_[timestamp].log` - General server logs
- `responses_[timestamp].log` - Detailed request/response logs

These log files are useful for debugging and troubleshooting.

## Usage Examples in Claude Desktop

When this server is configured in Claude Desktop, you can call tools with prompts like these:

### Date and Time Tool
```
@date_time
```
This will display the current date and time. You can also specify a format:
```
@date_time {"format": "iso"}
```

### Calculator Tool
```
@calculator {"expression": "1 + 2 * 3"}
```
Or in a more natural way:
```
Please calculate this: @calculator 1 + 2 * 3
```

### Text Manipulation Tools
```
@text_count {"text": "This is a sample text.\nCounting words, characters, and lines."}
```

```
@text_format {"text": "hello world", "format": "uppercase"}
```

### Statistics Tool
```
@statistics {"numbers": "10, 20, 30, 40, 50"}
```

### Random Generator Tool
```
@random_generator {"type": "uuid"}
```

```
@random_generator {"type": "number", "min": 1, "max": 100}
```

```
@random_generator {"type": "string", "length": 16}
```

### JSON Tools
```
@json_tools {"operation": "format", "json": "{\"name\":\"John\",\"age\":30}"}
```

```
@json_tools {"operation": "query", "json": "{\"users\":[{\"name\":\"John\",\"age\":30}]}", "path": "users.0.name"}
```

## Testing with the Client (Optional)

While the server is running, you can test it using the client with the following command:

```bash
dart run claude_desktop_client.dart
```

## Notes

- This sample is intended for use in a local environment
- If using in a production environment, please ensure appropriate security measures
- Check compatibility with the latest version of Claude Desktop
