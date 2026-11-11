# 猫咪示例 · 司康

示例中的猫咪名叫 **司康**。`source.jpg` 是项目维护者提供的司康原始照片，用于展示从照片、像素底稿到拼豆图纸的制作流程。

## 示例生成

`pixel.png` 使用 `doubao-seedream-5-0-pro` 以原始照片为参考生成，再处理为透明背景。像素底稿不是本项目转换器自动重绘的结果。

`generated/` 使用以下命令生成：

```bash
python -m scripts.cli examples/cat/pixel.png examples/cat/generated --title "猫咪 · 拼豆图纸"
```

该命令仅在 `generated/` 不存在时可用。重新生成示例时，先在一个新的临时目录验证结果，再更新示例文件。

通用色号不对应任何实体品牌。预览仅用于展示图纸效果，不构成材料颜色或熨烫效果保证。
