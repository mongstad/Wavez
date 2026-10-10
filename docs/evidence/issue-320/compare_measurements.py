"""Compare accepted/candidate production controls and calculate sampled contrast."""
import argparse
import json
import re
from pathlib import Path
from PIL import Image
p = argparse.ArgumentParser()
p.add_argument('before', type=Path); p.add_argument('after', type=Path)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
before = json.loads((a.before / 'report.json').read_text())
after = json.loads((a.after / 'report.json').read_text())
def luminance(value):
    channels = [int(value[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return sum(weight * (c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4)
               for c, weight in zip(channels, (.2126, .7152, .0722)))
def contrast(foreground, background):
    low, high = sorted((luminance(foreground), luminance(background)))
    return (high + .05) / (low + .05)
def color_hex(serialized):
    return "".join(f"{round(float(c)*255):02x}" for c in serialized.strip("()").split(", ")[:3])
def tint(ink, modulation):
    return ''.join(f'{round(int(ink[i:i+2], 16)*int(modulation[i:i+2], 16)/255):02x}' for i in (0, 2, 4))
rows = []
for name, candidate in after.items():
    if 'foreground' not in candidate: continue
    baseline = before[name]
    assert candidate['rect'] == baseline['rect'], name
    foreground = tint(candidate['foreground'], candidate['tint'])
    old_foreground = tint(baseline['foreground'], baseline['tint'])
    minimum = 3.0 if name.startswith('pin-') else 4.5
    exception = name.endswith('-disabled')
    ratios = [contrast(foreground, bg) for bg in candidate['background_samples']]
    assert ratios and (exception or min(ratios) >= minimum), (name, ratios)
    rows.append(dict(control=name, foreground=candidate['foreground'], tint=candidate['tint'],
                     effective_foreground=foreground, background_samples=candidate['background_samples'],
                     ratios=ratios, before_ratios=[contrast(old_foreground, bg) for bg in baseline['background_samples']],
                     minimum=None if exception else minimum, exception='inactive control' if exception else None))
assert 'input-selected' in {row['control'] for row in rows}
assert before['dark_theme'] == after['dark_theme']
for sample in ['Simulation-1440', 'Simulation-970', 'Simulation-3840']:
    assert after[sample]['foreground'] == '563493'
    for side in ['top', 'right', 'bottom']:
        assert after[f'pin-{side}-{sample.split("-")[-1]}']['foreground'] == after[sample]['foreground']
icon_pairs = []
theme = after['light_theme']
for state in ['checked', 'unchecked']:
    svg = theme['CheckButton']['icons'][state]
    track, knob = re.findall(r'fill="#([0-9a-f]{6})"', svg)
    ratio = contrast(track, knob)
    assert ratio >= 3, (state, track, knob, ratio)
    icon_pairs.append(dict(control='switch-'+state, track=track, knob=knob, ratio=ratio))
for state in ['grabber', 'grabber_highlight']:
    svg = theme['HSlider']['icons'][state]
    fill = re.search(r'fill="#([0-9a-f]{6})"', svg)[1]
    outline = re.search(r'stroke="#([0-9a-f]{6})"', svg)[1]
    track = theme['HSlider']['styles']['slider']['bg_color']
    track_hex = color_hex(track)
    ratio = contrast(outline, track_hex)
    assert ratio >= 3
    icon_pairs.append(dict(control='slider-'+state, body=fill, outline=outline, adjacent_track=track_hex, ratio=ratio))
boundaries = []
for name, type_name, state in [('dropdown-normal','OptionButton','normal'), ('dropdown-hover','OptionButton','hover'), ('dropdown-pressed','OptionButton','pressed'), ('input-normal','LineEdit','normal')]:
    sample = after[name]
    border = color_hex(theme[type_name]['styles'][state]['border_color'])
    effective = tint(border, sample['tint'])
    ratios = [contrast(effective, background) for background in sample['background_samples']]
    assert min(ratios) >= 3, (name, ratios)
    boundaries.append(dict(control=name, border=border, effective_border=effective, adjacent_samples=sample['background_samples'], ratios=ratios))
dark = Image.open(a.before / 'dark-restored.png').tobytes() == Image.open(a.after / 'dark-restored.png').tobytes()
assert dark
scientific = Image.open(a.before / 'expanded-light-1440.png').crop((0,48,1080,796)).tobytes() == Image.open(a.after / 'expanded-light-1440.png').crop((0,48,1080,796)).tobytes()
assert scientific
result = dict(sampled_controls=rows, resolved_icon_pairs=icon_pairs, resolved_boundaries_against_sampled_fills=boundaries,
              dark_theme_resources_identical=True, dark_restored_pixels_identical=dark,
              loaded_scientific_viewport_pixels_identical=scientific,
              pin_heading_relationship_verified=True, pin_keyboard=after['pin_keyboard'],
              requested_4k_actual_window=after['Simulation-3840']['window'],
              measurements='resolved foreground × recorded control tint versus rendered background pixels; solid source artwork pairs reported separately')
a.output.write_text(json.dumps(result, indent=2)+'\n')
print(f'{len(rows)} sampled control/state/layout comparisons, {len(icon_pairs)} artwork pairs; Dark and scientific pixels identical')
