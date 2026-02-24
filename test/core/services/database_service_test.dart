import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/database_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

class FakeStreamTransformer extends Fake
    implements StreamTransformer<List<int>, dynamic> {}

void main() {
  late DatabaseService databaseService;
  late MockHttpClient mockHttpClient;
  late MockHttpClientRequest mockRequest;
  late MockHttpClientResponse mockResponse;
  late MockHttpHeaders mockHeaders;

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
    registerFallbackValue(Uri());
    registerFallbackValue(
      (X509Certificate cert, String host, int port) => true,
    );
    registerFallbackValue(FakeStreamTransformer());
  });

  setUp(() {
    databaseService = DatabaseService();
    mockHttpClient = MockHttpClient();
    mockRequest = MockHttpClientRequest();
    mockResponse = MockHttpClientResponse();
    mockHeaders = MockHttpHeaders();

    // Setup default mock behaviors
    when(
      () => mockHttpClient.connectionTimeout = any(),
    ).thenReturn(const Duration(seconds: 0));
    when(
      () => mockHttpClient.idleTimeout = any(),
    ).thenReturn(const Duration(seconds: 0));
    when(() => mockHttpClient.maxConnectionsPerHost = any()).thenReturn(0);
    when(() => mockHttpClient.badCertificateCallback = any()).thenReturn(null);

    // Default postUrl behavior
    when(
      () => mockHttpClient.postUrl(any()),
    ).thenAnswer((_) async => mockRequest);

    when(() => mockRequest.headers).thenReturn(mockHeaders);
    when(() => mockHeaders.set(any(), any())).thenReturn(null);
    when(() => mockRequest.write(any())).thenReturn(null);
    when(() => mockRequest.close()).thenAnswer((_) async => mockResponse);
  });

  group('DatabaseService', () {
    test('fetchDatabaseList returns list of databases on success', () async {
      final responseBody = jsonEncode({
        'result': ['db1', 'db2'],
      });

      when(
        () => mockResponse.transform(utf8.decoder),
      ).thenAnswer((_) => Stream.value(responseBody));
      when(() => mockResponse.statusCode).thenReturn(200);

      // Using HttpOverrides to inject mockHttpClient
      await HttpOverrides.runZoned(() async {
        final dbs = await databaseService.fetchDatabaseList('example.com');
        expect(dbs, ['db1', 'db2']);
      }, createHttpClient: (_) => mockHttpClient);

      verify(
        () => mockHttpClient.postUrl(
          Uri.parse('https://example.com/web/database/list'),
        ),
      ).called(1);
    });

    test('fetchDatabaseList handles http prefix', () async {
      final responseBody = jsonEncode({
        'result': ['db1'],
      });

      when(
        () => mockResponse.transform(utf8.decoder),
      ).thenAnswer((_) => Stream.value(responseBody));

      await HttpOverrides.runZoned(() async {
        await databaseService.fetchDatabaseList('http://example.com');
      }, createHttpClient: (_) => mockHttpClient);

      verify(
        () => mockHttpClient.postUrl(
          Uri.parse('http://example.com/web/database/list'),
        ),
      ).called(1);
    });

    test('fetchDatabaseList handles heavy/complex URL', () async {
      final responseBody = jsonEncode({
        'result': ['db1'],
      });

      when(
        () => mockResponse.transform(utf8.decoder),
      ).thenAnswer((_) => Stream.value(responseBody));

      await HttpOverrides.runZoned(() async {
        await databaseService.fetchDatabaseList(
          'https://sub.example.com:8069/',
        );
      }, createHttpClient: (_) => mockHttpClient);

      // Expect trailing slash removed
      verify(
        () => mockHttpClient.postUrl(
          Uri.parse('https://sub.example.com:8069/web/database/list'),
        ),
      ).called(1);
    });

    test(
      'fetchDatabaseList returns empty list on invalid response structure',
      () async {
        final responseBody = jsonEncode({'error': 'something'});

        when(
          () => mockResponse.transform(utf8.decoder),
        ).thenAnswer((_) => Stream.value(responseBody));

        await HttpOverrides.runZoned(() async {
          final dbs = await databaseService.fetchDatabaseList('example.com');
          expect(dbs, isEmpty);
        }, createHttpClient: (_) => mockHttpClient);
      },
    );

    test('fetchDatabaseList throws exception on network error', () async {
      when(
        () => mockHttpClient.postUrl(any()),
      ).thenThrow(SocketException('No internet'));

      await HttpOverrides.runZoned(() async {
        expect(
          () => databaseService.fetchDatabaseList('example.com'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Error fetching database list'),
            ),
          ),
        );
      }, createHttpClient: (_) => mockHttpClient);
    });
  });
}
