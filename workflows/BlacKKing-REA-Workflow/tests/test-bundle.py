"""Pure boundary controls; never create a directory in the source repository."""
import importlib.util
from pathlib import Path
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "scripts/build-bundle.py"
spec = importlib.util.spec_from_file_location("blackking_bundle_test", SOURCE)
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


class BundleBoundaries(unittest.TestCase):
    def test_canonical_destination_boundaries(self):
        root = SOURCE.parents[3].resolve()
        cases = [
            (root / "generated-review-fixture", True),
            (root.parent / "outside-review-fixture", False),
            (root.parent / "outside-review-fixture" / ".." / root.name / "generated-review-fixture", True),
            (root / ".." / "outside-review-fixture", False),
            (root.parent / "." / root.name / "generated-review-fixture", True),
        ]
        for path, inside in cases:
            with self.subTest(path=path):
                self.assertEqual(bundle.plain(path).is_relative_to(root), inside)
                self.assertNotIn("..", bundle.plain(path).parts)

    def test_unsafe_archive_names(self):
        for name in ["/absolute", "../escape", "a/../escape", "a//b", "C:/escape", "a\\b",
                     "a:stream", "AUX.txt", "a/NUL", "a/trailing.", "a/trailing ", "a/./b"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                bundle.logical(name)
        self.assertEqual(bundle.logical("folder with spaces/file.txt").as_posix(), "folder with spaces/file.txt")

    def test_member_owner_collision_and_type(self):
        bad = [
            [("other/file", False, True, None)],
            [("package/file", False, False, None)],
            [("package/A", False, True, None), ("package/a", False, True, None)],
            [("package/a/../../escape", False, True, None)],
        ]
        for members in bad:
            with self.subTest(members=members), self.assertRaises(ValueError):
                bundle.project_members(members, "package")


if __name__ == "__main__":
    unittest.main()
