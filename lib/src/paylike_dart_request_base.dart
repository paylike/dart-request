import 'dart:async';
import 'dart:convert';

import 'package:sprintf/sprintf.dart';
import 'dart:io' as io;

// Indicates that a rate limit has been reached during a request
class RateLimitException implements Exception {
  late String cause;
  Duration? retryAfter;
  RateLimitException() {
    cause = 'Request got rate limited';
  }
  RateLimitException.withTime(String retryAfter) {
    cause = sprintf('Request got rate limited for %s', [retryAfter]);
    this.retryAfter = Duration(milliseconds: int.parse(retryAfter));
  }
}

// VersionException indicates that an unexpected version was used when calling the API
class VersionException implements Exception {
  late String cause;
  late int givenVersion;
  VersionException(int givenVersion) {
    cause = sprintf(
        'Unexpected "version", got "%d" expected a positive integer',
        [givenVersion]);
    this.givenVersion = givenVersion;
  }
}

// Indicates that there was an unexpected server error during the communication
class ServerErrorException implements Exception {
  String cause = 'Unexpected server error';
  int? status;
  Map<String, List<String>>? headers;
  ServerErrorException.withHTTPInfo(this.status, io.HttpHeaders headers) {
    this.headers = {};
    headers.forEach((name, values) {
      this.headers![name] = values;
    });
  }
}

// PaylikeException originates from paylike servers
class PaylikeException implements Exception {
  late String cause;
  late String code;
  late int statusCode;
  late List<String> errors;
  PaylikeException(Map<String, dynamic> body, int statusCode) {
    statusCode = statusCode;
    cause = body['message'];
    code = body['code'];
    errors = body['errors'] ?? [];
  }
}

// Provides a handy minimal interface over io.HttpClientResponse
class PaylikeResponse {
  io.HttpClientResponse response;
  PaylikeResponse(this.response);
  Future<String> getBody() {
    final completer = Completer<String>();
    final contents = StringBuffer();
    response.transform(utf8.decoder).listen((data) {
      contents.write(data);
    }, onDone: () => completer.complete(contents.toString()));
    return completer.future;
  }

  Future<Stream<dynamic>> getBodyReader() async {
    if (response.statusCode == 209) {
      return Future.value(Stream.empty());
    }

    var decoded = jsonDecode(await getBody());
    if (decoded is List) {
      return Stream.fromIterable(decoded);
    }
    return Stream.value(decoded);
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
  String clientId = 'dart-1';
  String method = 'GET';
  RequestOptions();
  RequestOptions.fromClientId(String clientId) {
    this.clientId = clientId;
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
      throw VersionException(version);
    }
    this.version = version;
    return this;
  }
}

// Executes requests
class PaylikeRequester {
  Function log = (dynamic o) => print(o);
  io.HttpClient client = io.HttpClient();
  PaylikeRequester();
  PaylikeRequester.withLog(this.log);
  PaylikeRequester.withClientAndLog(this.client, this.log);
  PaylikeRequester setLog(Function log) {
    this.log = log;
    return this;
  }

  PaylikeRequester setClient(io.HttpClient client) {
    this.client = client;
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
        request = await client.getUrl(url);
        break;
      case 'POST':
        request = await client.postUrl(url);
        headers = {
          ...headers,
          'Content-Type': 'application/json',
        };
        break;
      default:
        throw ('Unexpected error');
    }
    headers.forEach((key, value) {
      request.headers.add(key, value);
    });
    if (opts.method == 'POST') {
      request.write(jsonEncode(opts.data));
    }
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
      return PaylikeResponse(response);
    } else {
      Exception exception = ServerErrorException.withHTTPInfo(
          response.statusCode, response.headers);
      try {
        var parsed = PaylikeResponse(response);
        Map<String, dynamic> body = jsonDecode(await parsed.getBody());
        exception = PaylikeException(body, response.statusCode);
      } catch (_) {}
      throw exception;
    }
  }
}
