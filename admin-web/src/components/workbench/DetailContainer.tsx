import { Card, type CardProps } from 'antd';
import type { ReactNode } from 'react';

type DetailContainerProps = {
  title: ReactNode;
  extra?: ReactNode;
  children: ReactNode;
  testId?: string;
} & Pick<CardProps, 'size'>;

export function DetailContainer({ title, extra, children, size = 'default', testId }: DetailContainerProps) {
  return (
    <Card title={title} extra={extra} size={size} data-testid={testId}>
      {children}
    </Card>
  );
}

export default DetailContainer;
