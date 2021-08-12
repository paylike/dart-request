import 'dart:async';
import 'dart:convert';

import 'package:sprintf/sprintf.dart';
import 'dart:io' as io;

// Indicates that a rate limit has been reached during a request
class RateLimitException implements Exception {
  late String cause;
  String? time;
  RateLimitException() {
    cause = 'Request got rate limited';
  }
  RateLimitException.withTime(this.time) {
    cause = sprintf('Request got rate limited for %s', [time]);
  }
}

// Indicates that there was an unexpected server error during the communication
class ServerErrorException implements Exception {
  String cause = 'Unexpected server error';
  int? status;
  Map<String, String>? headers;
  ServerErrorException.withHTTPInfo(this.status, io.HttpHeaders headers) {
    this.headers = {};
    headers.forEach((name, values) {
      headers.add(name, values);
    });
  }
}

// Provides a handy minimal interface over io.HttpClientResponse
class PaylikeResponse {
  late io.HttpClientResponse response;
  PaylikeResponse.fromIO(this.response);
  Future<String> getBody() {
    final completer = Completer<String>();
    final contents = StringBuffer();
    response.transform(utf8.decoder).listen((data) {
      contents.write(data);
    }, onDone: () => completer.complete(contents.toString()));
    return completer.future;
  }

  Stream<String> getBodyReader() {
    if (response.statusCode == 209) {
      return Stream.empty();
    }
    return response.transform(utf8.decoder);
  }
}

// Provides configuraton options for PaylikeRequester
class RequestOptions {
  RequestOptions.v1() {
    version = 1;
  }
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

  Future<PaylikeResponse> request(String endpoint, RequestOptions? opts) async {
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
      if (opts.timeout.inSeconds == 0) {
        response = await request.close();
      } else {
        response = await request.close().timeout(opts.timeout);
      }
    } on TimeoutException catch (_) {
      request.abort();
      throw TimeoutException('Request timed out', opts.timeout);
    }
    if (response.statusCode == 429) {
      var retryHeaders = response.headers['retry-after'];
      if (retryHeaders != null && retryHeaders.length == 1) {
        throw RateLimitException.withTime(retryHeaders[0]);
      }
      throw RateLimitException();
    } else if (response.statusCode < 300) {
      return PaylikeResponse.fromIO(response);
    } else {
      throw ServerErrorException.withHTTPInfo(
          response.statusCode, response.headers);
    }
  }
}
