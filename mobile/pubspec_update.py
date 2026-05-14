import os

with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    text = f.read()

# Add dio_cookie_manager and cookie_jar to dependencies
if 'dio_cookie_manager' not in text:
    text = text.replace('  dio: ^5.7.0', '  dio: ^5.7.0\n  dio_cookie_manager: ^3.1.1\n  cookie_jar: ^4.0.8')
    with open('pubspec.yaml', 'w', encoding='utf-8') as f:
        f.write(text)
