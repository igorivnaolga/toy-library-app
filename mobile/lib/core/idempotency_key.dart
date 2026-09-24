import "dart:math";

final Random _random = Random.secure();

/// Random URL-safe key so a retried request is applied once by the backend.
String newIdempotencyKey() {
  const alphabet =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  return List.generate(32, (_) => alphabet[_random.nextInt(alphabet.length)])
      .join();
}
