"""Focused negative gates for readable, complete and verbatim ZIP notices."""
import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import zipfile

from tools import distribution_licenses as distribution
from tools.sync_about_notices import resource_text

ROOT = Path(__file__).resolve().parents[1]


class DistributionLicensesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.source = self.folder / 'source'
        self.output = self.folder / 'package'
        self.output.mkdir()
        for name in distribution.REQUIRED + ['GETTING_STARTED.md', 'viewer/ui/about/notices.tres',
                                             'viewer/ui/about/Wavez_Banner_No_Slogan_No_Border_Dark.png',
                                             'viewer/ui/about/Wavez_Banner_No_Slogan_No_Border_White.png']:
            target = self.source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        # Small isolated binary fixture; production pin remains unchanged.
        binary = b'isolated test executable'
        (self.output / 'WAVEZ.x86_64').write_bytes(binary)
        (self.output / 'WAVEZ.pck').write_bytes(b'isolated test pack')
        inventory = json.loads((self.source / 'licenses/sources.json').read_text())
        inventory['linux_release_x86_64_sha256'] = distribution.digest(binary)
        (self.source / 'licenses/sources.json').write_text(json.dumps(inventory))
        self.info = dict(version=dict(full='v0.1.0.106'), godot=inventory['godot'],
                         artifacts={p.name: distribution.digest(p.read_bytes())
                                    for p in self.output.glob('WAVEZ.*')})

    def archive(self):
        return distribution.assemble(self.output, self.info, self.source)

    def rewrite(self, archive, changed):
        replacement = self.folder / 'changed.zip'
        with zipfile.ZipFile(archive) as before, zipfile.ZipFile(replacement, 'w') as after:
            for member in before.infolist():
                data = before.read(member)
                result = changed(member, data)
                if result is not None: after.writestr(member, result)
        return replacement

    def test_extractable_verbatim_notices_and_local_links(self):
        archive = self.archive()
        with zipfile.ZipFile(archive) as z:
            z.extractall(self.folder / 'outside-repository')
        root = self.folder / 'outside-repository' / archive.stem
        for name in distribution.REQUIRED:
            self.assertEqual((root / name).read_bytes(), (self.source / name).read_bytes())
        for link in distribution.inventory_links((root / 'THIRD_PARTY_LICENSES.md').read_text()):
            self.assertTrue((root / link).is_file(), link)
        report = distribution.verify_archive(archive, self.source)
        self.assertEqual(report['canonical_notice_digests'], 'PASS')
        expected = distribution.digest(archive.read_bytes())
        self.assertTrue((self.output / 'SHA256SUMS.txt').read_text().startswith(expected))

    def test_central_notice_paths_and_literal_navigation(self):
        archive = self.archive()
        with zipfile.ZipFile(archive) as z:
            members = {n.split('/', 1)[1] for n in z.namelist()}
        for name in distribution.source_notices(self.source)['notices']:
            self.assertTrue(name.startswith('licenses/'), name)
            self.assertIn(name, members)
            self.assertIn('`' + name + '`', (self.source / 'THIRD_PARTY_LICENSES.md').read_text())
        self.assertIn('LICENSE', members)
        self.assertIn('TRADEMARKS.md', members)
        self.assertNotIn('GODOT_LICENSE.txt', members)
        self.assertNotIn('viewer/ui/fonts/LICENSE-DejaVu.txt', members)

    def test_missing_and_truncated_upstream_text_stop_before_zip(self):
        notice = self.source / 'licenses/GODOT_COPYRIGHT.txt'
        original = notice.read_bytes()
        notice.unlink()
        with self.assertRaises(FileNotFoundError): self.archive()
        notice.write_bytes(original[:-1])
        with self.assertRaisesRegex(ValueError, 'changed upstream notice'): self.archive()
        self.assertFalse(list(self.output.glob('*.zip')))

    def test_stale_offline_about_resource_is_rejected(self):
        (self.source / 'viewer/ui/about/notices.tres').write_text('stale')
        with self.assertRaisesRegex(ValueError, 'About notices are stale'): self.archive()

    def test_unaudited_runtime_and_replaced_template_are_rejected(self):
        altered = copy.deepcopy(self.info); altered['godot'] = 'different engine'
        with self.assertRaisesRegex(ValueError, 'audited version'):
            distribution.assemble(self.output, altered, self.source)
        (self.output / 'WAVEZ.x86_64').write_bytes(b'replaced template')
        with self.assertRaisesRegex(ValueError, 'audited official binary'): self.archive()

    def test_broken_inventory_link_is_rejected(self):
        with (self.source / 'THIRD_PARTY_LICENSES.md').open('a') as f:
            f.write('\n[Missing notice](missing/LICENSE.txt)\n')
        (self.source / 'viewer/ui/about/notices.tres').write_text(resource_text(self.source))
        with self.assertRaisesRegex(ValueError, 'Unresolved local inventory link'): self.archive()
        self.assertFalse(list(self.output.glob('*.zip')))

    def test_missing_or_modified_zip_license_is_rejected(self):
        archive = self.archive()
        missing = self.rewrite(archive, lambda member, data:
                               None if member.filename.endswith('/licenses/GODOT_LICENSE.txt') else data)
        with self.assertRaisesRegex(ValueError, 'canonical distribution file'):
            distribution.verify_archive(missing, self.source)
        altered = self.rewrite(archive, lambda member, data:
                               b'shortened text' if member.filename.endswith('/licenses/GODOT_LICENSE.txt') else data)
        with self.assertRaisesRegex(ValueError, 'canonical distribution file'):
            distribution.verify_archive(altered, self.source)

    def test_unreadable_license_and_untracked_member_are_rejected(self):
        archive = self.archive()
        def unreadable(member, data):
            if member.filename.endswith('/licenses/GODOT_LICENSE.txt'):
                member.external_attr = 0o100000 << 16
            return data
        with self.assertRaisesRegex(ValueError, 'Unreadable'):
            distribution.verify_archive(self.rewrite(archive, unreadable), self.source)
        with zipfile.ZipFile(archive, 'a') as z:
            extra = zipfile.ZipInfo(archive.stem + '/unexpected.txt')
            extra.external_attr = 0o100644 << 16
            z.writestr(extra, 'not in manifest')
        with self.assertRaisesRegex(ValueError, 'every ZIP member'):
            distribution.verify_archive(archive, self.source)


if __name__ == '__main__':
    unittest.main()
