import os

path = 'test/features/mentor/mentor_shell_panel_test.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('    required this.practiceSessionNotifier,\n    required this.accountNotifier,', '    required this.practiceSessionNotifier,')
text = text.replace('  final PracticeSessionNotifier practiceSessionNotifier;\n  final AccountNotifier accountNotifier;', '  final PracticeSessionNotifier practiceSessionNotifier;')
text = text.replace('      accountNotifier: accountNotifier,\n      accountNotifier: accountNotifier,', '      accountNotifier: accountNotifier,')

# line 469
text = text.replace('    final accountNotifier = AccountNotifier(\n      repository: accountRepository,\n    );\n    final accountNotifier = AccountNotifier(\n      repository: accountRepository,\n    );', '    final accountNotifier = AccountNotifier(\n      repository: accountRepository,\n    );')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
