# Conventions: react

**Stack:** react
**Applies to extensions:** .tsx; .ts files that import from `react`, `react-dom`, or project hooks/atoms

## Naming

- All naming rules from `typescript.md` apply, with the overrides below.
- Components, pages, entities, builders, atoms, classes: `PascalCase`. Hooks: `camelCase` starting with `use`.
- File pattern: `<Name>.<folderType>.<ext>` — `.hook.ts`, `.atom.ts`, `.builder.ts`, `.entity.ts`, `.page.tsx`, `.test.tsx`. Components are the exception: `<ComponentName>.tsx` inside `<ComponentName>/`.
- Component prop interfaces: `I<ComponentName>` (`IUserCard`). Exported type alias: `<ComponentName>Props = I<ComponentName>`. This overrides the no-`I`-prefix rule from `typescript.md`.
- Action components: `<Type><Action>` (`ButtonSubmit`, `LinkDownload`). Type comes first.
- Entity components: `<Entity><Type>` (`UserList`, `OrderCard`). Entity comes first.
- Grouped actions: `<Context>Actions` or `<Context>Buttons` (`FormActions`, `TableActions`).
- CVA variant identifiers: `camelCase` ending in `Variants` (`buttonVariants`, `cardHeaderVariants`).

## Formatting

- All formatting rules from `typescript.md` apply, with the overrides below.
- 2-space indent. Single quotes. Semicolons mandatory. Trailing newline at end of file.
- No space after `if`, `for`, `while`, `switch`, `catch` (`if(condition)`, not `if (condition)`).
- No space before function parentheses (`function name()`, not `function name ()`).
- Components use the `function` keyword with `FC` typing: `const Foo: FC<FooProps> = function(props: FooProps) { ... }`. Arrow function expressions for component bodies are prohibited.
- One blank line maximum between blocks.
- Hard limit: 100 lines per UI component file. Above that, split into a `nested/` folder of sub-components.

## File organization

- Feature-first layout under `src/features/<FeatureName>/` containing `components/`, `hooks/`, `entities/`, `builders/`, `atoms/`, `utils/`, optional `rest/`, and a feature-root `index.ts`.
- Each component lives in its own folder: `<ComponentName>/<ComponentName>.tsx` + `index.ts`. Sub-components in `<ComponentName>/nested/`. Variant implementations in `<ComponentName>/variants/`. Each subfolder carries its own `index.ts`.
- Pages: `src/pages/<Domain>/<Action>.page.tsx` (`Edit`, `List`, `New`, `Show`). Page-level components for route roots only.
- Shared cross-feature code mirrors the same layout under `src/components/`, `src/hooks/`, `src/entities/`, `src/builders/`, `src/atoms/`, `src/utils/`.
- Two-level component architecture: primitives in `src/components/ui/` (shadcn/ui, accessible, no business logic) and business components in a dedicated UI feature folder (e.g., `src/features/<UILibrary>/`). Business components consume primitives; primitives never consume business components.
- Tests mirror source under `tests/behavior/features/<FeatureName>/<folderType>/<Name>.test.<ext>`. Not co-located.
- Every folder with source files re-exports through an `index.ts`. Index files re-export only — no logic.

## Imports and dependencies

- All import rules from `typescript.md` apply, with the overrides below.
- Path aliases (`@features`, `@components/ui`, `@hooks`, `@atoms`, `@entities`, `@builders`, `@utils`, `@pages`, `@routes`, `@api`, `@assets`, `@types`, plus per-feature aliases) are mandatory for cross-folder imports. Relative paths only within the same component folder.
- Adding a path alias updates `tsconfig.app.json`, the test tsconfig, and the bundler config (Vite/Webpack) in the same change.
- No `export default` in `src/features/**`, `src/hooks/**`, `src/components/**`, or any `index.ts`. Named exports only. Index files use `export * from './<Name>'`.
- Stack baseline: React 19, react-router 7, react-hook-form 7, Tailwind 4, Vite 6, Vitest 3, ESLint 9, Jotai 2, TanStack Query 5, TypeScript 5, `class-variance-authority`, HeroIcons, shadcn/ui. Alternatives for the same role require explicit user confirmation per `universal.md` §1.3.
- Accessible interactive primitives (Dialog, DropdownMenu, Select, Popover, Tabs, Accordion, Tooltip, Switch, Checkbox, Combobox, RadioGroup) consumed from the shadcn/ui layer. Raw Radix UI primitives are not used outside that layer.
- Icons from `@heroicons/react` first. Custom SVG icons only when HeroIcons has no equivalent; custom icons follow the same `cva` + token rules and include `aria-hidden="true"` when decorative.
- Environment variables via `import.meta.env`, prefixed `REACT_APP_` (core) or `PUBLIC_` (client-exposed). Centralized in a config module per `universal.md` §2.5.

## Styling

- All visual styling goes through `class-variance-authority` (`cva`). Raw Tailwind class strings on JSX `className` are prohibited, even for a single static class set.
- Combine variant output with additional classes via the project's `cn()` utility.
- Use design system tokens (`bg-background-base`, `text-text-primary`, `border-border-base`, `text-primary-base`, `bg-error-base`, etc.). Hard-coded colors, spacings, and font sizes are prohibited.
- Composite components declare one `cva` variant per sub-component. CVA does not support slots; do not emulate them with concatenation.

## State and data

- Local UI state: `useState` / `useReducer`.
- Cross-component shared state: Jotai atoms. One atom file per feature concern under `atoms/`; multiple atoms per file only when they belong to the same concern (search atom + getters in one file; sort/pagination in separate files).
- Server state: TanStack Query. Do not mirror server data into Jotai atoms or component state.
- React Context restricted to stable, low-frequency values (theme, auth identity). Not a substitute for Jotai or TanStack Query.
- One hook serves one target. Combining unrelated concerns in a single hook is prohibited; split.
- Hook input and return types are exported: `Use<Name>Params`, `Use<Name>Return`. Mutation hooks return the TanStack Query mutation result spread alongside any extra fields.
- Builders expose one public method, `build()`. One builder serves one building target.
- Entities are immutable data containers. Public fields are `readonly`. A static `empty(overrides)` factory is provided.

## Error handling

- All error handling rules from `typescript.md` apply.
- Render-time errors are caught by an error boundary at feature roots. Do not catch them in leaf components to suppress.
- TanStack Query errors surface via the query result; handle in the consuming hook or component, not inside `queryFn`.
- React Hook Form validation surfaces via form state. Do not throw from `onSubmit` to signal validation failure; return early.

## Testing

**Test framework:** Vitest with React Testing Library and `@testing-library/user-event`.
**Test file pattern:** `tests/behavior/features/<FeatureName>/<folderType>/<Name>.test.<ext>`.
**Test runner command:** `npm test` (delegates to Vitest).

- All testing rules from `typescript.md` apply.
- Behavior tests only: assert on what the user sees and what user interactions produce. Do not assert on internal state, hook return shape, or implementation details.
- Every component, hook, entity, builder, and atom ships with its behavior test in the same change. A source file without its test is incomplete per `universal.md` §1.6.
- Queries: prefer `getByRole` with accessible name; fall back to `getByLabelText`, `getByText`. Avoid `getByTestId` unless no accessible query works.
- Interactions via `userEvent`, not `fireEvent`, except for low-level events `userEvent` does not model.
- Mock TanStack Query and Jotai providers via the project's test setup, not via per-test global stubs.
- Snapshot tests are prohibited for component output. Use explicit assertions.

## Stack-specific prohibitions

- No direct Tailwind class strings on JSX. Always go through `cva`.
- No arrow function expressions for components. Use `const Name: FC<Props> = function(props: Props) { ... }`.
- No `export default` in `src/features/**`, `src/hooks/**`, `src/components/**`, or any `index.ts`.
- No relative paths for cross-folder imports.
- No `useState` for state shared across components or persisted across routes. Lift to a Jotai atom or to TanStack Query.
- No business logic inside `@components/ui` primitives. No raw Radix UI primitives consumed outside that layer.
- No CVA slots emulation. Each sub-component declares its own variant.
- No hard-coded colors, spacings, or font sizes. Use design system tokens.
- No UI component file above 100 lines. Split into `nested/` sub-components.
- No "super hooks" combining unrelated concerns. One hook, one target.
- No comments in any language other than English. No systematic comments restating what the code does.
- No `console.log` in production paths. Use the project's logger.
