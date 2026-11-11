"""Image conversion and deterministic pattern file exports."""

from __future__ import annotations

import json
from collections import Counter, deque
from pathlib import Path
from typing import Any

from PIL import Image, UnidentifiedImageError

DEFAULT_SIZES = (36, 52, 78, 104, 156)
WHITE_THRESHOLD = 242
MIN_SIZE = 4
MAX_SIZE = 256


class PatternError(ValueError):
    """An input or option cannot produce a pattern."""


def _validate_sizes(sizes: list[int] | tuple[int, ...]) -> tuple[int, ...]:
    if not sizes:
        raise PatternError("至少需要一个画板尺寸。")
    if any(type(size) is not int for size in sizes):
        raise PatternError("画板尺寸必须是整数。")
    if len(set(sizes)) != len(sizes):
        raise PatternError("画板尺寸不能重复。")
    if any(not MIN_SIZE <= size <= MAX_SIZE for size in sizes):
        raise PatternError(f"画板尺寸必须在 {MIN_SIZE} 到 {MAX_SIZE} 之间。")
    return tuple(sizes)


def _validate_colors(max_colors: int) -> int:
    if type(max_colors) is not int or not 4 <= max_colors <= 32:
        raise PatternError("最大颜色数必须是 4 到 32 之间的整数。")
    return max_colors


def _validate_default(default_size: int, sizes: tuple[int, ...]) -> int:
    if type(default_size) is not int or default_size not in sizes:
        raise PatternError("默认尺寸必须包含在画板尺寸列表中。")
    return default_size


def _compositor(image: Image.Image) -> Image.Image:
    white = Image.new("RGBA", image.size, (255, 255, 255, 255))
    return Image.alpha_composite(white, image.convert("RGBA"))


def _edge_background_mask(image: Image.Image) -> set[int]:
    """Return four-connected, nearly white pixels reachable from an image edge.

    Opaque white pixels not reached from an edge are deliberately not removed.
    Only fully opaque images should be passed to this function.
    """
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    candidates = {
        y * width + x
        for y in range(height)
        for x in range(width)
        if pixels[x, y][3] == 255
        and min(pixels[x, y][:3]) >= WHITE_THRESHOLD
    }
    queue = deque(
        index
        for index in candidates
        if index % width in (0, width - 1)
        or index // width in (0, height - 1)
    )
    reached: set[int] = set()
    while queue:
        index = queue.popleft()
        if index in reached:
            continue
        reached.add(index)
        x, y = index % width, index // width
        for neighbor in (
            index - 1 if x else -1,
            index + 1 if x + 1 < width else -1,
            index - width if y else -1,
            index + width if y + 1 < height else -1,
        ):
            if neighbor in candidates and neighbor not in reached:
                queue.append(neighbor)
    return reached


def _background(image: Image.Image, mode: str) -> tuple[Image.Image, set[int]]:
    """Composite translucent pixels and identify background pixels to blank."""
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    if alpha.getextrema()[0] == 255:
        if mode == "white":
            return _compositor(rgba), _edge_background_mask(rgba)
        return _compositor(rgba), set()

    # Alpha is always the background. Compositing before quantization makes
    # partially transparent foreground colors comparable to opaque colors.
    composited = _compositor(rgba)
    # Near-white cleanup is intentionally limited to fully opaque inputs. On an
    # image with alpha, compositing translucent pixels to white must not turn a
    # white foreground into background merely because it touches an alpha edge.
    return composited, {
        index for index, value in enumerate(alpha.tobytes()) if value == 0
    }


def _contain(image: Image.Image, size: int, keep_border: bool) -> Image.Image:
    width, height = image.size
    if not keep_border:
        box = image.getbbox()
        if box is not None:
            image = image.crop(box)
            width, height = image.size
    scale = min(size / width, size / height)
    target = (
        max(1, min(size, round(width * scale))),
        max(1, min(size, round(height * scale))),
    )
    # Composite RGB over white, but resize alpha independently. Pillow's RGBA
    # resampling and paste can otherwise propagate opaque white into padding.
    composited = Image.alpha_composite(
        Image.new("RGBA", image.size, (255, 255, 255, 255)), image
    ).convert("RGB")
    rgb = composited.resize(target, Image.Resampling.LANCZOS)
    resized_alpha = image.getchannel("A").resize(target, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - target[0]) // 2, (size - target[1]) // 2)
    canvas.paste(rgb, offset)
    alpha = Image.new("L", (size, size), 0)
    alpha.paste(resized_alpha, offset)
    canvas.putalpha(alpha)
    return canvas


def _make_board(image: Image.Image, size: int, max_colors: int) -> dict[str, Any]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    alpha = rgba.getchannel("A").tobytes()
    color_samples = [
        (*pixels[x, y][:3],)
        for y in range(size)
        for x in range(size)
        if alpha[y * size + x] > 0
    ]
    if color_samples:
        sample = Image.new("RGB", (len(color_samples), 1))
        sample.putdata(color_samples)
        quantized = sample.quantize(
            colors=max_colors,
            method=Image.Quantize.MEDIANCUT,
            dither=Image.Dither.NONE,
        )
        rgb_palette = quantized.getpalette()[: max_colors * 3]
        rgb_palette += [0] * (256 * 3 - len(rgb_palette))
        # Quantize a nontransparent strip, then map every cell to its
        # palette index. This excludes transparent cells from median-cut.
        indices = iter(quantized.tobytes())
        rgb_colors = [tuple(rgb_palette[i : i + 3]) for i in range(0, max_colors * 3, 3)]
        cells: list[int | None] = []
        for y in range(size):
            for x in range(size):
                if pixels[x, y][3] == 0:
                    cells.append(None)
                else:
                    cells.append(next(indices))
    else:
        rgb_colors = []
        cells = [None] * (size * size)

    used = sorted({cell for cell in cells if cell is not None})
    remap = {old: new + 1 for new, old in enumerate(used)}
    rows = [
        [remap.get(cell) for cell in cells[y * size : (y + 1) * size]]
        for y in range(size)
    ]
    usage = Counter(cell for row in rows for cell in row if cell is not None)
    palette = [
        {
            "id": remap[old],
            "name": f"C{remap[old]:02d}",
            "hex": "#{:02X}{:02X}{:02X}".format(*rgb_colors[old]),
        }
        for old in used
    ]
    return {
        "size": size,
        "rows": rows,
        "palette": palette,
        "bead_count": sum(usage.values()),
        "usage": {str(color_id): usage[color_id] for color_id in sorted(usage)},
    }


def create_boards(
    image: Image.Image,
    sizes: list[int] | tuple[int, ...] = DEFAULT_SIZES,
    default_size: int = 104,
    max_colors: int = 24,
    keep_border: bool = False,
    background: str = "white",
) -> list[dict[str, Any]]:
    """Build independent, square boards from an opened Pillow image."""
    sizes = _validate_sizes(sizes)
    _validate_default(default_size, sizes)
    _validate_colors(max_colors)
    if background not in {"white", "none"}:
        raise PatternError("背景模式必须是 white 或 none。")
    if image.width < 1 or image.height < 1:
        raise PatternError("输入图片不能为空。")

    prepared, removed = _background(image, background)
    alpha = image.convert("RGBA").getchannel("A")
    if removed:
        alpha_bytes = bytearray(alpha.tobytes())
        for index in removed:
            alpha_bytes[index] = 0
        alpha = Image.frombytes("L", prepared.size, bytes(alpha_bytes))
    prepared.putalpha(alpha)
    # Keep hidden RGB values from bleeding into visible cells during RGBA resize.
    source = prepared.tobytes()
    cleaned = bytearray(source)
    for index, opacity in enumerate(alpha.tobytes()):
        if opacity == 0:
            cleaned[index * 4 : index * 4 + 3] = b"\0\0\0"
    prepared = Image.frombytes("RGBA", prepared.size, bytes(cleaned))
    return [_make_board(_contain(prepared, size, keep_border), size, max_colors) for size in sizes]


def _pixel_preview(board: dict[str, Any], cell_size: int = 8) -> Image.Image:
    size = board["size"]
    colors = {color["id"]: color["hex"] for color in board["palette"]}
    image = Image.new("RGB", (size * cell_size, size * cell_size), "#FFFFFF")
    for y, row in enumerate(board["rows"]):
        for x, color_id in enumerate(row):
            if color_id is not None:
                image.paste(
                    colors[color_id],
                    (x * cell_size, y * cell_size, (x + 1) * cell_size, (y + 1) * cell_size),
                )
    return image


def _csv_text(board: dict[str, Any], usage: bool = False) -> str:
    import csv
    import io

    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    if usage:
        writer.writerow(["color_id", "name", "hex", "count"])
        for color in board["palette"]:
            writer.writerow(
                [color["id"], color["name"], color["hex"], board["usage"][str(color["id"])]]
            )
    else:
        for row in board["rows"]:
            writer.writerow(["" if cell is None else cell for cell in row])
    return output.getvalue()


def result_for(
    image: Image.Image,
    source_name: str,
    title: str = "拼豆图纸",
    sizes: list[int] | tuple[int, ...] = DEFAULT_SIZES,
    default_size: int = 104,
    max_colors: int = 24,
    keep_border: bool = False,
    background: str = "white",
) -> dict[str, Any]:
    return {
        "boards": create_boards(image, sizes, default_size, max_colors, keep_border, background),
        "default_size": default_size,
        "title": title,
        "source_name": source_name,
    }


def generate(
    source: str | Path,
    output: str | Path,
    *,
    sizes: list[int] | tuple[int, ...] = DEFAULT_SIZES,
    default_size: int = 104,
    max_colors: int = 24,
    keep_border: bool = False,
    background: str = "white",
    title: str | None = None,
) -> dict[str, Any]:
    """Create a new output directory and write all pattern deliverables."""
    from .html import render_html

    source = Path(source)
    output = Path(output)
    sizes = _validate_sizes(sizes)
    _validate_default(default_size, sizes)
    _validate_colors(max_colors)
    if background not in {"white", "none"}:
        raise PatternError("背景模式必须是 white 或 none。")
    if output.exists():
        raise PatternError(f"输出目录已存在，拒绝覆盖：{output}")
    if not source.is_file():
        raise PatternError(f"输入图片不存在或不是文件：{source}")
    if output.parent and not output.parent.exists():
        raise PatternError(f"输出目录的父目录不存在：{output.parent}")

    try:
        with Image.open(source) as opened:
            opened.load()
            image = opened.convert("RGBA")
    except (UnidentifiedImageError, OSError, ValueError) as error:
        raise PatternError(f"无法读取输入图片：{source}") from error

    if image.width > 20000 or image.height > 20000:
        raise PatternError("输入图片边长不能超过 20000 像素。")

    result = result_for(
        image,
        source.name,
        title=title or f"{source.stem} · 拼豆图纸",
        sizes=sizes,
        default_size=default_size,
        max_colors=max_colors,
        keep_border=keep_border,
        background=background,
    )
    created = False
    try:
        output.mkdir()
        created = True
        (output / "output").mkdir()
        (output / "data").mkdir()
        data_text = json.dumps(result, ensure_ascii=False, separators=(",", ":"))
        (output / "data" / "boards.json").write_text(data_text + "\n", encoding="utf-8")
        (output / "output" / "pattern.html").write_text(
            render_html(result), encoding="utf-8"
        )
        for board in result["boards"]:
            directory = output / f"board-{board['size']}"
            directory.mkdir()
            (directory / "grid.csv").write_text(_csv_text(board), encoding="utf-8-sig")
            (directory / "usage.csv").write_text(
                _csv_text(board, usage=True), encoding="utf-8-sig"
            )
            _pixel_preview(board).save(directory / "preview.png", optimize=True)
        manifest = {
            "schema_version": 1,
            "title": result["title"],
            "source_name": result["source_name"],
            "default_size": result["default_size"],
            "options": {
                "sizes": list(sizes),
                "max_colors": max_colors,
                "keep_border": keep_border,
                "background": background,
                "white_threshold": WHITE_THRESHOLD if background == "white" else None,
            },
            "files": {
                "html": "output/pattern.html",
                "data": "data/boards.json",
                "boards": [
                    {
                        "size": board["size"],
                        "directory": f"board-{board['size']}",
                        "grid": f"board-{board['size']}/grid.csv",
                        "usage": f"board-{board['size']}/usage.csv",
                        "preview": f"board-{board['size']}/preview.png",
                        "bead_count": board["bead_count"],
                        "color_count": len(board["palette"]),
                    }
                    for board in result["boards"]
                ],
            },
        }
        (output / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    except Exception:
        if created:
            import shutil

            shutil.rmtree(output)
        raise
    return result
