import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/widgets/app_empty_state.dart';
import 'package:mobile/app/widgets/app_english_phrase.dart';
import 'package:mobile/app/widgets/app_scene_pill.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Scene browsing entry point.
///
/// Users can search, filter by scene, and sort results.
/// Each card opens the existing execution path through route args.
typedef DiscoverCatalogLoader = Future<PracticeActivityCatalog> Function();
typedef DiscoverPracticeOpener =
    Future<void> Function(BuildContext context, PracticeRouteArgs args);

/// Sort modes for the scene list.
enum _SortMode { mostUsed, newest, all }

/// Well-known scene categories (from design spec).
const _sceneCategories = [
  'all',
  'mealtime',
  'drinking',
  'diaper',
  'bath',
  'bedtime',
  'outing',
];

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key, this.catalogLoader, this.practiceOpener});

  final DiscoverCatalogLoader? catalogLoader;
  final DiscoverPracticeOpener? practiceOpener;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with AutomaticKeepAliveClientMixin<DiscoverScreen> {
  late Future<PracticeActivityCatalog> _catalogFuture;
  String? _navigationError;

  // --- V1: search, scene filter, sort ---
  final _searchController = TextEditingController();
  String _selectedScene = 'all';
  _SortMode _sortMode = _SortMode.all;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    super.build(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayoutConstants.maxContentWidth,
          ),
          child: FutureBuilder<PracticeActivityCatalog>(
            future: _catalogFuture,
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState != ConnectionState.done;
              final catalog = snapshot.data;
              final allActivities = catalog?.activities ?? [];
              final filtered = _applyFilters(allActivities);

              return ListView(
                key: const Key('shell-tab-discover'),
                padding: AppLayoutConstants.shellTabPadding,
                children: [
                  // --- Hero card ---
                  _DiscoverHero(theme: theme),
                  const SizedBox(height: 16),

                  // --- Search bar ---
                  _DiscoverSearchBar(
                    controller: _searchController,
                    hintText: l.discoverSearchHint,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                  const SizedBox(height: 12),

                  // --- Scene pills + sort ---
                  _DiscoverFilterBar(
                    selectedScene: _selectedScene,
                    sortMode: _sortMode,
                    onSceneChanged: (scene) {
                      setState(() => _selectedScene = scene);
                    },
                    onSortChanged: (mode) {
                      setState(() => _sortMode = mode);
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Error banners ---
                  if (_navigationError != null) ...[
                    AppBanner(
                      key: const Key('discover-navigation-error'),
                      message: _navigationError!,
                      backgroundColor: colors.errorSoft,
                      foregroundColor: colors.error,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (catalog?.catalogWarning != null &&
                      catalog!.catalogWarning!.trim().isNotEmpty) ...[
                    AppBanner(
                      key: const Key('discover-catalog-warning'),
                      message: catalog.catalogWarning!,
                      backgroundColor: colors.warningSoft,
                      foregroundColor: colors.warning,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- Content ---
                  if (isLoading)
                    const _DiscoverLoadingState()
                  else if (snapshot.hasError)
                    _DiscoverErrorState(
                      message: l.discoverLoadError,
                      onRetry: _retryCatalog,
                    )
                  else if (catalog == null || catalog.isEmpty)
                    _DiscoverEmptyState(onRetry: _retryCatalog)
                  else if (filtered.isEmpty)
                    _DiscoverFilterEmptyState(
                      isSearch: _searchQuery.isNotEmpty,
                      onClearSearch: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedScene = 'all';
                        });
                      },
                    )
                  else
                    _DiscoverSceneList(
                      activities: filtered,
                      onOpenActivity: _openActivity,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Apply scene filter, search query, and sort to the activity list.
  List<PracticeCatalogActivitySummary> _applyFilters(
    List<PracticeCatalogActivitySummary> activities,
  ) {
    var result = List<PracticeCatalogActivitySummary>.from(activities);

    // Scene filter
    if (_selectedScene != 'all') {
      final sceneLabel = _sceneLabel(_selectedScene);
      result = result
          .where(
            (a) => a.sceneTag.toLowerCase().contains(sceneLabel.toLowerCase()),
          )
          .toList();
    }

    // Search filter (supports English and Chinese scene text)
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((a) {
        final title = a.title.toLowerCase();
        final summary = a.summary.toLowerCase();
        final scene = a.sceneTag.toLowerCase();
        return title.contains(query) ||
            summary.contains(query) ||
            scene.contains(query);
      }).toList();
    }

    // Sort
    switch (_sortMode) {
      case _SortMode.mostUsed:
        result.sort((a, b) => b.totalEvents.compareTo(a.totalEvents));
      case _SortMode.newest:
        result.sort((a, b) {
          final aTime = a.lastEventTime ?? DateTime(0);
          final bTime = b.lastEventTime ?? DateTime(0);
          return bTime.compareTo(aTime);
        });
      case _SortMode.all:
        // Default order from backend
        break;
    }

    return result;
  }

  String _sceneLabel(String sceneKey) {
    switch (sceneKey) {
      case 'mealtime':
        return '喂饭';
      case 'drinking':
        return '喝水';
      case 'diaper':
        return '换尿布';
      case 'bath':
        return '洗澡';
      case 'bedtime':
        return '睡前';
      case 'outing':
        return '出门';
      default:
        return '';
    }
  }

  Future<PracticeActivityCatalog> _loadCatalog() async {
    final loader = widget.catalogLoader;
    if (loader != null) {
      return loader();
    }
    final repo = await ref.read(practiceRepositoryProvider.future);
    return repo.getActivityCatalog();
  }

  Future<void> _retryCatalog() async {
    setState(() {
      _navigationError = null;
      _catalogFuture = _loadCatalog();
    });
  }

  Future<void> _openActivity(PracticeCatalogActivitySummary activity) async {
    final l = AppLocalizations.of(context)!;
    final routeArgs = PracticeRouteArgs.maybeCreate(
      spaceId: activity.spaceId,
      activityId: activity.activityId,
    );
    if (routeArgs == null) {
      setState(() {
        _navigationError = l.discoverInvalidCardError;
      });
      return;
    }

    setState(() {
      _navigationError = null;
    });

    try {
      final opener = widget.practiceOpener;
      if (opener != null) {
        await opener(context, routeArgs);
      } else {
        await routeArgs.push<void>(context);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _navigationError = l.discoverOpenActivityError(activity.title, '请稍后重试');
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────

class _DiscoverHero extends StatelessWidget {
  const _DiscoverHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      key: const Key('discover-hero-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BabyTalk',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colors.english,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '照护场景',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────

class _DiscoverSearchBar extends StatelessWidget {
  const _DiscoverSearchBar({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: '搜索场景或照护时刻',
      child: TextField(
        key: const Key('discover-search-field'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 15, color: colors.textMuted),
          prefixIcon: Icon(
            Icons.search,
            size: AppLayoutConstants.iconSizeSm,
            color: colors.textMuted,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  key: const Key('discover-search-clear'),
                  icon: Icon(Icons.clear, size: 18, color: colors.textMuted),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: colors.bgSunken,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppLayoutConstants.spacingMd,
            vertical: AppLayoutConstants.inputVerticalPadding,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
            borderSide: BorderSide(color: colors.accent, width: 1.4),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter Bar (Scene Pills + Sort)
// ─────────────────────────────────────────────────────────────

class _DiscoverFilterBar extends StatelessWidget {
  const _DiscoverFilterBar({
    required this.selectedScene,
    required this.sortMode,
    required this.onSceneChanged,
    required this.onSortChanged,
  });

  final String selectedScene;
  final _SortMode sortMode;
  final ValueChanged<String> onSceneChanged;
  final ValueChanged<_SortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scene pills (horizontal scroll)
        SizedBox(
          height: AppLayoutConstants.minTouchTarget,
          child: SingleChildScrollView(
            key: const Key('discover-scene-pills'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _sceneCategories.length; i++) ...[
                  if (i > 0)
                    const SizedBox(width: AppLayoutConstants.spacingXs),
                  AppScenePill(
                    key: Key('discover-pill-${_sceneCategories[i]}'),
                    label: _sceneLabelFromKey(l, _sceneCategories[i]),
                    isSelected: _sceneCategories[i] == selectedScene,
                    onTap: () => onSceneChanged(_sceneCategories[i]),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: AppLayoutConstants.spacingXs),

        // Sort dropdown
        Align(
          alignment: Alignment.centerRight,
          child: _DiscoverSortDropdown(
            sortMode: sortMode,
            onChanged: onSortChanged,
          ),
        ),
      ],
    );
  }

  String _sceneLabelFromKey(AppLocalizations l, String key) {
    switch (key) {
      case 'all':
        return l.discoverSceneAll;
      case 'mealtime':
        return l.discoverSceneMealtime;
      case 'drinking':
        return l.discoverSceneDrinking;
      case 'diaper':
        return l.discoverSceneDiaper;
      case 'bath':
        return l.discoverSceneBath;
      case 'bedtime':
        return l.discoverSceneBedtime;
      case 'outing':
        return l.discoverSceneOuting;
      default:
        return key;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Scene Pill
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// Sort Dropdown
// ─────────────────────────────────────────────────────────────

class _DiscoverSortDropdown extends StatelessWidget {
  const _DiscoverSortDropdown({
    required this.sortMode,
    required this.onChanged,
  });

  final _SortMode sortMode;
  final ValueChanged<_SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Semantics(
      label: '排序方式',
      child: PopupMenuButton<_SortMode>(
        key: const Key('discover-sort-dropdown'),
        onSelected: onChanged,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
        ),
        color: colors.bgSurface,
        itemBuilder: (context) => [
          _sortMenuItem(l, _SortMode.mostUsed, Icons.trending_up),
          _sortMenuItem(l, _SortMode.newest, Icons.access_time),
          _sortMenuItem(l, _SortMode.all, Icons.sort),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayoutConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            color: colors.bgSunken,
            borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_sortIcon(sortMode), size: 16, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                _sortLabel(l, sortMode),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_SortMode> _sortMenuItem(
    AppLocalizations l,
    _SortMode mode,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(_sortLabel(l, mode)),
        ],
      ),
    );
  }

  String _sortLabel(AppLocalizations l, _SortMode mode) {
    switch (mode) {
      case _SortMode.mostUsed:
        return l.discoverSortMostUsed;
      case _SortMode.newest:
        return l.discoverSortNewest;
      case _SortMode.all:
        return l.discoverSortAll;
    }
  }

  IconData _sortIcon(_SortMode mode) {
    switch (mode) {
      case _SortMode.mostUsed:
        return Icons.trending_up;
      case _SortMode.newest:
        return Icons.access_time;
      case _SortMode.all:
        return Icons.sort;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Scene List
// ─────────────────────────────────────────────────────────────

class _DiscoverSceneList extends StatelessWidget {
  const _DiscoverSceneList({
    required this.activities,
    required this.onOpenActivity,
  });

  final List<PracticeCatalogActivitySummary> activities;
  final ValueChanged<PracticeCatalogActivitySummary> onOpenActivity;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('discover-phrase-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result count
        Padding(
          padding: const EdgeInsets.only(bottom: AppLayoutConstants.spacingXs),
          child: Text(
            '${activities.length} 个场景',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted),
          ),
        ),
        // Scene cards
        for (final activity in activities) ...[
          _SceneCard(activity: activity, onTap: () => onOpenActivity(activity)),
          const SizedBox(height: AppLayoutConstants.spacingXs),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scene Card
// ─────────────────────────────────────────────────────────────

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.activity, required this.onTap});

  final PracticeCatalogActivitySummary activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final sceneLabel = _sceneTagLabel(activity.sceneTag);
    final sceneSummary = _sceneCopy(activity.summary);
    final coachTip = _sceneCopy(activity.coachTip.trim());

    return Semantics(
      label: '${activity.title}，场景$sceneLabel',
      button: true,
      child: AppSurfaceCard(
        key: Key('discover-phrase-card-${activity.activityId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scene tag + primary button row
            Row(
              children: [
                // Scene tag pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayoutConstants.spacingXs,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.englishSoft,
                    borderRadius: BorderRadius.circular(
                      AppLayoutConstants.pillRadius,
                    ),
                  ),
                  child: Text(
                    sceneLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.english,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Semantics(
                  button: true,
                  label: l.discoverPracticeThis,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(
                      AppLayoutConstants.pillRadius,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayoutConstants.spacingSm,
                        vertical: AppLayoutConstants.spacingXxs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(
                          AppLayoutConstants.pillRadius,
                        ),
                      ),
                      child: Text(
                        l.discoverPracticeThis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppLayoutConstants.spacingSm),

            // Current care moment title
            AppEnglishPhrase(activity.title),
            const SizedBox(height: AppLayoutConstants.spacingXs),

            Text(
              sceneSummary,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if (coachTip.isNotEmpty) ...[
              const SizedBox(height: AppLayoutConstants.spacingXs),
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      coachTip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _sceneTagLabel(String tag) {
    final lower = tag.toLowerCase();
    if (lower.contains('喂') || lower.contains('meal') || lower.contains('饭')) {
      return '喂饭';
    }
    if (lower.contains('喝') || lower.contains('drink') || lower.contains('水')) {
      return '喝水';
    }
    if (lower.contains('尿') ||
        lower.contains('diaper') ||
        lower.contains('换')) {
      return '换尿布';
    }
    if (lower.contains('洗') || lower.contains('bath') || lower.contains('澡')) {
      return '洗澡';
    }
    if (lower.contains('睡') ||
        lower.contains('bed') ||
        lower.contains('night')) {
      return '睡前';
    }
    if (lower.contains('出') || lower.contains('out') || lower.contains('门')) {
      return '出门';
    }
    return tag.isNotEmpty ? tag : '其他';
  }

  String _sceneCopy(String value) {
    return value
        .replaceAll('练习', '照护')
        .replaceAll('课程', '场景')
        .replaceAll('学习进度', '照护节奏')
        .replaceAll('完成任务', '完成照护')
        .replaceAll('短语', '表达')
        .replaceAll('1 of N', '当前节点');
  }
}

// ─────────────────────────────────────────────────────────────
// States: Loading, Error, Empty, Filter Empty
// ─────────────────────────────────────────────────────────────

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('discover-loading-state'),
      padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        children: [
          const AppShimmer(
            key: Key('discover-loading-indicator'),
            height: 4,
            borderRadius: 2,
          ),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          Text(
            l.discoverLoadingCatalog,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppLayoutConstants.spacingXs),
          Text(
            l.discoverLoadingNote,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DiscoverErrorState extends StatelessWidget {
  const _DiscoverErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('discover-error-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
      decoration: BoxDecoration(
        color: colors.errorSoft,
        borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.discoverLoadError,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppLayoutConstants.spacingXs),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          OutlinedButton(
            key: const Key('discover-retry-button'),
            onPressed: onRetry,
            child: Text(l.discoverRetryLoad),
          ),
        ],
      ),
    );
  }
}

class _DiscoverEmptyState extends StatelessWidget {
  const _DiscoverEmptyState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AppEmptyState(
      key: const Key('discover-empty-state'),
      icon: Icons.explore_off_outlined,
      title: l.discoverEmpty,
      description: l.discoverEmptyNote,
      actionLabel: l.discoverRetryRead,
      onAction: () => onRetry(),
    );
  }
}

class _DiscoverFilterEmptyState extends StatelessWidget {
  const _DiscoverFilterEmptyState({
    required this.isSearch,
    required this.onClearSearch,
  });

  final bool isSearch;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('discover-filter-empty-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        children: [
          Icon(
            isSearch ? Icons.search_off : Icons.filter_list_off,
            size: AppLayoutConstants.iconSizeLg,
            color: colors.textMuted,
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Text(
            isSearch ? l.discoverSearchEmpty : l.discoverSceneEmpty,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          OutlinedButton(
            key: const Key('discover-clear-filters'),
            onPressed: onClearSearch,
            child: Text(isSearch ? '清除搜索' : '查看全部场景'),
          ),
        ],
      ),
    );
  }
}
