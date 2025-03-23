import 'package:straw_mcp/src/mcp/resources.dart';
import 'package:test/test.dart';

// ignore_for_file: avoid_print, avoid_dynamic_calls

void main() {
  group('Resource definition tests', () {
    test('Resource class converts to JSON correctly', () {
      final resource = Resource(
        uri: 'file:///path/to/document.txt',
        name: 'Text File',
        description: 'Sample text file',
        mimeType: 'text/plain',
        size: 1024,
      );

      final json = resource.toJson();

      expect(json['uri'], equals('file:///path/to/document.txt'));
      expect(json['name'], equals('Text File'));
      expect(json['description'], equals('Sample text file'));
      expect(json['mimeType'], equals('text/plain'));
      expect(json['size'], equals(1024));
    });

    test('Resource.fromJson correctly restores resource', () {
      final jsonData = {
        'uri': 'file:///example.json',
        'name': 'JSON File',
        'description': 'Configuration file',
        'mimeType': 'application/json',
        'size': 512,
      };

      final resource = Resource.fromJson(jsonData);

      expect(resource.uri, equals('file:///example.json'));
      expect(resource.name, equals('JSON File'));
      expect(resource.description, equals('Configuration file'));
      expect(resource.mimeType, equals('application/json'));
      expect(resource.size, equals(512));
    });

    test('ResourceTemplate class converts to JSON correctly', () {
      final template = ResourceTemplate(
        uriTemplate: 'file:///users/{userId}/profile',
        name: 'User Profile',
        description: 'User-specific profile information',
        mimeType: 'application/json',
      );

      final json = template.toJson();

      expect(json['uriTemplate'], equals('file:///users/{userId}/profile'));
      expect(json['name'], equals('User Profile'));
      expect(json['description'], equals('User-specific profile information'));
      expect(json['mimeType'], equals('application/json'));
    });
  });

  group('Resource content tests', () {
    test('TextResourceContents converts to JSON correctly', () {
      final contents = TextResourceContents(
        uri: 'file:///example.txt',
        text: 'Hello, world!',
        mimeType: 'text/plain',
      );

      final json = contents.toJson();

      expect(json['uri'], equals('file:///example.txt'));
      expect(json['text'], equals('Hello, world!'));
      expect(json['mimeType'], equals('text/plain'));
      expect(json.containsKey('blob'), isFalse);
    });

    test('BlobResourceContents converts to JSON correctly', () {
      final contents = BlobResourceContents(
        uri: 'file:///image.png',
        blob: 'base64encodeddata',
        mimeType: 'image/png',
      );

      final json = contents.toJson();

      expect(json['uri'], equals('file:///image.png'));
      expect(json['blob'], equals('base64encodeddata'));
      expect(json['mimeType'], equals('image/png'));
      expect(json.containsKey('text'), isFalse);
    });

    test('ResourceContents.fromJson restores text resource', () {
      final jsonData = {
        'uri': 'file:///text.txt',
        'text': 'Text content',
        'mimeType': 'text/plain',
      };

      final contents = ResourceContents.fromJson(jsonData);

      expect(contents, isA<TextResourceContents>());
      expect(contents.uri, equals('file:///text.txt'));
      expect((contents as TextResourceContents).text, equals('Text content'));
      expect(contents.mimeType, equals('text/plain'));
    });

    test('ResourceContents.fromJson restores binary resource', () {
      final jsonData = {
        'uri': 'file:///binary.dat',
        'blob': 'binarydata',
        'mimeType': 'application/octet-stream',
      };

      final contents = ResourceContents.fromJson(jsonData);

      expect(contents, isA<BlobResourceContents>());
      expect(contents.uri, equals('file:///binary.dat'));
      expect((contents as BlobResourceContents).blob, equals('binarydata'));
      expect(contents.mimeType, equals('application/octet-stream'));
    });
  });

  group('Resource operation request tests', () {
    test('ListResourcesRequest is generated correctly', () {
      final request = ListResourcesRequest();

      expect(request.method, equals('resources/list'));
      expect(request.params['cursor'], isNull);

      final requestWithCursor = ListResourcesRequest(cursor: 'page2');
      expect(requestWithCursor.params['cursor'], equals('page2'));
    });

    test('ReadResourceRequest is generated correctly', () {
      final request = ReadResourceRequest(uri: 'file:///example.txt');

      expect(request.method, equals('resources/read'));
      expect(request.params['uri'], equals('file:///example.txt'));
    });

    test('SubscribeRequest is generated correctly', () {
      final request = SubscribeRequest(uri: 'file:///log.txt');

      expect(request.method, equals('resources/subscribe'));
      expect(request.params['uri'], equals('file:///log.txt'));
    });

    test('UnsubscribeRequest is generated correctly', () {
      final request = UnsubscribeRequest(uri: 'file:///log.txt');

      expect(request.method, equals('resources/unsubscribe'));
      expect(request.params['uri'], equals('file:///log.txt'));
    });
  });

  group('Resource result tests', () {
    test('ListResourcesResult is generated correctly', () {
      final resources = [
        Resource(uri: 'file:///file1.txt', name: 'File 1'),
        Resource(uri: 'file:///file2.txt', name: 'File 2'),
      ];

      final result = ListResourcesResult(
        resources: resources,
        nextCursor: 'next',
      );

      final json = result.toJson();

      expect(json['resources'], isA<List>());
      expect(json['resources'].length, equals(2));
      expect(json['resources'][0]['uri'], equals('file:///file1.txt'));
      expect(json['resources'][1]['uri'], equals('file:///file2.txt'));
      expect(json['nextCursor'], equals('next'));
    });

    test('ReadResourceResult is generated correctly', () {
      final contents = [
        TextResourceContents(
          uri: 'file:///example.txt',
          text: 'File content',
          mimeType: 'text/plain',
        ),
      ];

      final result = ReadResourceResult(contents: contents);

      final json = result.toJson();

      expect(json['contents'], isA<List>());
      expect(json['contents'].length, equals(1));
      expect(json['contents'][0]['uri'], equals('file:///example.txt'));
      expect(json['contents'][0]['text'], equals('File content'));
    });
  });
}
