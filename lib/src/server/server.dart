/// Core server implementation for the MCP protocol.
library;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:straw_mcp/src/json_rpc/message.dart';
import 'package:straw_mcp/src/server/builder/builder.dart';
import 'package:straw_mcp/src/shared/logging/logging_mixin.dart';
import 'package:straw_mcp/src/mcp/logging.dart';
import 'package:straw_mcp/src/mcp/prompts.dart';
import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:straw_mcp/src/mcp/tools.dart';
import 'package:straw_mcp/src/mcp/types.dart';
import 'package:straw_mcp/src/mcp/utils.dart';
import 'package:straw_mcp/src/server/sse_server_transport.dart';
import 'package:straw_mcp/src/server/stdio_server_transport.dart';
import 'package:straw_mcp/src/shared/logging/logging_options.dart';
import 'package:straw_mcp/src/shared/transport.dart';
import 'package:synchronized/synchronized.dart';

/// Handler function for resource requests.
typedef ResourceHandlerFunction =
    Future<List<ResourceContents>> Function(ReadResourceRequest request);

/// Handler function for resource template requests.
typedef ResourceTemplateHandlerFunction =
    Future<List<ResourceContents>> Function(ReadResourceRequest request);

/// Handler function for prompt requests.
typedef PromptHandlerFunction =
    Future<GetPromptResult> Function(GetPromptRequest request);

/// Handler function for tool calls.
typedef ToolHandlerFunction =
    Future<CallToolResult> Function(CallToolRequest request);

/// Handler function for notifications.
typedef NotificationHandlerFunction =
    void Function(JsonRpcNotification notification);

/// Combines a tool with its handler function.
class ServerTool {
  /// Creates a new server tool.
  ///
  /// - [tool]: The tool definition including name, description, and parameters
  /// - [handler]: The function that will be called when the tool is invoked
  ServerTool(this.tool, this.handler);

  /// The tool definition.
  final Tool tool;

  /// The handler function for the tool.
  final ToolHandlerFunction handler;
}

/// Context for client identification in notifications.
class NotificationContext {
  /// Creates a new notification context.
  ///
  /// - [clientId]: Unique identifier for the client
  /// - [sessionId]: Identifier for the client session
  NotificationContext(this.clientId, this.sessionId);

  /// Client identifier.
  final String clientId;

  /// Session identifier.
  final String sessionId;
}

/// Combines a notification with client context.
class ServerNotification {
  /// Creates a new server notification.
  ServerNotification(this.context, this.notification);

  /// The client context.
  final NotificationContext context;

  /// The notification message.
  final JsonRpcNotification notification;
}

/// Server options for configuring the server's behavior and capabilities.
class ServerOptions {
  ServerOptions({
    this.capabilities,
    this.enforceStrictCapabilities = false,
    this.instructions,
    this.logging = const LoggingOptions(),
    this.timeout,
  });

  final ServerCapabilities? capabilities;
  final bool enforceStrictCapabilities;
  final String? instructions;
  final LoggingOptions logging;
  final Duration? timeout;
}

/// Core implementation of an MCP server.
///
/// Handles all protocol-level interactions with clients, including
/// request handling, notification management, and capability negotiation.
/// This is the main server-side implementation of the Model Context Protocol.
class Server with LoggingMixin {
  /// Creates a new server using the builder pattern.
  ///
  /// This static factory method uses the ServerBuilder to create and configure
  /// an MCP server with a fluent, declarative API.
  ///
  /// Example:
  /// ```dart
  /// final server = Server.build(
  ///   (b) => b
  ///     ..name = 'example-server'
  ///     ..version = '1.0.0'
  ///     ..logging()
  ///     ..tool(
  ///       (t) => t
  ///         ..name = 'calculator'
  ///         ..description = 'Simple calculator'
  ///         ..number(name: 'a', required: true)
  ///         ..number(name: 'b', required: true)
  ///         ..string(
  ///           name: 'operation',
  ///           required: true,
  ///           enumValues: ['add', 'subtract', 'multiply', 'divide']
  ///         )
  ///         ..handler = (request) async {
  ///           // Calculator implementation
  ///         },
  ///     ),
  /// );
  /// ```
  ///
  /// [updates] - A function that configures the server builder with the desired options.
  static Server build(void Function(ServerBuilder) updates) {
    final builder = ServerBuilder();
    updates(builder);
    return builder.build();
  }

  /// Creates a new MCP server.
  ///
  /// - [name]: The name of the server to advertise to clients
  /// - [version]: The version of the server implementation
  /// - [options]: Optional server configuration options
  /// - [logger]: Optional logger for server events
  Server({
    required this.name,
    required this.options,
    this.version = latestProtocolVersion,
  }) {
    initializeLogFile();
  }

  static const latestProtocolVersion = '2024-11-05';
  static const jsonrpcVersion = '2.0';

  /// Name of the server.
  final String name;

  /// Version of the server.
  final String version;

  final ServerOptions options;

  /// Logger for server events.
  @override
  LoggingOptions get loggingOptions => options.logging;

  /// Instructions for using the server.
  String instructions = '';

  /// Server capabilities that will be advertised to clients.
  ///
  /// Defines what features this server supports, such as resources,
  /// prompts, tools, and logging.
  final ServerCapabilities capabilities = ServerCapabilities();

  // Resources and handlers
  final Map<String, _ResourceEntry> _resources = {};
  final Map<String, _ResourceTemplateEntry> _resourceTemplates = {};
  final Map<String, Prompt> _prompts = {};
  final Map<String, PromptHandlerFunction> _promptHandlers = {};
  final Map<String, ServerTool> _tools = {};
  final Map<String, NotificationHandlerFunction> _notificationHandlers = {};

  // Notification management
  final StreamController<ServerNotification> _notifications =
      StreamController<ServerNotification>.broadcast();

  // Client context and locks
  NotificationContext? _currentClient;
  final Lock _lock = Lock();
  bool _initialized = false;

  // トランスポート関連
  Transport? _transport;
  bool _isTransportStarted = false;

  /// MCPサーバーを起動します。
  ///
  /// 指定された[transport]を使用して通信を開始します。
  Future<void> start(Transport transport) async {
    if (_isTransportStarted) {
      logInfo('Server is already running');
      return;
    }

    _transport = transport;
    logInfo('Starting MCP server');

    // トランスポートのコールバックを設定
    _transport!.onMessage = (message) async {
      final response = await handleMessage(message);
      if (response != null) {
        await _transport!.send(response);
      }
    };

    _transport!.onError = (error) {
      logError('Transport error: $error');
    };

    _transport!.onClose = () {
      logInfo('Transport closed');
      if (!_isClosed) {
        // トランスポートが閉じられた場合、サーバーも閉じる
        close();
      }
    };

    // トランスポートを開始
    await _transport!.start();
    _isTransportStarted = true;

    // 通知監視を開始
    _setupNotificationListener();

    logInfo('MCP server started');
  }

  /// 通知リスナーをセットアップします。
  void _setupNotificationListener() {
    // 通知をトランスポートに送信
    notifications.listen(
      (notification) {
        if (_transport != null && _isTransportStarted) {
          _transport!.send(notification.notification);
        }
      },
      onError: (error) {
        logError('Error in notification stream: $error');
      },
    );
  }

  /// Handles an incoming JSON-RPC message.
  Future<JsonRpcMessage?> handleMessage(String message) async {
    try {
      final jsonMap = json.decode(message) as Map<String, dynamic>;

      // Check for valid JSON-RPC version
      final jsonrpc = jsonMap['jsonrpc'] as String?;
      if (jsonrpc != jsonRpcVersion) {
        return createErrorResponse(
          jsonMap['id'] as RequestId?,
          invalidRequest,
          'Invalid JSON-RPC version',
        );
      }

      // Handle notifications (no id)
      if (!jsonMap.containsKey('id')) {
        final notification = JsonRpcNotification.fromJson(jsonMap);
        _handleNotification(notification);
        return null;
      }

      final id = jsonMap['id'] as RequestId;
      final method = jsonMap['method'] as String?;

      if (method == null) {
        return createErrorResponse(id, invalidRequest, 'Method is required');
      }

      // Handle different request types
      switch (method) {
        case 'initialize':
          return await _handleInitialize(jsonMap);
        case 'ping':
          return await _handlePing(id);
        case 'resources/list':
          return await _handleListResources(id, jsonMap);
        case 'resources/templates/list':
          return await _handleListResourceTemplates(id, jsonMap);
        case 'resources/read':
          return await _handleReadResource(id, jsonMap);
        case 'resources/subscribe':
          return await _handleSubscribe(id, jsonMap);
        case 'resources/unsubscribe':
          return await _handleUnsubscribe(id, jsonMap);
        case 'prompts/list':
          return await _handleListPrompts(id, jsonMap);
        case 'prompts/get':
          return await _handleGetPrompt(id, jsonMap);
        case 'tools/list':
          return await _handleListTools(id, jsonMap);
        case 'tools/call':
          return await _handleCallTool(id, jsonMap);
        case 'logging/setLevel':
          return await _handleSetLevel(id, jsonMap);
        case 'completion/complete':
          return await _handleComplete(id, jsonMap);
        default:
          return createErrorResponse(
            id,
            methodNotFound,
            'Method not found: $method',
          );
      }
    } on Exception catch (e) {
      return createErrorResponse(
        null as RequestId?,
        parseError,
        'Parse error: $e',
      );
    }
  }

  // Various handler methods follow...

  // Initialize request handler
  Future<JsonRpcMessage> _handleInitialize(Map<String, dynamic> jsonMap) async {
    final id = jsonMap['id'] as RequestId;
    final params = jsonMap['params'] as Map<String, dynamic>?;

    if (params == null) {
      return createErrorResponse(id, invalidParams, 'Missing params');
    }

    // Build server capabilities
    final serverCapabilities = ServerCapabilities(
      logging: capabilities.logging,
    );

    if (capabilities.resources != null) {
      serverCapabilities.resources = capabilities.resources;
    }

    if (capabilities.prompts != null) {
      serverCapabilities.prompts = capabilities.prompts;
    }

    if (capabilities.tools != null) {
      serverCapabilities.tools = capabilities.tools;
    }

    final result = InitializeResult(
      protocolVersion: latestProtocolVersion,
      capabilities: serverCapabilities,
      serverInfo: Implementation(name: name, version: version),
      instructions: instructions.isEmpty ? null : instructions,
    );

    _initialized = true;

    return createResponse(id, result.toJson());
  }

  // Ping request handler
  Future<JsonRpcMessage> _handlePing(RequestId id) async {
    return createResponse(id, <String, dynamic>{});
  }

  // Resource methods
  Future<JsonRpcMessage> _handleListResources(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.resources == null) {
      return createErrorResponse(id, methodNotFound, 'Resources not supported');
    }

    final resources = <Resource>[];
    await _lock.synchronized(() {
      resources.addAll(_resources.values.map((e) => e.resource));
    });

    final result = ListResourcesResult(resources: resources);
    return createResponse(id, result.toJson());
  }

  Future<JsonRpcMessage> _handleListResourceTemplates(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.resources == null) {
      return createErrorResponse(id, methodNotFound, 'Resources not supported');
    }

    final templates = <ResourceTemplate>[];
    await _lock.synchronized(() {
      templates.addAll(_resourceTemplates.values.map((e) => e.template));
    });

    final result = ListResourceTemplatesResult(resourceTemplates: templates);
    return createResponse(id, result.toJson());
  }

  Future<JsonRpcMessage> _handleReadResource(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.resources == null) {
      return createErrorResponse(id, methodNotFound, 'Resources not supported');
    }

    final params = jsonMap['params'] as Map<String, dynamic>?;
    if (params == null || !params.containsKey('uri')) {
      return createErrorResponse(
        id,
        invalidParams,
        'Missing required parameter: uri',
      );
    }

    final uri = params['uri'] as String;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};
    final request = ReadResourceRequest(uri: uri, arguments: arguments);

    // Try direct resource first
    ResourceHandlerFunction? directHandler;
    ResourceTemplateHandlerFunction? templateHandler;

    await _lock.synchronized(() {
      if (_resources.containsKey(uri)) {
        directHandler = _resources[uri]!.handler;
      } else {
        // Try to match against templates
        for (final entry in _resourceTemplates.entries) {
          if (matchesUriTemplate(uri, entry.key)) {
            templateHandler = entry.value.handler;
            break;
          }
        }
      }
    });

    // Handle the resource
    if (directHandler != null) {
      return _executeResourceHandler(id, directHandler!, request);
    } else if (templateHandler != null) {
      return _executeResourceTemplateHandler(id, templateHandler!, request);
    } else {
      return createErrorResponse(
        id,
        invalidParams,
        'No handler found for resource URI: $uri',
      );
    }
  }

  Future<JsonRpcMessage> _executeResourceHandler(
    RequestId id,
    ResourceHandlerFunction handler,
    ReadResourceRequest request,
  ) async {
    try {
      final contents = await handler(request);
      final result = ReadResourceResult(contents: contents);
      return createResponse(id, result.toJson());
    } on Exception catch (e) {
      return createErrorResponse(
        id,
        internalError,
        'Error executing resource handler: $e',
      );
    }
  }

  Future<JsonRpcMessage> _executeResourceTemplateHandler(
    RequestId id,
    ResourceTemplateHandlerFunction handler,
    ReadResourceRequest request,
  ) async {
    try {
      final contents = await handler(request);
      final result = ReadResourceResult(contents: contents);
      return createResponse(id, result.toJson());
    } on Exception catch (e) {
      return createErrorResponse(
        id,
        internalError,
        'Error executing resource template handler: $e',
      );
    }
  }

  Future<JsonRpcMessage> _handleSubscribe(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.resources == null || !capabilities.resources!.subscribe) {
      return createErrorResponse(
        id,
        methodNotFound,
        'Resource subscription not supported',
      );
    }

    // Implementation would go here...

    return createResponse(id, <String, dynamic>{});
  }

  Future<JsonRpcMessage> _handleUnsubscribe(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.resources == null || !capabilities.resources!.subscribe) {
      return createErrorResponse(
        id,
        methodNotFound,
        'Resource subscription not supported',
      );
    }

    // Implementation would go here...

    return createResponse(id, <String, dynamic>{});
  }

  // Prompt methods
  Future<JsonRpcMessage> _handleListPrompts(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.prompts == null) {
      return createErrorResponse(id, methodNotFound, 'Prompts not supported');
    }

    final prompts = <Prompt>[];
    await _lock.synchronized(() {
      prompts.addAll(_prompts.values);
    });

    final result = ListPromptsResult(prompts: prompts);
    return createResponse(id, result.toJson());
  }

  Future<JsonRpcMessage> _handleGetPrompt(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.prompts == null) {
      return createErrorResponse(id, methodNotFound, 'Prompts not supported');
    }

    final params = jsonMap['params'] as Map<String, dynamic>?;
    if (params == null || !params.containsKey('name')) {
      return createErrorResponse(
        id,
        invalidParams,
        'Missing required parameter: name',
      );
    }

    final name = params['name'] as String;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};
    final request = GetPromptRequest(name: name, arguments: arguments);

    PromptHandlerFunction? handler;
    await _lock.synchronized(() {
      handler = _promptHandlers[name];
    });

    if (handler == null) {
      return createErrorResponse(id, invalidParams, 'Prompt not found: $name');
    }

    return _executePromptHandler(id, handler!, request);
  }

  Future<JsonRpcMessage> _executePromptHandler(
    RequestId id,
    PromptHandlerFunction handler,
    GetPromptRequest request,
  ) async {
    try {
      final result = await handler(request);
      return createResponse(id, result.toJson());
    } on Exception catch (e) {
      return createErrorResponse(
        id,
        internalError,
        'Error executing prompt handler: $e',
      );
    }
  }

  // Tool methods
  Future<JsonRpcMessage> _handleListTools(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.tools == null) {
      return createErrorResponse(id, methodNotFound, 'Tools not supported');
    }

    final tools = <Tool>[];
    await _lock.synchronized(() {
      tools.addAll(_tools.values.map((e) => e.tool));
    });

    // Sort tools by name for consistent ordering
    tools.sort((a, b) => a.name.compareTo(b.name));

    final result = ListToolsResult(tools: tools);
    return createResponse(id, result.toJson());
  }

  Future<JsonRpcMessage> _handleCallTool(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (capabilities.tools == null) {
      return createErrorResponse(id, methodNotFound, 'Tools not supported');
    }

    final params = jsonMap['params'] as Map<String, dynamic>?;
    if (params == null || !params.containsKey('name')) {
      return createErrorResponse(
        id,
        invalidParams,
        'Missing required parameter: name',
      );
    }

    final name = params['name'] as String;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};
    final request = CallToolRequest(name: name, arguments: arguments);

    ServerTool? tool;
    await _lock.synchronized(() {
      tool = _tools[name];
    });

    if (tool == null) {
      return createErrorResponse(id, invalidParams, 'Tool not found: $name');
    }

    return _executeToolHandler(id, tool!.handler, request);
  }

  Future<JsonRpcMessage> _executeToolHandler(
    RequestId id,
    ToolHandlerFunction handler,
    CallToolRequest request,
  ) async {
    try {
      final result = await handler(request);
      return createResponse(id, result.toJson());
    } on Exception catch (e) {
      return createErrorResponse(
        id,
        internalError,
        'Error executing tool handler: $e',
      );
    }
  }

  // Logging methods
  Future<JsonRpcMessage> _handleSetLevel(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    if (!capabilities.logging) {
      return createErrorResponse(id, methodNotFound, 'Logging not supported');
    }

    // Implementation would go here...

    return createResponse(id, <String, dynamic>{});
  }

  // Completion methods
  Future<JsonRpcMessage> _handleComplete(
    RequestId id,
    Map<String, dynamic> jsonMap,
  ) async {
    // Implementation would go here...

    return createResponse(id, <String, dynamic>{
      'completion': <String, dynamic>{
        'values': <String>[],
        'total': 0,
        'hasMore': false,
      },
    });
  }

  // Notification handling
  void _handleNotification(JsonRpcNotification notification) {
    final method = notification.method;

    NotificationHandlerFunction? handler;
    _lock.synchronized(() {
      handler = _notificationHandlers[method];
    });

    handler?.call(notification);
  }

  /// Adds a resource and its handler to the server.
  ///
  /// The [resource] defines the metadata for the resource, while the
  /// [handler] function is called when a client requests to read the resource.
  void addResource(Resource resource, ResourceHandlerFunction handler) {
    _lock.synchronized(() {
      capabilities.resources ??= ResourceCapabilities();

      _resources[resource.uri] = _ResourceEntry(resource, handler);
    });
  }

  /// Adds a resource template and its handler to the server.
  ///
  /// Resource templates allow for dynamic resources with variable parts in their URIs.
  /// The [template] defines the URI template pattern, while the [handler] function
  /// is called when a client requests to read a resource matching the template.
  void addResourceTemplate(
    ResourceTemplate template,
    ResourceTemplateHandlerFunction handler,
  ) {
    _lock.synchronized(() {
      capabilities.resources ??= ResourceCapabilities();

      _resourceTemplates[template.uriTemplate] = _ResourceTemplateEntry(
        template,
        handler,
      );
    });
  }

  /// Adds a prompt and its handler to the server.
  ///
  /// The [prompt] defines the metadata for the prompt, while the
  /// [handler] function is called when a client requests to get the prompt.
  void addPrompt(Prompt prompt, PromptHandlerFunction handler) {
    _lock.synchronized(() {
      capabilities.prompts ??= PromptCapabilities();

      _prompts[prompt.name] = prompt;
      _promptHandlers[prompt.name] = handler;
    });
  }

  /// Adds a tool and its handler to the server.
  ///
  /// The [tool] defines the metadata and parameters for the tool, while the
  /// [handler] function is called when a client requests to call the tool.
  void addTool(Tool tool, ToolHandlerFunction handler) {
    addTools([ServerTool(tool, handler)]);
  }

  /// Adds multiple tools at once.
  void addTools(List<ServerTool> tools) {
    var shouldNotify = false;

    _lock.synchronized(() {
      capabilities.tools ??= ToolCapabilities();

      for (final tool in tools) {
        _tools[tool.tool.name] = tool;
      }

      shouldNotify = _initialized;
    });

    if (shouldNotify) {
      sendNotification(ToolListChangedNotification());
    }
  }

  /// Replaces all tools with a new set.
  void setTools(List<ServerTool> tools) {
    var shouldNotify = false;

    _lock.synchronized(() {
      _tools.clear();

      for (final tool in tools) {
        _tools[tool.tool.name] = tool;
      }

      shouldNotify = _initialized;
    });

    if (shouldNotify) {
      sendNotification(ToolListChangedNotification());
    }
  }

  /// Deletes the specified tools.
  void deleteTools(List<String> names) {
    var shouldNotify = false;

    _lock.synchronized(() {
      for (final name in names) {
        _tools.remove(name);
      }

      shouldNotify = _initialized;
    });

    if (shouldNotify) {
      sendNotification(ToolListChangedNotification());
    }
  }

  /// Adds a notification server.
  void addNotificationHandler(
    String method,
    NotificationHandlerFunction handler,
  ) {
    _lock.synchronized(() {
      _notificationHandlers[method] = handler;
    });
  }

  /// Sets the current client context.
  void setCurrentClient(NotificationContext context) {
    _currentClient = context;
  }

  /// Gets the stream of server notifications.
  Stream<ServerNotification> get notifications => _notifications.stream;

  // LoggingMixin によりロギングメソッドが提供される

  /// Sends a log message notification to the client.
  ///
  /// This method can be used to send log messages to the client when the server
  /// has logging capabilities enabled. The client must have registered for these
  /// notifications or set a logging level via setLevel request.
  ///
  /// - [notification]: The log message notification to send
  void sendLoggingNotification(LoggingMessageNotification notification) {
    if (!capabilities.logging) {
      return; // Logging not supported/enabled
    }
    sendNotification(notification);
  }

  /// Sends a notification to the client.
  ///
  /// This is a general-purpose method to send any type of notification to the client.
  /// Use this method when you need to send custom notifications that are not
  /// covered by specific methods like [sendLoggingNotification].
  ///
  /// - [notification]: The notification to send
  void sendNotification(Notification notification) {
    final jsonNotification = JsonRpcNotification(
      version: jsonRpcVersion,
      method: notification.method,
      params: notification.params,
    );

    // トランスポート経由で直接送信
    if (_transport != null && _isTransportStarted) {
      _transport!.send(jsonNotification);
      return;
    }

    // 後方互換性のために通知キューにも追加
    if (_currentClient != null) {
      _notifications.add(ServerNotification(_currentClient!, jsonNotification));
    }
  }

  /// Flag indicating whether the server is closed
  bool _isClosed = false;

  /// State of the server closure
  final StreamController<bool> _closeStateController =
      StreamController<bool>.broadcast();

  /// Stream notifying the state of the server closure
  Stream<bool> get closeState => _closeStateController.stream;

  /// Whether the server is closed
  bool get isClosed => _isClosed;

  /// サーバーを閉じて、リソースを解放します。
  Future<void> close() async {
    if (_isClosed) {
      return; // すでに閉じている場合は何もしない
    }

    _isClosed = true;
    logInfo('Closing MCP server');

    try {
      // 閉じ始めを通知
      _closeStateController.add(true);

      // トランスポートを閉じる
      if (_transport != null && _isTransportStarted) {
        try {
          await _transport!.close();
          _transport = null;
          _isTransportStarted = false;
          logInfo('Transport closed');
        } catch (e) {
          logError('Error closing transport: $e');
        }
      }

      // ログファイルを閉じる
      await closeLogFile();

      // 各リソースのクリーンアップ
      await _lock.synchronized(() {
        _resources.clear();
        _resourceTemplates.clear();
        _tools.clear();
        _prompts.clear();
        _promptHandlers.clear();
        _notificationHandlers.clear();
      });

      // 通知コントローラーを閉じる
      if (!_notifications.isClosed) {
        await _notifications.close();
      }

      // 閉じる状態のコントローラーを閉じる
      if (!_closeStateController.isClosed) {
        await _closeStateController.close();
      }

      logInfo('MCP server closed successfully');
    } catch (e) {
      logError('Error closing MCP server: $e');
      // エラーがあっても、可能な限りリソースを解放するために続行

      try {
        if (!_notifications.isClosed) {
          await _notifications.close();
        }
      } catch (e2) {
        logError('Error closing notifications controller: $e2');
      }

      try {
        if (!_closeStateController.isClosed) {
          await _closeStateController.close();
        }
      } catch (e2) {
        logError('Error closing close state controller: $e2');
      }
    }
  }
}

/// Internal class for storing resources and their handlers.
class _ResourceEntry {
  _ResourceEntry(this.resource, this.handler);

  final Resource resource;
  final ResourceHandlerFunction handler;
}

/// Internal class for storing resource templates and their handlers.
class _ResourceTemplateEntry {
  _ResourceTemplateEntry(this.template, this.handler);

  final ResourceTemplate template;
  final ResourceTemplateHandlerFunction handler;
}
