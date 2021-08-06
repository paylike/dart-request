import 'dart:async';
import 'dart:io' as io;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:paylike_dart_request/paylike_dart_request.dart';
import 'package:test/test.dart';

import 'paylike_dart_request_test.mocks.dart';

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
      var client = MockHttpClient();
      var mockRequest = MockHttpClientRequest();
      var mockHeaders = MockHttpHeaders();
      var mockResponse = MockHttpClientResponse();

      when(client.getUrl(Uri.parse(TEST_URL))).thenAnswer((_) {
        return Future.value(mockRequest);
      });
      when(mockRequest.headers).thenReturn(mockHeaders);
      when(mockHeaders.add('X-Client', 'dart-1')).thenReturn(true);
      when(mockHeaders.add('Accept-Version', '1')).thenReturn(true);
      when(mockRequest.close()).thenAnswer((_) {
        return Future.value(mockResponse);
      });
      when(mockResponse.statusCode).thenReturn(200);
      var opts = RequestOptions().setClient(client).setVersion(1);
      var response = await requester.request(TEST_URL, opts);
      expect(response.statusCode, 200);
    });

    test('Should be able to attach queries', () async {
      var client = MockHttpClient();
      var mockRequest = MockHttpClientRequest();
      var mockHeaders = MockHttpHeaders();
      var mockResponse = MockHttpClientResponse();

      var uri = Uri.parse(TEST_URL);
      uri.replace(queryParameters: {
        'foo': 'bar',
      });

      when(client.getUrl(uri)).thenAnswer((_) {
        return Future.value(mockRequest);
      });
      when(mockRequest.headers).thenReturn(mockHeaders);
      when(mockHeaders.add('X-Client', 'dart-1')).thenReturn(true);
      when(mockHeaders.add('Accept-Version', '1')).thenReturn(true);
      when(mockRequest.close()).thenAnswer((_) {
        return Future.value(mockResponse);
      });
      when(mockResponse.statusCode).thenReturn(200);
      var opts = RequestOptions().setClient(client).setVersion(1);
      var response = await requester.request(TEST_URL, opts);
      expect(response.statusCode, 200);
    });
    test('Should be able to send data', () async {
      var client = MockHttpClient();
      var mockRequest = MockHttpClientRequest();
      var mockHeaders = MockHttpHeaders();
      var mockResponse = MockHttpClientResponse();

      var uri = Uri.parse(TEST_URL);
      uri.replace(queryParameters: {
        'foo': 'bar',
      });

      when(client.postUrl(uri)).thenAnswer((_) {
        return Future.value(mockRequest);
      });
      when(mockRequest.write({'foo': 'bar'})).thenReturn(true);
      when(mockRequest.headers).thenReturn(mockHeaders);
      when(mockHeaders.add('X-Client', 'dart-1')).thenReturn(true);
      when(mockHeaders.add('Accept-Version', '1')).thenReturn(true);
      when(mockHeaders.add('Content-Type', 'application/json'))
          .thenReturn(true);
      when(mockRequest.close()).thenAnswer((_) {
        return Future.value(mockResponse);
      });
      when(mockResponse.statusCode).thenReturn(200);
      var opts = RequestOptions().setClient(client).setVersion(1).setData({
        'foo': 'bar',
      });
      var response = await requester.request(TEST_URL, opts);
      expect(response.statusCode, 200);
      expect(response.statusCode, 200);
    });
  });
}
