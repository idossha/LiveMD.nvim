# Testing nvim-markdown-preview

This directory contains tests for the nvim-markdown-preview plugin.

## Test Structure

- `simple_test.lua`: Self-contained test file that tests the core functionality
- `run_tests.lua`: Script to run the tests

## Requirements

To run the tests, you'll need:

1. Lua 5.1+ installed

No external dependencies are required as the tests use a simple custom testing framework built into the files themselves.

## Running Tests

From the `tests/` directory, run:

```bash
lua run_tests.lua
```

The tests are designed to run standalone without any test framework dependencies. They use a simple custom testing framework built into the test files themselves.

## Test Coverage

The tests verify:

1. Configuration loading with defaults and custom settings
2. Starting and stopping the preview server
3. Toggling preview state
4. Content generation from buffer
5. Filetype checking for markdown files

## Adding Tests

When adding new tests:

1. Prefer to add to the simple_test.lua file for simplicity
2. Follow the describe/it pattern used in the existing tests
3. Make sure to properly mock any Neovim API calls your tests need

## Design Philosophy

The tests are designed to be simple and focused on core functionality rather than implementation details. They verify that:

1. The plugin properly initializes with the expected configuration
2. Starting/stopping preview works as expected
3. Toggle functionality correctly changes state
4. Basic buffer content extraction works

This approach allows the implementation to change without breaking tests as long as the core functionality remains the same.