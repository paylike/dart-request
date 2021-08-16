import 'package:paylike_dart_request/paylike_dart_request.dart';

Future<void> fetchBodyAsStream(
    PaylikeRequester requester, RequestOptions opts) async {
  var response = await requester.request('http://foo', opts);
  var reader = await response.getBodyReader();
  await reader.forEach((element) {
    print(element);
  });
}

void main() {
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

  fetchBodyAsStream(requester, opts).catchError((error) {
    print(error);
  });
}
