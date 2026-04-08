'use client';

import { useState, useEffect, useMemo, useCallback } from 'react';
import LZString from 'lz-string';
import { marked } from 'marked';

marked.setOptions({ breaks: true, gfm: true });

export default function Home() {
  const [markdown, setMarkdown] = useState('');
  const [links, setLinks] = useState([]);
  const [justGenerated, setJustGenerated] = useState(null);
  const [copiedId, setCopiedId] = useState(null);
  const [showPreview, setShowPreview] = useState(false);
  const [mounted, setMounted] = useState(false);

  // Load from localStorage on mount
  useEffect(() => {
    setMounted(true);
    try {
      const saved = localStorage.getItem('mdshare-links');
      if (saved) setLinks(JSON.parse(saved));
    } catch {}
  }, []);

  // Persist links
  useEffect(() => {
    if (!mounted) return;
    if (links.length > 0) {
      localStorage.setItem('mdshare-links', JSON.stringify(links));
    }
  }, [links, mounted]);

  // Debounced URL size estimation
  const [estimatedUrlLen, setEstimatedUrlLen] = useState(0);
  useEffect(() => {
    if (!markdown.trim()) { setEstimatedUrlLen(0); return; }
    const t = setTimeout(() => {
      const compressed = LZString.compressToEncodedURIComponent(markdown);
      setEstimatedUrlLen(compressed.length + 50);
    }, 250);
    return () => clearTimeout(t);
  }, [markdown]);

  const previewHtml = useMemo(() => {
    if (!markdown.trim()) return '';
    return marked.parse(markdown);
  }, [markdown]);

  const generateLink = useCallback(() => {
    if (!markdown.trim()) return;
    const compressed = LZString.compressToEncodedURIComponent(markdown);
    const url = `${window.location.origin}/view?c=${compressed}`;

    const titleMatch = markdown.match(/^#{1,3}\s+(.+)$/m);
    const title = titleMatch
      ? titleMatch[1].substring(0, 60).trim()
      : markdown.split('\n')[0].substring(0, 60).trim() || 'Untitled';

    const newLink = {
      id: Date.now().toString(36) + Math.random().toString(36).substr(2, 5),
      title,
      url,
      createdAt: new Date().toISOString(),
      charCount: markdown.length,
    };

    setLinks(prev => [newLink, ...prev]);
    setJustGenerated(newLink.id);
    setMarkdown('');
    setTimeout(() => setJustGenerated(null), 3000);
  }, [markdown]);

  const copyToClipboard = useCallback(async (text, id) => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const ta = document.createElement('textarea');
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
    }
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  }, []);

  const deleteLink = useCallback((id) => {
    setLinks(prev => {
      const updated = prev.filter(l => l.id !== id);
      if (updated.length === 0) localStorage.removeItem('mdshare-links');
      return updated;
    });
  }, []);

  const pasteFromClipboard = useCallback(async () => {
    try {
      const text = await navigator.clipboard.readText();
      setMarkdown(text);
    } catch {}
  }, []);

  const formatDate = (iso) => {
    return new Date(iso).toLocaleDateString('en-US', {
      month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
    });
  };

  const urlTooLong = estimatedUrlLen > 8000;
  const urlWarning = estimatedUrlLen > 4000 && estimatedUrlLen <= 8000;

  return (
    <div className="app">
      <div className="bg-gradient" />

      <header className="header">
        <div className="logo">
          <span className="logo-icon">◆</span>
          <h1>MDShare</h1>
        </div>
        <p className="tagline">Paste your Markdown · Get a shareable link · Feed it to Illuminate</p>
      </header>

      <main>
        <div className="editor-container">
          <div className="editor-header">
            <div className="tab-bar">
              <button className={`tab ${!showPreview ? 'active' : ''}`} onClick={() => setShowPreview(false)}>
                <span className="tab-icon">✏️</span> Editor
              </button>
              <button className={`tab ${showPreview ? 'active' : ''}`} onClick={() => setShowPreview(true)}>
                <span className="tab-icon">👁</span> Preview
              </button>
            </div>
            <div className="editor-meta">
              <span className="char-count">{markdown.length.toLocaleString()} chars</span>
              {estimatedUrlLen > 0 && (
                <span className={`url-size ${urlTooLong ? 'error' : urlWarning ? 'warning' : 'ok'}`}>
                  ~{(estimatedUrlLen / 1000).toFixed(1)}KB
                </span>
              )}
            </div>
          </div>

          <div className="editor-body">
            <textarea
              className={`editor-textarea ${showPreview ? 'mobile-hidden' : ''}`}
              value={markdown}
              onChange={(e) => setMarkdown(e.target.value)}
              placeholder={'# Paste your markdown here...\n\nStart typing or paste content.\nIt gets compressed into a shareable URL.\nNo server storage — everything lives in the link.'}
              spellCheck={false}
              autoFocus
            />
            <div className={`preview-panel ${!showPreview ? 'mobile-hidden' : ''}`}>
              {previewHtml ? (
                <div className="markdown-body" dangerouslySetInnerHTML={{ __html: previewHtml }} />
              ) : (
                <p className="empty-preview">Live preview will appear here…</p>
              )}
            </div>
          </div>

          <div className="editor-actions">
            <button className="btn-paste" onClick={pasteFromClipboard}>
              📋 Paste from Clipboard
            </button>
            {urlTooLong && (
              <p className="url-error">Content too long for URL encoding. Please shorten it.</p>
            )}
            <button
              className="btn-generate"
              onClick={generateLink}
              disabled={!markdown.trim() || urlTooLong}
            >
              <span className="btn-sparkle">✦</span>
              Generate Link
            </button>
          </div>
        </div>

        {mounted && links.length > 0 && (
          <section className="links-section">
            <div className="links-header">
              <h2>
                <span className="section-icon">🔗</span>
                Your Links
                <span className="link-count">{links.length}</span>
              </h2>
              {links.length > 1 && (
                <button
                  className="btn-clear-all"
                  onClick={() => { setLinks([]); localStorage.removeItem('mdshare-links'); }}
                >
                  Clear All
                </button>
              )}
            </div>
            <div className="links-list">
              {links.map(link => (
                <div key={link.id} className={`link-card ${justGenerated === link.id ? 'just-generated' : ''}`}>
                  <div className="link-info">
                    <h3 className="link-title">{link.title}</h3>
                    <div className="link-meta">
                      <span>{formatDate(link.createdAt)}</span>
                      <span>·</span>
                      <span>{link.charCount.toLocaleString()} chars</span>
                    </div>
                  </div>
                  <div className="link-actions">
                    <button
                      className={`btn-action btn-copy ${copiedId === link.id ? 'copied' : ''}`}
                      onClick={() => copyToClipboard(link.url, link.id)}
                    >
                      {copiedId === link.id ? '✓ Copied' : '📋 Copy'}
                    </button>
                    <a href={link.url} target="_blank" rel="noopener noreferrer" className="btn-action btn-open">
                      ↗ Open
                    </a>
                    <button className="btn-action btn-delete" onClick={() => deleteLink(link.id)}>
                      🗑
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}
      </main>

      <footer className="footer">
        <p>
          Built for <a href="https://illuminate.google.com" target="_blank" rel="noopener noreferrer">Google Illuminate</a> · No data stored on servers · Content lives in the URL
        </p>
      </footer>
    </div>
  );
}
