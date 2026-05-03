# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added `enable_logging` option to config section for controlling detailed logging
- Added `nodes_provider` option for dynamic node discovery via MFA

### Changed
- Updated documentation to reflect Spark DSL syntax (replacing old `defrpc` macro references)
- Improved error handling documentation with clearer examples

### Fixed
- Fixed inconsistencies between README examples and actual Spark DSL syntax

## [0.9.0] - 2024-01-15

### Added
- Migrated from macro-based DSL to Spark DSL for better extensibility
- Added `rpc_function` entities with support for argument names (better IDE support)
- Added `private: true` option to generate private functions (`defp`)
- Added `new_name` option to create function aliases
- Added comprehensive architecture documentation in `guides/ARCHITECTURE.md`
- Added support for `:infinity` timeout

### Changed
- **BREAKING**: Replaced `defrpc` macro with `rpc_function` in Spark DSL
- **BREAKING**: Replaced `config :my_app, :api` with `config do...end` blocks
- Improved error handling with unified `EasyRpc.Error` struct
- Enhanced node selection strategies with better documentation

### Deprecated
- Old macro style (`use EasyRpc.RpcWrapper`) - still works but not recommended

### Removed
- Removed deprecated `DefRpc` module (replaced by Spark DSL)

## [0.7.0] - 2023-12-01

### Added
- Added `sleep_before_retry` option for retry delay control
- Added benchmark suite for performance comparison
- Added telemetry events for RPC calls

### Changed
- Improved retry logic to automatically enable error_handling
- Better error messages with context details

### Fixed
- Fixed sticky node not working with round_robin strategy
- Fixed timeout not being applied correctly in some edge cases

## [0.6.0] - 2023-10-15

### Added
- Initial release with basic RPC wrapping functionality
- Support for random, round_robin, and hash node selection
- Basic retry and timeout support
- Error handling with raise or {:ok, result} tuples

[Unreleased]: https://github.com/ohhi-vn/easy_rpc/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/ohhi-vn/easy_rpc/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/ohhi-vn/easy_rpc/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/ohhi-vn/easy_rpc/releases/tag/v0.6.0
