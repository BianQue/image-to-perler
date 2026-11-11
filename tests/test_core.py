from __future__ import annotations

import unittest

from PIL import Image

from scripts.core import DEFAULT_SIZES, PatternError, create_boards, result_for


class ImageProcessingTests(unittest.TestCase):
    def test_transparency_is_blank_and_opaque_white_is_kept(self) -> None:
        image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for y in range(1, 7):
            for x in range(1, 7):
                image.putpixel((x, y), (255, 255, 255, 255))

        board = create_boards(image, [8], 8, background="none")[0]
        bordered = create_boards(image, [8], 8, background="none", keep_border=True)[0]

        self.assertEqual(len(board["palette"]), 1)
        self.assertEqual(board["palette"][0]["hex"], "#FFFFFF")
        self.assertEqual(bordered["rows"][0], [None] * 8)
        self.assertTrue(all(board["rows"][y][x] == 1 for y in range(8) for x in range(8)))
        self.assertEqual(board["bead_count"], 64)
        self.assertLess(bordered["bead_count"], board["bead_count"])

    def test_semitransparent_pixels_are_composited_over_white(self) -> None:
        image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        image.putpixel((4, 4), (0, 0, 0, 128))
        image.putpixel((3, 4), (0, 0, 0, 255))
        board = create_boards(image, [8], 8, max_colors=4, background="none")[0]
        values = {color["hex"] for color in board["palette"]}

        self.assertIn("#000000", values)
        self.assertTrue(any(value not in {"#000000", "#FFFFFF"} for value in values))
        self.assertIsNone(board["rows"][0][0])
        black_id = next(color["id"] for color in board["palette"] if color["hex"] == "#000000")
        self.assertNotEqual(board["rows"][4][4], black_id)

    def test_default_white_removes_only_connected_near_white_edges(self) -> None:
        image = Image.new("RGB", (12, 12), (244, 244, 244))
        for y in range(3, 9):
            for x in range(3, 9):
                image.putpixel((x, y), (55, 35, 20))
        # A white bead is fully enclosed by the non-white center.
        image.putpixel((5, 5), (255, 255, 255))

        white = create_boards(image, [12], 12, keep_border=True)[0]
        retained = create_boards(image, [12], 12, keep_border=True, background="none")[0]

        self.assertIsNone(white["rows"][0][0])
        self.assertIsNotNone(retained["rows"][0][0])
        self.assertIsNotNone(white["rows"][5][5])
        self.assertEqual(len(white["palette"]), 2)
        self.assertIn("#FFFFFF", {color["hex"] for color in white["palette"]})
        self.assertLess(white["bead_count"], retained["bead_count"])

    def test_default_crops_background_and_contain_centers_wide_image(self) -> None:
        image = Image.new("RGBA", (16, 8), (0, 0, 0, 0))
        for y in range(2, 6):
            for x in range(1, 15):
                image.putpixel((x, y), (190, 35, 20, 255))

        board = create_boards(image, [8], 8, max_colors=4)[0]
        occupied = [(x, y) for y, row in enumerate(board["rows"]) for x, value in enumerate(row) if value]
        xs = [point[0] for point in occupied]
        ys = [point[1] for point in occupied]

        # The transparent border is cropped before contain, so the 14:4
        # subject fills the width and has a two-row letterbox above and below.
        self.assertEqual(min(xs), 0)
        self.assertEqual(max(xs), 7)
        self.assertLessEqual(max(ys) - min(ys), 1)
        self.assertEqual(min(ys), 8 - 1 - max(ys))

    def test_keep_border_preserves_original_canvas_extent(self) -> None:
        image = Image.new("RGBA", (12, 8), (0, 0, 0, 0))
        image.putpixel((4, 4), (20, 30, 40, 255))
        cropped = create_boards(image, [12], 12)[0]
        kept = create_boards(image, [12], 12, keep_border=True)[0]

        self.assertGreater(cropped["bead_count"], kept["bead_count"])
        self.assertEqual(len(cropped["rows"]), len(kept["rows"]))

    def test_multiple_boards_default_and_usage_are_self_consistent(self) -> None:
        image = Image.new("RGBA", (17, 13), (0, 0, 0, 0))
        for y in range(2, 11):
            for x in range(1, 16):
                image.putpixel((x, y), (x * 13 % 256, y * 23 % 256, x * y * 3 % 256, 255))

        result = result_for(image, "many.png", sizes=[8, 12, 16], default_size=12, max_colors=8)

        self.assertEqual([board["size"] for board in result["boards"]], [8, 12, 16])
        self.assertEqual(result["default_size"], 12)
        self.assertEqual(result["source_name"], "many.png")
        for board in result["boards"]:
            with self.subTest(size=board["size"]):
                self.assertEqual(len(board["rows"]), board["size"])
                self.assertTrue(all(len(row) == board["size"] for row in board["rows"]))
                self.assertLessEqual(len(board["palette"]), 8)
                palette_ids = {color["id"] for color in board["palette"]}
                counts = {color_id: 0 for color_id in palette_ids}
                for row in board["rows"]:
                    for color_id in row:
                        if color_id is not None:
                            self.assertIn(color_id, palette_ids)
                            counts[color_id] += 1
                self.assertEqual(board["usage"], {str(key): value for key, value in counts.items()})
                self.assertEqual(sum(board["usage"].values()), board["bead_count"])
                self.assertEqual(sum(counts.values()), board["bead_count"])
                self.assertTrue(all(color["hex"].startswith("#") and len(color["hex"]) == 7 for color in board["palette"]))

    def test_fully_transparent_image_makes_empty_boards(self) -> None:
        board = create_boards(Image.new("RGBA", (10, 6)), [8], 8)[0]
        self.assertEqual(board["palette"], [])
        self.assertEqual(board["usage"], {})
        self.assertEqual(board["bead_count"], 0)
        self.assertTrue(all(cell is None for row in board["rows"] for cell in row))

    def test_invalid_parameters(self) -> None:
        image = Image.new("RGB", (8, 8), "red")
        invalid = (
            {"sizes": [], "default_size": 8},
            {"sizes": [8, 8], "default_size": 8},
            {"sizes": [3], "default_size": 3},
            {"sizes": [8], "default_size": 12},
            {"sizes": [8], "default_size": 8, "max_colors": 3},
            {"sizes": [8], "default_size": 8, "max_colors": 33},
            {"sizes": [8], "default_size": 8, "background": "black"},
        )
        for arguments in invalid:
            with self.subTest(arguments=arguments), self.assertRaises(PatternError):
                create_boards(image, **arguments)

    def test_documented_defaults(self) -> None:
        self.assertEqual(DEFAULT_SIZES, (36, 52, 78, 104, 156))


if __name__ == "__main__":
    unittest.main()
