(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const configuredTheme = '{{MERMAID_THEME}}';
    let generation = 0;

    function sourceFor(block) {
        if (block.dataset.mermaidSource !== undefined) {
            return block.dataset.mermaidSource;
        }
        const source = block.querySelector('.mermaid-source code')?.textContent ?? '';
        block.dataset.mermaidSource = source;
        return source;
    }

    function restoreSource(block, source) {
        block.replaceChildren();
        const pre = document.createElement('pre');
        pre.className = 'mermaid-source';
        const code = document.createElement('code');
        code.className = 'language-mermaid';
        code.textContent = source;
        pre.appendChild(code);
        const error = document.createElement('p');
        error.className = 'mermaid-error';
        error.setAttribute('role', 'status');
        error.textContent = 'Could not render Mermaid diagram. Showing source.';
        block.append(pre, error);
    }

    async function renderAll() {
        if (!window.mermaid) {
            return;
        }
        const currentGeneration = ++generation;
        const useDarkTheme = configuredTheme === 'dark'
            || (configuredTheme === 'auto' && media.matches);
        const theme = useDarkTheme ? 'dark' : 'default';
        window.mermaid.initialize({
            startOnLoad: false,
            securityLevel: 'strict',
            suppressErrorRendering: true,
            theme,
            flowchart: { htmlLabels: false }
        });

        const blocks = document.querySelectorAll('[data-mermaid-diagram]');
        for (const [index, block] of blocks.entries()) {
            const source = sourceFor(block);
            try {
                const id = `marklens-mermaid-${currentGeneration}-${index}`;
                const { svg, bindFunctions } = await window.mermaid.render(id, source);
                if (currentGeneration !== generation) {
                    return;
                }
                block.innerHTML = svg;
                block.classList.add('is-rendered');
                bindFunctions?.(block);
            } catch (_) {
                if (currentGeneration === generation) {
                    block.classList.remove('is-rendered');
                    restoreSource(block, source);
                }
            }
        }
    }

    document.addEventListener('DOMContentLoaded', renderAll);
    if (configuredTheme === 'auto') {
        media.addEventListener?.('change', renderAll);
    }
})();
