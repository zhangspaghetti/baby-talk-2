import os
path = 'test/features/mentor/mentor_shell_panel_test.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

bad_block = """    final gardenGrowthRepo = GardenGrowthRepository(
      practiceRepository: practiceRepository,
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
    );
    final accountNotifier = AccountNotifier(
      repository: _StaticAccountRepository(seedSnapshot: accountSeedSnapshot),
    );
    final gardenGrowthNotifier = GardenGrowthNotifier("""

good_block = """    final gardenGrowthRepo = GardenGrowthRepository(
      practiceRepository: practiceRepository,
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
    );
    final gardenGrowthNotifier = GardenGrowthNotifier("""

text = text.replace(bad_block, good_block)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
