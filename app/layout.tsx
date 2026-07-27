import type { Metadata } from 'next';
import './styles.css';

export const metadata: Metadata = {
  title: 'VIVID+ | Rewards & Membership',
  description: 'VIVID+ digital membership, rewards, events, and VIP experiences.'
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
