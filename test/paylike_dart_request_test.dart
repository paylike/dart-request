import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:paylike_dart_request/paylike_dart_request.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';

import 'paylike_dart_request_test.mocks.dart';

class Mocker {
  MockHttpClient client = MockHttpClient();
  MockHttpClientRequest request = MockHttpClientRequest();
  MockHttpHeaders headers = MockHttpHeaders();
  MockHttpClientResponse response = MockHttpClientResponse();
}

@GenerateMocks([
  io.HttpClient,
  io.HttpClientRequest,
  io.HttpClientResponse,
  io.HttpHeaders
])
void main() {
  const TEST_URL = 'http://foo';
  group('Requester setup tests', () {
    test('Should not be able to set a version under 1', () async {
      expect(
          () => RequestOptions().setVersion(0),
          throwsA(sprintf(
              'Unexpected "version", got "%d" expected a positive integer',
              [0])));
    });

    test('Should be able to attach essential headers to requests', () async {
      var mocker = Mocker();
      when(mocker.client.getUrl(Uri.parse(TEST_URL))).thenAnswer((_) {
        return Future.value(mocker.request);
      });
      when(mocker.request.headers).thenReturn(mocker.headers);
      when(mocker.headers.add('X-Client', 'dart-1')).thenReturn(true);
      when(mocker.headers.add('Accept-Version', '1')).thenReturn(true);
      when(mocker.request.close()).thenAnswer((_) {
        return Future.value(mocker.response);
      });
      when(mocker.response.statusCode).thenReturn(200);
      var opts = RequestOptions().setVersion(1);
      var requester =
          PaylikeRequester.withClientAndLog(mocker.client, (dynamic o) => null);
      await requester.request(TEST_URL, opts);
    });

    test('Should be able to attach queries', () async {
      var mocker = Mocker();
      var uri = Uri.parse(TEST_URL);
      uri.replace(queryParameters: {
        'foo': 'bar',
      });

      when(mocker.client.getUrl(uri)).thenAnswer((_) {
        return Future.value(mocker.request);
      });
      when(mocker.request.headers).thenReturn(mocker.headers);
      when(mocker.headers.add('X-Client', 'dart-1')).thenReturn(true);
      when(mocker.headers.add('Accept-Version', '1')).thenReturn(true);
      when(mocker.request.close()).thenAnswer((_) {
        return Future.value(mocker.response);
      });
      when(mocker.response.statusCode).thenReturn(200);
      var opts = RequestOptions().setVersion(1);
      var requester =
          PaylikeRequester.withClientAndLog(mocker.client, (dynamic o) => null);
      await requester.request(TEST_URL, opts);
    });

    test('Should be able to send data', () async {
      var mocker = Mocker();

      var uri = Uri.parse(TEST_URL);
      when(mocker.client.postUrl(uri)).thenAnswer((_) {
        return Future.value(mocker.request);
      });
      when(mocker.request.write({'foo': 'bar'})).thenReturn(true);
      when(mocker.request.headers).thenReturn(mocker.headers);
      when(mocker.headers.add('X-Client', 'dart-1')).thenReturn(true);
      when(mocker.headers.add('Accept-Version', '1')).thenReturn(true);
      when(mocker.headers.add('Content-Type', 'application/json'))
          .thenReturn(true);
      when(mocker.request.close()).thenAnswer((_) {
        return Future.value(mocker.response);
      });
      when(mocker.response.statusCode).thenReturn(200);
      var opts = RequestOptions().setVersion(1).setData({
        'foo': 'bar',
      });
      var requester =
          PaylikeRequester.withClientAndLog(mocker.client, (dynamic o) => null);
      await requester.request(TEST_URL, opts);
    });

    test('Should be able to set logging', () async {
      var mocker = Mocker();
      when(mocker.client.getUrl(Uri.parse(TEST_URL))).thenAnswer((_) {
        return Future.value(mocker.request);
      });
      when(mocker.request.headers).thenReturn(mocker.headers);
      when(mocker.headers.add('X-Client', 'dart-1')).thenReturn(true);
      when(mocker.headers.add('Accept-Version', '1')).thenReturn(true);
      when(mocker.request.close()).thenAnswer((_) {
        return Future.value(mocker.response);
      });
      when(mocker.response.statusCode).thenReturn(200);
      var loggingRequester =
          PaylikeRequester.withClientAndLog(mocker.client, (dynamic o) {
        expect(o['t'], 'request');
        expect(o['method'], 'GET');
        expect(o['url'], Uri.parse(TEST_URL));
        expect(o['timeout'], Duration(seconds: 20));
      });
      var opts = RequestOptions.v1();
      await loggingRequester.request(TEST_URL, opts);
    });

    test('Should be able to throw an error if rate limiting as an issue',
        () async {
      var mocker = Mocker();
      when(mocker.client.getUrl(Uri.parse(TEST_URL))).thenAnswer((_) {
        return Future.value(mocker.request);
      });
      when(mocker.request.headers).thenReturn(mocker.headers);
      when(mocker.headers.add('X-Client', 'dart-1')).thenReturn(true);
      when(mocker.headers.add('Accept-Version', '1')).thenReturn(true);
      when(mocker.request.close()).thenAnswer((_) {
        return Future.value(mocker.response);
      });
      when(mocker.response.statusCode).thenReturn(429);
      when(mocker.response.headers).thenReturn(mocker.headers);
      when(mocker.headers['retry-after']).thenReturn(['20']);
      var opts = RequestOptions.v1();
      try {
        var requester = PaylikeRequester.withClientAndLog(
            mocker.client, (dynamic o) => null);
        await requester.request(TEST_URL, opts);
        fail('exception is not thrown');
      } catch (e) {
        expect(e is RateLimitException, true);
        expect((e as RateLimitException).time, '20');
      }
    });

    test('Should be able to throw an error if an internal server error happens',
        () async {
      var mocker = Mocker();
      when(mocker.client.getUrl(Uri.parse(TEST_URL))).thenAnswer((_) {
        return Future.value(mocker.request);
      });
      when(mocker.request.headers).thenReturn(mocker.headers);
      when(mocker.headers.add('X-Client', 'dart-1')).thenReturn(true);
      when(mocker.headers.add('Accept-Version', '1')).thenReturn(true);
      when(mocker.request.close()).thenAnswer((_) {
        return Future.value(mocker.response);
      });
      when(mocker.response.statusCode).thenReturn(500);
      when(mocker.response.headers).thenReturn(mocker.headers);
      var opts = RequestOptions.v1();
      try {
        var requester = PaylikeRequester.withClientAndLog(
            mocker.client, (dynamic o) => null);
        await requester.request(TEST_URL, opts);
        fail('exception is not thrown');
      } catch (e) {
        expect(e is ServerErrorException, true);
        expect((e as ServerErrorException).status, 500);
      }
    });
  });

  group('Requester core functionality', () {
    final requester = PaylikeRequester();

    test('Timeouts should work seemlessly', () async {
      var handler = Pipeline().addHandler((request) async {
        expect(request.headers['X-Client'], 'dart-1');
        expect(request.headers['Accept-Version'], '1');
        await Future.delayed(Duration(seconds: 4));
        return Response(200);
      });
      var server = await serve(handler, 'localhost', 8080);

      var opts = RequestOptions.v1().setTimeout(Duration(seconds: 2));
      try {
        await requester.request('http://localhost:8080', opts);
        fail('exception is not thrown');
      } catch (e) {
        expect(e is TimeoutException, true);
      }
      await server.close(force: true);
    });

    test('Response needs to be able to provide body as a string', () async {
      var handler = Pipeline().addHandler((request) async {
        return Response(200,
            body: jsonEncode({
              'foo': 'bar',
            }));
      });
      var server = await serve(handler, 'localhost', 8080);

      var opts = RequestOptions.v1().setTimeout(Duration(seconds: 2));
      var response = await requester.request('http://localhost:8080', opts);
      Map<String, dynamic> body = jsonDecode(await response.getBody());
      expect(body['foo'], 'bar');
      await server.close(force: true);
    });

    test('Response needs to be able to provide body as object stream',
        () async {
      var testArray = [1, 2, 3, 4];
      var handler = Pipeline().addHandler((request) async {
        return Response(200, body: jsonEncode(testArray));
      });
      var server = await serve(handler, 'localhost', 8080);

      var opts = RequestOptions.v1().setTimeout(Duration(seconds: 2));
      var response = await requester.request('http://localhost:8080', opts);
      var reader = await response.getBodyReader();
      await reader.forEach((element) {
        expect(element is int, true);
        expect(testArray.contains(element), true);
      });
      await server.close(force: true);
    });
  });
}
