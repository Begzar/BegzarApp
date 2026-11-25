/// A server the app can dial, and the label it is known by while doing so.
///
/// The name is an identifier rather than UI copy: it is what the native engine
/// is told it is connecting to and what a connection failure names in its log
/// message. Nothing renders it, which is why it is not localized.
class ProxyConfigEntity {
  final String url;
  final String name;

  const ProxyConfigEntity({required this.url, required this.name});
}

/// Turns the config URLs a subscription carried into things the app can dial.
///
/// The API layer hands back URLs and stops there — it moves bytes and proves
/// they came from Begzar, and has no business deciding what a config is. The
/// numbering happens here because the position in the list is the only handle
/// the server gives: the payload is a bare list of URLs with no names on it.
List<ProxyConfigEntity> proxyConfigsFromSubscription(List<String> urls) {
  return [
    for (final (index, url) in urls.indexed)
      ProxyConfigEntity(url: url, name: 'Server ${index + 1}'),
  ];
}
