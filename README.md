# Paylike low-level request helper

For a higher-level client see https://pub.dev.

*This implementation is based on [Paylike/JS-Request](https://github.com/paylike/js-request)*

This is a low-level library used for making HTTP(s) requests to Paylike APIs. It
incorporates the conventions described in the
[Paylike API reference](https://github.com/paylike/api-reference).

It is built to work in any Dart environment (including Flutter) by
accepting a [io.HttpClient](https://api.dart.dev/stable/2.13.4/dart-io/HttpClient-class.html)
implementation as input. This library utilises `io.HttpClient` because of its capabilities to abort
requests properly if necessary.

This function is usually put behind a retry mechanism. Paylike APIs _will_
expect any client to gracefully handle a rate limiting response and expects them
to retry.

A retry mechanism is not included in this package because it is highly specific
to the project and is difficult to implement for streaming requests without
further context.

## Example

```dart
  var requester = PaylikeRequester().setLog((dynamic o) => print(o));
  var opts = RequestOptions.fromClientId('dart-1')
      .setQuery({
        'foo': 'bar',
      })
      .setVersion(1)
      .setData({
        'foo': 'bar',
      });
  requester.request('http://foo', opts).then((response) {
    return response.getBody();
  }).then((body) {
    print(body);
  }).catchError((error) {
    print(error);
  });
```

## `PaylikeRequester`

The default class used to initiate a requester instance

```dart
var requester = PaylikeRequester();
```

By default the requester is initiated with the default io.HttpClient as its client and a simple log function:
```dart
class PaylikeRequester {
  Function log = (dynamic o) => print(o);
  io.HttpClient client = io.HttpClient();
  ....
}
```

You change this by using a named constructor:
```dart
var requester = PaylikeRequester.withClientAndLog(io.HttpClient(), (dynamic o) => print(o));
```

#### `request` function

Used for executing requests, have the following footprint:
```dart
Future<PaylikeResponse> request(String endpoint, RequestOptions? opts)
```

Consumes an endpoint and [RequestOptions](#requestoptions) then returns [PaylikeResponse](#paylikeresponse)

## RequestOptions

Describes the different options you can use to construct your request.

Constructors
```dart
var opts = RequestOptions.v1() // Creates a version 1 request option

var opts = RequestOptions.fromClientId('your-client-id'); // Creates from your client id
```

RequestOptions works utilizing a builder pattern:

```dart
  var opts = RequestOptions.fromClientId('dart-1')
      .setQuery({
        'foo': 'bar',
      })
      .setVersion(1)
      .setData({
        'foo': 'bar',
      })
      .setTimeout(Duration(seconds: 20));
```

## `PaylikeResponse`

Describes the response of your request

```dart
var response = await requester.request('http://foo', opts);

var body = await response.getBody(); // String | Returns response body in plain simple string

var reader = await response.getBodyReader(); // Stream<dynamic> | Returns an object stream with the decoded json body
```


## Error handling

`request` may throw any of the following error classes as well as any error
thrown by the `io.HttpClient` implementation.

All error classes can be accessed through the package.

### Example

```dart

try {
  await requester.request('http://foo', opts);
catch (e) {
  if (e is RateLimitException) {
    // initiate retry
  }
  if (e is ServerErrorException) {
    // unexpected server error
  }
}


try {
  var opts = RequestOptions().setVersion(0);
} catch (e) {
  if (e is VersionException) {
    // version should be a positive integer
  }
}
```

### Error classes

- `RateLimitException`

  May have a `retryAfter` (Duration) property if sent by the server
  specifying the minimum delay.

- `TimeoutException`

  Comes from `dart:async` library https://api.dart.dev/be/169657/dart-async/TimeoutException-class.html

- `ServerErrorException`

  Has `status` and `headers` properties copied from the io.HttpClientResponse

- `PaylikeException`

  These errors correspond to
  [status codes](https://github.com/paylike/api-reference/blob/master/status-codes.md)
  from the API reference. They have at least a `code` and `message` property,
  but may also have other useful properties relevant to the specific error code,
  such as a minimum and maximum for amounts.
