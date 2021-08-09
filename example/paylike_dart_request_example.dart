import 'package:paylike_dart_request/paylike_dart_request.dart';

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
  requester.request('http://foo', opts).then((value) {
    print(value);
  }).catchError((error) {
    print(error);
  });
}
