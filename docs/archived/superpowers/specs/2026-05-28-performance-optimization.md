# BabyTalk Flutter Mobile - Performance Optimization Strategy

> Date: 2026-05-28
> Target: BabyTalk Flutter mobile app (Dart SDK ^3.11.4)
> Scope: Startup, Memory, Frame Rate, Network, Bundle Size

---

## 1. App Startup Optimization

### 1.1 Current State Analysis

The current boot path is sequential and blocking:

```
main() → WidgetsFlutterBinding.ensureInitialized()
       → SystemChrome.setPreferredOrientations()
       → AppBootState.load(rootBundle)          // JSON parse + asset validation
       → BabyTalkApp(bootState: bootState)
       → FutureBuilder<_AppLaunchState>         // Isar open + repository chain
       → MaterialApp.router
```

**Current bottlenecks:**
- `AppBootState.load()` parses `seed_content.json` (5.3 KB) and validates ALL audio assets eagerly via `validateAssets()` — 9 MP3 files loaded from bundle synchronously
- `_loadLaunchState()` opens 4+ Isar instances sequentially (practice, mentor, account, household)
- Provider graph resolution is waterfall: each repository depends on the previous one
- `AuthState.load()` and `FeatureGates.resolve()` add additional async waits

**Measured baseline targets:**

| Metric | Current (est.) | Target | Stretch |
|--------|----------------|--------|---------|
| Cold start to first frame | ~3-4s | <1.5s | <1s |
| Warm start to first frame | ~1.5-2s | <800ms | <500ms |
| Time to interactive | ~4-5s | <2.5s | <1.5s |

### 1.2 Cold Start Optimization

#### 1.2.1 Asset Validation Deferred

`AssetPhraseService.validateAssets()` calls `bundle.load()` on every audio file at boot. This is unnecessary — the asset bundle system guarantees asset existence at build time.

**Action: Remove `validateAssets()` from boot path.** Validate in debug mode only via a `kDebugMode` guard, or remove entirely since `flutter build` already embeds assets.

```dart
// lib/features/practice/data/services/asset_phrase_service.dart
Future<SeedContentBundle> _loadSeedContent() async {
  final rawJson = await _bundle.loadString(assetPath);
  final content = SeedContentBundle.fromJsonString(rawJson);
  // Remove: await content.validateAssets(_bundle); — assets are guaranteed by build
  return content;
}
```

**Impact:** Eliminates 9 sequential `bundle.load()` calls from boot. Estimated savings: 200-400ms.

#### 1.2.2 Parallel Repository Initialization

Currently `_loadLaunchState()` chains `await ref.read(XRepositoryProvider.future)` sequentially. Isar instances and repositories that don't depend on each other should open in parallel.

**Action:** Use `Future.wait()` for independent repositories:

```dart
Future<_AppLaunchState> _loadLaunchState() async {
  // Phase 1: Independent — all can open in parallel
  final results = await Future.wait([
    ref.read(practiceRepositoryProvider.future),
    ref.read(accountRepositoryProvider.future),
    ref.read(householdRepositoryProvider.future),
    ref.read(mentorRepositoryProvider.future),
  ]);

  final practiceRepository = results[0] as PracticeRepository;
  final accountRepository = results[1] as AccountRepository;
  final householdRepository = results[2] as HouseholdRepository;
  final mentorRepository = results[3] as MentorRepository;

  // Phase 2: Sequential — depends on Phase 1 results
  final directory = await ref.read(appDirectoryProvider.future);
  // ... rest of launch state
}
```

**Prerequisite:** Verify provider dependency graph allows parallelization. Currently `accountRepositoryProvider` depends on `practiceRepositoryProvider`, so Phase 1 may need to be split into two waves.

**Impact:** 30-50% reduction in repository init time.

#### 1.2.3 Isar Lazy Open

Isar instances are opened eagerly during `_loadLaunchState()`. For features not needed at first paint (mentor, household), defer Isar open until the feature is accessed.

**Action:** Use lazy initialization pattern:

```dart
// Instead of opening mentor Isar at boot:
final mentorRepositoryProvider = FutureProvider<MentorRepository>((ref) async {
  // Defer open until first access — no longer in boot critical path
  return MentorRepository(
    localDataSource: await MentorLocalDataSource.open(directory: directory.path),
    // ...
  );
});
```

Move `mentorRepositoryProvider` and `householdRepositoryProvider` out of the `_loadLaunchState()` critical path. They can be resolved on-demand when the user navigates to the mentor panel or household settings.

**Impact:** Removes 2 Isar opens (~150-300ms) from boot critical path.

#### 1.2.4 Skeleton Screen for First Paint

Current `BootLoadingScreen` is a bare `CircularProgressIndicator`. Replace with a branded skeleton that matches the home screen layout.

**Action:** Create a `BootSkeletonScreen` that renders the shell nav + home layout skeleton immediately, before any async work completes:

```dart
class BootSkeletonScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Hero skeleton
            AppShimmer(width: 280, height: 120, borderRadius: 20),
            SizedBox(height: 24),
            // Activity slots skeleton
            Row(
              children: [
                AppShimmer(width: 100, height: 100, borderRadius: 16),
                SizedBox(width: 12),
                AppShimmer(width: 100, height: 100, borderRadius: 16),
                SizedBox(width: 12),
                AppShimmer(width: 100, height: 100, borderRadius: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

**Impact:** Perceived first paint drops from ~1s to <200ms (skeleton renders on first frame).

#### 1.2.5 Splash Screen with Fade Transition

Add a branded splash using Flutter's `flutter_native_splash` or manual approach. The splash should fade out smoothly into the skeleton, then into the real content.

**Action:**
1. Add `flutter_native_splash` config for native splash (instant on Android/iOS)
2. In `main.dart`, show branded splash → skeleton → real content with cross-fade

### 1.3 Warm Start Optimization

#### 1.3.1 Isar Cache Warming

On warm start, Isar files are already on disk. Ensure Isar is opened with optimal settings:

```dart
// Use compact mode for faster open
final isar = await Isar.open(
  [InteractionEventEntitySchema],
  directory: directory.path,
  name: 'practice_local',
  // Isar 3.x: no explicit compact mode, but ensure no compaction on open
);
```

#### 1.3.2 Provider State Persistence

Riverpod providers rebuild on warm start. Use `keepAlive` for critical providers that don't change:

```dart
final practiceRepositoryProvider = FutureProvider<PracticeRepository>((ref) async {
  ref.keepAlive(); // Survives widget tree rebuilds
  // ...
});
```

---

## 2. Memory Management

### 2.1 Image Caching Strategy

#### 2.1.1 Current State

No image assets exist in the current app (text-only UI). However, when profile images or activity illustrations are added, implement proactive caching:

```dart
// Future: when images are added
class ImageCacheManager {
  static const _maxCacheSize = 50 * 1024 * 1024; // 50 MB
  static const _maxEntryCount = 100;

  static Future<void> precacheHeroImages(BuildContext context) async {
    // Only precache images visible on first paint
    await precacheImage(
      AssetImage('assets/images/hero_garden.webp'),
      context,
    );
  }
}
```

**Rules:**
- Use `cached_network_image` for remote images (not yet needed)
- Maximum 50 MB in-memory image cache
- Evict non-visible images on low memory signals (`WidgetsBindingObserver.didReceiveMemoryPressure`)
- Use `WebP` format at 2x resolution for retina displays

### 2.2 Isar Query Optimization

#### 2.2.1 Current Issues

`PracticeLocalDataSource` has several query patterns that load all entities into memory:

```dart
// BAD: loads ALL events, then filters in Dart
Future<List<InteractionEventEntity>> listRawEntities({...}) async {
  return collection.where().findAll(); // Loads everything
}
```

**Action:** Push filters into Isar queries using compound indexes:

```dart
// GOOD: filter at database level
Future<List<InteractionEventEntity>> listRawEntities({
  String? spaceId,
  String? activityId,
}) async {
  return _isar.txn(() async {
    final collection = _isar.collection<InteractionEventEntity>();
    QueryBuilder<InteractionEventEntity, InteractionEventEntity, QAfterFilterCondition> query;

    if (spaceId != null && activityId != null) {
      query = collection
          .filter()
          .spaceIdEqualTo(spaceId)
          .activityIdEqualTo(activityId);
    } else if (spaceId != null) {
      query = collection.filter().spaceIdEqualTo(spaceId);
    } else if (activityId != null) {
      query = collection.filter().activityIdEqualTo(activityId);
    } else {
      return collection.where().findAll();
    }
    return query.findAll();
  });
}
```

#### 2.2.2 Index Recommendations

Add composite indexes to `InteractionEventEntity`:

```dart
@Collection(ignore: {'toList', 'fromJson'})
class InteractionEventEntity {
  // ... existing fields

  // Add composite index for common query patterns
  @Index(composite: [CompositeIndex('activityId')])
  late String spaceId;

  @Index(type: IndexType.value)
  late int syncState;
}
```

#### 2.2.3 Pagination for Large Result Sets

`countInteractionEvents()` loads ALL entities just to count them. Use Isar's `count()`:

```dart
Future<int> countInteractionEvents({String? spaceId, String? activityId}) async {
  return _isar.txn(() async {
    final collection = _isar.collection<InteractionEventEntity>();
    if (spaceId != null && activityId != null) {
      return collection
          .filter()
          .spaceIdEqualTo(spaceId)
          .activityIdEqualTo(activityId)
          .count();
    }
    return collection.where().count();
  });
}
```

### 2.3 Widget Disposal Patterns

#### 2.3.1 Current State

`_HomeScreenState` correctly disposes listeners and route subscriptions. Good patterns observed:
- `removeListener` in `dispose()`
- `appRouteObserver.unsubscribe(this)` in `dispose()`
- Cached notifier references for cleanup

**Action: Audit all `ConsumerStatefulWidget` classes for:**
1. Missing `dispose()` on controllers
2. Missing `removeListener`/`removeObserver` calls
3. `ChangeNotifier` listeners not removed

#### 2.3.2 Audio Controller Lifecycle

`PracticeAudioController` is created per-session. Ensure disposal:

```dart
// In PracticeSessionNotifier
@override
void dispose() {
  _audioController?.dispose(); // Must dispose audioplayers
  super.dispose();
}
```

### 2.4 Memory Leak Prevention

#### 2.4.1 Stream Subscription Management

`ShareReentryCoordinator` and `InviteReentryCoordinator` use streams. Ensure all subscriptions are cancelled:

```dart
// Pattern for stream subscriptions
late StreamSubscription<Uri> _shareSubscription;

@override
void dispose() {
  _shareSubscription.cancel();
  super.dispose();
}
```

#### 2.4.2 Timer Management

`PracticeContinuityNotifier` uses refresh timeouts. Ensure timers are cancelled on dispose:

```dart
Timer? _refreshTimer;

@override
void dispose() {
  _refreshTimer?.cancel();
  super.dispose();
}
```

#### 2.4.3 Memory Pressure Response

Register `WidgetsBindingObserver` in `BabyTalkApp` to respond to memory warnings:

```dart
class _BabyTalkAppState extends ConsumerState<BabyTalkApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didReceiveMemoryPressure() {
    // Clear non-essential caches
    PaintingBinding.instance.imageCache.clear();
    // Trigger Isar compaction if needed
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

---

## 3. Frame Rate Assurance

### 3.1 Widget Rebuild Optimization

#### 3.1.1 Current Issues

`HomeScreen` watches multiple notifiers:

```dart
final gardenGrowthNotifier = ref.watch(gardenGrowthNotifierProvider);
final continuityNotifier = ref.watch(practiceContinuityNotifierProvider);
final householdNotifier = ref.watch(householdNotifierProvider);
```

Each `ref.watch()` triggers a rebuild when that notifier changes. If `householdNotifier` changes while the user is on the home screen, the entire `build()` re-runs even though household data isn't displayed.

**Action:** Use `ref.select()` to watch only specific properties:

```dart
// Instead of watching the entire notifier:
final hasResolvedContinuity = ref.watch(
  practiceContinuityNotifierProvider.select((n) => n.hasResolvedRecommendation),
);
final continuitySnapshot = ref.watch(
  practiceContinuityNotifierProvider.select((n) => n.snapshot),
);
```

#### 3.1.2 Const Widgets

Audit all widget constructors for `const` opportunities. Most stateless widgets in `app/widgets/` should be const-constructable.

**Current good examples:** `AppShimmer` could be const if not for the animation controller. `BootLoadingScreen` is already const.

#### 3.1.3 RepaintBoundary

Wrap expensive-to-repaint widgets (hero animations, celebration overlay) in `RepaintBoundary`:

```dart
RepaintBoundary(
  child: HomeV23PhraseHero(
    starterPhrase: starterPhrase,
    // ...
  ),
)
```

### 3.2 Animation Performance

#### 3.2.1 AppShimmer Optimization

`AppShimmer` uses `AnimationController.repeat()` which runs continuously. When the shimmer is not visible (off-screen, disposed but not garbage collected), it still consumes GPU cycles.

**Action:** Use `TickerMode.of(context)` awareness — the `SingleTickerProviderStateMixin` already handles this correctly by disabling the ticker when the widget is off-tree. Verified correct.

**Additional optimization:** Use `AnimatedBuilder` instead of `AnimatedBuilder` (already done). Consider reducing animation duration from 1500ms to 1000ms for snappier feel.

#### 3.2.2 Theme Transition Animation

`BabyTalkColors.lerp()` currently snaps `BoxShadow` values at t=0.5 instead of interpolating. For smooth theme transitions:

```dart
// Current: snaps
warmShadowSm: t < 0.5 ? warmShadowSm : other.warmShadowSm,

// Better: interpolate shadow color and blur
warmShadowSm: [
  BoxShadow(
    color: Color.lerp(warmShadowSm[0].color, other.warmShadowSm[0].color, t)!,
    blurRadius: lerpDouble(warmShadowSm[0].blurRadius, other.warmShadowSm[0].blurRadius, t)!,
    offset: Offset.lerp(warmShadowSm[0].offset, other.warmShadowSm[0].offset, t)!,
  ),
],
```

### 3.3 List Virtualization

#### 3.3.1 HomeScreen ListView

`HomeScreen` uses a plain `ListView` with 4-5 children. For future growth (when more cards are added), switch to `ListView.builder`:

```dart
// Current
ListView(
  children: [
    HomeV23PhraseHero(...),
    const HomeV23ActivitySlots(),
    HomeGardenMiniEntry(...),
  ],
)

// Future-proof: if children list grows beyond 10 items
ListView.builder(
  itemCount: _buildHomeItems().length,
  itemBuilder: (context, index) => _buildHomeItems()[index],
)
```

**Current assessment:** Not needed yet — only 3-4 items. Monitor as features grow.

#### 3.3.2 Discovery Screen

When `DiscoverScreen` displays a list of activities, use `ListView.builder` with `AutomaticKeepAliveClientMixin` for tab persistence:

```dart
class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Preserve state when switching tabs
}
```

### 3.4 Heavy Computation Offloading

#### 3.4.1 JSON Parsing

`SeedContentBundle.fromJsonString()` parses JSON on the main isolate. For larger content bundles, move to a background isolate:

```dart
// When seed_content.json grows beyond 50 KB
class IsolateJsonParser {
  static Future<SeedContentBundle> parse(String rawJson) async {
    return compute(_parseInIsolate, rawJson);
  }

  static SeedContentBundle _parseInIsolate(String rawJson) {
    return SeedContentBundle.fromJsonString(rawJson);
  }
}
```

**Current assessment:** seed_content.json is only 5.3 KB — no need yet. Monitor as content grows.

#### 3.4.2 Isar Query Sorting

`_compareEntities()` sorts in Dart after loading all results. For large result sets, add `sortByClientTimestampDesc()` at the Isar query level:

```dart
return collection.where()
    .sortByClientTimestampDesc() // Sort at DB level
    .findAll();
```

---

## 4. Network Optimization

### 4.1 Current State

`AppDio` creates a basic Dio instance with:
- 10s connect timeout
- 30s receive timeout
- Cookie management
- No retry logic
- No request deduplication
- No response caching

### 4.2 Request Deduplication

#### 4.2.1 Duplicate Request Guard

When the user pulls-to-refresh or rapidly navigates, duplicate API calls can fire. Implement a request deduplication interceptor:

```dart
class DeduplicationInterceptor extends Interceptor {
  final _inFlightRequests = <String, Completer<Response>>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = '${options.method}:${options.uri}';
    final existing = _inFlightRequests[key];
    if (existing != null) {
      // Another request is in flight — wait for it
      existing.future.then(
        (response) => handler.resolve(response),
        onError: (error) => handler.reject(error),
      );
      return;
    }
    final completer = Completer<Response>();
    _inFlightRequests[key] = completer;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = '${response.requestOptions.method}:${response.requestOptions.uri}';
    _inFlightRequests.remove(key)?.complete(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = '${err.requestOptions.method}:${err.requestOptions.uri}';
    _inFlightRequests.remove(key)?.completeError(err);
    handler.next(err);
  }
}
```

### 4.3 Response Caching

#### 4.3.1 HTTP Cache Headers

The backend should return `Cache-Control` headers. On the client, implement a cache interceptor:

```dart
class CacheInterceptor extends Interceptor {
  final _cache = <String, _CachedResponse>{};
  static const _maxAge = Duration(minutes: 5);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = options.uri.toString();
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      handler.resolve(cached.response);
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method == 'GET') {
      final key = response.requestOptions.uri.toString();
      _cache[key] = _CachedResponse(response: response, cachedAt: DateTime.now());
    }
    handler.next(response);
  }
}
```

**Cache strategy per endpoint:**

| Endpoint | Cache TTL | Rationale |
|----------|-----------|-----------|
| Practice continuity | 5 min | Moderate freshness |
| Garden growth | 5 min | Moderate freshness |
| Account session | No cache | Always fresh |
| Household state | 5 min | Moderate freshness |
| Mentor suggestions | 30 min | Long-lived, AI-generated |

### 4.4 Retry with Backoff

#### 4.4.1 Exponential Backoff Interceptor

```dart
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration baseDelay;

  RetryInterceptor({this.maxRetries = 3, this.baseDelay = const Duration(seconds: 1)});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    if (retryCount < maxRetries && _isRetryable(err)) {
      final delay = baseDelay * (1 << retryCount); // exponential backoff
      await Future.delayed(delay);
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      try {
        final dio = Dio(); // Re-execute
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {}
    }
    handler.next(err);
  }

  bool _isRetryable(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        (err.response?.statusCode ?? 0) >= 500;
  }
}
```

### 4.5 Offline-First Strategy

#### 4.5.1 Current Offline Behavior

The app already has offline-first characteristics:
- Isar stores all interaction events locally
- `PracticeContinuityNotifier` has seed state for offline boot
- `GardenGrowthNotifier` caches growth data locally

**Gaps to fill:**

1. **Sync queue management:** When offline, queue API calls and replay on reconnect
2. **Connectivity listener:** Use `connectivity_plus` (already a dependency) to trigger sync on reconnect

```dart
class SyncManager {
  final Connectivity _connectivity;

  SyncManager(this._connectivity) {
    _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        _flushPendingSync();
      }
    });
  }

  Future<void> _flushPendingSync() async {
    // Replay pending events from Isar
    // Already handled by PracticeRepository.syncPendingEvents()
  }
}
```

#### 4.5.2 Optimistic Updates

For practice events, the app already writes locally first (Isar) and syncs later. This is correct. Ensure UI updates optimistically:

```dart
// Already implemented in PracticeSessionNotifier:
// 1. Write to Isar immediately
// 2. Show updated state in UI
// 3. Sync to server in background
// 4. Mark as synced on success
```

---

## 5. Bundle Size Optimization

### 5.1 Current Asset Footprint

| Asset Type | Count | Total Size | Notes |
|-----------|-------|------------|-------|
| Audio (MP3) | 9 | 1.14 MB | Practice phrases |
| Fonts (TTF) | 7 | ~200 KB (est.) | 3 families |
| JSON content | 1 | 5.3 KB | Seed content |
| **Total assets** | | **~1.35 MB** | |

### 5.2 Tree-Shaking

#### 5.2.1 Flutter Tree-Shaking

Enable tree-shaking in release builds (already default in Flutter). Verify unused Material icons are excluded:

```yaml
# pubspec.yaml — already correct
flutter:
  uses-material-design: true
```

**Action:** Run `flutter build apk --analyze-size` to identify largest dependencies:

```
Expected largest contributors:
- isar: ~2-3 MB native
- flutter_tts: ~1-2 MB native
- audioplayers: ~1 MB native
- dio: ~200 KB Dart
- provider/riverpod: ~100 KB Dart
```

#### 5.2.2 Remove Unused Dependencies

Audit `pubspec.yaml` for unused packages. Current dependencies look well-scoped. No obvious removals.

### 5.3 Code Splitting

#### 5.3.1 Deferred Imports

Flutter doesn't support code splitting in the traditional web sense. However, use deferred loading for features not needed at boot:

```dart
// Mentor feature — not needed at first paint
import 'package:mobile/features/mentor/presentation/mentor_panel_sheet.dart'
    deferred as mentor_panel;

// Load on first access
Future<void> openMentorPanel(...) async {
  await mentor_panel.loadLibrary();
  mentor_panel.openMentorPanelSheet(context, ...);
}
```

**Candidates for deferred loading:**
- `mentor_panel_sheet.dart` — only opened on user tap
- `share_callout_card.dart` — only on share flow
- `household_invite_card.dart` — only on invite flow

### 5.4 Asset Optimization

#### 5.4.1 Audio Compression

Current MP3 files average ~130 KB each. Options for further optimization:

| Format | Est. Size | Quality | Tradeoff |
|--------|-----------|---------|----------|
| MP3 (current) | 130 KB avg | Good | Baseline |
| AAC/M4A | ~100 KB avg | Better | Smaller size, same quality |
| Opus | ~60 KB avg | Excellent | Best compression, limited support |
| OGG Vorbis | ~80 KB avg | Good | Wide support |

**Recommendation:** Switch to AAC (`.m4a`) for 20-30% size reduction with same or better quality. Flutter's `audioplayers` supports AAC.

#### 5.4.2 Font Subsetting

Current fonts (Fraunces, DM Sans, JetBrains Mono) include full character sets. For Chinese parents learning English, only Latin characters + IPA symbols + Chinese characters are needed.

**Action:** Use `flutter_font_loader` or build-time subsetting:

```yaml
# Subset to: Basic Latin, IPA Extensions, Chinese (common 3000 chars)
fonts:
  - family: Fraunces
    fonts:
      - asset: assets/fonts/fraunces/Fraunces-Regular-subset.ttf
        weight: 400
```

**Estimated savings:** 30-50% per font file (from ~200 KB to ~100-140 KB total).

**Tool:** Use `pyftsubset` or `fonttools` to create subsets:

```bash
pyftsubset Fraunces-Regular.ttf \
  --unicodes="U+0000-007F,U+0080-00FF,U+0100-017F,U+2000-206F,U+4E00-9FFF" \
  --output-file=Fraunces-Regular-subset.ttf
```

#### 5.4.3 Unused Font Cleanup

`Fraunces-Variable.ttf` (45 KB) is included but not referenced in `pubspec.yaml`. Remove it:

```yaml
# Remove this line from pubspec.yaml assets:
# - asset: assets/fonts/fraunces/Fraunces-Variable.ttf  # NOT listed, but file exists on disk
```

**Action:** Delete `assets/fonts/fraunces/Fraunces-Variable.ttf` from the repository.

### 5.5 Native Library Optimization

#### 5.5.1 Isar Size

Isar adds ~2-3 MB to the APK. If this becomes a concern, consider:
- Switching to `drift` (SQLite) — smaller footprint but slower queries
- Using `hive` for simpler key-value storage where full DB is overkill

**Current assessment:** Isar is justified for the interaction event store with complex queries. Keep.

#### 5.5.2 flutter_tts Size

`flutter_tts` adds ~1-2 MB for TTS engine. If TTS is only used in specific screens, consider deferring the engine initialization:

```dart
// Only initialize TTS when the user first accesses TTS features
class TtsManager {
  static FlutterTts? _instance;
  static Future<FlutterTts> get instance async {
    return _instance ??= FlutterTts()..setLanguage('en-US');
  }
}
```

---

## 6. Performance Monitoring

### 6.1 Key Metrics to Track

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Cold start time | <1.5s | `WidgetsBinding.instance.addPostFrameCallback` timestamp in `main()` |
| Frame rate | 60fps sustained | `SchedulerBinding.instance.currentFrameTimeStamp` |
| Memory usage | <150MB steady | `ProcessInfo.currentRss` (dart:io) or platform channel |
| Isar query time | <50ms p95 | Wrap queries with `Stopwatch` in debug mode |
| API response time | <500ms p95 | Dio interceptor timing |

### 6.2 Debug Performance Overlay

Enable Flutter's performance overlay in debug mode:

```dart
MaterialApp(
  showPerformanceOverlay: kDebugMode,
  // ...
)
```

### 6.3 Timeline Traces

Add custom timeline events for critical paths:

```dart
import 'dart:developer';

Timeline.startSync('boot_load_seed_content');
final content = await assetPhraseService.loadSeedContent();
Timeline.finishSync();

Timeline.startSync('boot_open_isar');
final practiceRepository = await ref.read(practiceRepositoryProvider.future);
Timeline.finishSync();
```

---

## 7. Implementation Priority

### Phase 1: Quick Wins (1-2 days)

| # | Action | Impact | Risk |
|---|--------|--------|------|
| 1 | Remove `validateAssets()` from boot | -200-400ms boot | None |
| 2 | Parallel repository init | -30-50% init time | Low |
| 3 | Delete unused `Fraunces-Variable.ttf` | -45KB APK | None |
| 4 | Add `RepaintBoundary` to hero widgets | Smoother animations | None |
| 5 | Use `ref.select()` in HomeScreen | Fewer rebuilds | Low |

### Phase 2: Medium Effort (3-5 days)

| # | Action | Impact | Risk |
|---|--------|--------|------|
| 6 | Skeleton screen for first paint | Perceived perf +50% | Low |
| 7 | Deduplication interceptor | Prevent duplicate calls | Medium |
| 8 | Retry with backoff | Better reliability | Low |
| 9 | Isar query optimization (count, sort) | -50% query time | Medium |
| 10 | Deferred mentor/household Isar open | -150-300ms boot | Medium |

### Phase 3: Long-term (1-2 weeks)

| # | Action | Impact | Risk |
|---|--------|--------|------|
| 11 | Font subsetting | -30-50% font size | Medium |
| 12 | Audio format migration (MP3→AAC) | -20-30% audio size | Low |
| 13 | Deferred imports for mentor/share | Smaller initial bundle | Medium |
| 14 | Response caching interceptor | Fewer network calls | Medium |
| 15 | Memory pressure response handler | Better low-mem perf | Low |

---

## 8. Measurement Protocol

Before implementing any optimization:

1. **Baseline measurement:** Run `flutter run --profile` and record:
   - Time from `main()` to first frame via `Timeline.startSync`
   - Memory usage at steady state
   - Frame build times via `dart:developer` timeline

2. **After implementation:** Re-run same measurements and compare.

3. **Regression guard:** Add a startup time assertion in integration tests:

```dart
testWidgets('cold start under 1500ms', (tester) async {
  final stopwatch = Stopwatch()..start();
  await tester.pumpWidget(BabyTalkApp(bootState: mockBootState));
  stopwatch.stop();
  expect(stopwatch.elapsedMilliseconds, lessThan(1500));
});
```
