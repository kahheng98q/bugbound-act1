import type { ReactNode } from 'react';
import './globals.css';

export const metadata = {
  title: 'BUGBOUND // Demo 2',
  description: 'A programmer roguelike deckbuilder prototype about exploiting high-risk, high-reward bugs.',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
