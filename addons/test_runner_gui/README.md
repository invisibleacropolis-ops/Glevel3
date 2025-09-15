# Test Runner GUI

This editor plugin exposes a dock inside the Godot editor that wraps `tests/Test_runner.gd`.
It allows developers to run the headless test suite without leaving editor mode.

## Features
- Fields for every command-line flag supported by `Test_runner.gd`.
- Runs the suite using the current Godot executable in headless mode.
- Displays verbose output and exit code in a read-only panel.

## Usage
1. Enable **Test Runner GUI** in *Project > Project Settings > Plugins*.
2. A *Test Runner* dock will appear on the right side of the editor.
3. Configure desired flags and press **Run Tests**.
4. Results from the headless process appear in the output box.

The plugin invokes the same binary running the editor with the `--headless` flag and
executes `tests/Test_runner.gd` within the project path. Ensure a compatible Godot
console binary is available in your environment.
