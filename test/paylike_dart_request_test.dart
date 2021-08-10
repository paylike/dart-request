import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';
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
    final requester = PaylikeRequester.withLog((dynamic o) => null);

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
      var opts = RequestOptions().setClient(mocker.client).setVersion(1);
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
      var opts = RequestOptions().setClient(mocker.client).setVersion(1);
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
      var opts =
          RequestOptions().setClient(mocker.client).setVersion(1).setData({
        'foo': 'bar',
      });
      await requester.request(TEST_URL, opts);
    });

    test('Should be able to set logging', () async {
      var loggingRequester = PaylikeRequester.withLog((dynamic o) {
        expect(o['t'], 'request');
        expect(o['method'], 'GET');
        expect(o['url'], Uri.parse(TEST_URL));
        expect(o['timeout'], Duration(seconds: 20));
      });
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
      var opts = RequestOptions().setClient(mocker.client).setVersion(1);
      await loggingRequester.request(TEST_URL, opts);
    });
  });

  group('Requester timeout', () {
    final requester = PaylikeRequester();

    test('Should work seemlessly', () async {
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
        e is TimeoutException;
      }
      await server.close(force: true);
    });
  });
}
