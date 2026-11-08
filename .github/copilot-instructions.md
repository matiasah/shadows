# Project Guidelines

## Lua documentation

- When creating or modifying a Lua file, keep the whole file documented with LuaLS/EmmyLua `---@` annotations, not just the changed lines.
- Start each file with a `---@` summary of what the module provides.
- Declare classes with `---@class Name:Parent` and document every attribute with `---@field [private|protected] name type Description`, including inherited defaults, constructor fields, and internal state.
- Document every method and function, including constructors, overrides, callbacks, and private helpers. Use `---@description ...` for each function's summary, `---@param name type Description` for each parameter (mark optional parameters with `?` and state defaults), and `---@return type name Description` for each return value.
- Use precise types and keep annotations in sync with signatures and fields.

## Project structure

- The editable library source is in `src/shadows`; demos live in `DEMOS/`, unit tests in `spec/`, and API notes in `docs/`.
- Keep library code, tests, and demos separate. Do not copy the library into individual demos.
- Preserve the public `shadows` package name and the require-path setup documented in `README.md`.

## Testing

- The project runner is `love`. Run validation from the repository root with `love . <DemoName>`; use `--capture` for automated rendering checks and `--verify` when the demo supports regression assertions (for example, `love . Penumbra --capture --verify`).
- Use LÖVE as the primary validation runtime, not standalone Lua or Busted. Do not install Busted or native build dependencies just to validate the project. Keep focused unit tests under `spec/` supplemental when their runner is already available.
- Keep LÖVE rendering and end-to-end checks in the demos rather than duplicating runtime setup in unit tests.
- Use the existing demos and VS Code tasks when validating LÖVE behavior. For DPI-sensitive changes, run the HighDPI demo, including capture mode when relevant.

## README and API documentation

- For every source-code change under `src/`, update `README.md` in the same change to reflect any resulting project structure, behavior, public API, or usage changes.
- Keep API notes in `docs/` aligned with public API changes. Prefer updating the relevant existing page; add documentation for new public features as appropriate.
- Verify examples and descriptions against the implementation. Keep the distinction between the library source, test suite, and demos clear.

## Demo maintenance

- Update affected examples in `DEMOS/` when changing public APIs, behavior, or features demonstrated there.
- Keep the shared source-library setup in demos; do not introduce demo-specific copies of library code.
- After changing a demo or the behavior it demonstrates, run the relevant demo with `love` and its regression assertions when available. For DPI-sensitive changes, use `love . HighDPI --capture` and inspect the resulting screenshot for rendering issues.
