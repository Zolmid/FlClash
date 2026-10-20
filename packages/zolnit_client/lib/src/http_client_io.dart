import 'dart:io';

import 'package:http/io_client.dart';

IOClient createClient() => IOClient(
  HttpClient()..badCertificateCallback = (certificate, host, port) => false,
);
