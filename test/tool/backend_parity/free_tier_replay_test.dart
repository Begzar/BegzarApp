import 'package:begzar/core/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backend_replay.dart';

void main() {
  final replay = BackendReplay.load('free_tier');

  test('the free tier reaches every outcome it reached before the engine '
      'took its calls over', () async {
    for (final c in replay!.cases) {
      switch (c['op']) {
        case 'registerSession':
          await replay.check(
            c,
            call: (backend) =>
                ApiV2Service(backend: backend).initializeDevice(),
            describe: (token) => {'sessionKey': token},
          );
        case 'fetchFreeServers':
          await replay.check(
            c,
            call: (backend) =>
                ApiV2Service(backend: backend).getVPNConfigurations(),
            describe: (payload) => {
              'links': payload.configUrls,
              'serverVersion': payload.serverVersion,
              'updatedUrl': payload.updatedUrl,
            },
          );
        default:
          fail('no call replays ${c['op']}');
      }
    }
  }, skip: replay == null ? 'the private engine is not checked out' : false);
}
