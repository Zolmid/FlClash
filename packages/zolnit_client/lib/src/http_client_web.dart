import 'package:http/http.dart' as http;

http.Client createClient({
  Uri? origin,
  Object? nativeRequest,
  bool? isAndroid,
}) => http.Client();
