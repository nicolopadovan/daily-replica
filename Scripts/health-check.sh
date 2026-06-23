#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

HEALTH_FILTER="AppHealthChecksTests|testRefreshAccessibilityTrustUsesObservedWindowTitleCapability|testCaptureTickRefreshesAccessibilityTrustState|testCaptureTickMarksAccessibilityTrustedWhenWindowTitleWasCaptured|testStopTrackingAddsInactiveSegmentAndPreventsResumingWithPreviousActiveSpan"

printf 'Running health harness filter: %s\n' "$HEALTH_FILTER"
swift test --filter "$HEALTH_FILTER"
printf 'Health harness passed.\n'
