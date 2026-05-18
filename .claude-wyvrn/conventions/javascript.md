# Conventions: javascript

**Stack:** javascript
**Applies to extensions:** .js, .jsx, .mjs, .cjs

## Naming

- Variables, functions: `camelCase`.
- Classes, constructors, React components: `PascalCase`.
- Constants exported from a module: `SCREAMING_SNAKE_CASE`. Local constants: `camelCase`.
- Files: `kebab-case.js` for modules, `PascalCase.jsx` for React components.
- Boolean variables: `is`, `has`, `should`, `can` prefix.
- Private-by-convention members: leading underscore (`_internal`). No name mangling.

## Formatting

- Prettier with the project's `.prettierrc` is authoritative. If absent, Prettier defaults: 2-space indent, single quotes, semicolons, 80-column.
- ESLint with the project's `.eslintrc` for lint. Fix all errors; warnings within scope of the change.
- ES2022 features. Older targets only when the project's `package.json` `engines` or build target requires it.
- Arrow functions for callbacks and short pure functions. Named `function` declarations for module-level functions and methods.
- One statement per line. No comma operator chains.

## File organization

- ES modules (`import`/`export`) for `.js` and `.mjs`. CommonJS (`require`) for `.cjs` only.
- One public component or module per file. Internal helpers live alongside until they have a second caller.
- Index files (`index.js`) re-export only; no logic in `index.js`.
- Tests co-located as `[name].test.js` next to source, or under a parallel `__tests__/` folder. Match the project.
- Configuration files (`*.config.js`, `.eslintrc.js`) at project root.

## Imports and dependencies

- Import order: Node built-ins, third-party, project absolute imports, relative imports. Blank line between groups.
- No default exports for shared utilities; named exports only. Default exports are acceptable for React components and Next.js pages.
- New `dependencies` or `devDependencies` require explicit user confirmation per `universal.md` §1.3.
- Lock file (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`) is committed. Never edit by hand.
- Do not import from `node_modules` paths directly; import the package name.

## Error handling

- Throw `Error` or a subclass. Never throw strings, numbers, or plain objects.
- Custom error classes extend `Error`, set `this.name`, and capture stack with `Error.captureStackTrace` when available.
- `async`/`await` for asynchronous code. Promise chains only when composing existing Promise-returning APIs.
- Every `await` is either inside `try`/`catch` or inside a function whose caller catches. No floating rejections.
- Validate function inputs at exported API boundaries; trust internal callers per `universal.md` §2.5.

## Testing

**Test framework:** Jest. Vitest acceptable when the project uses Vite. Mocha + Chai when already in use.
**Test file pattern:** `[name].test.js` or `__tests__/[name].js`.
**Test runner command:** `npm test` (delegates to the project's configured runner).

- One `describe` per unit under test, one `it`/`test` per behavior.
- Setup via `beforeEach`. Avoid shared mutable state across tests.
- Mock with the runner's built-in (`jest.mock`, `vi.mock`). Do not introduce a mocking library when the runner has one.
- Snapshot tests sparingly: only for stable output where reviewing diffs is realistic.
- Async tests return the promise or use `async`/`await`. Do not call `done()` and `await` in the same test.

## Stack-specific prohibitions

- No `var`. Use `let` and `const`.
- No `==` or `!=`. Use `===` and `!==`.
- No `eval`, `Function` constructor, or `setTimeout(string, ...)`.
- No `console.log` left in production code paths. Use the project's logger.
- No mutating function parameters. No mutating shared module state.
- No `process.env.X` reads scattered across the codebase. Centralize in a config module.
