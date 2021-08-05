import 'package:http/http.dart' as http;
import 'package:sprintf/sprintf.dart';

// Provides configuraton options for PaylikeRequester
class RequestOptions {
  Map<String, String>? query;
  int? version;
  Object? data;
  http.Client client = http.Client();
  String clientId = 'dart-1';
  String method = 'GET';
  RequestOptions();
  RequestOptions.fromClientId(String clientId) {
    this.clientId = clientId;
  }
  RequestOptions setClient(http.Client client) {
    this.client = client;
    return this;
  }

  RequestOptions setQuery(Map<String, String> q) {
    query = q;
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
  Future<http.Response> request(String endpoint, RequestOptions? opts) async {
    opts ??= RequestOptions();
    var url = Uri.parse(endpoint);
    if (opts.query != null) {
      url.replace(queryParameters: opts.query);
    }
    var essentialHeaders = {
      'X-Client': opts.clientId,
      'Accept-Version': opts.version.toString(),
    };
    http.Response response;
    switch (opts.method) {
      case 'GET':
        response = await opts.client.get(url, headers: essentialHeaders);
        break;
      case 'POST':
        response = await opts.client.post(url,
            headers: {
              ...essentialHeaders,
              'Content-Type': 'application/json',
            },
            body: opts.data);
        break;
      default:
        throw ('Unexpected error');
    }
    return response;
  }
}
