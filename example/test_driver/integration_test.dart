import 'package:integration_test/integration_test_driver.dart';

/// Standard driver for on-device `integration_test` runs started with
/// `flutter drive`. Used for `integration_test/npg_simulator_test.dart` on the
/// iOS simulator, which Patrol cannot target (no RunnerUITests target, see
/// TESTING.md).
Future<void> main() => integrationDriver();
