import 'dart:io';
import 'dart:math';

/// A TCP port on 127.0.0.1 that is free right now.
Future<int> findFreeLocalPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// Hex string of [bytes] cryptographically random bytes.
String randomHexSecret([int bytes = 16]) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
