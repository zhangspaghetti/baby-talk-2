import 'dart:io';

import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';

HouseholdRepository createLocalHouseholdRepository({
  required AccountRepository accountRepository,
  required Directory directory,
  String? apiBaseUrl,
}) {
  return HouseholdRepository(
    localStore: HouseholdLocalStore(directoryResolver: () async => directory),
    apiService: HouseholdApiService(baseUrl: apiBaseUrl),
    accountSnapshotLoader: accountRepository.loadSnapshot,
    persistRefreshedSession: accountRepository.persistRefreshedSession,
  );
}
