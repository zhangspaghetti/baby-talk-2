import type { CSSProperties, ReactNode } from 'react';

const shellStyle: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'minmax(0, 1.35fr) minmax(360px, 0.95fr)',
  gap: 16,
  alignItems: 'start',
};

type QueuePageShellProps = {
  queue: ReactNode;
  detail: ReactNode;
};

export function QueuePageShell({ queue, detail }: QueuePageShellProps) {
  return (
    <div style={shellStyle}>
      {queue}
      {detail}
    </div>
  );
}

export default QueuePageShell;
