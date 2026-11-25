"""Copies the private engine's public models into the open engine stub.

    python3 tool/engine_stub/sync_models.py begzar-engine/lib/ engine_stub/lib/

The stub needs the engine's models (the app builds them and reads them) but
none of their wire conversions, which reach generated protobuf code the open
build does not have. This copies each model and cuts those members out, so the
stub's models are the engine's rather than a hand-kept imitation of them.
scripts/check_engine_stub.sh runs it into a scratch folder and fails when the
committed copy differs.
"""
import re, sys
SRC, DST = sys.argv[1], sys.argv[2]
HEADER = '''// The open engine stub's copy of the private engine's public model, with the
// wire conversions it has no use for removed. Keep it in step with the engine:
// scripts/check_engine_stub.sh fails when the app uses something it lacks.

'''
def strip_member(text, signature_regex):
    m = re.search(signature_regex, text, re.M)
    assert m, signature_regex
    start = text.rfind('\n', 0, m.start()) + 1
    while True:
        prev_end = start - 1
        prev_start = text.rfind('\n', 0, prev_end) + 1
        if prev_end > 0 and text[prev_start:prev_end].strip().startswith('///'):
            start = prev_start
        else:
            break
    i = m.start(); depth = 0
    while i < len(text):
        c = text[i]
        if c in '([':
            depth += 1
        elif c in ')]':
            depth -= 1
        elif c == '{' and depth == 0:
            d = 0
            while i < len(text):
                if text[i] == '{': d += 1
                elif text[i] == '}':
                    d -= 1
                    if d == 0:
                        i += 1
                        break
                i += 1
            break
        elif text.startswith('=>', i) and depth == 0:
            j = i + 2; d = 0
            while j < len(text):
                ch = text[j]
                if ch in '([{': d += 1
                elif ch in ')]}': d -= 1
                elif ch == ';' and d == 0: break
                j += 1
            i = j + 1
            break
        i += 1
    end = text.find('\n', i) + 1
    if text[end:end+1] == '\n':
        end += 1
    return text[:start] + text[end:]

jobs = {
 'models/engine_config_request.dart': [r'^\s*BuildEngineConfigRequest toGrpcModel\(\)'],
 'models/engine_log.dart': [r'^\s*factory EngineLogChunk\.fromGrpc\('],
 'models/begzar_engine_config.dart': [r'^\s*LaunchEngineRequest toGrpcModel\(\)'],
 'models/backend.dart': [],
 'models/latency_sample.dart': [], 'models/real_delay_sample.dart': [],
 'models/begzar_notification_text.dart': [], 'constants/engine_names.dart': [],
}
for path, members in jobs.items():
    t = open(SRC + path).read()
    t = '\n'.join(l for l in t.split('\n') if not (l.startswith('import ') and 'gen/bindings' in l))
    for sig in members:
        t = strip_member(t, sig)
    # What only the removed conversions used.
    if path == 'models/begzar_engine_config.dart':
        t = '// The tunnel descriptor only ever reached the wire.\n// ignore_for_file: unused_field\n\n' + t
    open(DST + path, 'w').write(HEADER + t.lstrip('\n'))
