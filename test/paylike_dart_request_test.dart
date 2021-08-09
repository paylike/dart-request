import 'dart:async';
import 'dart:io' as io;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:paylike_dart_request/paylike_dart_request.dart';
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
    final requester = PaylikeRequester();

    setUp(() {
      // Additional setup goes here.
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
}
