import os

path = 'test/features/mentor/mentor_shell_panel_test.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('      practiceSessionNotifier: practiceSessionNotifier,\n      accountNotifier: accountNotifier,', '      practiceSessionNotifier: practiceSessionNotifier,')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
