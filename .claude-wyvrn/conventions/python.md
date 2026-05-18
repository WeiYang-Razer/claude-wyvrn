# Conventions: python

**Stack:** python
**Applies to extensions:** .py, .pyi

## Naming

- Modules, packages, files: `snake_case`.
- Classes, exceptions, type variables: `PascalCase`.
- Functions, methods, variables: `snake_case`.
- Constants: `SCREAMING_SNAKE_CASE` at module level.
- Private-by-convention: leading underscore (`_internal`). Name-mangled: double leading underscore (`__truly_private`) only inside classes and rarely.
- Boolean: `is_`, `has_`, `should_`, `can_` prefix.

## Formatting

- `black` for formatting. `ruff format` is acceptable as a faster equivalent. The project's `pyproject.toml` is authoritative.
- `ruff` for linting. Fix all errors; warnings within scope of the change.
- 4-space indent. 88-column line length (black default). 120 acceptable when the project sets it.
- Double quotes for strings (black default). Single quotes only when the string contains a double quote.
- Trailing commas in multi-line collections and call sites.
- Type hints on all public function signatures. Type hints on internal functions when they aid clarity.

## File organization

- Package layout: `src/[package]/` with `__init__.py`. Tests under `tests/` mirroring `src/[package]/`.
- One public class per module unless classes are tightly coupled.
- Module-level docstrings on packages and entry points. Function docstrings on public APIs.
- `__all__` declared in modules with public APIs to control wildcard imports.
- Configuration in `pyproject.toml`. Avoid `setup.cfg` and `setup.py` for new projects.

## Imports and dependencies

- Import order per `isort`/`ruff`: standard library, third-party, first-party, local. Blank line between groups.
- Absolute imports for cross-package; relative imports (`from .module import ...`) within a package.
- No wildcard imports (`from foo import *`) outside `__init__.py` re-exports.
- New dependencies require explicit user confirmation per `universal.md` §1.3 and an entry in `pyproject.toml` `[project.dependencies]` or the project's poetry/uv lockfile.
- Pin direct dependencies; use the lockfile (`poetry.lock`, `uv.lock`, `requirements.txt` with hashes) for transitive pins.

## Error handling

- Raise specific exceptions, not bare `Exception`. Custom exceptions inherit from a project base.
- `except SpecificError:` always. Never `except:` or `except Exception:` without re-raising or logging.
- Use `raise ... from err` to preserve causality when wrapping exceptions.
- Context managers (`with`) for resource handling. Write `__enter__`/`__exit__` or `@contextmanager` rather than try/finally for cleanup.
- `assert` is for invariants in development. Do not use `assert` for input validation in production code paths (it is stripped under `python -O`).
- Do not catch `KeyboardInterrupt` or `SystemExit` outside top-level entry points.

## Testing

**Test framework:** pytest. unittest acceptable when already in use.
**Test file pattern:** `tests/test_[module].py` or `[module]_test.py`.
**Test runner command:** `pytest` from the project root.

- One `test_[behavior]` function per behavior. Class-based tests only for shared fixtures via `setup_method`.
- Fixtures via `@pytest.fixture`. Scope appropriately (`function`, `module`, `session`).
- Parameterized tests via `@pytest.mark.parametrize`.
- Mocks via `unittest.mock` or `pytest-mock`'s `mocker` fixture. No third-party mocking libraries.
- Async tests via `pytest-asyncio` with `@pytest.mark.asyncio`.
- Coverage measured but not gated unless the project sets a threshold.

## Stack-specific prohibitions

- No mutable default arguments (`def f(x=[])`).
- No `from foo import *` outside `__init__.py`.
- No `print` for production logging. Use the `logging` module.
- No `eval` or `exec` on untrusted input.
- No string concatenation for SQL, shell, or paths. Use parameterized queries, `subprocess` with list args, `pathlib.Path`.
- No `os.system`. Use `subprocess.run` with `check=True`.
- No `# type: ignore` without a comment. Prefer fixing the type.
