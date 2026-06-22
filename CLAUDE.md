# MyStudents — Repo Guide

iOS UIKit app (iOS 18+) for managing students, batches, attendance, and finances at a tuition center. Swift 5, MVVM + Repository, Core Data.

## Build / run

```bash
xcodebuild -project MyStudents.xcodeproj -scheme MyStudents -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

There is no test target yet.

## Project organization (Xcode)

The Xcode project uses `PBXFileSystemSynchronizedRootGroup` — **files in the `MyStudents/` folder are auto-included in the build target**. Do NOT manually edit `project.pbxproj` to add files; just write them to disk in the right folder.

```
MyStudents/
├── Core/                 # DI container, Core Data stack, AppTab, cloud sync config
├── Models/               # @objc NSManagedObject entities + their enums
├── Repositories/         # Protocols + CoreData* implementations (one pair per domain)
├── Services/             # PersistenceService, CloudSyncService
├── ViewModels/           # One file per feature; may contain several VMs (list, detail, etc.)
├── ViewControllers/      # Programmatic UIViewControllers (new code) or .swift+.xib pairs (legacy)
├── Views/                # Reusable subviews (EmptyStateView, *FormView)
├── Utilities/            # AppLogger, StoryboardIdentifiable
├── MyStudents.xcdatamodeld/   # Core Data model
└── Resources/
```

## Architecture

**Strict three-layer MVVM:**

```
ViewController ──owns──► ViewModel ──owns──► Repository ──uses──► PersistenceService ──uses──► CoreDataStack
```

- **`AppDependencyContainer`** (Core/) is the composition root. It holds a single `PersistenceService` (which wraps `CoreDataStack`) and lazy single-instance repositories. View models are produced via `make*ViewModel()` factory methods.
- Repositories are protocols (`*RepositoryProtocol`) with `CoreData*` implementations. Inject the protocol, not the concrete type.
- ViewModels conform to `ScreenViewModel` (just exposes a `title`) when they back a tab root.
- One ViewModel file may contain several VMs that belong to the same feature flow (see `AttendanceViewModel.swift`, `FinanceViewModel.swift`).

## Core Data conventions

- One shared **view context** across all repositories. `automaticallyMergesChangesFromParent = true`, merge policy `NSMergeByPropertyObjectTrumpMergePolicy`.
- Entity classes live in `Models/`, declared with `@objc(EntityName) final class … : NSManagedObject, Identifiable`. Set defaults in `awakeFromInsert`. Provide a `@nonobjc class func fetchRequest()` overload.
- For string-backed enum attributes, store the raw string and expose a typed computed accessor (e.g. `paymentStatus` wraps `status`). Pattern is used across `Payment`, `AttendanceRecord`, etc.
- Money is `NSDecimalNumber` end-to-end. Never use `Double` for currency. Use `NumberFormatter.financeAmount` (defined in `FinanceRepositoryProtocol.swift`) for display.
- Dates that represent a month are stored as `"yyyy-MM"` strings on the entity (see `Payment.month`) so they sort lexicographically and are easy to query with `IN`.
- Repositories expose `managedObjectContext` when view controllers need to observe `.NSManagedObjectContextDidSave` for cross-tab live updates (see `AttendanceRepositoryProtocol`).

## View controller conventions

**New code is programmatic** (no XIBs). Old code may still use `.swift + .xib` pairs — leave those alone unless rewriting.

- Init via `init(viewModel:)`, mark `init?(coder:)` as `fatalError`.
- Tab roots are direct children of a `UINavigationController` configured by `MainTabBarController`. Add a new tab by extending `AppTab` and the switch in `MainTabBarController.makeRootViewController(for:dependencyContainer:)`.
- For lists, use `UITableViewDiffableDataSource<Int, UUID>` with a parallel `[UUID: Row]` dictionary for fast lookups. Pattern shown in `AttendanceListViewController`, `PaymentListViewController`, `BatchListViewController`.
- On `applySnapshot`, **always call `snapshot.reconfigureItems(_:)` for items that already existed** — otherwise edits to the same UUID won't redraw the cell.
- Refresh strategy:
  1. `viewWillAppear` calls the load method (handles tab switches).
  2. For cross-tab live updates, subscribe to `.NSManagedObjectContextDidSave` and coalesce reloads via the main runloop (`AttendanceListViewController.observeContextChanges()` is the reference implementation).
- Empty state: use `Views/EmptyStateView.swift` or inline `UILabel` with `.secondaryLabel` and centerY constraint.
- Errors: `showError(_:)` from `ViewControllers/UIViewController+Alerts.swift` presents a localized alert. Repository errors should conform to `LocalizedError`.
- Keyboard: `hideKeyboardWhenTappedAround()` + `scrollView.enableKeyboardInsetAdjustment()` from `UIViewController+Keyboard.swift` for form screens.

## Adding a new feature (recipe)

1. **Model**: add entity to `MyStudents.xcdatamodeld/.../contents` (and the `<element>` positioning block at the bottom). Create `Models/<Entity>.swift`.
2. **Repository**: add `<Feature>RepositoryProtocol.swift` and `CoreData<Feature>Repository.swift`.
3. **Wire DI**: in `AppDependencyContainer`, add a `lazy var` for the repo and a `make<Feature>ViewModel()` factory.
4. **ViewModel**: one file under `ViewModels/`, multiple structs/classes inside if the feature has several screens.
5. **ViewController(s)**: under `ViewControllers/`, programmatic.
6. **Tab integration** (if a top-level tab): extend `AppTab` (title, system images) and `MainTabBarController.makeRootViewController(for:dependencyContainer:)`.
7. **Build** — the project's synchronized group picks up the new files automatically.

## Known quirks

- SourceKit / LSP frequently reports `Cannot find type 'X' in scope` and `No such module 'UIKit'` errors **across files in the same target**. These are stale-index diagnostics, NOT real errors — the actual `xcodebuild` is the source of truth. Don't chase them.
- `swift-actor-isolated-initializer` warnings on existing code (e.g. `AttendanceViewModel.swift:61`) are pre-existing; safe to ignore unless touching that line.
- All UI code defaults to `MainActor` isolation per `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in build settings.
- The Cloud sync path exists (`CloudSyncConfiguration`, `CloudKitSyncService`) but is wired to `.disabled` by default.

## Testing in the simulator

There's no test target. After UI changes, build for the simulator and verify by hand. For finance/attendance work, you usually need to create a batch and at least one student before bills/attendance can be generated.

## Commit conventions

See recent commits — short imperative subject ("Add attendance module", "Add batch management module"). Numbered PRs in parentheses.
