export 'http_client_web.dart' if (dart.library.io) 'http_client_io.dart';

class FirstPartyNetworkObserver {
  FirstPartyNetworkObserver(this.onChanged);
  final void Function() onChanged;
  Set<String>? _previous;

  void update(Iterable<String> results) {
    final network = results.where((value) => value != 'vpn').toSet();
    final previous = _previous;
    _previous = network;
    if (previous != null &&
        (previous.length != network.length || !previous.containsAll(network))) {
      onChanged();
    }
  }
}
