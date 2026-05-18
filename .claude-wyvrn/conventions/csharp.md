# Conventions: csharp

**Stack:** csharp
**Applies to extensions:** .cs

## Naming

- Types, methods, properties, events, namespaces: `PascalCase`.
- Local variables, parameters: `camelCase`.
- Private fields: `_camelCase` (leading underscore).
- Constants: `PascalCase` (`MaxRetryCount`), not `SCREAMING_SNAKE`.
- Interfaces: `IPascalCase` (`IUserRepository`).
- Async methods: suffix `Async` (`LoadAsync`, `SaveAsync`).
- Files: one public type per file, file name matches type name (`UserRepository.cs`).

## Formatting

- `dotnet format` with the project's `.editorconfig` is authoritative.
- 4-space indent, 120-column soft limit.
- Allman braces (open brace on its own line).
- `var` when the type is obvious from the right-hand side; explicit type otherwise.
- File-scoped namespaces (`namespace Foo.Bar;`) for new files when the project targets .NET 6+.
- `using` directives outside the namespace, sorted with `System.*` first.

## File organization

- Project structure follows `Project.csproj` solution layout. One public type per file.
- Folders mirror namespaces: `Services/Auth/AuthService.cs` lives in namespace `Project.Services.Auth`.
- Test projects named `Project.Tests` adjacent to `Project`.
- Generated code under `obj/` and `bin/` is never edited and is in `.gitignore`.
- Resource files (`.resx`) for localized strings; do not hard-code user-facing strings.

## Imports and dependencies

- NuGet package versions pinned in `Directory.Packages.props` (Central Package Management) when the solution uses CPM, otherwise in each `.csproj`.
- New NuGet packages require explicit user confirmation per `universal.md` §1.3.
- Prefer .NET BCL over third-party for collections, JSON, HTTP, logging.
- `global using` statements live in a single `GlobalUsings.cs` per project, not scattered.

## Error handling

- Exceptions for exceptional conditions. Return `Result<T>` / `OneOf` style for expected failures only when the project already uses that pattern.
- Custom exceptions inherit from a project base exception, not `Exception` directly. Constructors accept `string message` and `Exception? innerException`.
- Never catch `Exception` at boundary handlers without logging and rethrowing or wrapping. Catching `SystemException` or specific subclasses is preferred.
- Async methods accept a `CancellationToken` parameter and propagate it. Methods that cannot honor cancellation document why.
- `throw;` to rethrow inside catch blocks. Never `throw ex;` (loses the stack).

## Testing

**Test framework:** xUnit. NUnit acceptable when already in use.
**Test file pattern:** `[ClassUnderTest]Tests.cs` in a parallel `Project.Tests` project.
**Test runner command:** `dotnet test` from the solution root.

- `[Fact]` for parameterless tests, `[Theory]` with `[InlineData]` / `[MemberData]` for parameterized.
- Mocks via Moq or NSubstitute (whichever the project already uses). Do not introduce both.
- Test names: `MethodUnderTest_Scenario_ExpectedOutcome`.
- Async tests return `Task`, never `async void`.
- Integration tests under `Project.IntegrationTests` with `[Trait("Category", "Integration")]` for selective runs.

## Stack-specific prohibitions

- No `async void` outside event handlers.
- No `.Result` or `.Wait()` on tasks (deadlock risk). Use `await`.
- No `catch (Exception ex) { throw ex; }`.
- No `string.Format` for SQL or shell. Use parameterized commands.
- No `DateTime.Now` for ordering or storage. Use `DateTimeOffset.UtcNow`.
- No `public` fields. Use auto-properties.
