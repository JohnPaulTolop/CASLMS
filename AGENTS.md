# Project guidance

## Project conventions
- CASLMS is a Flutter app; preserve the Dart SDK constraint in `pubspec.yaml` (currently `^3.13.0`), the installed Flutter compatibility, null safety, and `flutter_lints` rules in `analysis_options.yaml`.
- Follow the existing separation of `lib/screens`, `lib/services`, `lib/models`, and `lib/config`. Reuse `lib/core/app_theme.dart`, `app_colors.dart`, and nearby shared widgets; preserve responsive layouts, typography, spacing, and navigation.
- Preserve Firebase Auth, App Check, Firestore, and Supabase integration boundaries. Never weaken authentication or access controls to make a change work.

## Explore efficiently
- Scale exploration to the task: start with relevant filenames or symbols, then read only needed sections and callers. Scope searches to likely paths; broaden only when evidence requires it.
- Reuse discovered context and avoid rereading unchanged code, repeated searches, whole-directory reads, and large outputs. Inspect docs and dependencies only when relevant; use external documentation when required for accuracy or explicitly requested.
- Skip `.git`, `.dart_tool`, `build`, caches, and `.codex-backups` in routine searches. Inspect generated files explicitly when needed; edit their source or generator rather than generated output where practical.
- Use minimal exploration for simple tasks. For complex work, inspect relevant architecture, break the work into logical steps, and plan only when useful.

## Serena, when available
- Use Serena's symbol navigation for classes, methods, references, and implementations when it improves the task. Activate the actual workspace if needed; read symbol bodies only when necessary.
- Reuse known symbol paths. Prefer symbol edits for whole-symbol changes and precise native patches for small changes within a symbol. Use native tools directly for trivial tasks or when simpler or more reliable.
- Fall back to scoped native searches and reads if Serena is unavailable, fails, or cannot handle the Dart code. Its installed adapter currently uses Dart 3.7.1 while this project targets Dart 3.13; do not treat its diagnostics as authoritative. Validate with the project's SDK.

## Make focused changes
- Make the smallest maintainable change that meets the request. Preserve unrelated behavior and formatting; avoid unrelated refactoring, duplicate utilities, unnecessary files, and new dependencies.
- Inspect relevant callers and dependencies before changing public interfaces. Match nearby Dart patterns and reuse existing widgets and services.
- Prefer targeted patches over full-file rewrites. Never trade correctness, security, maintainability, or required validation for token savings.
- Preserve user changes. Do not alter global Codex settings, model/provider/reasoning/API configuration, or unrelated MCP servers. Add no other agent configuration unless necessary for the task.

## Validate proportionately
- Run `dart format` only on modified Dart files that need formatting. Start with targeted `flutter analyze <path>` and relevant tests; broaden validation for shared architecture or changes affecting multiple features.
- Inspect the relevant test's runner before execution: `test/` includes Dart checks and JavaScript scripts as well as any Flutter tests. Use `flutter test` for Flutter tests and the existing Dart/script runner for other checks; inspect emulator or service requirements before integration checks.
- Do not repeat unchanged checks without a reason. Verify critical behavior and interface changes even when an editing tool reports success. Distinguish actual results from assumptions; never claim unrun checks passed.

## Communicate concisely
- Give brief progress updates for meaningful findings or blockers. Avoid redundant explanations, repeated file lists, large code dumps, and reprinting modified files unless requested.
- For normal coding tasks, finish with **Changes:** what changed; **Validation:** checks passed, failed, or not run; and **Notes:** only material limitations or follow-up actions, omitting Notes when unnecessary.
