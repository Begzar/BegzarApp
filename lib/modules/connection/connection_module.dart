/// The connection module's public surface.
///
/// Layers run Presentation over Application over Domain over Data. Only the
/// top three are exported: the data layer is an implementation detail reached
/// through `di/connection_providers.dart`, which is what tests override. A
/// consumer that imports a repository or a data source directly has skipped
/// two layers, and `test/architecture/layer_boundaries_test.dart` says so.
library;

// Presentation — the connection state widgets read.
export 'presentation/controllers/connection_notifier.dart';

// Application — the operations the UI can ask for.
export 'application/services/connection_service.dart';

// Domain — the model, and the rules that need no IO.
export 'domain/entities/connection_entity.dart';
export 'domain/enums/connection_status_enum.dart';
export 'domain/errors/connection_failure.dart';
export 'domain/local_proxy_endpoint.dart';
export 'domain/proxy_config_validator.dart';
export 'domain/tunnel_mode.dart';
export 'domain/tunnel_options.dart';
export 'domain/value_objects/ping_result.dart';

// Wiring.
export 'di/connection_providers.dart';
