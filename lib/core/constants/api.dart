/// Single source of truth for the PaAyo API host.
///
/// Phone + wireless debugging must reach this PC on the LAN, so use your
/// current IPv4 (run `ipconfig`) — not `127.0.0.1` / `10.0.2.2`.
/// Backend must be started with:
///   php artisan serve --host=0.0.0.0 --port=8000
class Api {
  /// LAN IPv4 of this machine (update when Wi‑Fi / hotspot IP changes).
  static const String host = "192.168.137.36";
  static const int port = 8000;

  static const String baseUrl = "http://$host:$port/api";
}
