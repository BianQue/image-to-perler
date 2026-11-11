"""Command-line entry point: python -m scripts.cli IMAGE OUTPUT."""

from __future__ import annotations

import argparse
import sys

from .core import DEFAULT_SIZES, MAX_SIZE, MIN_SIZE, PatternError, generate


def _size(value: str) -> int:
    try:
        size = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("尺寸必须是整数") from error
    if not MIN_SIZE <= size <= MAX_SIZE:
        raise argparse.ArgumentTypeError(f"尺寸必须在 {MIN_SIZE} 到 {MAX_SIZE} 之间")
    return size


def _sizes(value: str) -> list[int]:
    values = value.replace("，", ",").split(",")
    if not value.strip() or any(not part.strip() for part in values):
        raise argparse.ArgumentTypeError("尺寸列表使用英文逗号分隔，例如 36,52,78")
    sizes = [_size(part.strip()) for part in values]
    if len(set(sizes)) != len(sizes):
        raise argparse.ArgumentTypeError("尺寸列表不能重复")
    return sizes


def _max_colors(value: str) -> int:
    try:
        count = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("最大颜色数必须是整数") from error
    if not 4 <= count <= 32:
        raise argparse.ArgumentTypeError("最大颜色数必须在 4 到 32 之间")
    return count


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="image-to-perler",
        description="把像素 PNG 或原始照片转换成可编辑的多尺寸拼豆图纸。",
        epilog=(
            "默认裁去透明或清理出的边缘，再将主体等比 contain 到方板并居中；"
            "--keep-border 保留源图完整边缘。"
            "完全不透明图的 white 模式仅移除边缘四连通、RGB 各通道均不低于 242 的近白像素；"
            "带透明度的图直接以 alpha 判定背景，不再清理合成白色；none 保留所有非透明像素。"
            "alpha 0 始终为空，半透明像素先合成白色。"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("source", help="输入像素 PNG 或原始照片")
    parser.add_argument("output", help="新输出目录；目录已存在时拒绝覆盖")
    parser.add_argument(
        "--boards",
        type=_sizes,
        default=list(DEFAULT_SIZES),
        metavar="N,N,...",
        help=f"画板边长列表，默认 {','.join(map(str, DEFAULT_SIZES))}",
    )
    parser.add_argument(
        "--default-size",
        type=_size,
        default=None,
        metavar="N",
        help="默认展示尺寸，必须包含在 --boards 中；默认列表为 104，自定义列表取中间项",
    )
    parser.add_argument(
        "--max-colors",
        type=_max_colors,
        default=24,
        metavar="N",
        help="每个尺寸最多颜色数，4..32，默认 24",
    )
    parser.add_argument(
        "--keep-border",
        action="store_true",
        help="保留完整源图边缘，不先裁去透明或自动清理出的背景",
    )
    parser.add_argument(
        "--background",
        choices=("white", "none"),
        default="white",
        help="white 自动去近白边缘背景（默认）；none 保留全图非透明区域",
    )
    parser.add_argument("--title", help="图纸标题，默认使用源文件名")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    arguments = parser.parse_args(argv)
    fallback_size = (
        104
        if arguments.boards == list(DEFAULT_SIZES)
        else arguments.boards[len(arguments.boards) // 2]
    )
    default_size = (
        arguments.default_size
        if arguments.default_size is not None
        else fallback_size
    )
    if default_size not in arguments.boards:
        parser.error("--default-size 必须包含在 --boards 中")
    try:
        result = generate(
            arguments.source,
            arguments.output,
            sizes=arguments.boards,
            default_size=default_size,
            max_colors=arguments.max_colors,
            keep_border=arguments.keep_border,
            background=arguments.background,
            title=arguments.title,
        )
    except PatternError as error:
        parser.exit(2, f"错误：{error}\n")
    except OSError as error:
        parser.exit(1, f"写入失败：{error}\n")
    counts = "、".join(
        f"{board['size']}×{board['size']}（{board['bead_count']} 颗，{len(board['palette'])} 色）"
        for board in result["boards"]
    )
    print(f"已生成：{arguments.output}")
    print(f"默认尺寸：{result['default_size']}；画板：{counts}")
    print("在浏览器中打开 output/pattern.html 即可编辑与导出。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
