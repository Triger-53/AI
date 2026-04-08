import LZString from 'lz-string';
import { marked } from 'marked';
import Link from 'next/link';

marked.setOptions({ breaks: true, gfm: true });

export async function generateMetadata({ searchParams }) {
  const { c } = searchParams;
  if (!c) return { title: 'No Content — MDShare', robots: { index: false } };
  try {
    const md = LZString.decompressFromEncodedURIComponent(c);
    if (!md) return { title: 'Invalid — MDShare', robots: { index: false } };
    const m = md.match(/^#{1,3}\s+(.+)$/m);
    const title = m ? m[1].trim() : 'Shared Document';
    const lines = md.split('\n').filter(l => l.trim() && !l.startsWith('#'));
    const desc = lines[0]?.substring(0, 160) || 'Shared markdown content via MDShare';
    return {
      title: `${title} — MDShare`,
      description: desc,
      robots: { index: true, follow: true },
      openGraph: { title, description: desc, type: 'article' },
    };
  } catch { return { title: 'Error — MDShare' }; }
}

export default function ViewPage({ searchParams }) {
  const { c } = searchParams;

  if (!c) return (
    <div className="view-page">
      <div className="view-error">
        <h1>No Content Found</h1>
        <p>This link doesn&apos;t contain any markdown content.</p>
        <Link href="/" className="btn-home">← Create New</Link>
      </div>
    </div>
  );

  let md;
  try { md = LZString.decompressFromEncodedURIComponent(c); } catch { md = null; }

  if (!md) return (
    <div className="view-page">
      <div className="view-error">
        <h1>Invalid Link</h1>
        <p>This link appears to be corrupted.</p>
        <Link href="/" className="btn-home">← Create New</Link>
      </div>
    </div>
  );

  const html = marked.parse(md);

  return (
    <div className="view-page">
      <nav className="view-nav">
        <Link href="/" className="view-logo"><span className="logo-icon">◆</span> MDShare</Link>
        <Link href="/" className="btn-create">+ Create New</Link>
      </nav>
      <article className="view-content markdown-body" dangerouslySetInnerHTML={{ __html: html }} />
      <footer className="view-footer">
        <p>Shared via <Link href="/">MDShare</Link> · No server storage</p>
      </footer>
    </div>
  );
}
