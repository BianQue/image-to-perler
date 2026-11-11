# 开发说明

## 环境与命令

推荐 Node.js 24。仓库根目录执行 `npm ci`、`npm run typecheck`、`npm test`、`npm run build`；开发入口为 `npm run dev`。`dist/index.html` 是单文件交付目标。构建成功不等于通过 file://、断网、WebGL 或下载验收。

Python 实验工具需要 Python 3.10+ 和 `pip install -r requirements.txt`。检查命令为 `python -m unittest discover -s tests -v`、`python -m ruff check scripts tests`（Ruff 0.14.14）。

## 项目结构

- `src/core.ts`：Project v1、校验、量化、编辑、变换和用量 CSV。
- `src/palettes.ts`：生成的品牌色板数据。
- `scripts/convert-palettes.mjs`、`scripts/data/beadcolors/`：12 套 CSV 转换入口与原始数据，运行 `npm run palettes` 重建。
- `index.html`、`vite.config.ts`：工作台入口与单文件构建配置。
- `scripts/cli.py`、`core.py`、`html.py`：独立 Python 实验转换器与旧编辑器。
- `tests/`：TypeScript 和 Python 的行为测试。
- `third_party/`：公开分发数据的上游许可；根目录 `data/` 为忽略的本地研究资料，不随仓库和构建发布。

## Project v1 数据契约

以 `src/core.ts` 的 `validateProject` 为准。顶层包含 `version: 1`、`name`、`width`、`height`、`boardSize`、`palette`、`cells`、`completed`。宽、高和物理板边长是 1–256 的整数；默认板边长为 29。格子按行排列，索引为 `y * width + x`，两组数组长度均为 `width * height`。

`cells` 中的 `null` 表示空格，其他值必须引用当前色板中的色号。`completed` 为布尔值，空格不能标记完成。改变格子颜色会重置该格的完成状态；翻转和旋转携带完成状态，调整尺寸保留左上角重叠区域。

色板包含 `id`、`name` 和 `colors`，每个颜色包含 `id`、`name`、六位 HEX。颜色标识以色板标识加冒号开头，例如 `perler:80-19001`。不要按 HEX 合并不同品牌色号。完整导入例子见[色板来源](palette-provenance.md)。

当前量化使用 RGB 欧氏距离，alpha 小于 128 的像素为空格；超过颜色上限时保留首次匹配中最常用的颜色并重新匹配。它不是感知色差算法、自动抠图或实体颜色保证。

项目 JSON 是持久化格式。编辑器快照和下载行为必须按[验收清单](implementation-review.md)实际验证。Project 格式变化需要显式版本与迁移策略。

## Python 实验格式

Python `Board` 包含自身尺寸、调色板、网格和用量，多尺寸集合保存为 `boards.json`。`C01` 等编号仅在实验结果内有效；该格式不能直接作为 Project v1 导入。CSV 空字段代表空格，用量总和应等于非空格数。输出目录必须不存在。

## CI 与交付检查

GitHub Actions 配置 Node.js 24 的类型检查、单元测试、构建、全依赖审计与单文件数量检查，以及三种系统上的 Python 3.10/3.12 测试、Ruff 和示例生成。CI 尚不执行浏览器验收。审计使用 npm 官方 registry，部分镜像没有 audit endpoint。

发布前按[实施审查清单](implementation-review.md)记录实际结果，核对下载文件和许可证，确认素材权限。只有维护者明确授权后才能提交、打标签或发布；本轮工作不执行发布。

## 设计与许可

参见[领域词汇](GLOSSARY.md)与[色板来源说明](palette-provenance.md)。代码为独立实现，不复制未获许可的旧框架、模板、字体、图标或生成器。three.js 等 npm 依赖会进入构建，分发产物时必须保留适用的许可通知；Python 工具通过依赖安装使用 Pillow。色板数据的授权与代码 MIT 许可分开核对。
