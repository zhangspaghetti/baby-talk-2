import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(currentDir, '..');

function run(command: string, args: string[]) {
  spawnSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
    shell: false,
  });
}

export default async function globalTeardown() {
  run('docker', ['compose', 'stop', 'admin-web', 'admin-api', 'app-api', 'postgres', 'minio']);
  run('docker', ['compose', 'rm', '-sf', 'admin-web', 'admin-api', 'app-api', 'db-migration', 'postgres', 'minio']);
}
