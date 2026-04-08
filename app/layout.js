import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'], weight: ['300', '400', '500', '600', '700'] });

export const metadata = {
  title: 'MDShare — Paste & Share Markdown Instantly',
  description: 'Paste your Markdown, get a shareable link. Perfect for Google Illuminate and more. Fast, free, no account needed.',
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  );
}
