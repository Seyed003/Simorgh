/// Live throughput reported by the core once per second.
class TrafficStats {
  const TrafficStats({
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.uploadTotal = 0,
    this.downloadTotal = 0,
  });

  static const zero = TrafficStats();

  /// Bytes per second.
  final int uploadSpeed;
  final int downloadSpeed;

  /// Bytes since the connection started.
  final int uploadTotal;
  final int downloadTotal;

  TrafficStats add(int up, int down) => TrafficStats(
    uploadSpeed: up,
    downloadSpeed: down,
    uploadTotal: uploadTotal + up,
    downloadTotal: downloadTotal + down,
  );
}
