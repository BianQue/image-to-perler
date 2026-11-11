# 变更记录

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的格式，并在发布后使用语义化版本。

## [Unreleased]

### Added

- TypeScript / Vite / three.js 独立工作台与 Project v1；新增 UI 的最终浏览器验收尚未完成。
- beadcolors 的 12 套 MIT 色板，共 1,315 个色号条目，以及来源、转换和许可边界说明。
- 实施审查清单，区分自动化检查、旧构建冒烟结果与最终产物待验收项目。

### Changed

- 开发与 CI 使用 Node.js 24、Vitest 5.1；Python 示例统一以 `python -m scripts.cli` 调用。
- CI 示例输出路径通过 Python 环境变量读取，兼容 Windows、macOS 和 Linux。

### Earlier experimental additions

- 独立的图片转拼豆 Python 转换器。
- 多尺寸网格、通用色号、用量统计和像素预览。
- 无网络依赖的 HTML 编辑器，支持涂色、撤销和多种导出。
- Trae Skill、中文与英文使用文档。
- 猫咪公开示例和自动化测试。
