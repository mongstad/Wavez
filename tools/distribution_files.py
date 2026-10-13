"""Authoritative standalone file policy and offline Markdown link checks.

Keys are ZIP-relative destinations; values are committed source paths. No globbing.
Developer documentation belongs in the corresponding source archive.
"""
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

SOURCE_FILES = {
    'README.md': 'docs/standalone/README.md',
    'GETTING_STARTED.md': 'docs/standalone/GETTING_STARTED.md',
    'LICENSE': 'LICENSE',
    'TRADEMARKS.md': 'TRADEMARKS.md',
    'THIRD_PARTY_LICENSES.md': 'THIRD_PARTY_LICENSES.md',
    'licenses/GODOT_LICENSE.txt': 'licenses/GODOT_LICENSE.txt',
    'licenses/GODOT_COPYRIGHT.txt': 'licenses/GODOT_COPYRIGHT.txt',
    'licenses/COLORMAPS_LICENSE.txt': 'licenses/COLORMAPS_LICENSE.txt',
    'licenses/LICENSE-DejaVu.txt': 'licenses/LICENSE-DejaVu.txt',
    'licenses/sources.json': 'licenses/sources.json',
    'licenses/README.md': 'licenses/README.md',
}
GENERATED_FILES = {'WAVEZ.x86_64', 'WAVEZ.pck', 'INSTALL.txt', 'BUILD_MANIFEST.json'}
PACKAGE_FILES = frozenset(SOURCE_FILES) | GENERATED_FILES


def anchors(text):
    counts, result = {}, set()
    for title in re.findall(r'^#{1,6}\s+(.+?)\s*#*\s*$', text, re.M):
        title = re.sub(r'<[^>]+>', '', title).lower()
        title = re.sub(r'[^\w\- ]', '', title).replace(' ', '-')
        count = counts.get(title, 0)
        counts[title] = count + 1
        result.add(title + (f'-{count}' if count else ''))
    result.update(re.findall(r'<a\s+(?:name|id)=["\']([^"\']+)', text))
    return result


def verify_document_links(root):
    """Check every Markdown document actually extracted, including images/anchors.

    Web/source URLs are intentional online references, counted but not fetched.
    Relative files must remain inside the package and fragments must resolve.
    """
    root = Path(root).resolve()
    checked, external = 0, 0
    for path in sorted(root.rglob('*.md')):
        text = path.read_text()
        # Examples and HTML comments are not navigation links.
        text = re.sub(r'```.*?```|~~~.*?~~~|<!--.*?-->', '', text, flags=re.S)
        targets = re.findall(r'\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+["\'][^)]*)?\s*\)', text)
        targets += re.findall(r'^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)', text, re.M)
        targets += re.findall(r'(?:href|src|srcset)=["\']([^"\']+)["\']', text)
        for raw in targets:
            url = urlsplit(raw.strip('<>'))
            if url.scheme or url.netloc:
                external += 1
                continue
            local = unquote(url.path)
            target = (path.parent / local).resolve() if local else path
            label = f'{path.relative_to(root)} -> {raw}'
            if not target.is_relative_to(root) or not target.is_file():
                raise ValueError(f'Unresolved offline document link: {label}')
            if url.fragment and target.suffix == '.md' and unquote(url.fragment) not in anchors(target.read_text()):
                raise ValueError(f'Unresolved offline document anchor: {label}')
            checked += 1
    return dict(offline_document_links=checked, external_document_links=external,
                offline_document_links_status='PASS')
