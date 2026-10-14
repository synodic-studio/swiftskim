# AGENTS.md

Canonical guidance for working in **swiftskim** (repo: `synodic-studio/swiftskim`;
local dir `~/Developer/swiftskim`, renamed from `swift-quality-tools`). `CLAUDE.md`
imports this file. Nothing functional hardcodes the checkout path — config/engine
resolution is binary-relative — so the local dir name is not load-bearing.

## What this is

A Swift AST-lint engine whose primary ruleset enforces SwiftUI structure. Three
config-discovering CLI wrappers (`swiftformat-smart`, `swiftlint-smart`,
`swiftskim`) plus a SwiftSyntax rule engine enforcing 16 custom rules
text-pattern linters cannot express (~two-thirds SwiftUI, one-third general Swift).

Delivered as thin, skippable surfaces over one engine: CLI, Xcode build phase, a
Claude Code / Codex plugin (shared skill + post-edit hook), a Cursor `afterFileEdit`
hook, a pi extension, and an importable `SwiftSkim` SwiftPM library.

**Why things are the way they are** — the load-bearing decisions and their rationale
(opinionated-orchestrator identity, Swift 6.1 floor, tagged releases, library-not-plugins
extensibility, the dedicated `.swiftskim.yml`, etc.) live in [`docs/decisions.md`](docs/decisions.md).
Read it before questioning a design choice.

**Codex and Cursor support is best-effort.** Both hooks are built to each agent's
documented payload shape and checked with synthetic events (`verify-agent-hooks.sh`),
but neither has been fired in a live Codex or Cursor session. `format-swift.py` fails
open — an unrecognized payload is a silent no-op, never a false error. Claude Code and
pi are the verified surfaces; treat Codex/Cursor as offered-not-guaranteed until someone
smoke-tests them live. No MCP server is involved — the plugin hooks cover all three
agents directly, and that's intentional.

## Build in release mode — always

```bash
swift build -c release   # one package, all four binaries
```

The rule engine is no longer a separate nested SwiftPM package — it's a target in the
root package, so a single build emits all four binaries (`swiftformat-smart`,
`swiftlint-smart`, `swiftskim`, `swiftskim-engine`) into `.build/release/` and
SwiftSyntax compiles once.

Other projects' Xcode build phases reference `.build/release/` binaries. A debug-only
build leaves those stale, so Xcode shows outdated or missing warnings. After any change:
build **release**, test with `swiftskim`, then commit. Never hand back control having
built only debug.

## Rule identity is single-sourced

Every custom rule is defined once in `RuleRegistry.all` (in the rule engine). That is
the source of truth. Do **not** re-copy the rule list into docs — point at it:

```bash
swiftskim --list-rules   # authoritative list + one-line summaries
```

Adding a rule: append to `RuleRegistry.all` (id + summary), dispatch it in
`CustomRulesVisitor` using the **same** id, rebuild. The conformance test asserts the
documented lists match the registry, so an id can never silently diverge from what the
engine emits, filters, and suppresses. (This closed a real bug where the onChange rule
dispatched under `prefer_zero_param_onchange` but emitted `onchange_ignored_old_value`.)

## Configuration (`.swiftskim.yml`)

swiftskim owns its own config file, discovered by walking up from the working directory
— its rules roll up separately from SwiftLint/SwiftFormat. It governs rule selection and
the two thresholds; it does not configure file selection (exclusions stay shared from
`.swiftlint.yml`'s `excluded:`).

File selection is a `LintScope`, built from `.swiftlint.yml` and applied to explicitly
named paths as well as discovered ones — `swiftlint-smart` honors `included:` and
`excluded:`, `swiftskim` honors `excluded:` only. That parity is the point: SwiftLint
itself scopes only what it discovers, so a bare `swiftlint <path>` blocks on files a
repo-wide run never checks, which is every edit the post-edit hook sees. A path outside
the config's own directory stays in scope rather than being silently skipped.

`swiftlint-smart` enumerates directory inputs iteratively, pruning excluded trees
before traversal and applying inclusions to source files. It invokes strict SwiftLint
with bounded explicit-file batches, avoiding SwiftLint's recursive parallel walker
and its stack overflow on large dependency trees. Symlink cycles are deduplicated;
traversal errors, empty scopes, and any failed batch fail the invocation rather than
reporting partial coverage as success.

```yaml
# .swiftskim.yml
disabled_rules:                     # never run these (unknown ids → hard error, exit 2)
  - preview_required
# only_rules:                       # if set, ONLY these run (wins over disabled_rules)
#   - skimmable_body
skimmable_body_max_lines: 20        # default 15
excessive_nesting_max_depth: 4      # default 3
```

Precedence: CLI `--only-rules` fully overrides config selection; in-config `only_rules`
beats `disabled_rules`. Parsing/discovery lives in `SwiftSkimConfig.swift`; the engine
validates every id against `RuleRegistry` (`--disable-rules`/`--only-rules`). Legacy
fallback: a `swiftskim:` block in `.swiftlint.yml` still supplies thresholds when no
`.swiftskim.yml` exists. Template: `Configs/example-swiftskim.yml`.

## Warning-handling philosophy

**Every warning must be addressed — fixed properly OR exempted with a justified
suppression directive.** Not acceptable: ignoring warnings ("they were there before"),
dismissing them as unimportant, committing with unaddressed warnings, or degrading code
to silence a warning.

Before "fixing" a warning, ask: does this change improve the code or make it worse? If
you cannot improve it and the code is correct as-is, add a suppression **with a reason**.
If the code has a real problem, fix it properly.

### Suppression format

Custom rules use the `swiftskim:` prefix — deliberately distinct from SwiftLint's
`swiftlint:` so SwiftLint's `superfluous_disable_command` check still works. The old
`swiftlintcustom:` prefix is still accepted as a legacy alias (see `DirectiveParser`),
so existing directives keep working, but `swiftskim:` is the primary form.

```swift
// Reason: <why this is intentional/correct>
// swiftskim:disable:next <rule_id>
<code line>

// swiftskim:disable <rule_id>
// ... block ...
// swiftskim:enable <rule_id>
```

`:this` and `:previous` target the current and preceding line. If a `swiftlint:` or
`swiftformat:` directive sits immediately adjacent, they interfere (each `:next` binds
the very next line) — use `:this`/`:previous` to disambiguate.

## Architecture

- **Main tools:** `swiftformat-smart`, `swiftlint-smart`, `swiftskim`
  (`Sources/Swift*Smart/`), over a shared `Sources/SharedUtilities/`.
- **Rule engine:** targets (`CustomRules` library, `swiftskim-engine` executable) in the
  root package, sourced from
  `CustomRules/swiftlint-swiftsyntax-integration/rule-engine/Sources/`. Rules live
  one-area-per-file in `Sources/CustomRules/*.swift`; `RuleRegistry.swift` is canonical.
  (The engine was formerly its own nested package; it was collapsed into the root so
  SwiftSyntax compiles once. The deep source path is a leftover from that layout.)
- **Extension model:** the CLI takes no runtime rule plugins (no dynamic loading). Adding a
  *new* rule off the shelf = compose your own linter against the `SwiftSkim` library:
  conform to `Rule`, call `SwiftSkim.lint(source:externalRules:only:disabled:)`. External
  rules run in the same walk as built-ins and share suppression/filtering/output. Runnable
  example: `examples/custom-rule/` (built-ins + a custom `no_print_statements` rule). The
  library API's `only:`/`disabled:` mirror the CLI flags. Adding a *built-in* still means
  `RuleRegistry` + `CustomRulesVisitor` + rebuild.
- **Config discovery:** walk up for a project config, fall back to bundled `Configs/`.
- **Self-healing errors:** fixed `Problem/Context/Fix` shape an automated caller can parse.

## Testing

```bash
./Scripts/run-tests.sh          # full suite (unit + integration)
swift test --no-parallel        # unit only (Swift Testing)
```

`--no-parallel` is required, not cosmetic: `ConfigDiscoveryTests` drives discovery by changing the process-wide current directory, which every suite in the target shares, so concurrent suites see each other's cwd (and spawn from one that is being deleted).

Fixtures (deliberately-broken sample inputs) live in `Fixtures/` and are excluded from linting. The tool passes its own rule set on its own source: `swiftskim .` must exit clean before committing.

## Demo

`Scripts/demo.sh` is a four-beat live walkthrough for a screen share: the rule registry, a violation found in ordinary SwiftUI, grep-vs-AST on one file, and the post-edit hook returning exit 2 then exit 0 on the same event. Every number it prints is grepped back out of the run the audience just watched — nothing is hardcoded. It writes its Swift files to `$TMPDIR/swiftskim-demo` and never inside this repo.

```bash
./Scripts/demo.sh            # live, one beat per keypress (refuses without a tty)
./Scripts/demo.sh --auto     # rehearsal / smoke test
./Scripts/demo.sh --local    # use .build/release instead of the Homebrew install
./Scripts/demo.sh --cleanup  # remove the workspace so the next run is a first run
```

## Release gate — verify every delivery surface

`Scripts/verify-all.sh` is the pre-release gate: it verifies the engine **and** every
public surface, so a release can't ship a surface that silently broke. Each surface has
its own re-runnable script; the orchestrator runs them all and prints a pass/fail summary.

```bash
./Scripts/verify-all.sh              # local stage — no network
./Scripts/verify-all.sh --release    # local + release stage (needs pushed release tag)
```

- **local stage** (no network): build, unit+integration tests, self-lint, agent
  post-edit hooks (`verify-agent-hooks.sh` — the Claude Code / Codex / Cursor hook,
  checked against each agent's documented payload shape), pi extension
  (`verify-pi-extension.sh`), SPM library consumer against the working tree
  (`verify-consumer-spm.sh`).
- **release stage** (consumes the shipped release tag, so tag and push first): Homebrew
  install (`verify-brew-install.sh`), SPM consumer against the remote URL
  (`verify-consumer-spm.sh --remote`), Linux clean-room in an OrbStack/Docker Swift
  container (`verify-consumer-linux.sh`), and the Tuist demo (`verify-tuist-demo.sh`,
  project in `examples/tuist-demo/`).

For an authorized development-tool update without a tagged release, run the local
gate, push `develop`, then use `Scripts/verify-brew-install.sh --head` to install and
verify that development revision.

The two consumer surfaces share one scaffold (`Scripts/helpers/emit-spm-consumer.sh`) so the
consumer code can't drift between the macOS and Linux checks. Each surface script also
runs standalone for debugging a single surface.

## Build troubleshooting

If engine changes don't take effect: `swift package clean && swift build -c release`, or
remove `.build` and `.swiftpm`, then run `swift build -c release`. First clean build is
slow (SwiftSyntax); incrementals are fast. The `swiftskim-engine` target excludes its
`CustomRules` subdirectory because those sources belong to the separate library target;
do not accept SwiftPM "unhandled files" warnings from that overlap.
