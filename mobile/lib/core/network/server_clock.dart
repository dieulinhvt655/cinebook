/// Server-corrected "now". The backend returns `serverTime` with each seat hold; the
/// difference to the device clock is kept so countdowns follow the server's `expiresAt`
/// even when the phone's clock is wrong.
class ServerClock {
  ServerClock({DateTime Function()? deviceNow})
    : _deviceNow = deviceNow ?? DateTime.now;

  final DateTime Function() _deviceNow;
  Duration _offset = Duration.zero;

  Duration get offset => _offset;

  void sync(DateTime serverTime) {
    _offset = serverTime.difference(_deviceNow());
  }

  DateTime now() => _deviceNow().add(_offset);
}
