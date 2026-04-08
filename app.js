document.addEventListener('DOMContentLoaded', () => {
    const input = document.getElementById('markdown-input');
    const preview = document.getElementById('preview-pane');
    const genBtn = document.getElementById('gen-btn');
    const charCount = document.getElementById('char-count');
    const urlIndicator = document.getElementById('url-indicator');
    const urlError = document.getElementById('url-error');
    const linksList = document.getElementById('links-list');
    const linksSection = document.getElementById('links-section');
    const linkBadge = document.getElementById('link-badge');
    const clearBtn = document.getElementById('clear-btn');
    const tabEdit = document.getElementById('tab-edit');
    const tabPreview = document.getElementById('tab-preview');

    let history = JSON.parse(localStorage.getItem('mds-links') || '[]');

    const updateUI = () => {
        const value = input.value;
        charCount.innerText = `${value.length.toLocaleString()} chars`;
        
        if (value.trim()) {
            preview.innerHTML = marked.parse(value);
            const compressed = LZString.compressToEncodedURIComponent(value);
            const size = (compressed.length + window.location.href.length) / 1024;
            
            urlIndicator.style.display = 'inline-block';
            urlIndicator.innerText = `~${size.toFixed(1)}KB`;
            
            if (size > 8) {
                urlIndicator.className = 'url-size error';
                urlError.style.display = 'block';
                genBtn.disabled = true;
            } else if (size > 4) {
                urlIndicator.className = 'url-size warning';
                urlError.style.display = 'none';
                genBtn.disabled = false;
            } else {
                urlIndicator.className = 'url-size ok';
                urlError.style.display = 'none';
                genBtn.disabled = false;
            }
        } else {
            preview.innerHTML = '<p class="empty">Preview appears here…</p>';
            urlIndicator.style.display = 'none';
            genBtn.disabled = true;
        }
    };

    const renderLinks = () => {
        if (history.length === 0) {
            linksSection.style.display = 'none';
            return;
        }
        linksSection.style.display = 'block';
        linkBadge.innerText = history.length;
        linksList.innerHTML = history.map(l => `
            <div class="link-card" id="card-${l.id}">
                <div class="link-info">
                    <div class="link-title">${l.title}</div>
                    <div class="link-meta"><span>${new Date(l.at).toLocaleDateString()}</span><span>·</span><span>${l.len} chars</span></div>
                </div>
                <div class="link-actions">
                    <button class="btn-act" onclick="copyLink('${l.url}', '${l.id}')" id="copy-${l.id}">📋 Copy</button>
                    <a href="${l.url}" target="_blank" class="btn-act">↗ Open</a>
                    <button class="btn-act btn-del" onclick="deleteLink('${l.id}')">🗑</button>
                </div>
            </div>
        `).join('');
    };

    window.copyLink = (url, id) => {
        navigator.clipboard.writeText(url).then(() => {
            const btn = document.getElementById(`copy-${id}`);
            btn.innerText = '✓ Copied';
            btn.classList.add('copied');
            setTimeout(() => {
                btn.innerText = '📋 Copy';
                btn.classList.remove('copied');
            }, 2000);
        });
    };

    window.deleteLink = (id) => {
        history = history.filter(h => h.id !== id);
        localStorage.setItem('mds-links', JSON.stringify(history));
        renderLinks();
    };

    genBtn.addEventListener('click', () => {
        const value = input.value;
        const compressed = LZString.compressToEncodedURIComponent(value);
        // Using view.html instead of the root
        const url = `${window.location.origin}${window.location.pathname.replace('index.html', '')}view.html?c=${compressed}`;
        
        const m = value.match(/^#{1,3}\s+(.+)$/m);
        const title = m ? m[1].substring(0, 60) : value.split('\n')[0].substring(0, 60) || 'Untitled';
        
        const newEntry = {
            id: Date.now().toString(36),
            title: title.trim(),
            url: url,
            at: new Date().toISOString(),
            len: value.length
        };

        history = [newEntry, ...history];
        localStorage.setItem('mds-links', JSON.stringify(history));
        renderLinks();
        
        // Visual feedback
        const firstCard = document.getElementById(`card-${newEntry.id}`);
        if(firstCard) {
            firstCard.style.animation = 'slideIn .4s ease';
            firstCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    });

    clearBtn.addEventListener('click', () => {
        if(confirm('Clear all saved links?')) {
            history = [];
            localStorage.removeItem('mds-links');
            renderLinks();
        }
    });

    // Mobile Tabs
    tabEdit.addEventListener('click', () => {
        tabEdit.classList.add('active');
        tabPreview.classList.remove('active');
        input.classList.remove('mob-hide');
        preview.classList.add('mob-hide');
    });

    tabPreview.addEventListener('click', () => {
        tabPreview.classList.add('active');
        tabEdit.classList.remove('active');
        preview.classList.remove('mob-hide');
        input.classList.add('mob-hide');
    });

    input.addEventListener('input', updateUI);
    renderLinks();
});
