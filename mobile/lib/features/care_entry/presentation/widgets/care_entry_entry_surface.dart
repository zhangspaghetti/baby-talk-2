import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:mobile/features/care_entry/presentation/onboarding_conversation_controller.dart';

abstract interface class CareEntryAudioPlayer {
  Future<void> play({
    required OnboardingUtterance utterance,
    required String? conversationId,
  });

  Future<void> stop();

  Future<void> dispose();
}

final class AudioplayersCareEntryAudioPlayer implements CareEntryAudioPlayer {
  AudioplayersCareEntryAudioPlayer({
    AudioPlayer? player,
    GuestOnboardingAudioPlayer? guestAudioPlayer,
  }) : _player = player ?? AudioPlayer(),
       _guestAudioPlayer = guestAudioPlayer;

  final AudioPlayer _player;
  final GuestOnboardingAudioPlayer? _guestAudioPlayer;

  @override
  Future<void> play({
    required OnboardingUtterance utterance,
    required String? conversationId,
  }) async {
    final audioAsset = utterance.localAudioAsset;
    if (audioAsset != null) {
      final asset = audioAsset.startsWith('assets/')
          ? audioAsset.substring(7)
          : audioAsset;
      await _player.play(AssetSource(asset));
      return;
    }
    final guest = _guestAudioPlayer;
    if (!utterance.remoteAudioAvailable ||
        conversationId == null ||
        guest == null) {
      throw StateError('音频资源不可用。');
    }
    await guest.play(
      conversationId: conversationId,
      utteranceId: utterance.utteranceId,
    );
  }

  @override
  Future<void> stop() async {
    final localStop = _player.stop();
    final guestStop = _guestAudioPlayer?.stop();
    await Future.wait(<Future<void>>[localStop, ?guestStop]);
  }

  @override
  Future<void> dispose() async {
    await _guestAudioPlayer?.dispose();
    await _player.dispose();
  }
}

class CareEntryEntrySurface extends StatefulWidget {
  const CareEntryEntrySurface({
    super.key,
    required this.controller,
    this.audioControllerFactory,
    this.onRetry,
    this.onDefer,
    this.onContinueCareTurn,
    this.onToday,
    this.onGarden,
  });

  final OnboardingConversationController controller;
  final CareEntryAudioPlayer Function()? audioControllerFactory;
  final VoidCallback? onRetry;
  final Future<void> Function()? onDefer;
  final ValueChanged<OnboardingCareTurnHandoff>? onContinueCareTurn;
  final VoidCallback? onToday;
  final VoidCallback? onGarden;

  @override
  State<CareEntryEntrySurface> createState() => _CareEntryEntrySurfaceState();
}

class _CareEntryEntrySurfaceState extends State<CareEntryEntrySurface> {
  CareEntryAudioPlayer? _audioController;
  String? _audioMessage;
  bool _isPlaying = false;
  final TextEditingController _otherReactionController =
      TextEditingController();
  bool _isOtherReactionSelected = false;
  bool _isDeferring = false;
  bool _isCompleting = false;

  @override
  void dispose() {
    final audioController = _audioController;
    if (audioController != null) {
      unawaited(audioController.dispose());
    }
    _otherReactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Scaffold(
          backgroundColor: const Color(0xFFFFFBF3),
          appBar:
              state.phase == OnboardingConversationPhase.completed ||
                  widget.onDefer == null
              ? null
              : AppBar(
                  backgroundColor: const Color(0xFFFFFBF3),
                  elevation: 0,
                  actions: <Widget>[
                    TextButton(
                      key: const Key('care-entry-defer-action'),
                      onPressed: _isDeferring ? null : _defer,
                      child: Text(_isDeferring ? '正在保存…' : '稍后再来'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: switch (state.phase) {
                  OnboardingConversationPhase.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  OnboardingConversationPhase.failure => _FailureView(
                    message: state.errorMessage ?? '暂时无法准备入口。',
                    onRetry: widget.onRetry,
                  ),
                  OnboardingConversationPhase.selection => _SelectionView(
                    state: state,
                    onSelected: (id) => unawaited(widget.controller.select(id)),
                    onStarted: () =>
                        unawaited(widget.controller.startSelected()),
                  ),
                  OnboardingConversationPhase.resolvingFirstUtterance =>
                    const Center(child: CircularProgressIndicator()),
                  OnboardingConversationPhase.resolvingNextSupport =>
                    _ResolvingNextSupportView(
                      isCompleting: _isCompleting,
                      onFinishToday: _finishForTrace,
                    ),
                  OnboardingConversationPhase.savingReaction => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  OnboardingConversationPhase.firstUtterance ||
                  OnboardingConversationPhase.savingPhraseSaid =>
                    _FirstUtteranceView(
                      entry: state.activeEntry!,
                      utterance: state.activeUtterance!,
                      audioMessage: _audioMessage,
                      isPlaying: _isPlaying,
                      isSaving:
                          state.phase ==
                          OnboardingConversationPhase.savingPhraseSaid,
                      onPlayAudio: _playAudio,
                      onSaid: _markPhraseSaid,
                    ),
                  OnboardingConversationPhase.reactionPrompt =>
                    _ReactionPromptView(
                      selectedReaction: state.selectedReaction,
                      isOtherSelected: _isOtherReactionSelected,
                      otherController: _otherReactionController,
                      errorMessage: state.errorMessage,
                      onSelected: (reaction, otherText) {
                        setState(() => _isOtherReactionSelected = false);
                        unawaited(
                          widget.controller.selectReaction(
                            reaction,
                            otherText: otherText,
                          ),
                        );
                      },
                      onChooseOther: () {
                        setState(() => _isOtherReactionSelected = true);
                      },
                      onContinue: () => unawaited(
                        widget.controller.continueWithoutReaction(),
                      ),
                    ),
                  OnboardingConversationPhase.nextSupportReady ||
                  OnboardingConversationPhase.completing => _NextSupportView(
                    support: state.nextSupport!,
                    isCompleting:
                        _isCompleting ||
                        state.phase == OnboardingConversationPhase.completing,
                    errorMessage: state.errorMessage,
                    onContinue: _continueCareTurn,
                    onFinishToday: _finishForTrace,
                  ),
                  OnboardingConversationPhase.completed => _GardenTraceView(
                    onToday: widget.onToday,
                    onGarden: widget.onGarden,
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _playAudio() async {
    final utterance = widget.controller.state.activeUtterance;
    if (utterance == null || _isPlaying) return;
    setState(() {
      _isPlaying = true;
      _audioMessage = null;
    });
    final controller = _audioController ??=
        widget.audioControllerFactory?.call() ??
        AudioplayersCareEntryAudioPlayer();
    try {
      await controller.play(
        utterance: utterance,
        conversationId: widget.controller.state.conversationId,
      );
    } on Object {
      if (mounted) {
        setState(() => _audioMessage = '今天先看着读也可以。');
      }
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  void _markPhraseSaid() {
    final audioController = _audioController;
    if (audioController != null) {
      unawaited(audioController.stop().onError((_, _) {}));
    }
    if (mounted) {
      setState(() => _isPlaying = false);
    }
    unawaited(widget.controller.markPhraseSaid());
  }

  Future<void> _defer() async {
    final onDefer = widget.onDefer;
    if (onDefer == null || _isDeferring) return;
    setState(() => _isDeferring = true);
    try {
      await onDefer();
    } finally {
      if (mounted) setState(() => _isDeferring = false);
    }
  }

  Future<void> _finishForTrace() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await widget.controller.complete();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _continueCareTurn() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      final handoff = await widget.controller.continueToCareTurn();
      if (handoff != null) widget.onContinueCareTurn?.call(handoff);
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }
}

class _SelectionView extends StatelessWidget {
  const _SelectionView({
    required this.state,
    required this.onSelected,
    required this.onStarted,
  });

  final OnboardingConversationState state;
  final ValueChanged<CareEntryId> onSelected;
  final VoidCallback onStarted;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: <Widget>[
        Text(
          '今天先从现在这一刻开始。',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF3F342C),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '不用学英语，只要对宝宝轻轻说一句。',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6F6258)),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          key: const Key('care-entry-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.entries.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 142,
          ),
          itemBuilder: (context, index) {
            final entry = state.entries[index];
            return CareEntryTile(
              entry: entry,
              selected: entry.id == state.selectedEntryId,
              onPressed: () => onSelected(entry.id),
            );
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('care-entry-primary-action'),
            onPressed: state.selectedEntryId == null ? null : onStarted,
            child: const Text('直接从现在开始'),
          ),
        ),
      ],
    );
  }
}

class CareEntryTile extends StatelessWidget {
  const CareEntryTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onPressed,
  });

  final ResolvedCareEntry entry;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFFD67B45)
        : const Color(0xFFE1D7CA);
    return Semantics(
      button: true,
      selected: selected,
      label: entry.isRecommended ? '${entry.title}，现在推荐' : entry.title,
      child: OutlinedButton(
        key: Key('care-entry-tile-${entry.id.value}'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
          backgroundColor: selected ? const Color(0xFFFFF1E5) : Colors.white,
          side: BorderSide(color: borderColor, width: selected ? 2 : 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(_iconFor(entry.visualToken), color: const Color(0xFF6F6258)),
            const SizedBox(height: 10),
            Text(
              entry.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(entry.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _FirstUtteranceView extends StatelessWidget {
  const _FirstUtteranceView({
    required this.entry,
    required this.utterance,
    required this.audioMessage,
    required this.isPlaying,
    required this.isSaving,
    required this.onPlayAudio,
    required this.onSaid,
  });

  final ResolvedCareEntry entry;
  final OnboardingUtterance utterance;
  final String? audioMessage;
  final bool isPlaying;
  final bool isSaving;
  final VoidCallback onPlayAudio;
  final VoidCallback onSaid;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      children: <Widget>[
        Text(
          entry.title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: const Color(0xFFD06F3D)),
        ),
        const SizedBox(height: 18),
        Text(
          utterance.english,
          key: const Key('care-entry-first-utterance-english'),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: const Color(0xFF3F342C),
            fontFamily: 'Fraunces',
          ),
        ),
        const SizedBox(height: 16),
        Text(utterance.chinese, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          utterance.pronunciation,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6F6258)),
        ),
        const SizedBox(height: 28),
        if (utterance.localAudioAsset != null || utterance.remoteAudioAvailable)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('care-entry-first-utterance-audio'),
              onPressed: isPlaying ? null : onPlayAudio,
              icon: const Icon(Icons.volume_up_outlined),
              label: Text(isPlaying ? '正在播放' : '听标准发音'),
            ),
          ),
        if (audioMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(audioMessage!, key: const Key('care-entry-audio-message')),
        ],
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('care-entry-said-action'),
            onPressed: isSaving ? null : onSaid,
            child: Text(isSaving ? '正在记下' : '我说了'),
          ),
        ),
      ],
    );
  }
}

class _ReactionPromptView extends StatelessWidget {
  const _ReactionPromptView({
    required this.selectedReaction,
    required this.isOtherSelected,
    required this.otherController,
    required this.errorMessage,
    required this.onSelected,
    required this.onChooseOther,
    required this.onContinue,
  });

  final CareReaction? selectedReaction;
  final bool isOtherSelected;
  final TextEditingController otherController;
  final String? errorMessage;
  final void Function(CareReaction reaction, String? otherText) onSelected;
  final VoidCallback onChooseOther;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('care-entry-reaction-prompt'),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      children: <Widget>[
        Text(
          '宝宝现在怎么了？',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF3F342C),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text('选一个最接近的，也可以直接看下一句。'),
        const SizedBox(height: 20),
        for (final reaction in CareReaction.values) ...<Widget>[
          OutlinedButton(
            key: Key('care-entry-reaction-${reaction.wireValue}'),
            onPressed: reaction == CareReaction.other
                ? onChooseOther
                : () => onSelected(reaction, null),
            child: Text(_reactionLabel(reaction)),
          ),
          const SizedBox(height: 8),
        ],
        if (isOtherSelected) ...<Widget>[
          TextField(
            key: const Key('care-entry-reaction-other-text'),
            controller: otherController,
            maxLength: 200,
            decoration: const InputDecoration(labelText: '补充宝宝的反应（可不填）'),
          ),
          OutlinedButton(
            key: const Key('care-entry-reaction-other-submit'),
            onPressed: () =>
                onSelected(CareReaction.other, otherController.text.trim()),
            child: const Text('确认其他反应'),
          ),
        ],
        if (errorMessage != null) Text(errorMessage!),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('care-entry-reaction-skip'),
          onPressed: onContinue,
          child: const Text('直接看下一句'),
        ),
      ],
    );
  }
}

class _NextSupportView extends StatelessWidget {
  const _NextSupportView({
    required this.support,
    required this.isCompleting,
    required this.errorMessage,
    required this.onContinue,
    required this.onFinishToday,
  });

  final CareNextSupportUtterance support;
  final bool isCompleting;
  final String? errorMessage;
  final VoidCallback onContinue;
  final VoidCallback onFinishToday;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('care-entry-next-support'),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: <Widget>[
        Text(
          support.english,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: const Color(0xFF3F342C),
            fontFamily: 'Fraunces',
          ),
        ),
        const SizedBox(height: 16),
        Text(support.chinese, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 36),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('care-entry-continue-action'),
            onPressed: isCompleting ? null : onContinue,
            child: Text(isCompleting ? '正在保存' : '继续说下去'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('care-entry-finish-today-action'),
          onPressed: isCompleting ? null : onFinishToday,
          child: const Text('今天先到这里'),
        ),
        if (errorMessage != null) Text(errorMessage!),
      ],
    );
  }
}

class _ResolvingNextSupportView extends StatelessWidget {
  const _ResolvingNextSupportView({
    required this.isCompleting,
    required this.onFinishToday,
  });

  final bool isCompleting;
  final VoidCallback onFinishToday;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('正在把下一句换好。'),
            const SizedBox(height: 20),
            TextButton(
              key: const Key('care-entry-loading-finish-today-action'),
              onPressed: isCompleting ? null : onFinishToday,
              child: Text(isCompleting ? '正在保存' : '今天先到这里'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GardenTraceView extends StatelessWidget {
  const _GardenTraceView({required this.onToday, required this.onGarden});

  final VoidCallback? onToday;
  final VoidCallback? onGarden;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('care-entry-garden-trace'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '第一句已经留在你的小花园里。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text('宝宝和你，已经开始了今天这一刻。'),
            const SizedBox(height: 28),
            FilledButton(
              key: const Key('care-entry-open-today-action'),
              onPressed: onToday,
              child: const Text('开始今天的小时间'),
            ),
            TextButton(
              key: const Key('care-entry-open-garden-action'),
              onPressed: onGarden,
              child: const Text('看看花园'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('再试一次')),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String visualToken) => switch (visualToken) {
  'route.moon' => Icons.nightlight_round,
  'route.bottle' => Icons.local_drink_outlined,
  'route.soothing' => Icons.water_drop_outlined,
  'route.diaper' => Icons.checkroom_outlined,
  _ => Icons.favorite_outline,
};

String _reactionLabel(CareReaction reaction) => switch (reaction) {
  CareReaction.cooperating => '配合',
  CareReaction.hesitant => '犹豫',
  CareReaction.resisting => '不想',
  CareReaction.noResponse => '没反应',
  CareReaction.other => '其他',
};
