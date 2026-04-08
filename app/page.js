'use client';
import { useState, useEffect, useMemo, useCallback } from 'react';
import LZString from 'lz-string';
import { marked } from 'marked';

marked.setOptions({ breaks: true, gfm: true });

export default function Home() {
  const [md, setMd] = useState('');
  const [links, setLinks] = useState([]);
  const [fresh, setFresh] = useState(null);
  const [copiedId, setCopiedId] = useState(null);
  const [mobileTab, setMobileTab] = useState('edit');
  const [urlLen, setUrlLen] = useState(0);

  useEffect(() => {
    try { const s = localStorage.getItem('mds-links'); if (s) setLinks(JSON.parse(s)); } catch {}
  }, []);

  useEffect(() => {
    if (links.length) localStorage.setItem('mds-links', JSON.stringify(links));
    else localStorage.removeItem('mds-links');
  }, [links]);

  useEffect(() => {
    if (!md.trim()) { setUrlLen(0); return; }
    const t = setTimeout(() => {
      setUrlLen(LZString.compressToEncodedURIComponent(md).length + 60);
    }, 300);
    return () => clearTimeout(t);
  }, [md]);

  const preview = useMemo(() => md.trim() ? marked.parse(md) : '', [md]);

  const generate = useCallback(() => {
    if (!md.trim()) return;
    const c = LZString.compressToEncodedURIComponent(md);
    const url = `${window.location.origin}/view?c=${c}`;
    const m = md.match(/^#{1,3}\s+(.+)$/m);
    const title = m ? m[1].substring(0, 60).trim() : md.split('\n')[0].substring(0, 60).trim() || 'Untitled';
    const id = Date.now().toString(36) + Math.random().toString(36).substr(2, 4);
    setLinks(p => [{ id, title, url, at: new Date().toISOString(), len: md.length }, ...p]);
    setFresh(id);
    setTimeout(() => setFresh(null), 3000);
  }, [md]);

  const copy = useCallback(async (text, id) => {
    try { await navigator.clipboard.writeText(text); } catch {
      const ta = document.createElement('textarea'); ta.value = text;
      document.body.appendChild(ta); ta.select(); document.execCommand('copy');
      document.body.removeChild(ta);
    }
    setCopiedId(id); setTimeout(() => setCopiedId(null), 2000);
  }, []);

  const tooLong = urlLen > 8000;
  const warn = urlLen > 4000 && !tooLong;

  const fmt = (iso) => new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });

  return (
    <div className="app">
      <div className="bg-glow" />
      <header className="header">
        <div className="logo"><span className="logo-icon">◆</span><h1>MDShare</h1></div>
        <p className="tagline">Paste your Markdown · Get a shareable link · Feed it to Illuminate</p>
      </header>

      <main>
        <div className="editor-wrap">
          <div className="tab-bar">
            <div className="tab-btns">
              <button className={`tab ${mobileTab === 'edit' ? 'active' : ''}`} onClick={() => setMobileTab('edit')}>✏️ Editor</button>
              <button className={`tab ${mobileTab === 'preview' ? 'active' : ''}`} onClick={() => setMobileTab('preview')}>👁 Preview</button>
            </div>
            <div className="editor-meta">
              <span className="char-count">{md.length.toLocaleString()} chars</span>
              {urlLen > 0 && <span className={`url-size ${tooLong ? 'error' : warn ? 'warning' : 'ok'}`}>~{(urlLen/1000).toFixed(1)}KB</span>}
            </div>
          </div>

          <div className="editor-body">
            <textarea
              className={`editor-textarea${mobileTab !== 'edit' ? ' mob-hide' : ''}`}
              value={md} onChange={e => setMd(e.target.value)}
              placeholder={"# Paste your markdown here...\n\nStart typing or paste content.\nIt gets compressed into a shareable URL."}
              spellCheck={false}
            />
            <div className={`preview-pane markdown-body desk-show${mobileTab !== 'preview' ? ' mob-hide' : ''}`}
              dangerouslySetInnerHTML={{ __html: preview || '<p class="empty">Preview appears here…</p>' }}
            />
          </div>

          <div className="editor-actions">
            {tooLong && <p className="url-error">⚠️ Content too long for URL encoding. Please shorten your markdown.</p>}
            <button className="btn-gen" onClick={generate} disabled={!md.trim() || tooLong}>
              <span className="sparkle">✦</span> Generate Link
            </button>
          </div>
        </div>

        {links.length > 0 && (
          <section className="links-section">
            <div className="links-header">
              <h2><span>🔗</span> Your Links <span className="link-count">{links.length}</span></h2>
              {links.length > 1 && <button className="btn-clear" onClick={() => setLinks([])}>Clear All</button>}
            </div>
            <div className="links-list">
              {links.map(l => (
                <div key={l.id} className={`link-card${fresh === l.id ? ' fresh' : ''}`}>
                  <div className="link-info">
                    <div className="link-title">{l.title}</div>
                    <div className="link-meta"><span>{fmt(l.at)}</span><span>·</span><span>{l.len.toLocaleString()} chars</span></div>
                  </div>
                  <div className="link-actions">
                    <button className={`btn-act${copiedId === l.id ? ' copied' : ''}`} onClick={() => copy(l.url, l.id)}>
                      {copiedId === l.id ? '✓ Copied' : '📋 Copy'}
                    </button>
                    <a href={l.url} target="_blank" rel="noopener noreferrer" className="btn-act">↗ Open</a>
                    <button className="btn-act btn-del" onClick={() => setLinks(p => p.filter(x => x.id !== l.id))}>🗑</button>
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}
      </main>

      <footer className="footer">
        <p>Built for <a href="https://illuminate.google.com" target="_blank" rel="noopener noreferrer">Google Illuminate</a> · No server storage · Content lives in the URL</p>
      </footer>
    </div>
  );
}
