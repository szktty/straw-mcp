import 'package:straw_mcp/src/json/jsonable.dart';
import 'package:straw_mcp/src/mcp/types.dart';

/// A reference to a resource or resource template definition.
class ResourceReference implements Jsonable {
  /// Create a new resource reference.
  ///
  /// [uri]: The URI or URI template of the resource.
  ResourceReference(this.uri);

  /// The URI or URI template of the resource.
  final String uri;

  /// Converts the resource reference to a JSON map.
  Map<String, dynamic> toJson() {
    return {'type': 'ref/resource', 'uri': uri};
  }

  /// Creates a resource reference from a JSON map.
  factory ResourceReference.fromJson(Map<String, dynamic> json) {
    return ResourceReference(json['uri'] as String);
  }
}

/// Identifies a prompt.
class PromptReference implements Jsonable {
  /// Create a new prompt reference.
  ///
  /// [name]: The name of the prompt or prompt template.
  PromptReference(this.name);

  /// The name of the prompt or prompt template.
  final String name;

  /// Converts the prompt reference to a JSON map.
  Map<String, dynamic> toJson() {
    return {'type': 'ref/prompt', 'name': name};
  }

  /// Creates a prompt reference from a JSON map.
  factory PromptReference.fromJson(Map<String, dynamic> json) {
    return PromptReference(json['name'] as String);
  }
}

/// A request from the client to the server, to ask for completion options.
class CompleteRequest extends Request {
  /// Create a new completion request.
  ///
  /// [ref]: A reference to a prompt or resource.
  /// [argumentName]: The name of the argument to complete.
  /// [argumentValue]: The value of the argument to use for completion matching.
  CompleteRequest({
    required Object ref,
    required String argumentName,
    required String argumentValue,
  }) : super(method: 'completion/complete', params: {
         'ref':
             (ref is PromptReference || ref is ResourceReference)
                 ? (ref as Jsonable).toJson()
                 : throw ArgumentError(
                   'ref must be a PromptReference or ResourceReference',
                 ),
         'argument': {'name': argumentName, 'value': argumentValue},
       });

  /// Create a new completion request for a prompt.
  ///
  /// [promptName]: The name of the prompt or prompt template.
  /// [argumentName]: The name of the argument to complete.
  /// [argumentValue]: The value of the argument to use for completion matching.
  factory CompleteRequest.forPrompt({
    required String promptName,
    required String argumentName,
    required String argumentValue,
  }) {
    return CompleteRequest(
      ref: PromptReference(promptName),
      argumentName: argumentName,
      argumentValue: argumentValue,
    );
  }

  /// Create a new completion request for a resource.
  ///
  /// [resourceUri]: The URI or URI template of the resource.
  /// [argumentName]: The name of the argument to complete.
  /// [argumentValue]: The value of the argument to use for completion matching.
  factory CompleteRequest.forResource({
    required String resourceUri,
    required String argumentName,
    required String argumentValue,
  }) {
    return CompleteRequest(
      ref: ResourceReference(resourceUri),
      argumentName: argumentName,
      argumentValue: argumentValue,
    );
  }

  /// Creates a completion request from a JSON map.
  factory CompleteRequest.fromJson(Map<String, dynamic> json) {
    final params = json['params'] as Map<String, dynamic>;
    final refJson = params['ref'] as Map<String, dynamic>;
    final refType = refJson['type'] as String;

    final argument = params['argument'] as Map<String, dynamic>;
    final argumentName = argument['name'] as String;
    final argumentValue = argument['value'] as String;

    Object ref;
    if (refType == 'ref/prompt') {
      ref = PromptReference.fromJson(refJson);
    } else if (refType == 'ref/resource') {
      ref = ResourceReference.fromJson(refJson);
    } else {
      throw ArgumentError('Unknown reference type: $refType');
    }

    return CompleteRequest(
      ref: ref,
      argumentName: argumentName,
      argumentValue: argumentValue,
    );
  }
}

/// The server's response to a completion/complete request.
class CompleteResult extends Result {
  /// Create a new completion result.
  ///
  /// [values]: An array of completion values.
  /// [total]: The total number of completion options available.
  /// [hasMore]: Indicates whether there are additional completion options.
  CompleteResult({
    required this.values,
    this.total,
    this.hasMore = false,
    super.meta,
  });

  /// An array of completion values.
  final List<String> values;

  /// The total number of completion options available.
  final int? total;

  /// Indicates whether there are additional completion options.
  final bool hasMore;

  /// Creates a completion result from a JSON map.
  factory CompleteResult.fromJson(Map<String, dynamic> json) {
    final completion = json['completion'] as Map<String, dynamic>;
    return CompleteResult(
      values: (completion['values'] as List<dynamic>).cast<String>(),
      total: completion['total'] as int?,
      hasMore: completion['hasMore'] as bool? ?? false,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }

  /// Converts the completion result to a JSON map.
  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();

    result['completion'] = {
      'values': values,
      if (total != null) 'total': total,
      if (hasMore) 'hasMore': hasMore,
    };

    return result;
  }
}
