import 'dart:convert';

import 'package:crypto/crypto.dart';

/// What a Play purchase is bound to: the account's username, hashed.
///
/// Play keeps it with the purchase as `obfuscatedAccountId`, which is at most
/// 64 characters and may not carry personal data in the clear — a SHA-256
/// hex digest is exactly 64, and the server computes the same value from the
/// username it already holds to check that a purchase belongs to the account
/// that reports it.
String playAccountTag(String username) =>
    sha256.convert(utf8.encode(username)).toString();
