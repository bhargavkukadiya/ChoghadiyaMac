#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_MODE="${1:-run}"
case "$TASK_MODE" in
    run|--debug|--logs|--telemetry|--verify) ;;
    *) echo "Usage: $0 [--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
cd "$TASK_ROOT"
pkill -x ChoghadiyaMacApp >/dev/null 2>&1 || true
# Unsigned local development. Validate App Group sharing with a signed build in Xcode.
xcodebuild -project ChoghadiyaMac.xcodeproj -scheme ChoghadiyaMacApp \
    -destination 'platform=macOS' -derivedDataPath build/Run \
    build CODE_SIGNING_ALLOWED=NO
TASK_APP="$TASK_ROOT/build/Run/Build/Products/Debug/ChoghadiyaMacApp.app"
if [[ "$TASK_MODE" == --debug ]]; then
    exec lldb -- "$TASK_APP/Contents/MacOS/ChoghadiyaMacApp"
fi
/usr/bin/open -n "$TASK_APP"
case "$TASK_MODE" in
    --logs|--telemetry)
        exec /usr/bin/log stream --info --style compact --predicate 'process == "ChoghadiyaMacApp"' ;;
    --verify)
        sleep 1
        pgrep -x ChoghadiyaMacApp >/dev/null ;;
esac
