import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'exception.dart';

// Provides a handy minimal interface over io.HttpClientResponse.
class PaylikeResponse {
  io.HttpClientResponse response;
  PaylikeResponse(this.response);
  // Provides response body in a string.
  Future<String> getBody() {
    final completer = Completer<String>();
    final contents = StringBuffer();
    response.transform(utf8.decoder).listen((data) {
      contents.write(data);
    }, onDone: () => completer.complete(contents.toString()));
    return completer.future;
  }

  // Provides response body in a stream.
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
  // Creates a version 1 API
  RequestOptions.v1() {
    version = 1;
  }
  Map<String, String>? query;
  int? version;
  dynamic data;
  Duration timeout = Duration(seconds: 20);
  String clientId = 'dart-1';
  String method = 'GET';
  bool form = false;
  Map<String, String>? formFields;

  RequestOptions({
    this.version = 1,
    this.query,
    this.data,
    this.timeout = const Duration(seconds: 20),
    this.clientId = 'dart-1',
    this.method = 'GET',
    this.form = false,
    this.formFields,
  });

  // Creates request options from Client ID
  RequestOptions.fromClientId(String clientId) {
    this.clientId = clientId;
  }
  // Sets query parameters
  RequestOptions setQuery(Map<String, String> q) {
    query = q;
    return this;
  }

  // Sets a custom timeout
  RequestOptions setTimeout(Duration timeout) {
    this.timeout = timeout;
    return this;
  }

  // Sets JSON body
  RequestOptions setData(Object d) {
    data = d;
    method = 'POST';
    return this;
  }

  // Sets form data usage
  RequestOptions useForm() {
    form = true;
    return this;
  }

  // Sets version for the API
  RequestOptions setVersion(int version) {
    if (version < 1) {
      throw VersionException(version);
    }
    this.version = version;
    return this;
  }
}

// Used for orchestration the execution of requests.
class PaylikeRequester {
  Function log = (dynamic o) => print('''
  ${jsonEncode(o)}
  ''');
  io.HttpClient client = io.HttpClient();
  PaylikeRequester();
  // Creates a PaylikeRequester with custom log.
  PaylikeRequester.withLog(this.log);
  // Creates a PaylikeRequester with custom log and client ID.
  PaylikeRequester.withClientAndLog(this.client, this.log);
  // Sets a custom logging function on a PaylikeRequester instance.
  PaylikeRequester setLog(Function log) {
    this.log = log;
    return this;
  }

  // Sets a client ID on a PaylikeRequester instance.
  PaylikeRequester setClient(io.HttpClient client) {
    this.client = client;
    return this;
  }

  // Executes the requests created by [PaylikeRequester.request]
  Future<PaylikeResponse> _executeRequest({
    required Uri url,
    required RequestOptions opts,
    required io.HttpClientRequest request,
  }) async {
    io.HttpClientResponse response;
    var op = {
      't': 'request',
      'method': opts.method,
      'url': url.toString(),
      'timeout': opts.timeout.toString(),
      'form': opts.form.toString(),
      'formFields': opts.formFields,
      'headers': request.headers.toString(),
    };
    try {
      log(op);
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

  // Executes request toward a given endpoint with given request options and returns a PaylikeResponse
  Future<PaylikeResponse> request(String endpoint, RequestOptions? opts) async {
    opts ??= RequestOptions();
    var url = Uri.parse(endpoint);
    io.HttpClientRequest? request;
    if (opts.form) {
      if (opts.formFields == null) {
        throw Exception('Cannot make a request as a form without formFields');
      }
      var formBodyParts = (opts.formFields as Map<String, String>)
          .keys
          .map((key) =>
              '$key=${Uri.encodeQueryComponent(opts?.formFields?[key] as String)}')
          .toList();
      var bodyBytes = utf8.encode(formBodyParts.join('&')); // utf8 encode
      request = await client.postUrl(url);
      // it's polite to send the body length to the server
      request.headers.set('Content-Length', bodyBytes.length.toString());
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      // todo add other headers here
      request.add(bodyBytes);
    } else {
      if (opts.query != null) {
        url.replace(queryParameters: opts.query);
      }
      var headers = {
        'X-Client': opts.clientId,
        'Accept-Version': opts.version.toString(),
      };
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
        request?.headers.add(key, value);
      });
      if (opts.method == 'POST') {
        request.write(jsonEncode(opts.data));
      }
    }
    return _executeRequest(url: url, opts: opts, request: request);
  }
}
