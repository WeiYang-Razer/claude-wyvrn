# Conventions: <stack>

> [template] Template for a stack-specific conventions file. Instantiate as `[stack].md` under `~/.claude-wyvrn/conventions/` (package-shipped) or `.claude-wyvrn-local/conventions/` (project-specific).

**Stack:** <stack identifier, e.g., js, python, cpp, csharp>
**Applies to extensions:** <comma-separated list, e.g., .js, .jsx, .mjs, .cjs>

> [template] The `Applies to extensions` header tells `/flow` which file extensions trigger lazy-loading of this convention. See the matching list in `~/.claude-wyvrn/CLAUDE.md`.

## Naming

> [template] Conventions for naming variables, functions, classes, files, types, constants, modules. Specific and testable — "camelCase for function names" not "clear names".

<naming conventions>

## Formatting

> [template] Formatting rules specific to this stack. Indentation, line length, bracket style, quoting. Reference the formatter/linter if the project uses one.

<formatting conventions>

## File organization

> [template] How files and directories are organized within this stack. What goes in which kind of file. Where imports live. How exports are structured.

<file organization>

## Imports and dependencies

> [template] Rules about importing, exporting, and adding dependencies specific to this stack.

<imports and dependencies>

## Error handling

> [template] Stack-specific error handling conventions. How errors are thrown, caught, propagated, logged.

<error handling>

## Testing

> [template] Stack-specific test conventions. Test framework, file naming, test runner invocation command, test organization. General test rules are in `~/.claude-wyvrn/conventions/universal.md` §1.6; this section layers stack-specific details on top.

**Test framework:** <name and version>
**Test file pattern:** <glob or pattern>
**Test runner command:** <command>

<stack-specific test rules>

## Stack-specific prohibitions

> [template] Things not to do that are specific to this stack. If none, write "N/A".

<prohibitions, or N/A>
