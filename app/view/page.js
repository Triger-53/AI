import LZString from 'lz-string';
import { marked } from 'marked';
import Link from 'next/link';

marked.setOptions({ breaks: true, gfm: true });

export async function generateMetadata({ searchParams }) {
  const { c } = searchParams;
  if (!c) return { title: 'No Content — MDShare', robots: { index: false } };

  try {
    const markdown = LZString.decompressFromEncodedURIComponent(c);
    if (!markdown) return { title: 'Invalid Link — MDShare', robots: { index: false } };

    const titleMatch = markdown.match(/^#{1,3}\s+(.+)$/m);
    const title = titleMatch ? titleMatch[1].trim() : 'Shared Document';
    const lines = markdown.split('\n').filter(l => l.trim() && !l.startsWith('#'));
    const description = lines[0]?.substring(0, 160) || 'Shared markdown content via MDShare';

    return {
      title: `${title} — MDShare`,
      description,
      robots: { index: true, follow: true },
      openGraph: { title, description, type: 'article' },
    };
  } catch {
    return { title: 'Error — MDShare' };
  }
}

export default function ViewPage({ searchParams }) {
  const { c } = searchParams;

  if (!c) {
    return (
      <div className="view-page">
        <div className="bg-gradient" />
        <nav className="view-nav">
          <Link href="/" className="view-logo"><span className="logo-icon">◆</span> MDShare</Link>
        </nav>
        <div className="view-error">
          <h1>No Content Found</h1>
          <p>This link doesn&apos;t contain any markdown content.</p>
          <Link href="/" className="btn-home">← Create a new document</Link>
        </div>
      </div>
    );
  }

  let markdown;
  try {
    markdown = LZString.decompressFromEncodedURIComponent(c);
  } catch {
    markdown = null;
  }

  if (!markdown) {
    return (
      <div className="view-page">
        <div className="bg-gradient" />
        <nav className="view-nav">
          <Link href="/" className="view-logo"><span className="logo-icon">◆</span> MDShare</Link>
        </nav>
        <div className="view-error">
          <h1>Invalid Link</h1>
          <p>This link appears to be corrupted or invalid.</p>
          <Link href="/" className="btn-home">← Create a new document</Link>
        </div>
      </div>
    );
  }

  const html = marked.parse(markdown);

  return (
    <div className="view-page">
      <div className="bg-gradient" />
      <nav className="view-nav">
        <Link href="/" className="view-logo"><span className="logo-icon">◆</span> MDShare</Link>
        <Link href="/" className="btn-create">+ Create New</Link>
      </nav>
      <article
        className="view-content markdown-body"
        dangerouslySetInnerHTML={{ __html: html }}
      />
      <footer className="view-footer">
        <p>Shared via <Link href="/">MDShare</Link> · No server storage — content lives in the URL</p>
      </footer>
    </div>
  );
}
