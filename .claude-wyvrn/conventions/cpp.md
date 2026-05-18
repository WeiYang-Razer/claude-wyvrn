# Conventions: cpp

**Stack:** cpp
**Applies to extensions:** .cpp, .cc, .cxx, .h, .hpp, .hxx

## Naming

- Types, classes, structs, enums: `PascalCase`.
- Functions, methods, variables: `camelCase`.
- Constants and enum members: `kPascalCase` (e.g., `kMaxBufferSize`).
- Macros: `SCREAMING_SNAKE_CASE`. Reserve macros for header guards, platform gates, and compiler-feature detection (`__has_include`, `__cpp_lib_*`) only.
- Member variables: trailing underscore (`buffer_`, `count_`). No `m_` prefix.
- Files: `snake_case.cpp` / `snake_case.h`. One primary class per pair, file name matches class name.
- Template parameters: `PascalCase` (`typename Range`, `typename Allocator`). Concept names are `PascalCase` and read as adjectives or noun phrases (`Sortable`, `RandomAccessIterator`).

## Formatting

- C++23 baseline. Concepts, ranges and views, `std::span`, `std::string_view`, `std::format` / `std::print` / `std::println`, three-way comparison, modules, `std::jthread`, `std::expected`, `std::mdspan`, `std::flat_map`, `std::generator`, `if consteval`, and deducing `this` are baseline — do not gate behind project opt-ins.
- `clang-format` with the project's `.clang-format` file is authoritative. If absent, Google style with 4-space indent and 100-column lines.
- West const (`const int x`) for new code.
- Braces on the same line for functions and control flow.
- Pointer/reference sigil binds to the type: `int* p`, not `int *p`.
- Brace-initialize (`T x{...}`) by default to prevent narrowing. Use `=` only for primitives where narrowing is intended and obvious.
- Almost-always-`auto` for local variables when the type is obvious from the right-hand side or irrelevant to the reader. Spell the type out when the contract matters (return types of public APIs, function parameters, members).

## File organization

- Header (`.h`/`.hpp`) declares; implementation (`.cpp`) defines. Inline definitions in headers only for templates and trivial accessors.
- Header guards use `#pragma once`. Include-guard macros (`PROJECT_MODULE_FILE_H_`) only when the toolchain does not support `#pragma once`.
- Include order: corresponding header first, blank line, C system headers, blank line, C++ standard headers, blank line, third-party, blank line, project headers. Each group alphabetized.
- One class per header unless classes are tightly coupled (PIMPL, friend pairs).
- Forward-declare in headers when the full definition is not needed; include in the `.cpp`.
- New libraries expose C++ modules (`export module foo;`). Legacy headers stay as headers — do not mass-convert.

## Imports and dependencies

- Use angle brackets for system and third-party (`<vector>`, `<boost/optional.hpp>`); quotes for project headers (`"foo/bar.h"`).
- New third-party libraries require explicit user confirmation per `universal.md` §1.3 and an entry in the build system (CMake `find_package`, vcpkg manifest, or equivalent).
- No `using namespace std;` at file or header scope. Inside function bodies only when scoped narrowly. The `using std::swap; swap(a, b);` two-step is the exception — that is the documented customization-point idiom, not a namespace import.
- Prefer standard library over hand-rolled. Prefer Boost over hand-rolled when Boost is already a dependency.

## Resource management and ownership

- **Rule of Zero.** Default. Compose existing RAII types (smart pointers, containers, file/socket wrappers) and let the compiler generate special members. Author Rule-of-Five types only when wrapping a raw resource — and then `=delete` or `=default` every special member explicitly.
- **No raw `new` / `delete`.** Allocate through `std::make_unique`, `std::make_shared`, containers, or allocator-aware factories. Placement-new is permitted only inside allocator-aware code and intrusive containers.
- **Ownership in signatures is contractual:**
  - `std::unique_ptr<T>` by value — sink (callee takes ownership).
  - `std::shared_ptr<T>` by value — sink that shares ownership. Never `shared_ptr<T>&` or `const shared_ptr<T>&` unless you genuinely need to rebind or inspect the control block.
  - `T&` / `const T&` — non-owning, non-null borrow.
  - `T*` — non-owning, nullable borrow. Prefer references when null is not a valid state.
  - `std::string_view` for read-only string parameters; `std::span<T>` / `std::span<const T>` for contiguous-range parameters. Never store either as a member unless lifetime is guaranteed by construction.
- `std::weak_ptr` to break ownership cycles and for observer/cache references that must not extend lifetime.
- `std::enable_shared_from_this` when an instance must hand out `shared_ptr`s to itself (typically for async callbacks that outlive the immediate caller).
- `shared_ptr` is only thread-safe at the control-block level. Concurrent mutation of the pointee still needs synchronization. Do not assume `shared_ptr` makes shared state safe.
- Move-only types are the default for unique resources. Make types non-copyable by holding a `unique_ptr` member rather than `=delete`-ing copy operations by hand.

## Const, constexpr, and compile-time

- Prefer `constexpr` over `const` for compile-time constants. Prefer `constexpr` variables and functions over macros.
- `consteval` for functions that must run at compile time (e.g., format-string validation, ID hashing).
- `constinit` on non-trivial namespace-scope objects to guarantee constant initialization and avoid static-init-order issues.
- `const`-qualify member functions that don't mutate observable state. Mark data members `mutable` only for caches and synchronization primitives.
- `[[nodiscard]]` on every function returning `std::optional`, `std::expected`, error codes, RAII handles, or any value whose silent discard is a likely bug. Apply to types as well (`[[nodiscard]] class ScopeGuard { ... };`).
- `static_assert` for compile-time invariants. `[[assume(expr)]]` (C++23) for optimizer hints on release-time invariants the compiler can't see.

## Types and idioms

- `enum class` always. Plain `enum` is prohibited in new code.
- Strong typedefs (named-type wrappers) for primitive IDs and units when mixing them is a likely bug — don't pass three `int`s when you mean `UserId`, `OrderId`, `Quantity`.
- Concepts replace SFINAE for new generic code. Constrain template parameters with `requires` clauses or concept-named parameters (`template <std::ranges::input_range R>`).
- Range-based `for` and `<ranges>` over hand-written index loops. Pipelines (`vec | std::views::filter(...) | std::views::transform(...)`) when they read more clearly than the loop they replace — not for their own sake.
- Lambdas over named functor types for local callbacks. Capture by reference only when the lambda cannot outlive the captured object; capture by value (or `[ptr = std::move(ptr)]`) otherwise. No default captures (`[=]`, `[&]`) — list them.
- `std::format` / `std::println` for formatted output. No `printf`-family in new code. No `iostream` chaining for non-trivial formatting.

## Error handling

- Exceptions for exceptional conditions. `std::expected<T, E>` for expected failures with a value; `std::optional<T>` when the absence is itself the only failure mode; error codes only at C ABI boundaries.
- Do not throw across DLL/SO boundaries unless the build configuration explicitly supports it.
- `noexcept` on move constructors, move assignment, destructors, and swap functions. `noexcept` on any function that genuinely cannot throw — it enables optimizations and is part of the type's contract.
- `assert()` for invariant checks in debug builds. For release-time invariants, use the project's `CHECK`/`DCHECK` pair that aborts with diagnostics.
- No bare `catch (...)` without rethrow.

## Concurrency

- `std::jthread` for owned threads. It joins on destruction and carries a `std::stop_token` — use it instead of ad-hoc atomic-bool cancellation flags.
- `std::latch`, `std::barrier`, `std::counting_semaphore` for coordination. Reach for these before hand-rolling condition-variable dances.
- `std::async` is permitted only with an explicit launch policy (`std::launch::async`). The defaulted policy is a foot-gun (may run deferred on the calling thread) — do not rely on it.
- Shared mutable state needs `std::mutex` / `std::shared_mutex` / `std::atomic`. `shared_ptr` does not make the pointee thread-safe (see ownership section).
- No naked `std::thread`. Use `std::jthread`, `std::async` with explicit policy, or the project's task system.

## Testing

**Test framework:** GoogleTest (gtest) with GoogleMock. Catch2 v3 acceptable when already in use.
**Test file pattern:** `[component]_test.cpp` co-located with the source under `tests/` mirroring the source tree.
**Test runner command:** `ctest --output-on-failure --parallel` from the build directory; `ctest --rerun-failed --output-on-failure` to iterate on failures.

- One `TEST(SuiteName, CaseName)` per behavior. Use `TEST_F` fixtures for shared setup.
- Death tests for `CHECK` and `assert` paths via `EXPECT_DEATH`.
- Mocks via `gmock`. Do not hand-roll mock classes when a `MOCK_METHOD` will do.
- Sanitizers (ASan, UBSan, TSan) run in CI on test builds. Tests must pass under all enabled sanitizers.

## Stack-specific prohibitions

- No `std::endl` in hot paths; use `'\n'`.
- No C-style casts. Use `static_cast`, `const_cast`, `reinterpret_cast`, `dynamic_cast`.
- No raw `new` / `delete` outside placement-new in allocator-aware code.
- No `std::shared_ptr` when `std::unique_ptr` suffices.
- No `shared_ptr<T>&` or `const shared_ptr<T>&` parameters unless rebinding or inspecting the control block.
- No plain `enum` — `enum class` only.
- No bare `catch (...)` without rethrow.
- No naked threads. Use `std::jthread`, `std::async` with explicit launch policy, or the project's task system.
- No default-capture lambdas (`[=]`, `[&]`) — capture lists must be explicit.
- No `printf`-family or unstructured `iostream` chains for new formatted output — use `std::format` / `std::println`.
