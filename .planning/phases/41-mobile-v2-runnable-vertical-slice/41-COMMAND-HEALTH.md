# Phase 41 Command Health

Run all package checks from the repository root in PowerShell. The repo-root
`flutter.cmd` wrapper targets the legacy `mobile/` package, so Phase 41 commands
must enter `mobile_v2/` explicitly.

## Focused package commands

```powershell
Push-Location mobile_v2
try {
  dart format --output=none --set-exit-if-changed .
  flutter analyze
  flutter test
} finally {
  Pop-Location
}
```

## Semantic firewalls

```powershell
dart run tool/verify_mobile_v2_semantic_firewall.dart
dart run tool/verify_activation_governor_contract.dart
```

## Dependency resolution

```powershell
Push-Location mobile_v2
try {
  flutter pub get
} finally {
  Pop-Location
}
```

Plan 41-01 installs only `crypto:^3.0.7`. It does not install, lock, smoke-test,
or otherwise require Riverpod. `flutter_riverpod` first belongs to Plan 41-08.

## Direct SDK fallbacks

If the `flutter` or `dart` command is shadowed or a wrapper changes package
directories, resolve the installed SDK executables and invoke them directly:

```powershell
$flutter = (Get-Command flutter).Source
$dart = (Get-Command dart).Source

Push-Location mobile_v2
try {
  & $dart format --output=none --set-exit-if-changed .
  & $flutter analyze
  & $flutter test
  & $flutter pub get
} finally {
  Pop-Location
}

& $dart run tool/verify_mobile_v2_semantic_firewall.dart
& $dart run tool/verify_activation_governor_contract.dart
```

When command discovery itself is unhealthy, use the Flutter installation path
reported by `Get-Command flutter`, then derive Dart from its cache:

```powershell
$flutter = 'C:\software\flutter\bin\flutter.bat'
$dart = 'C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe'
```
