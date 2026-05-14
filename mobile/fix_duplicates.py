import os
import re

def fix_app_dart():
    with open('lib/app/app.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    # Remove duplicate imports
    lines = content.split('\n')
    seen_imports = set()
    new_lines = []
    for line in lines:
        if line.startswith('import '):
            if line in seen_imports:
                continue
            seen_imports.add(line)
        new_lines.append(line)
    
    with open('lib/app/app.dart', 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))

def fix_mentor_test():
    path = 'test/features/mentor/mentor_shell_panel_test.dart'
    if not os.path.exists(path): return
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Simple deduplication in _Harness
    content = re.sub(r'final AccountNotifier accountNotifier;\s+final AccountNotifier accountNotifier;', r'final AccountNotifier accountNotifier;', content)
    content = re.sub(r'required this\.accountNotifier,\s+required this\.accountNotifier,', r'required this.accountNotifier,', content)
    content = re.sub(r'accountNotifier: accountNotifier,\s+accountNotifier: accountNotifier,', r'accountNotifier: accountNotifier,', content)
    content = re.sub(r'final accountNotifier = AccountNotifier\([^)]+\);\s+final accountNotifier = AccountNotifier\([^)]+\);', r'final accountNotifier = AccountNotifier(repository: accountRepository);', content)
    content = re.sub(r'final accountNotifier = AccountNotifier\(\s*repository: accountRepository,\s*\);\s*final accountNotifier = AccountNotifier\(\s*repository: accountRepository,\s*\);', r'final accountNotifier = AccountNotifier(repository: accountRepository);', content)

    # Some variables like `final accountNotifier = AccountNotifier(...)` might be duplicated
    lines = content.split('\n')
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if 'final accountNotifier =' in line and i > 0 and 'final accountNotifier =' in new_lines[-1]:
            i += 1
            continue
        new_lines.append(line)
        i += 1
        
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))

if __name__ == '__main__':
    fix_app_dart()
    fix_mentor_test()
    print("Fixed duplicates.")
