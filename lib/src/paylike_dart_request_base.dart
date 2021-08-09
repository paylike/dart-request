import 'dart:async';

import 'package:sprintf/sprintf.dart';
import 'dart:io' as io;

// Provides configuraton options for PaylikeRequester
class RequestOptions {
  Map<String, String>? query;
  int? version;
  Object? data;
  Duration timeout = Duration(seconds: 20);
  io.HttpClient client = io.HttpClient();
  String clientId = 'dart-1';
  String method = 'GET';
  RequestOptions();
  RequestOptions.fromClientId(String clientId) {
    this.clientId = clientId;
  }
  RequestOptions setClient(io.HttpClient client) {
    this.client = client;
    return this;
  }

  RequestOptions setQuery(Map<String, String> q) {
    query = q;
    return this;
  }

  RequestOptions setTimeout(Duration timeout) {
    this.timeout = timeout;
    return this;
  }

  RequestOptions setData(Object d) {
    data = d;
    method = 'POST';
    return this;
  }

  RequestOptions setVersion(int version) {
    if (version < 1) {
      throw (sprintf(
          'Unexpected "version", got "%d" expected a positive integer',
          [version]));
    }
    this.version = version;
    return this;
  }
}

void setHeadersOnRequest(
    io.HttpClientRequest request, Map<String, String> headers) {}

// Executes requests
class PaylikeRequester {
  Function log = (dynamic o) => print(o);
  PaylikeRequester();
  PaylikeRequester.withLog(Function log) {
    this.log = log;
  }
  PaylikeRequester setLog(Function log) {
    this.log = log;
    return this;
  }

  Future<io.HttpClientResponse> request(
      String endpoint, RequestOptions? opts) async {
    opts ??= RequestOptions();
    var url = Uri.parse(endpoint);
    if (opts.query != null) {
      url.replace(queryParameters: opts.query);
    }
    var headers = {
      'X-Client': opts.clientId,
      'Accept-Version': opts.version.toString(),
    };

    io.HttpClientRequest request;
    switch (opts.method) {
      case 'GET':
        request = await opts.client.getUrl(url);
        break;
      case 'POST':
        request = await opts.client.postUrl(url);
        headers = {
          ...headers,
          'Content-Type': 'application/json',
        };
        request.write(opts.data);
        break;
      default:
        throw ('Unexpected error');
    }
    headers.forEach((key, value) {
      request.headers.add(key, value);
    });
    io.HttpClientResponse response;
    try {
      log({
        't': 'request',
        'method': opts.method,
        'url': url,
        'timeout': opts.timeout
      });
      response = await request.close().timeout(opts.timeout);
    } on TimeoutException catch (_) {
      request.abort();
      rethrow;
    }
    return response;
  }
}
