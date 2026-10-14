#!/usr/bin/env python3
"""Exercise directory lint with a bundled config outside a dependency-heavy tree."""

import pathlib
import subprocess
import sys
import tempfile


def main() -> None:
    binary = str(pathlib.Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="swiftskim-traversal-") as temporary:
        root = pathlib.Path(temporary)
        project = root / "project"
        project.mkdir()
        config = root / "shared.yml"
        config.write_text("excluded:\n  - .build\nonly_rules:\n  - force_cast\n")
        source = project / "App.swift"
        source.write_text("let value = 1\n")
        nested = project / ".build"
        for _ in range(96):
            nested = nested / "nested"
        nested.mkdir(parents=True)
        (nested / "Excluded.swift").write_text("let value = thing as! String\n")
        command = [binary, ".", "--config", str(config)]
        clean = subprocess.run(command, cwd=project, capture_output=True, text=True, timeout=30)
        assert clean.returncode == 0, clean.stdout + clean.stderr
        assert "App.swift" in clean.stderr + clean.stdout
        assert "Excluded.swift" not in clean.stderr + clean.stdout
        source.write_text("let value = thing as! String\n")
        broken = subprocess.run(command, cwd=project, capture_output=True, text=True, timeout=30)
        assert broken.returncode != 0, "Directory lint silently accepted an in-scope violation"
        assert "force_cast" in broken.stderr + broken.stdout
    print("Directory traversal regression passed: full scope, excluded tree pruned, violations fail closed")


if __name__ == "__main__":
    main()
