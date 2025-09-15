# Testing Overview

This project is organized as a Godot 4 game with the following script layout:

- `src/core` – fundamental Resource types such as `Component` and `EntityData`.
- `src/globals` – autoload singletons like `AssetRegistry`, `EventBus`, and `ModuleRegistry`.
- `src/systems` – example gameplay systems and components.
- `src/tests` – individual test scripts exercising the registries. When
  interacting with the `ModuleRegistry`, rely on its helper methods
  (`register_module`, `get_module`, and `has_module`) instead of
  manipulating the internal `modules` dictionary directly so future
  refactors only need to adjust the singleton.
- `tests` – a headless test harness and its manifest.

## Test Runner

The headless test runner lives at `tests/Test_runner.gd`. It loads `tests/tests_manifest.json` to determine which test scripts to execute and supports tagging, dependency resolution, batching, and JUnit/JSON output.

The script was written against older GDScript syntax and currently fails to parse in Godot 4 due to use of deprecated ternary operators and nested function definitions. Attempting to run it with a Godot 4.2 headless binary results in an error such as:

```
Unexpected "?" in source. If you want a ternary operator, use "truthy_value if true_condition else falsy_value".
```

## Plan to actualize the Test Runner

1. **Update syntax** – Replace all `condition ? a : b` expressions with `a if condition else b`, convert nested functions to variables holding lambdas, and remove unsupported `try`/`catch` blocks.
2. **Type annotations** – Godot 4 treats some implicit `Variant` types as warnings. Add explicit types for variables where inference is ambiguous to avoid warnings promoted to errors.
3. **Dependency helpers** – Maintain the existing dependency-resolution logic so tests can declare `depends_on` entries in the manifest.
4. **Expand coverage** – Add new test scripts for `Component`, `EntityData`, and systems under `src/systems`, then reference them in `tests/tests_manifest.json`.
5. **Continuous integration** – Run the runner in headless mode: `godot --headless -s tests/Test_runner.gd`, capturing `results.json` and `results.xml` for reporting.

Implementing these steps will allow the test harness to execute all available scripts while respecting declared dependencies and filters.
