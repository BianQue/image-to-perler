from __future__ import annotations

import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from scripts.core import PatternError, generate


ROOT = Path(__file__).resolve().parents[1]


class CommandLineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.source = self.directory / "像素.png"
        image = Image.new("RGBA", (24, 16), (0, 0, 0, 0))
        for y in range(3, 13):
            for x in range(2, 22):
                image.putpixel((x, y), ((x * 11) % 256, (y * 19) % 256, 100, 255))
        image.save(self.source)
        self.output = self.directory / "pattern"

    def run_cli(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, "-m", "scripts.cli", *arguments],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
            timeout=90,
        )

    def test_cli_writes_real_html_json_csv_previews_and_manifest(self) -> None:
        completed = self.run_cli(
            str(self.source),
            str(self.output),
            "--boards",
            "8,12",
            "--default-size",
            "12",
            "--max-colors",
            "8",
            "--title",
            "测试 <图纸>",
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("默认尺寸：12", completed.stdout)

        html_path = self.output / "output" / "pattern.html"
        html = html_path.read_text(encoding="utf-8")
        self.assertTrue(html.startswith("<!doctype html>"))
        self.assertIn('<html lang="zh-CN">', html)
        self.assertIn("测试 &lt;图纸&gt;", html)
        self.assertIn('id="pattern-data"', html)
        self.assertIn("exportShare", html)
        self.assertIn("exportHTML", html)
        self.assertIn("event.ctrlKey||event.metaKey", html)
        self.assertNotIn("localStorage", html)
        self.assertNotIn("<script src=", html)
        self.assertNotIn("<link rel=", html)

        result = json.loads((self.output / "data" / "boards.json").read_text(encoding="utf-8"))
        start = html.index('<script id="pattern-data" type="application/json">')
        start = html.index(">", start) + 1
        end = html.index("</script>", start)
        embedded = json.loads(html[start:end])
        self.assertEqual(embedded, result)
        self.assertEqual(result["default_size"], 12)
        self.assertEqual(result["source_name"], self.source.name)
        self.assertEqual([board["size"] for board in result["boards"]], [8, 12])

        manifest = json.loads((self.output / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["default_size"], 12)
        self.assertEqual(manifest["options"]["max_colors"], 8)
        self.assertEqual(manifest["options"]["white_threshold"], 242)
        self.assertEqual(manifest["files"]["html"], "output/pattern.html")
        for entry in manifest["files"]["boards"]:
            with (self.output / entry["usage"]).open(encoding="utf-8-sig", newline="") as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(sum(int(row["count"]) for row in rows), entry["bead_count"])
            self.assertEqual(len(rows), entry["color_count"])
            self.assertTrue((self.output / entry["grid"]).is_file())
            self.assertTrue((self.output / entry["preview"]).is_file())

        for board in result["boards"]:
            with self.subTest(size=board["size"]):
                size = board["size"]
                directory = self.output / f"board-{size}"
                with (directory / "grid.csv").open(encoding="utf-8-sig", newline="") as stream:
                    grid = list(csv.reader(stream))
                with (directory / "usage.csv").open(encoding="utf-8-sig", newline="") as stream:
                    usage = list(csv.DictReader(stream))
                self.assertEqual(len(grid), size)
                self.assertTrue(all(len(row) == size for row in grid))
                flattened = [int(value) if value else None for row in grid for value in row]
                self.assertEqual(flattened, [value for row in board["rows"] for value in row])
                self.assertEqual(sum(int(row["count"]) for row in usage), board["bead_count"])
                self.assertEqual({int(row["color_id"]) for row in usage}, {color["id"] for color in board["palette"]})
                with Image.open(directory / "preview.png") as preview:
                    self.assertEqual(preview.format, "PNG")
                    self.assertEqual(preview.size, (size * 8, size * 8))

    def test_existing_output_is_rejected_without_changing_it(self) -> None:
        self.output.mkdir()
        marker = self.output / "keep.txt"
        marker.write_text("不要覆盖", encoding="utf-8")
        completed = self.run_cli(str(self.source), str(self.output), "--boards", "8,12")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("已存在", completed.stderr)
        self.assertEqual(marker.read_text(encoding="utf-8"), "不要覆盖")
        self.assertFalse((self.output / "manifest.json").exists())

    def test_cli_default_size_is_middle_board_and_default_colors_24(self) -> None:
        completed = self.run_cli(str(self.source), str(self.output), "--boards", "8,12,16")
        self.assertEqual(completed.returncode, 0, completed.stderr)
        result = json.loads((self.output / "data" / "boards.json").read_text(encoding="utf-8"))
        manifest = json.loads((self.output / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(result["default_size"], 12)
        self.assertEqual(manifest["options"]["max_colors"], 24)

    def test_default_size_is_104_without_processing_all_large_boards(self) -> None:
        from unittest.mock import patch

        from scripts.cli import main

        with patch("scripts.cli.generate") as mocked_generate:
            mocked_generate.return_value = {"boards": [], "default_size": 104}
            self.assertEqual(main([str(self.source), str(self.output)]), 0)
        self.assertEqual(mocked_generate.call_args.kwargs["sizes"], [36, 52, 78, 104, 156])
        self.assertEqual(mocked_generate.call_args.kwargs["default_size"], 104)
        self.assertEqual(mocked_generate.call_args.kwargs["max_colors"], 24)

    def test_invalid_cli_parameters(self) -> None:
        cases = (
            ("--boards", ""),
            ("--boards", "8,8"),
            ("--boards", "3,12"),
            ("--boards", "8,12", "--default-size", "16"),
            ("--max-colors", "3"),
            ("--max-colors", "33"),
            ("--background", "black"),
        )
        for index, arguments in enumerate(cases):
            with self.subTest(arguments=arguments):
                completed = self.run_cli(str(self.source), str(self.directory / f"bad-{index}"), *arguments)
                self.assertEqual(completed.returncode, 2)
                self.assertTrue(completed.stderr)
                self.assertFalse((self.directory / f"bad-{index}").exists())

    def test_missing_or_invalid_input_is_an_error(self) -> None:
        missing = self.run_cli(str(self.directory / "missing.png"), str(self.output))
        self.assertEqual(missing.returncode, 2)
        invalid_source = self.directory / "invalid.png"
        invalid_source.write_text("not an image", encoding="utf-8")
        invalid = self.run_cli(str(invalid_source), str(self.output))
        self.assertEqual(invalid.returncode, 2)
        self.assertIn("无法读取", invalid.stderr)
        self.assertFalse(self.output.exists())

    def test_generate_validates_before_creating_output(self) -> None:
        with self.assertRaises(PatternError):
            generate(self.source, self.output, sizes=[8], default_size=12)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
