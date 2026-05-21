# Safety Baseline

## Command Constraints

Allowed command families:

- Version control: `git`
- File viewing and search: `cat`, `head`, `tail`, `grep`, `find`, `ls`, `rg`
- File operations inside this repo: `mkdir`, `cp`, `mv`
- Package/build/test tools already used by the project: `npm`, `pnpm`, `yarn`, `mvn`, `gradle`, `flutter`, `dart`, `python`, `node`, `java`, `javac`

Forbidden commands or patterns:

- `rm -rf /`
- `sudo`
- `curl | bash` or `wget | bash`
- `chmod 777`
- `eval` or shell-level `exec` for generated text
- `git clean -fdx`

Deletion requires explicit human confirmation and must stay inside the project directory.

## Sensitive Information

Never write passwords, API keys, tokens, certificates, or private keys into source, docs, logs, test fixtures, or commit messages. Sensitive values must be passed through environment variables or secret stores.

Before commit, scan staged diffs for:

- API key assignments
- secret assignments
- password assignments
- token assignments
- private key headers
- bearer credentials
- non-localhost plain HTTP URLs

## Dependency Safety

Dependency or lockfile changes must be committed separately and reviewed as supply-chain changes.