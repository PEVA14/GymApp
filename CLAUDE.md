# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

GymStats is a native iOS gym tracker (Swift, SwiftUI, SwiftData) built by a CS
student who is experienced in C++/TypeScript but **new to Swift and SwiftUI**.
It is simultaneously a personal app, a learning exercise, and a CV/portfolio
project.

Because of that, how you work here matters as much as what you produce:

- Build in small, reviewable steps that each end in something that compiles and runs.
- Explain Swift/SwiftUI-specific concepts when they first appear (property
  wrappers, `@State` vs `@Bindable`, value vs reference semantics, SwiftData
  delete rules). Do not explain general programming concepts.
- Do not introduce abstractions, protocols, or design patterns without a
  concrete reason that you state. Readable beats clever.
- Where several architectures are reasonable, present the tradeoffs and ask
  rather than deciding silently.
- Do not build ahead of the current step, even if you can see where it's going.

## Commands

Build:

```bash
xcodebuild -project GymStats.xcodeproj -scheme GymStats -destination 'generic/platform=iOS Simulator' build
```

Run the unit tests (the UI test target is still the unused Xcode template;
exclude it):

```bash
xcodebuild test -project GymStats.xcodeproj -scheme GymStats -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GymStatsTests
```

Run a single test:

```bash
xcodebuild test -project GymStats.xcodeproj -scheme GymStats -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GymStatsTests/ModelSchemaTests/containerBuildsAndPersists
```

Test runs take 60–90s (simulator boot). Run them in the background.

`xcodebuild`'s console reporter is unreliable for Swift Testing — it prints
failures with no message and `0.000 seconds`. For real failure detail, read the
result bundle instead:

```bash
xcrun xcresulttool get test-results summary --path <path-from-build-output>.xcresult
```

The project uses **Xcode synchronised folder groups** (`objectVersion = 77`), so
new files and folders on disk are picked up automatically. Never hand-edit
`project.pbxproj` to add a file.

## Architecture

Plain SwiftUI + SwiftData. **There is deliberately no MVVM layer.** `@Query` is
a View property wrapper; wrapping models in ViewModel classes means abandoning it
and hand-rolling `FetchDescriptor` plus change notification. Views read with
`@Query` and write via `@Environment(\.modelContext)`.

```
GymStats/
  App/        GymStatsApp.swift (owns the ModelContainer), RootView.swift (TabView)
  Models/     @Model classes — MUST NOT import SwiftUI
  Core/       Pure helpers: units, formatters, training math, preview sample data
  Features/   SwiftUI views, grouped by feature (Exercises, Templates, Workout,
              History, Measurements, Settings) — not by type
```

`Models/` must never `import SwiftUI`. That rule is what makes it a checkbox
change to share the models with a Widget, Live Activity, or watchOS target later.

The one place stateful controller objects are justified is the active workout
(elapsed timer, current exercise/set, rest countdown) — one `@Observable` class,
introduced when that feature is built, not before.

## Data model invariants

These encode requirements that are expensive to retrofit. Do not casually change them.

**Sessions snapshot templates; they never reference them.** `WorkoutSession` has
no relationship to `WorkoutTemplate` — only a dead `templateID: UUID?`. Starting
a workout deep-copies the template. This is what makes "editing a routine never
alters history" true by construction. Covered by
`ModelSchemaTests.deletingTemplateLeavesHistoryIntact`.

**But `SessionExercise` does hold a live link to `Exercise`.** Asymmetric on
purpose: a template is a plan that changes, an exercise is an identity that
persists, so renaming a movement should propagate through all history. The
`exerciseName` field is a snapshot fallback for if the exercise is ever deleted.

**Exercises are archived (`isArchived`), never hard-deleted.** Deleting orphans
history.

**Units are canonical in storage, converted only at the edges.** Weights are
always kilograms (`weightKg`), lengths always centimetres. Display unit is a
presentation concern. `Core/Units.swift` is the only place conversion lives.
Storing user-entered units plus a flag would corrupt every query, chart, and
future HealthKit export.

**`BodyMeasurement` is narrow: one row per `(date, type, value)`,** not one row
per date with a column per body part. Adding a measurement type is a new
`MeasurementType` case with zero schema change, and it matches how HealthKit
models samples.

**Enums are stored as raw `String`s** (`muscleGroupRaw`, `typeRaw`) with typed
computed accessors, so a value written by a newer app version degrades to a
default instead of failing to decode.

**Derived values are computed, never persisted** — volume, estimated 1RM, PR
flags. Put that logic in `Core/` as free functions so tests, widgets, and a watch
app can all call it.

## Constraints for planned features

CloudKit sync is not enabled yet, but the schema already obeys CloudKit's rules
because retrofitting them onto a database holding real training history means a
migration. Keep obeying them:

1. Every property has a default value or is optional.
2. Every relationship is optional (hence `var sets: [SetEntry]?`).
3. No `@Attribute(.unique)` — CloudKit has no unique constraints. Enforce
   uniqueness in the UI.
4. Every relationship pair declares `inverse:` on exactly one side (the to-many side).
5. No `.deny` delete rules.

For Live Activities / widgets / watch: the in-progress workout **must** be
written to SwiftData at start (`endedAt == nil` means in progress), not
accumulated in view `@State` and saved at finish. Otherwise the feature has to be
rewritten to add them. Every model also carries an explicit `UUID` because
`PersistentIdentifier` is not stable across processes and can't go in a Live
Activity payload or widget deep link.

## SwiftData gotchas hit in this project

**A `ModelContext` does not retain its `ModelContainer`.** Writing
`try ModelContainer(...).mainContext` as a one-liner lets the container
deallocate immediately and the context traps (`SIGTRAP`) on first use. Hold the
container in a stored property. This cost a long debugging session; it presents
as *every* test in the target failing, including empty ones, because one crash
takes down the whole test process.

**Relationship arrays have no guaranteed order.** Every ordered collection uses
an explicit `sortOrder: Int` and is read through an `orderedX` computed property.
Never rely on the stored array's order.

`ModelSchemaTests` is `@Suite(.serialized)` so a crash stays attributable to one test.

## Status

The original milestone is complete. The app has three tabs:

- **Train** — routine list, routine editor, exercise library, active workout
- **History** — sessions by month, read-only detail
- **Body** — latest value per measurement type, per-type history with a trend chart

Working end to end: exercise CRUD with archiving, template building with
reordering and target sets, starting a workout from a routine, logging sets,
finishing (which prunes incomplete sets), workout history, previous-performance
display during a workout, personal-record detection, body measurements,
measurement charts, per-exercise progression charts (top set / est. 1RM /
volume), and a kg↔lb + cm↔in display preference.

Deferred by decision, not oversight: App Group container (needs a paid developer
account; postponed, will require a store migration), Swift 6 language mode
(currently Swift 5 to avoid strict-concurrency noise while learning), rest timer,
Live Activities, HealthKit, widgets, CloudKit, watchOS.

## Conventions worth matching

- **Sheets are transactional, pushed screens save as you go.** A modal with
  Cancel/Save copies into `@State` and writes on save (`ExerciseEditorView`,
  `LogMeasurementView`). A pushed detail screen uses `@Bindable` and writes
  through immediately (`TemplateEditorView`). Don't mix the two.
- **Filtering and grouping happen in memory**, not in `@Query` predicates, except
  where the predicate is static (history's `endedAt != nil`). A dynamic predicate
  needs a custom initialiser and buys nothing at personal-library scale.
- **Numeric text fields use `Binding<String>`**, not `format: .number`, so an
  unset value shows a placeholder rather than a literal `0`, and a comma is
  accepted as a decimal separator.
- **Charts are not zero-based** for body measurements or weight metrics — see
  `MeasurementChart`. Training *volume* is the exception and does start at zero,
  because it is a quantity of work.
- **Charts convert to display units before computing their axis domain**, so the
  scale and its labels can never disagree.
- **`UnitSettings` is the only place display conversion happens.** Views read
  `@AppStorage(SettingsKey.weightUnit)` and build a `UnitSettings`; the store
  stays kilograms and centimetres regardless.
- **A `NavigationStack` with a `path` binding must use value-based links
  throughout.** Mixing in a closure-based `NavigationLink` silently breaks any
  value-based push made from inside it — see `TrainRoute`.
- Personal records are measured by estimated 1RM (Epley), which captures both
  more weight and more reps. Epley overestimates past ~12 reps; this is known and
  deliberately not clamped.
