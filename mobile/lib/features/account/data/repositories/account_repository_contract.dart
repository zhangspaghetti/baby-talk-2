import 'package:mobile/features/account/data/local/account_local_store.dart';

enum AccountRuntimeTrigger {
  appBoot,
  loginSuccess,
  homeVisible,
  foregroundResume,
  manualRetry,
}

extension AccountRuntimeTriggerWire on AccountRuntimeTrigger {
  String get wireValue {
    switch (this) {
      case AccountRuntimeTrigger.appBoot:
        return 'app_boot';
      case AccountRuntimeTrigger.loginSuccess:
        return 'login_success';
      case AccountRuntimeTrigger.homeVisible:
        return 'home_visible';
      case AccountRuntimeTrigger.foregroundResume:
        return 'foreground_resume';
      case AccountRuntimeTrigger.manualRetry:
        return 'manual_retry';
    }
  }
}

abstract class AccountRepositoryContract {
  Future<AccountLocalSnapshot> loadSnapshot();

  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  });

  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  });

  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  });

  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  });

  Future<AccountLocalSnapshot> deleteAccount({String reason = 'forget_me'});

  Future<void> close();
}
