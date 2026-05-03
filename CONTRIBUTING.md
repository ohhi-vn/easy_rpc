# Contributing to EasyRpc

Thank you for considering contributing to EasyRpc! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our code of conduct (to be added).

## How Can I Contribute?

### Reporting Bugs

- Use the [GitHub Issues](https://github.com/ohhi-vn/easy_rpc/issues) tracker
- Describe the bug clearly with steps to reproduce
- Include Elixir version, EasyRpc version, and relevant configuration
- Include error messages and stack traces if applicable

### Suggesting Enhancements

- Open an issue with the "enhancement" label
- Describe the use case and expected behavior
- Consider backward compatibility

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run tests (`mix test`)
5. Run formatter (`mix format`)
6. Commit with clear messages
7. Push to your fork
8. Create a Pull Request

## Development Setup

```bash
# Clone the repository
git clone https://github.com/ohhi-vn/easy_rpc.git
cd easy_rpc

# Get dependencies
mix deps.get

# Run tests
mix test

# Run with coverage
mix test --cover

# Generate docs locally
mix docs
```

## Testing

- Write tests for new features or bug fixes
- Maintain or improve test coverage
- Run the full test suite before submitting: `mix test`
- Include both unit tests and integration tests where appropriate

### Test Structure

- `test/easy_rpc_test.exs` - Main module tests
- `test/spark_dsl_test.exs` - Spark DSL tests
- `test/rpc_call_test.exs` - RPC execution tests
- `test/error_test.exs` - Error handling tests
- `test/node_selector_test.exs` - Node selection strategy tests

## Documentation

- Update documentation for any user-facing changes
- Follow the existing documentation style
- Update `README.md` for new features
- Add to `CHANGELOG.md` under `[Unreleased]` section
- Update `guides/ARCHITECTURE.md` for significant design changes

### Documentation Style

- Use clear, concise language
- Include code examples for new features
- Use proper Elixir syntax highlighting in markdown
- Keep examples practical and runnable

## Code Style

- Run `mix format` before committing
- Follow Elixir conventions and best practices
- Use pattern matching over conditional logic where appropriate
- Prefer `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Write descriptive function names (e.g., `calculate_total/2` not `calc/2`)

## Spark DSL Guidelines

When modifying or extending the Spark DSL:

- Maintain backward compatibility when possible
- Document new DSL options in `EasyRpc.Dsl` module
- Add appropriate validators in `EasyRpc.Verifiers`
- Update transformers in `EasyRpc.Transformers`
- Add tests for new DSL features

## Review Process

1. All PRs require at least one review
2. CI must pass (tests, formatter, dialyzer if available)
3. Documentation must be updated for user-facing changes
4. Significant changes may require discussion before implementation

## Questions?

Feel free to open an issue with the "question" label or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
