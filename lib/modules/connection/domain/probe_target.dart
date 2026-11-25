/// Where a delay probe sends its request through the server it measures.
///
/// The URLs belong to the data layer; this only says which one is meant.
enum ProbeTarget {
  /// Google's connectivity check. Every delay the app ranks or shows is
  /// measured against it.
  google,

  /// A connectivity check outside Google.
  ///
  /// Some servers reach Google and fail the TLS handshake with every other
  /// host, so a tunnel through one loads almost nothing. Quick connect asks
  /// this as well before it trusts a server with a connect.
  outsideGoogle,
}
