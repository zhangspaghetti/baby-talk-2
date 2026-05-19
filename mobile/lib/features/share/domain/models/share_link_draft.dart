import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';

part '../../../../generated/features/share/domain/models/share_link_draft.freezed.dart';

const List<String> shareDraftBlockedFragments = <String>[
  'installationid',
  'eventkey',
  'fallbackreason',
  'warningmessage',
  'debug',
];

enum ShareLinkSource {
  latestImpact('latest_impact'),
  continuityRecommendation('continuity_recommendation'),
  pairedProgress('paired_progress');

  const ShareLinkSource(this.wireValue);

  final String wireValue;
}

@freezed
class ShareLinkDraft with _$ShareLinkDraft {
  const ShareLinkDraft._();

  const factory ShareLinkDraft({
    required ShareLinkSource source,
    required String headline,
    required String storyText,
    String? phraseText,
    String? recommendationTitle,
    String? recommendationReason,
    String? spaceId,
    String? activityId,
  }) = _ShareLinkDraft;

  bool get hasPublicPayload {
    return headline.trim().isNotEmpty &&
        storyText.trim().isNotEmpty &&
        (phraseText?.trim().isNotEmpty == true ||
            recommendationTitle?.trim().isNotEmpty == true);
  }

  Map<String, Object?> toCreatePayload({String? platformHint}) {
    return <String, Object?>{
      'source': source.wireValue,
      'platformHint': _sanitizeKey(platformHint, maxLength: 16),
      'headline': headline,
      'storyText': storyText,
      'phraseText': phraseText,
      'recommendationTitle': recommendationTitle,
      'recommendationReason': recommendationReason,
      'spaceId': _sanitizeKey(spaceId, maxLength: 64),
      'activityId': _sanitizeKey(activityId, maxLength: 64),
    }..removeWhere((String _, Object? value) => value == null);
  }

  String? buildShareMessage(String shareUrl) {
    final normalizedUrl = _normalizeShareUrl(shareUrl);
    if (normalizedUrl == null || !hasPublicPayload) {
      return null;
    }

    final lines = <String>[
      headline,
      storyText,
      if (phraseText?.trim().isNotEmpty == true) '今天说的一句：${phraseText!.trim()}',
      if (recommendationTitle?.trim().isNotEmpty == true)
        recommendationReason?.trim().isNotEmpty == true
            ? '${recommendationTitle!.trim()} · ${recommendationReason!.trim()}'
            : recommendationTitle!.trim(),
      normalizedUrl,
    ];
    final message = lines
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join('\n');
    return _sanitizePublicText(message, maxLength: 560);
  }

  static ShareLinkDraft? fromSnapshots({
    GardenGrowthSnapshot? growthSnapshot,
    PracticeContinuitySnapshot? continuitySnapshot,
  }) {
    final impact = growthSnapshot?.latestImpact;
    final recommendedActivity = continuitySnapshot?.recommendedActivity;

    final impactHeadline = _sanitizePublicText(impact?.headline, maxLength: 80);
    final impactDetail = _sanitizePublicText(impact?.detail, maxLength: 200);
    final phraseText = _sanitizePublicText(impact?.phraseTitle, maxLength: 120);
    final recommendationTitle = _buildRecommendationTitle(recommendedActivity);
    final recommendationReason = _buildRecommendationReason(
      recommendedActivity,
    );

    final hasImpact = impactHeadline != null && impactDetail != null;
    final hasRecommendation = recommendationTitle != null;
    if (!hasImpact && !hasRecommendation) {
      return null;
    }

    final headline = hasImpact ? impactHeadline : recommendationTitle;
    final storyText = _buildStoryText(
      impactDetail: hasImpact ? impactDetail : null,
      recommendationTitle: recommendationTitle,
      recommendationReason: recommendationReason,
    );
    if (storyText == null) {
      return null;
    }

    final source = switch ((hasImpact, hasRecommendation)) {
      (true, true) => ShareLinkSource.pairedProgress,
      (true, false) => ShareLinkSource.latestImpact,
      (false, true) => ShareLinkSource.continuityRecommendation,
      (false, false) => ShareLinkSource.latestImpact,
    };

    return ShareLinkDraft(
      source: source,
      headline: headline!,
      storyText: storyText,
      phraseText: phraseText,
      recommendationTitle: recommendationTitle,
      recommendationReason: recommendationReason,
      spaceId: _sanitizeKey(
        impact?.spaceId ?? recommendedActivity?.spaceId,
        maxLength: 64,
      ),
      activityId: _sanitizeKey(
        impact?.activityId ?? recommendedActivity?.activityId,
        maxLength: 64,
      ),
    );
  }

  static String? _buildStoryText({
    required String? impactDetail,
    required String? recommendationTitle,
    required String? recommendationReason,
  }) {
    final parts = <String>[
      if (impactDetail != null) ...[impactDetail],
      if (recommendationTitle != null)
        recommendationReason == null
            ? '接下来可以继续 ${recommendationTitle.replaceFirst('接下来继续 ', '')}。'
            : '$recommendationTitle。$recommendationReason',
    ];
    if (parts.isEmpty) {
      return null;
    }
    return _sanitizePublicText(parts.join(' '), maxLength: 280);
  }

  static String? _buildRecommendationTitle(
    PracticeCatalogActivitySummary? activity,
  ) {
    final title = _sanitizePublicText(activity?.title, maxLength: 96);
    if (title == null) {
      return null;
    }
    return _sanitizePublicText('接下来继续 $title', maxLength: 120);
  }

  static String? _buildRecommendationReason(
    PracticeCatalogActivitySummary? activity,
  ) {
    if (activity == null) {
      return null;
    }
    final summary = _sanitizePublicText(activity.summary, maxLength: 120);
    final nextPhrase = _sanitizePublicText(
      activity.nextPhraseEnglish,
      maxLength: 48,
    );
    if (summary != null && nextPhrase != null) {
      return _sanitizePublicText(
        '$summary 先从 $nextPhrase 开始就好。',
        maxLength: 160,
      );
    }
    if (summary != null) {
      return _sanitizePublicText(summary, maxLength: 160);
    }
    if (nextPhrase != null) {
      return _sanitizePublicText('先从 $nextPhrase 开始就好。', maxLength: 160);
    }
    return null;
  }
}

String? _sanitizePublicText(String? rawValue, {required int maxLength}) {
  if (rawValue == null) {
    return null;
  }
  final normalized = rawValue.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return null;
  }
  final lowered = normalized.toLowerCase();
  for (final fragment in shareDraftBlockedFragments) {
    if (lowered.contains(fragment)) {
      return null;
    }
  }
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return normalized.substring(0, maxLength).trimRight();
}

String? _sanitizeKey(String? rawValue, {required int maxLength}) {
  if (rawValue == null) {
    return null;
  }
  final normalized = rawValue.trim();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return normalized.substring(0, maxLength).trimRight();
}

String? _normalizeShareUrl(String rawUrl) {
  final normalized = rawUrl.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') {
    return null;
  }
  return uri.toString();
}
