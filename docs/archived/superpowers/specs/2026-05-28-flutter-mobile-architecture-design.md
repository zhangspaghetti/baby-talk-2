# BabyTalk Flutter Mobile — Architecture Design

Date: 2026-05-28
Status: Proposed
Scope: Full Flutter mobile app architecture for implementation phase

---

## 0. Executive Summary

BabyTalk is a Flutter mobile app helping Chinese parents of 0-3 year olds speak short English phrases during everyday care routines. The architecture follows **feature-first clean architecture** with Riverpod state management, go_router navigation, Isar local storage, and Dio networking. The app shell uses a 4-tab bottom navigation (Home / Discover / Garden / Me) with an end drawer for household context.

**Key architectural decisions:**
- Feature-first module structure with data/domain/presentation layers per feature
- Riverpod `ChangeNotifier` + `FutureProvider` pattern (not codegen — matches existing codebase)
- Isar for offline-first local persistence (practice events, onboarding snapshots, mentor data)
- Dio with cookie-based auth interceptor for API communication
- go_router declarative routing with shell route for tab navigation
- Warm Paper Kindness design system via `BabyTalkColors` ThemeExtension

---

## 1. Module Structure

### 1.1 Directory Tree

```
mobile/lib/
├── main.dart                          # Entry point, ProviderScope
├── l10n/                              # Localization (intl)
├── generated/                         # Build_runner output (freezed, json, isar)
│
├── app/                               # App-level orchestration
│   ├── app.dart                       # MaterialApp.router, boot orchestrator
│   ├── app_reentry_orchestrator.dart  # Deep link / invite re-entry
│   ├── auth_state.dart               # Global auth state (login/logout triggers)
│   ├── feature_gates.dart            # Feature flag system
│   ├── invite_reentry_coordinator.dart
│   ├── share_reentry_coordinator.dart
│   ├── local_sensitive_data_clearance_registry.dart
│   ├── providers/
│   │   └── repository_providers.dart  # ALL Riverpod providers (app-wide)
│   ├── router/
│   │   ├── app_go_router.dart         # GoRouter configuration
│   │   ├── app_router.dart            # Legacy router (to be removed)
│   │   └── app_route_contract.dart    # Route name constants
│   ├── theme/
│   │   ├── app_theme.dart             # ThemeData + BabyTalkColors extension
│   │   └── app_layout_constants.dart  # Spacing, radius, touch targets
│   └── widgets/                       # Cross-feature shared widgets
│       ├── app_banner.dart
│       ├── app_celebration_overlay.dart
│       ├── app_empty_state.dart
│       ├── app_haptics.dart
│       ├── app_shimmer.dart
│       ├── app_step_progress.dart
│       └── app_surface_card.dart
│
├── core/                              # Infrastructure (no business logic)
│   ├── device/
│   │   └── installation_id_service.dart
│   ├── local_data_lifecycle/
│   │   ├── local_sensitive_data_clearance.dart
│   │   └── local_sensitive_data_backup_protection.dart
│   └── network/
│       ├── app_dio.dart               # Dio factory with cookie jar
│       ├── auth_headers.dart          # Auth header injection
│       └── auth_interceptor.dart      # 401 refresh / redirect
│
└── features/                          # Feature modules (clean architecture)
    ├── account/                       # Auth + account management
    ├── auth/                          # Auth screen (thin wrapper)
    ├── discover/                      # NEW — scene phrase browsing
    ├── garden/                        # NEW — single plant growth
    ├── growth/                        # NEW — multi-dimensional stats
    ├── household/                     # Household sharing + roles
    ├── mentor/                        # Xiaohe AI mentor panel
    ├── onboarding/                    # Scene-first onboarding flow
    ├── practice/                      # Phrase practice + home screen
    ├── settings/                      # NEW — reminders, profile, prefs
    ├── share/                         # Share card generation
    ├── shell/                         # 4-tab navigation shell
    └── sync/                          # Data sync orchestration
```

### 1.2 Feature Module Internal Structure

Each feature follows the same three-layer pattern:

```
features/<name>/
├── data/
│   ├── local/                         # Isar entities, local stores
│   │   ├── <entity>_entity.dart       # Isar collection schema
│   │   └── <name>_local_data_source.dart
│   ├── repositories/
│   │   ├── <name>_repository.dart     # Concrete implementation
│   │   └── <name>_repository_contract.dart  # Abstract interface (optional)
│   └── services/
│       ├── <name>_api_service.dart     # Dio HTTP calls
│       └── <name>_external_*.dart      # Platform bridges (share, TTS, etc.)
├── domain/
│   ├── models/                        # Freezed value objects
│   │   ├── <name>_snapshot.dart        # Immutable state snapshot
│   │   └── <name>_<concept>.dart
│   └── services/                      # Domain logic (pure, no Flutter deps)
│       └── local_<name>_service.dart
└── presentation/
    ├── <name>_notifier.dart           # ChangeNotifier (Riverpod)
    ├── <name>_view_model.dart         # Derived UI state
    ├── screens/
    │   └── <name>_screen.dart         # Top-level page widget
    └── widgets/                       # Feature-local widgets
        └── <name>_<component>.dart
```

**Freezed 约定：** Freezed 用于不可变数据模型（snapshot、entity）。普通 Dart 类用于简单 DTO 和配置。判断标准：需要 `copyWith`/`==`/`hashCode` 的用 Freezed，否则用普通类。

### 1.3 Feature Responsibility Matrix

| Feature | Responsibility | Key Models | Key Notifiers |
|---------|---------------|------------|---------------|
| **account** | Login/logout, session mgmt, consent | `AccountSession`, `AccountConsentState` | `AccountNotifier` |
| **auth** | Auth screen UI (thin wrapper over account) | — | — |
| **onboarding** | Scene-first intro, baby profile setup | `OnboardingSnapshot`, `StageMatch` | `OnboardingNotifier` |
| **practice** | Phrase cards, audio, reactions, home screen | `PracticePhrase`, `InteractionEventPayload`, `PracticeContinuitySnapshot` | `PracticeSessionNotifier`, `PracticeContinuityNotifier` |
| **discover** | Scene phrase browsing, search, filtering | `DiscoverScene`, `DiscoverPhrase` | `DiscoverNotifier` |
| **garden** | Single plant growth, fertilizer cycle | `GardenSnapshot`, `GardenStage` | `GardenNotifier` |
| **growth** | Multi-dimensional stats (week/month/year/total/journey) | `GrowthSnapshot`, `GrowthDimension` | `GrowthNotifier` |
| **mentor** | Xiaohe AI mentor panel, suggestions | `MentorFactEvent`, `LocalMentorSuggestion` | `MentorNotifier` |
| **household** | Household sharing, roles, invite links | `HouseholdSharedContext`, `HouseholdRole` | `HouseholdNotifier` |
| **settings** | Reminders, baby profile, playback prefs | `SettingsSnapshot` | `SettingsNotifier` |
| **share** | Share card generation, platform launch | `ShareCardPayload` | `ShareNotifier` |
| **shell** | 4-tab navigation, end drawer | — | — |
| **sync** | Offline→online data reconciliation | `SyncQueueEntry` | `SyncNotifier` |

---

## 2. State Management — Riverpod Patterns

### 2.1 Provider Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                    ProviderScope (root)                  │
├─────────────────────────────────────────────────────────┤
│  App-level providers (always alive)                     │
│  ├── appDirectoryProvider          FutureProvider<Dir>   │
│  ├── accountApiServiceProvider     Provider              │
│  ├── authenticatedApiClientProvider Provider             │
│  ├── accountRepositoryProvider     FutureProvider        │
│  ├── accountNotifierProvider       ChangeNotifierProvider│
│  ├── assetPhraseServiceProvider    Provider              │
│  └── practiceRepositoryProvider    FutureProvider        │
├─────────────────────────────────────────────────────────┤
│  Feature-level providers (autoDispose where possible)   │
│  ├── onboardingNotifierProvider    autoDispose           │
│  ├── practiceContinuityNotifierProvider autoDispose      │
│  ├── gardenGrowthNotifierProvider  autoDispose           │
│  ├── mentorNotifierProvider        autoDispose           │
│  ├── householdNotifierProvider     autoDispose           │
│  ├── discoverNotifierProvider      autoDispose           │
│  ├── growthNotifierProvider        autoDispose           │
│  ├── settingsNotifierProvider      autoDispose           │
│  └── shareNotifierProvider         autoDispose           │
├─────────────────────────────────────────────────────────┤
│  Route-scoped providers (family, autoDispose)           │
│  └── practiceSessionNotifierProvider.family             │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Provider Patterns

**Pattern 1: Repository FutureProvider (async init)**

Used for repositories that need Isar or directory resolution before use.

```dart
// repository_providers.dart
final practiceRepositoryProvider = FutureProvider<PracticeRepository>((ref) async {
  final assetPhraseService = ref.watch(assetPhraseServiceProvider);
  final directory = await ref.watch(appDirectoryProvider.future);
  final apiService = ref.watch(dynamicPracticeApiServiceProvider);

  final localDataSource = await PracticeLocalDataSource.open(
    directory: directory.path,
  );
  return PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    dynamicPracticeApiService: apiService,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
    ),
  );
});
```

**Pattern 2: ChangeNotifier Provider (stateful UI logic)**

Used for notifiers that manage complex UI state with notifyListeners().

```dart
final accountNotifierProvider = ChangeNotifierProvider<AccountNotifier>((ref) {
  final repository = ref.watch(accountRepositoryProvider).requireValue;
  return AccountNotifier(repository: repository)..initialize();
});
```

**Pattern 3: autoDispose ChangeNotifier (tab-scoped)**

Used for feature state that should release when the tab is not visible.

```dart
final gardenNotifierProvider =
    ChangeNotifierProvider.autoDispose<GardenNotifier>((ref) {
  final repository = ref.watch(gardenRepositoryProvider);
  return GardenNotifier(repository: repository)..initialize();
});
```

**Pattern 4: Family Provider (route-scoped)**

Used for per-route state that depends on route arguments.

```dart
final practiceSessionNotifierProvider =
    ChangeNotifierProvider.autoDispose
        .family<PracticeSessionNotifier, PracticeSessionProviderArgs>((ref, args) {
  final repository = ref.watch(practiceRepositoryProvider).requireValue;
  return PracticeSessionNotifier(
    repository: repository,
    spaceId: args.routeArgs.spaceId,
    activityId: args.routeArgs.activityId,
  )..initialize();
});
```

### 2.3 State Flow Pattern

```
┌──────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────┐
│   API    │───>│  Repository  │───>│   Notifier   │───>│  Widget  │
│ (Dio)    │    │ (data layer) │    │ (ChangeNotify│    │ (Consumer│
│          │<───│              │<───│   + Snapshot) │<───│  watch)  │
└──────────┘    └──────────────┘    └──────────────┘    └──────────┘
     │                │                    │
     │           ┌────┴────┐          ┌────┴────┐
     │           │  Isar   │          │ViewModel│
     │           │ (local) │          │(derived)│
     │           └─────────┘          └─────────┘
     │
  ┌──┴──┐
  │Sync │  (offline queue → flush on reconnect)
  │Queue│
  └─────┘
```

**Notifier contract:**
1. `initialize()` — called once in provider creation (`..initialize()`)
2. `snapshot` — immutable domain object exposing current state
3. `viewModel` — derived UI-friendly projection (optional, for complex cases)
4. `notifyListeners()` — triggers widget rebuild via `ref.watch()`

---

## 3. Data Layer

### 3.1 Repository Pattern

```
┌─────────────────────────────────────────────────────────┐
│                    Repository                            │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ LocalStore   │  │ ApiService  │  │ AssetService│    │
│  │ (Isar)       │  │ (Dio)       │  │ (Bundle)    │    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
│         │                │                │            │
│         └────────────────┼────────────────┘            │
│                          │                             │
│                   ┌──────┴──────┐                      │
│                   │  Merge Logic│                      │
│                   │  (offline   │                      │
│                   │   first)    │                      │
│                   └─────────────┘                      │
└─────────────────────────────────────────────────────────┘
```

**Repository responsibilities:**
- Merge local + remote data (local-first reads, background sync writes)
- Expose domain models (not entities or DTOs)
- Handle connectivity-aware fetch (check network before API calls)
- Queue offline mutations for later sync

### 3.2 Isar Schema Design

**Existing collections:**

| Collection | Feature | Purpose |
|------------|---------|---------|
| `InteractionEventEntity` | practice | Practice events (phrase spoken, reaction) |
| `MentorFactEventEntity` | mentor | Mentor interaction history |

**New collections needed:**

| Collection | Feature | Purpose |
|------------|---------|---------|
| `GardenEntity` | garden | Plant state, fertilizer inventory, growth stage |
| `GrowthStatEntity` | growth | Aggregated stats per dimension |
| `DiscoverCacheEntity` | discover | Cached scene/phrase catalog |
| `SettingsEntity` | settings | User preferences (reminders, playback) |
| `SyncQueueEntity` | sync | Pending mutations for offline→online flush |

**Example Isar entity:**

```dart
@collection
class GardenEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String plantId;

  late String currentStage;    // seed | sprout | budding | bloom | fruit
  late int fertilizerCount;    // pending fertilizer packages
  late int appliedCount;       // total fertilizer applied
  late int stageThreshold;     // fertilizer needed for next stage
  late DateTime lastUpdatedAt;
  late String? stageAnimationAsset;
}
```

### 3.3 API Contract Structure

All API services follow the same pattern:

```dart
class DiscoverApiService {
  DiscoverApiService({required AuthenticatedApiClient client})
    : _client = client;

  final AuthenticatedApiClient _client;
  Dio get _dio => _client.dio;

  /// GET /api/v1/scenes
  Future<List<SceneDto>> fetchScenes() async {
    final response = await _dio.get('/api/v1/scenes');
    // parse + return
  }

  /// GET /api/v1/scenes/:id/phrases
  Future<List<PhraseDto>> fetchPhrases(String sceneId) async {
    final response = await _dio.get('/api/v1/scenes/$sceneId/phrases');
    // parse + return
  }
}
```

**API service provider pattern:**

```dart
final discoverApiServiceProvider = Provider<DiscoverApiService>((ref) {
  final service = DiscoverApiService(
    client: ref.watch(authenticatedApiClientProvider),
  );
  ref.onDispose(service.close);
  return service;
});
```

### 3.4 Network Layer Stack

```
┌─────────────────────────────────┐
│        Feature ApiService       │  (e.g. DiscoverApiService)
├─────────────────────────────────┤
│     AuthenticatedApiClient      │  (attaches auth headers)
├─────────────────────────────────┤
│          AuthInterceptor        │  (401 → refresh → retry)
├─────────────────────────────────┤
│       CookieManager             │  (session persistence)
├─────────────────────────────────┤
│            Dio                  │  (HTTP client)
├─────────────────────────────────┤
│     BaseOptions                 │  (timeout, content-type)
└─────────────────────────────────┘
```

---

## 4. Routing — go_router Configuration

### 4.1 Route Tree

```
GoRouter
│
├── / (ShellRoute → AppShellScreen)
│   ├── NavigationBar tab 0: HomeScreen (practice feature)
│   ├── NavigationBar tab 1: DiscoverScreen (discover feature)
│   ├── NavigationBar tab 2: GardenScreen (garden feature)
│   └── NavigationBar tab 3: MeScreen (me feature)
│       ├── → GrowthDetailScreen (/me/growth)
│       └── → SettingsScreen (/me/settings)
│
├── /onboarding → OnboardingScreen
│
├── /practice → PracticeSessionScreen
│   └── (extra: PracticeRouteEntry)
│
├── /account → AuthScreen
│
└── /auth → AuthScreen (alias)
```

### 4.2 go_router Implementation

```dart
// app_go_router.dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRouteNames.shell,
    routes: [
      // Shell route with nested tab navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home
          StatefulShellBranch(navigatorKey: _homeNavigatorKey, routes: [
            GoRoute(
              path: AppRouteNames.shell,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          // Tab 1: Discover
          StatefulShellBranch(navigatorKey: _discoverNavigatorKey, routes: [
            GoRoute(
              path: AppRouteNames.discover,
              builder: (context, state) => const DiscoverScreen(),
            ),
          ]),
          // Tab 2: Garden
          StatefulShellBranch(navigatorKey: _gardenNavigatorKey, routes: [
            GoRoute(
              path: AppRouteNames.garden,
              builder: (context, state) => const GardenScreen(),
            ),
          ]),
          // Tab 3: Me
          StatefulShellBranch(navigatorKey: _meNavigatorKey, routes: [
            GoRoute(
              path: AppRouteNames.me,
              builder: (context, state) => const MeScreen(),
              routes: [
                GoRoute(
                  path: 'growth',
                  builder: (context, state) => const GrowthDetailScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),
      // Full-screen routes (outside shell)
      GoRoute(
        path: AppRouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRouteNames.practice,
        builder: (context, state) {
          final entry = PracticeRouteEntry.fromObject(state.extra);
          return PracticeSessionScreen(routeEntry: entry);
        },
      ),
      GoRoute(
        path: AppRouteNames.account,
        builder: (context, state) => const AuthScreen(),
      ),
    ],
    redirect: (context, state) {
      // Boot state drives redirect (onboarding vs shell)
      return null;
    },
  );
});
```

### 4.3 Route Name Constants

```dart
class AppRouteNames {
  const AppRouteNames._();

  static const shell = '/';
  static const home = shell;
  static const discover = '/discover';
  static const garden = '/garden';
  static const me = '/me';
  static const growthDetail = '/me/growth';
  static const settings = '/me/settings';
  static const onboarding = '/onboarding';
  static const practice = '/practice';
  static const account = '/account';
}
```

### 4.4 Navigation Diagram

```
                    ┌─────────────┐
                    │  App Start  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Boot      │
                    │   State     │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐    │     ┌──────▼──────┐
       │ Onboarding  │    │     │   Account   │
       │  Screen     │    │     │   Screen    │
       └──────┬──────┘    │     └─────────────┘
              │           │
              └─────┬─────┘
                    │
            ┌───────▼───────┐
            │  AppShellScreen│
            │  (4-tab nav)  │
            └───┬───┬───┬───┘
                │   │   │   │
    ┌───┐  ┌───▼┐ ┌▼──┐ ┌▼──┐
    │   │  │Home│ │Dis│ │Gar│ │Me │
    │   │  └─┬──┘ └───┘ └───┘ └─┬─┘
    │   │    │                   │
    │   │    │            ┌──────┼──────┐
    │   │    │            │      │      │
    │   │ ┌──▼───┐   ┌───▼──┐ ┌─▼────┐ │
    │   │ │Pract.│   │Growth│ │Sett. │ │
    │   │ │Sessn │   │Detail│ │      │ │
    │   │ └──────┘   └──────┘ └──────┘ │
    │   │                              │
    └───┘  (Mentor FAB — opens sheet from any tab)
```

---

## 5. Shared Components (app/widgets/)

### 5.1 Component Inventory

| Widget | Purpose | Used By |
|--------|---------|---------|
| `AppBanner` | Top-of-page announcement strip | Home, Discover |
| `AppCelebrationOverlay` | Full-screen celebration animation | Practice, Garden stage-up |
| `AppEmptyState` | Empty list placeholder with illustration | Discover, Growth |
| `AppHaptics` | Haptic feedback wrapper | All tap targets |
| `AppShimmer` | Loading skeleton placeholder | All async screens |
| `AppStepProgress` | Multi-step progress indicator | Onboarding |
| `AppSurfaceCard` | Standard card with warm shadow | All card layouts |

### 5.2 New Shared Widgets Needed

| Widget | Purpose | Spec Reference |
|--------|---------|---------------|
| `ScenePill` | 32px filter pill, `--radius-full` | component-spec.md |
| `PrimaryCTA` | 56px primary button, `--radius-md` | component-spec.md |
| `SecondaryButton` | 44px outlined button | component-spec.md |
| `MentorAvatar` | 40px / 28px avatar with halo | component-spec.md |
| `MentorBubble` | Surface bg, 18px radius speech bubble | component-spec.md |
| `EnglishPhrase` | Fraunces font, `--english` color | component-spec.md |
| `AudioButton` | 40px playback trigger | component-spec.md |
| `BabyReaction` | Icon + text reaction chip | component-spec.md |
| `XiaoheFAB` | 56x56px floating action button | component-spec.md |
| `Toast` | Sage-soft bg, 1.5-3s auto-dismiss | component-spec.md |
| `InputField` | `--bg-sunken`, `--radius-sm` | component-spec.md |
| `BarChart` | Lightweight weekly bar chart | Growth V2 |
| `GrowthStageVisual` | SVG/CSS plant stage animation | Garden V2 |
| `FertilizerButton` | Fertilizer claim/apply CTA | Garden V2 |

### 5.3 Widget Composition Rules

1. **Shared widgets go in `app/widgets/`** — only if used by 2+ features
2. **Feature-local widgets stay in `features/<name>/presentation/widgets/`** — even if they look reusable
3. **Promote to shared when** a second feature imports it — move, don't copy
4. **All shared widgets use `context.appColors`** — never hardcode color values
5. **Touch targets >= 44px** — enforced via `AppLayoutConstants.minTouchTarget`

---

## 6. Feature Deep Dives

### 6.1 Home (Practice Feature)

**Current state:** `HomeScreen` lives inside `features/practice/presentation/screens/`.

**Responsibility:** Care moment anchor, quick rescue list, mentor suggestions, garden/growth summary cards.

**Data flow:**

```
PracticeRepository
  ├── loadHomeSummary()        → PracticeHomeSummary
  ├── loadRecentResult()       → PracticeRecentResultSummary
  ├── loadContinuitySnapshot() → PracticeContinuitySnapshot
  └── loadActivityCatalog()    → PracticeActivityCatalog

PracticeContinuityNotifier
  ├── snapshot: PracticeContinuitySnapshot
  └── recommendNext() → picks next phrase based on recency + scene
```

**Widgets:**
- `HomePersonalizedHero` — care moment anchor (time-of-day + scene)
- `HomeTodaySceneCard` — current scene context
- `HomeRecentResultCard` — last practice result
- `HomeV23PhraseHero` — featured phrase card
- `HomeV23ActivitySlots` — quick rescue activity list
- `HomeGardenMiniEntry` — garden teaser
- `HomeGrowthSummaryCard` — growth teaser
- `HomeWeekStatsCard` — weekly stats strip

### 6.2 Discover (NEW)

**Responsibility:** Scene phrase browsing, search, filtering. Differentiated from Home (Home = active practice, Discover = reference library).

**Data flow:**

```
DiscoverApiService
  ├── fetchScenes()           → List<SceneDto>
  ├── fetchPhrases(sceneId)   → List<PhraseDto>
  └── searchPhrases(query)    → List<PhraseDto>

DiscoverRepository
  ├── getCachedScenes()       → from Isar DiscoverCacheEntity
  ├── refreshScenes()         → API → cache
  └── getPhrases(sceneId)     → cached or fetch

DiscoverNotifier
  ├── snapshot: DiscoverSnapshot
  │   ├── scenes: List<DiscoverScene>
  │   ├── selectedSceneId: String?
  │   ├── phrases: List<DiscoverPhrase>
  │   ├── searchQuery: String
  │   └── sortMode: SortMode  // mostUsed | newest | all
  ├── selectScene(id)
  ├── search(query)
  └── changeSort(mode)
```

**Widgets:**
- `DiscoverSearchBar` — inline lightweight search
- `DiscoverScenePills` — horizontal scrollable scene filter
- `DiscoverPhraseCard` — single-column phrase card with usage hint
- `DiscoverSortChip` — sort mode selector

### 6.3 Garden (NEW)

**Responsibility:** Single plant growth model (芭芭农场 pattern). Fertilizer claim → apply → stage progression.

**Data flow:**

```
GardenApiService
  ├── fetchGardenState()      → GardenDto
  ├── claimFertilizer()       → ClaimResult
  └── applyFertilizer()       → ApplyResult

GardenRepository
  ├── getGardenSnapshot()     → local-first, background sync
  ├── claimFertilizer()       → optimistic update + queue
  ├── applyFertilizer()       → optimistic update + queue
  └── getStageConfig()        → from asset bundle

GardenNotifier
  ├── snapshot: GardenSnapshot
  │   ├── currentStage: GardenStage  // seed|sprout|budding|bloom|fruit
  │   ├── fertilizerPending: int
  │   ├── fertilizerApplied: int
  │   ├── stageThreshold: int
  │   ├── stageAnimationAsset: String
  │   └── lastUpdatedAt: DateTime
  ├── claimFertilizer()
  ├── applyFertilizer()
  └── refresh()
```

**Growth stages:**

```
seed ──(3)──> sprout ──(7)──> budding ──(10)──> bloom ──(15)──> fruit
       3 pkg        7 pkg          10 pkg          15 pkg
```

(Numbers are configurable via `seed_content.json`)

**Widgets:**
- `GardenStageVisual` — animated plant at current stage
- `GardenProgressBar` — fertilizer progress (applied/threshold)
- `GardenFertilizerClaim` — pending fertilizer claim CTA
- `GardenFertilizeButton` — apply fertilizer CTA
- `GardenStageTransition` — celebration animation on stage-up

### 6.4 Growth (NEW)

**Responsibility:** Multi-dimensional stats (微信读书 pattern). Week/Month/Year/Total/Journey tabs.

**Data flow:**

```
GrowthApiService
  ├── fetchStats(dimension)   → GrowthStatsDto
  └── fetchJourney()          → List<MilestoneDto>

GrowthRepository
  ├── getStats(dimension)     → cached + refresh
  ├── getJourney()            → milestone timeline
  └── getGardenSummary()      → cross-reference garden state

GrowthNotifier
  ├── snapshot: GrowthSnapshot
  │   ├── selectedDimension: GrowthDimension  // week|month|year|total|journey
  │   ├── weekStats: WeekStats
  │   ├── monthStats: MonthStats
  │   ├── yearStats: YearStats
  │   ├── totalStats: TotalStats
  │   └── milestones: List<Milestone>
  ├── selectDimension(dim)
  └── refresh()
```

**Widgets:**
- `GrowthDimensionTabs` — week/month/year/total/journey selector
- `GrowthWeekView` — daily bar chart + scene breakdown
- `GrowthMonthView` — monthly summary + scene coverage
- `GrowthYearView` — yearly trend
- `GrowthTotalView` — lifetime stats
- `GrowthJourneyView` — milestone timeline
- `GrowthGardenSummary` — garden state cross-reference

### 6.5 Me (NEW — replaces "成长" tab)

**Responsibility:** User profile hub, garden/growth entry blocks, function grid.

**Structure:**

```
MeScreen
├── UserInfoSection          (avatar + name + baby info)
├── GardenStatusBlock        (current stage + progress → tap to GardenScreen)
├── GrowthDataBlock          (total phrases + streak days → tap to GrowthDetailScreen)
├── FunctionGrid (2-col)
│   ├── ReminderSettings     → SettingsScreen
│   ├── BabyProfile          → SettingsScreen
│   ├── PlaybackPrefs        → SettingsScreen
│   └── HelpFeedback         → external
└── SettingsIcon (top-right) → SettingsScreen
```

### 6.6 Settings (NEW)

**Responsibility:** Reminders, baby profile, playback preferences, help, about.

**Data flow:**

```
SettingsRepository
  ├── getSettings()           → SettingsSnapshot
  ├── updateReminder(config)
  ├── updateBabyProfile(profile)
  └── updatePlaybackPrefs(prefs)

SettingsNotifier
  ├── snapshot: SettingsSnapshot
  │   ├── reminderEnabled: bool
  │   ├── reminderTime: TimeOfDay
  │   ├── babyNickname: String
  │   ├── babyAgeMonths: int?
  │   ├── caregiverRole: CaregiverRole
  │   ├── volume: double
  │   └── speechRate: SpeechRate  // slow | normal | fast
  ├── toggleReminder()
  ├── updateReminderTime(time)
  ├── updateBabyProfile(nickname, ageMonths)
  ├── updateCaregiverRole(role)
  ├── updateVolume(vol)
  └── updateSpeechRate(rate)
```

---

## 7. Offline Support Strategy

### 7.1 Offline-First Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Widget Layer                          │
│              (ref.watch(notifierProvider))               │
├─────────────────────────────────────────────────────────┤
│                   Notifier Layer                         │
│         (reads from repository, exposes snapshot)        │
├─────────────────────────────────────────────────────────┤
│                  Repository Layer                        │
│                                                         │
│  ┌─────────────┐         ┌─────────────┐               │
│  │  Local Read  │         │  API Read   │               │
│  │  (Isar)      │◄────────│  (Dio)      │               │
│  │  always first│  cache  │  background │               │
│  └──────┬──────┘  write   └──────┬──────┘               │
│         │                        │                      │
│  ┌──────▼──────┐         ┌──────▼──────┐               │
│  │ Local Write │         │ Sync Queue  │               │
│  │ (optimistic)│         │ (offline    │               │
│  │             │         │  mutations) │               │
│  └─────────────┘         └──────┬──────┘               │
│                                 │                      │
│                          ┌──────▼──────┐               │
│                          │ Sync Worker │               │
│                          │ (on reconnect│              │
│                          │  or app open)│              │
│                          └─────────────┘               │
└─────────────────────────────────────────────────────────┘
```

### 7.2 Sync Strategy by Feature

| Feature | Read Strategy | Write Strategy | Offline Behavior |
|---------|--------------|----------------|------------------|
| **practice** | Local-first (Isar events) | Optimistic local + queue API | Full offline practice |
| **garden** | Local-first (Isar garden state) | Optimistic local + queue API | Claim/apply offline, sync later |
| **growth** | Cache-first (Isar stats) | Read-only (computed from events) | Show cached stats |
| **discover** | Cache-first (Isar catalog) | Read-only | Browse cached scenes |
| **mentor** | Local-first (Isar suggestions) | Local only (no API write) | Full offline mentor |
| **onboarding** | Local-first (snapshot store) | Local only | Full offline onboarding |
| **settings** | Local-first (Isar prefs) | Local only | Full offline settings |
| **account** | API-first | API required | Login requires network |
| **household** | API-first with local cache | API required | Read cached, write needs network |

### 7.3 Sync Queue Design

```dart
@collection
class SyncQueueEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late String featureName;      // 'garden', 'practice', etc.

  late String operationType;    // 'claim_fertilizer', 'record_event'
  late String payloadJson;      // serialized operation args
  late DateTime createdAt;
  late int retryCount;
  late String? lastError;
}
```

**Sync worker triggers:**
1. App foreground resume (connectivity check → flush)
2. After successful API call (piggyback flush)
3. Manual pull-to-refresh on any screen

### 7.4 Connectivity Monitoring

```dart
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).valueOrNull ?? [];
  return results.any((r) => r != ConnectivityResult.none);
});
```

---

## 8. Performance Optimization

### 8.1 Widget Rebuild Strategy

| Technique | Where | Why |
|-----------|-------|-----|
| `autoDispose` | Tab-scoped notifiers | Release state when tab not visible |
| `const` constructors | All leaf widgets | Skip rebuild when parent rebuilds |
| `Selector` / `select()` | Fine-grained state reads | Rebuild only on specific field change |
| `AnimatedSwitcher` | Tab body | Smooth tab transitions without full rebuild |
| `IndexedStack` | Shell body | Keep tab state alive, avoid rebuild on switch |
| `ListView.builder` | All lists | Lazy item construction |
| `SliverList` | Long scrollable areas |Viewport-based lazy loading |

### 8.2 Lazy Loading Strategy

> **注意：** Repository 有依赖链（practice→account→household→mentor），不能使用 `Future.wait()` 并行初始化所有 Repository。正确做法是只并行初始化 `practiceRepository` 和 `accountRepository`，延迟 `mentorRepository` 和 `householdRepository`。

```
App Start
  ├── Load critical providers (account, practice repo)
  ├── Show shell immediately (skeleton loading)
  └── Defer non-critical providers

Tab Switch (lazy init)
  ├── Garden tab first visit → gardenNotifierProvider.initialize()
  ├── Discover tab first visit → discoverNotifierProvider.initialize()
  └── Me tab first visit → growthNotifierProvider.initialize()

Route Navigation
  ├── Practice session → practiceSessionNotifierProvider.family(args)
  └── Settings → settingsNotifierProvider.initialize()
```

### 8.3 Image and Asset Optimization

| Asset Type | Strategy |
|------------|----------|
| Audio files | Preload on practice screen entry, dispose on exit |
| Plant SVGs | Inline SVG (5 stages), no network fetch |
| Fonts | 3 families pre-bundled (Fraunces, DM Sans, JetBrains Mono) |
| seed_content.json | Parsed once at boot, cached in provider |

### 8.4 Isar Performance

- **Index all query fields** — `@Index()` on `spaceId`, `activityId`, `eventTime`
- **Use `Isar.autoIncrement` IDs** — avoid UUID generation overhead
- **Batch writes** — `isar.writeTxn()` for bulk event saves
- **Limit query results** — `.limit(50)` for recent events, `.limit(20)` for discover

---

## 9. Testing Strategy

### 9.1 Test Pyramid

```
                    ┌─────────┐
                    │  E2E    │  5-10 critical flows
                    │ (integ) │  s01-s06 test files
                    ├─────────┤
                    │ Widget  │  30-50 key screens
                    │  Tests  │  Golden tests for design tokens
                    ├─────────┤
                    │  Unit   │  100+ repository/notifier tests
                    │  Tests  │  Pure domain logic
                    └─────────┘
```

### 9.2 Unit Tests

**What to test:**
- Repository merge logic (local + remote data reconciliation)
- Notifier state transitions (initialize → action → snapshot update)
- Domain services (stage matching, fertilizer calculation, stats aggregation)
- Sync queue operations (enqueue, dequeue, retry)

**Pattern:**

```dart
testWidgets('GardenNotifier applies fertilizer and advances progress', (tester) async {
  final repository = MockGardenRepository();
  when(() => repository.getGardenSnapshot()).thenAnswer(
    (_) async => GardenSnapshot.initial(),
  );

  final container = ProviderContainer(overrides: [
    gardenRepositoryProvider.overrideWithValue(repository),
  ]);

  final notifier = container.read(gardenNotifierProvider);
  await notifier.initialize();

  expect(notifier.snapshot.fertilizerApplied, 0);

  when(() => repository.applyFertilizer()).thenAnswer(
    (_) async => GardenSnapshot(fertilizerApplied: 1, ...),
  );
  await notifier.applyFertilizer();

  expect(notifier.snapshot.fertilizerApplied, 1);
});
```

### 9.3 Widget Tests

**What to test:**
- Screen renders correct content for given state
- User interactions trigger correct notifier methods
- Design token compliance (colors, spacing, typography)
- Loading/error/empty states

**Pattern:**

```dart
testWidgets('GardenScreen shows claim button when fertilizer pending', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gardenNotifierProvider.overrideWith(() => MockGardenNotifier(
          snapshot: GardenSnapshot(fertilizerPending: 3, ...),
        )),
      ],
      child: const MaterialApp(home: GardenScreen()),
    ),
  );

  expect(find.byKey(const Key('garden-claim-fertilizer')), findsOneWidget);
  expect(find.text('领取 3 包肥料'), findsOneWidget);
});
```

### 9.4 Integration Tests

**Existing test files (to be extended):**

| Test File | Flow |
|-----------|------|
| `s01_guest_practice_flow_test.dart` | Guest → onboarding → practice → reaction |
| `s02_personalized_onboarding_flow_test.dart` | Onboarding with baby profile |
| `s03_account_sync_restore_flow_test.dart` | Login → sync → restore |
| `s06_full_chain_release_flow_test.dart` | Full chain for release validation |

**New integration tests needed:**

| Test File | Flow |
|-----------|------|
| `s04_garden_growth_cycle_test.dart` | Practice → fertilizer → claim → apply → stage up |
| `s05_discover_browse_test.dart` | Browse scenes → filter → view phrase detail |
| `s07_settings_profile_test.dart` | Update baby profile → verify home screen |
| `s08_offline_sync_test.dart` | Go offline → practice → reconnect → verify sync |

### 9.5 Test Infrastructure

```
integration_test/
├── support/
│   ├── e2e_test_harness.dart          # Common test setup
│   ├── full_chain_test_harness.dart   # Full chain setup
│   ├── app_test_repositories.dart     # Mock repository overrides
│   └── in_memory_demo_backend.dart    # In-memory API mock
├── s01_guest_practice_flow_test.dart
├── s02_personalized_onboarding_flow_test.dart
├── ...
└── r4_performance_benchmark_test.dart  # Performance regression
```

---

## 10. Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Refactor shell to `StatefulShellRoute.indexedStack` (go_router)
- [ ] Create `discover/`, `garden/`, `growth/`, `settings/`, `me/` feature skeletons
- [ ] Add new Isar collections (`GardenEntity`, `GrowthStatEntity`, `SettingsEntity`, `SyncQueueEntity`)
- [ ] Implement `DiscoverRepository` + `DiscoverNotifier`
- [ ] Implement `SettingsRepository` + `SettingsNotifier`

### Phase 2: Garden + Growth (Week 2)
- [ ] Implement `GardenRepository` + `GardenNotifier` (fertilizer cycle)
- [ ] Implement `GrowthRepository` + `GrowthNotifier` (5 dimensions)
- [ ] Build `GardenScreen` with stage visual + fertilizer CTAs
- [ ] Build `GrowthDetailScreen` with dimension tabs
- [ ] Build `MeScreen` with garden/growth entry blocks

### Phase 3: Integration (Week 3)
- [ ] Wire garden fertilizer from practice events
- [ ] Wire growth stats from practice events
- [ ] Implement sync queue + offline flush worker
- [ ] Connect settings to practice (speech rate, volume)
- [ ] Integration tests for new flows

### Phase 4: Polish (Week 4)
- [ ] Performance optimization (lazy loading, rebuild reduction)
- [ ] Design token audit (consistency check against component-spec.md)
- [ ] Accessibility audit (semantics, touch targets, reduced motion)
- [ ] E2E test coverage for all critical paths

---

## Appendix A: Dependency Graph

```
                    ┌─────────────┐
                    │   main.dart │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    app.dart │
                    │  (Provider  │
                    │   Scope)    │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
  │   core/     │  │  features/  │  │  app/widgets │
  │  (infra)    │  │ (business)  │  │  (shared UI) │
  └──────┬──────┘  └──────┬──────┘  └─────────────┘
         │                │
         │    ┌───────────┼───────────┐
         │    │           │           │
         │    │     ┌─────▼─────┐    │
         │    │     │  domain/  │    │
         │    │     │ (models,  │    │
         │    │     │ services) │    │
         │    │     └─────┬─────┘    │
         │    │           │          │
         │    │     ┌─────▼─────┐    │
         └────┼─────│  data/    │    │
              │     │ (repo,    │    │
              │     │  local,   │    │
              │     │  api)     │    │
              │     └───────────┘    │
              │                      │
              │     ┌───────────┐    │
              └─────│presentati-│────┘
                    │on/        │
                    │(notifier, │
                    │ screen,   │
                    │ widgets)  │
                    └───────────┘

Dependency rules:
  presentation/ → domain/ (via notifier)
  presentation/ → data/ (via repository provider)
  data/ → core/ (via Dio, Isar)
  domain/ → (nothing — pure Dart)
  core/ → (nothing — infrastructure only)
```

## Appendix B: Design Token → Flutter Mapping

| CSS Token | Flutter Equivalent |
|-----------|-------------------|
| `--bg-base: #FFF8F0` | `AppTheme.bgBase` / `context.appColors.bgBase` |
| `--bg-surface: #FFFFFF` | `AppTheme.bgSurface` |
| `--accent: #FF8C42` | `AppTheme.accent` / `colorScheme.primary` |
| `--english: #3B8577` | `AppTheme.english` / `colorScheme.secondary` |
| `--radius-sm: 8px` | `AppLayoutConstants.cardRadius` |
| `--radius-md: 16px` | `AppLayoutConstants.cardRadius` (same) |
| `--radius-full: 9999px` | `AppLayoutConstants.pillRadius` |
| `--shadow-sm` | `AppTheme.warmShadowSm` |
| `--shadow-md` | `AppTheme.warmShadowMd` |
| `Title 1: Fraunces 28/500` | `AppTheme.title1Style` |
| `Mono: JetBrains 14/400` | `AppTheme.monoStyle` |

## Appendix C: File Count Estimate

| Category | Existing | New | Total |
|----------|----------|-----|-------|
| Feature modules | 7 | 5 (discover, garden, growth, settings, me) | 12 |
| Dart files | 137 | ~60 | ~197 |
| Isar collections | 2 | 4 | 6 |
| Riverpod providers | ~20 | ~15 | ~35 |
| Shared widgets | 7 | 14 | 21 |
| Integration tests | 6 | 4 | 10 |

---

## Appendix D: Architecture Review Improvements (2026-05-28)

Based on Flutter architecture best practices review, the following improvements were confirmed:

### D1. Logic Layer (Conditional)

Complex business logic should live in `domain/services/`, not in Repositories or Notifiers.

| Service | Responsibility | Dependencies |
|---------|---------------|--------------|
| `GardenFertilizerService` | Stage calculation, daily cap check, fertilizer expiry | Pure function, no Flutter deps |
| `GrowthStatsService` | Scene distribution aggregation, streak calculation | Pure function, no Flutter deps |
| `PracticeRecommendationService` | Time-based scene recommendation, phrase dedup, difficulty matching | Pure function, no Flutter deps |

**Principle:** Logic Layer is stateless, no Flutter dependencies, no Repository dependencies.

### D2. Service Boundary

Each Service wraps exactly one external data source:

| Service | Wraps | Responsibilities |
|---------|-------|-----------------|
| `ApiService` | Dio HTTP | Only HTTP calls, no caching, no business logic |
| `LocalStore` | Isar | Only Isar operations, no API calls, no business logic |
| `AssetService` | Flutter Bundle | Only asset loading |
| `TtsService` | flutter_tts | Only TTS operations |

**Repository responsibilities:**
- Merge LocalStore + ApiService data (local-first reads)
- Handle caching strategy
- Queue offline mutations for sync
- Transform entities to domain models

### D3. ViewModel Naming Convention

| Pattern | Usage | Example |
|---------|-------|---------|
| `ChangeNotifier` | Feature-level state | `GardenNotifier`, `GrowthNotifier` |
| `ChangeNotifier.family` | Route-level state | `PracticeSessionNotifier` |
| `FutureProvider` | Async repository init | `practiceRepositoryProvider` |

All notifiers use `ChangeNotifier` (not codegen). ViewModels are optional derived state objects for complex UI projections.

### D4. Test Strategy

| Layer | Test Type | Tool | Coverage Target |
|-------|-----------|------|-----------------|
| Service | Unit test | mockito | 90%+ |
| Repository | Unit + Integration | mockito + isar_test | 85%+ |
| ViewModel/Notifier | Unit test | mockito | 80%+ |
| Widget | Widget test | flutter_test | 70%+ |
| E2E | Integration test | integration_test | Key paths 100% |

Test file organization:
```
test/
├── unit/data/services/
├── unit/data/repositories/
├── unit/domain/services/
├── unit/presentation/notifiers/
├── widget/features/
├── integration/flows/
└── e2e/
```
