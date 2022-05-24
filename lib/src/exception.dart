import 'dart:io' as io;

// Indicates that a rate limit has been reached during a request.
class RateLimitException implements Exception {
  late String cause;
  Duration? retryAfter;
  RateLimitException() {
    cause = 'Request got rate limited';
  }
  // Creates a RateLimitException from the provided string
  // which is supposed in ms.
  RateLimitException.withTime(String retryAfter) {
    cause = 'Request got rate limited for $retryAfter';
    this.retryAfter = Duration(milliseconds: int.parse(retryAfter));
  }
}

// VersionException indicates that an unexpected version was used when calling the API.
class VersionException implements Exception {
  late String cause;
  late int givenVersion;
  // Creates a VersionException from the provided mismatched version.
  VersionException(int givenVersion) {
    cause =
        'Unexpected "version", got $givenVersion expected a positive integer';
    this.givenVersion = givenVersion;
  }
}

// Indicates that there was an unexpected server error during the communication.
class ServerErrorException implements Exception {
  String cause = 'Unexpected server error';
  int? status;
  Map<String, List<String>>? headers;
  // Creates a ServerErrorException with HTTP info attached.
  ServerErrorException.withHTTPInfo(this.status, io.HttpHeaders headers) {
    this.headers = {};
    headers.forEach((name, values) {
      this.headers![name] = values;
    });
  }
}

// PaylikeException originates from paylike servers.
class PaylikeException implements Exception {
  late String cause;
  late String code;
  late int statusCode;
  late List<String> errors;
  // Creates a PaylikeException from the body and statusCode.
  PaylikeException(Map<String, dynamic> body, int statusCode) {
    this.statusCode = statusCode;
    cause = body['message'];
    code = body['code'];
    errors = ((body['errors'] ?? []) as List<dynamic>).cast<String>();
  }
}
