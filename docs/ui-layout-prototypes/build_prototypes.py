"""Build portable layout studies using the app's existing artwork (no dependencies)."""
from pathlib import Path
import base64
import mimetypes

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SRC = HERE / 'src'
SKINS = ('rain_radio', 'flower_not_flower', 'vinyl_memories')


def data_url(path):
    mime = mimetypes.guess_type(path.name)[0] or 'application/octet-stream'
    return f'data:{mime};base64,' + base64.b64encode(path.read_bytes()).decode('ascii')


def build():
    rules = []
    for skin in SKINS:
        root = ROOT / 'assets/theme_skins' / skin
        values = {
            'landscape': root / 'backgrounds/landscape.webp',
            'portrait': root / 'backgrounds/portrait.webp',
        }
        for state in ('normal', 'hover', 'pressed'):
            values[f'button-{state}'] = root / 'buttons' / f'{skin.replace("_", "-")}-wide-primary-{state}.png'
        rules.append(f'body[data-skin="{skin}"]{{' + ''.join(f'--{key}:url("{data_url(path)}");' for key, path in values.items()) + '}')
    asset_css = '\n'.join(rules)
    css = (SRC / 'common.css').read_text(encoding='utf-8')
    js = (SRC / 'common.js').read_text(encoding='utf-8')
    shared = (SRC / 'shared.html').read_text(encoding='utf-8')
    for stem in ('01-story-scene', '02-story-journal', '03-story-stage'):
        source = (SRC / f'{stem}.html').read_text(encoding='utf-8')
        source = source.replace('<!-- STYLES -->', f'<style>\n{css}\n{asset_css}\n</style>')
        source = source.replace('<!-- SHARED -->', shared)
        source = source.replace('<!-- SCRIPT -->', f'<script>\n{js}\n</script>')
        target = HERE / f'{stem}.html'
        target.write_text(source, encoding='utf-8')
        print(f'{target.name}: {target.stat().st_size / 1024 / 1024:.2f} MiB')
    index = (SRC / 'index.html').read_text(encoding='utf-8')
    for number, skin in enumerate(SKINS, 1):
        preview = ROOT / 'build/ui-prototype-qa' / f'{number}-desktop.jpg'
        if not preview.exists():
            preview = ROOT / 'assets/theme_skins' / skin / 'backgrounds/landscape.webp'
        index = index.replace(f'{{{{PREVIEW_{number}}}}}', data_url(preview))
    (HERE / 'index.html').write_text(index, encoding='utf-8')


if __name__ == '__main__':
    build()
