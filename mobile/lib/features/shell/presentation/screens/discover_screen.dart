import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/widgets/app_empty_state.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/shell/presentation/widgets/discover_activity_card.dart';
import 'package:mobile/features/shell/presentation/widgets/discover_space_section.dart';
import 'package:mobile/features/shell/presentation/widgets/discover_view_toggle.dart';
import 'package:mobile/l10n/app_localizations.dart';

typedef DiscoverCatalogLoader = Future<PracticeActivityCatalog> Function();
typedef DiscoverPracticeOpener =
    Future<void> Function(BuildContext context, PracticeRouteArgs args);

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
  DiscoverBrowseView _selectedView = DiscoverBrowseView.activity;
  String? _navigationError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
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

              return ListView(
                key: const Key('shell-tab-discover'),
                padding: AppLayoutConstants.shellTabPadding,
                children: [
                  _DiscoverHero(theme: theme),
                  const SizedBox(height: 16),
                  DiscoverViewToggle(
                    selectedView: _selectedView,
                    onChanged: (view) {
                      setState(() {
                        _selectedView = view;
                      });
                    },
                  ),
                  if (_navigationError != null) ...[
                    const SizedBox(height: 16),
                    AppBanner(
                      key: const Key('discover-navigation-error'),
                      message: _navigationError!,
                      backgroundColor: colors.errorSoft,
                      foregroundColor: colors.error,
                    ),
                  ],
                  if (catalog?.catalogWarning != null &&
                      catalog!.catalogWarning!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppBanner(
                      key: const Key('discover-catalog-warning'),
                      message: catalog.catalogWarning!,
                      backgroundColor: colors.warningSoft,
                      foregroundColor: colors.warning,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isLoading)
                    const _DiscoverLoadingState()
                  else if (snapshot.hasError)
                    _DiscoverErrorState(
                      message: l.discoverLoadError,
                      onRetry: _retryCatalog,
                    )
                  else if (catalog == null || catalog.isEmpty)
                    _DiscoverEmptyState(onRetry: _retryCatalog)
                  else if (_selectedView == DiscoverBrowseView.activity)
                    _DiscoverActivityList(
                      activities: catalog.activities,
                      onOpenActivity: _openActivity,
                    )
                  else
                    _DiscoverSpaceList(
                      spaces: catalog.spaces,
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

  Future<PracticeActivityCatalog> _loadCatalog() {
    final loader = widget.catalogLoader;
    if (loader != null) {
      return loader();
    }
    return ref
        .read(practiceRepositoryProvider)
        .requireValue
        .getActivityCatalog();
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

class _DiscoverHero extends StatelessWidget {
  const _DiscoverHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('discover-hero-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.discoverTitle, style: theme.textTheme.labelMedium),
          const SizedBox(height: 10),
          Text(l.discoverSubtitle, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('discover-loading-state'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        children: [
          const AppShimmer(
            key: Key('discover-loading-indicator'),
            height: 4,
            borderRadius: 2,
          ),
          const SizedBox(height: 16),
          Text(
            l.discoverLoadingCatalog,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.errorSoft,
        borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
          const SizedBox(height: 16),
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

class _DiscoverActivityList extends StatelessWidget {
  const _DiscoverActivityList({
    required this.activities,
    required this.onOpenActivity,
  });

  final List<PracticeCatalogActivitySummary> activities;
  final ValueChanged<PracticeCatalogActivitySummary> onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      key: const Key('discover-view-activity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.discoverBrowseByActivity,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l.discoverActivityRouteNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final activity in activities) ...[
          DiscoverActivityCard(
            activity: activity,
            onOpen: () => onOpenActivity(activity),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _DiscoverSpaceList extends StatelessWidget {
  const _DiscoverSpaceList({
    required this.spaces,
    required this.onOpenActivity,
  });

  final List<PracticeCatalogSpaceSummary> spaces;
  final ValueChanged<PracticeCatalogActivitySummary> onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      key: const Key('discover-view-space'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.discoverBrowseBySpace,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l.discoverSpaceRouteNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final space in spaces) ...[
          DiscoverSpaceSection(space: space, onOpenActivity: onOpenActivity),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
