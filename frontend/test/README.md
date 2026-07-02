# Testing Guide

## Overview

This directory contains unit tests, widget tests, and integration tests for the Meatvo app.

## Test Structure

```
test/
├── helpers/
│   └── test_helpers.dart       # Test utilities and helpers
├── models/
│   └── product_model_test.dart  # Product model unit tests
├── services/
│   ├── auth_service_test.dart  # Auth service tests
│   ├── cart_service_test.dart  # Cart service tests
│   └── order_service_test.dart # Order service tests
└── widget_test.dart            # Widget tests
```

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/models/product_model_test.dart
```

### Run tests with coverage
```bash
flutter test --coverage
```

## Test Requirements

### Service Tests
Service tests use local fakes. The test setup will:
1. Create fake service instances
2. Avoid backend/network calls in unit tests
3. Keep full backend-connected flows for integration tests

**Important:** 
- Unit tests do not bootstrap external services.
- Tests use `TestSetup.initializeTestEnvironment()`.
- For full integration tests, target the Node backend with `integration_test`.
- Model tests are pure unit tests and do not require external dependencies.

### Model Tests
Model tests are pure unit tests and don't require external dependencies - they always run.

### Model Tests
Model tests are pure unit tests and don't require external dependencies.

### Widget Tests
Widget tests may require proper initialization of services. Use `pumpAndSettle()` to wait for async operations.

## Adding New Tests

1. Create test file in appropriate directory (`test/services/`, `test/models/`, etc.)
2. Follow naming convention: `*_test.dart`
3. Use test groups to organize related tests
4. Add test helpers in `test/helpers/` for reusable utilities

## Best Practices

1. **Isolation**: Each test should be independent
2. **Naming**: Use descriptive test names
3. **Setup/Teardown**: Use `setUp()` and `tearDown()` for common initialization
4. **Mocks**: Use mockito/mocktail for external dependencies
5. **Coverage**: Aim for high test coverage on critical paths

## Future Enhancements

- [ ] Integration tests for complete user flows
- [ ] E2E tests with Flutter Driver/Integration Test
- [ ] Performance tests
- [ ] Golden tests for UI consistency

