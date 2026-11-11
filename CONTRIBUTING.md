# 贡献指南

小修复可以直接提交 PR。涉及 Project 格式、色板来源或交互方向的变化，请先说明问题和预期行为。

## 配置开发环境

使用 Node.js 24，在仓库根目录运行：

```bash
npm ci
npm run typecheck
npm test
npm run build
```

使用 `npm run dev` 开发界面。最终验证对象是 `dist/index.html`，需要直接打开并断网测试。

修改 Python 实验转换器时，使用 Python 3.10 或更高版本运行：

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s tests -v
python -m pip install ruff==0.14.14
python -m ruff check scripts tests
python -m scripts.cli --help
```

## 检查改动

- 用自制的小型透明 PNG 验证空格和白色豆的区别。
- 为转换、编辑和项目读写补充可观察行为的测试。
- 修改编辑器后验证跨板编辑、撤销重做、3D 与实际下载文件。
- 核对导出中的格数、色号引用、完成状态和用量总数。
- 修改 Project 格式时更新版本和迁移说明，不静默重解释已有文件。
- 检查 README、Skill 和实际界面的说明是否一致。
- 记录运行的命令与结果，把未运行的验收项明确列出。

完整交付要求见[实施审查清单](docs/implementation-review.md)。

## 遵守数据与许可边界

以[开发说明](docs/development.md)和[领域词汇](docs/GLOSSARY.md)为设计依据。Project 使用全局豆格坐标，物理板分区不改变作品坐标。

不要复制旧框架、未获许可的模板、字体、图标或色板。新增依赖时说明用途与许可。色板贡献必须记录来源、系列、再分发许可与转换方法，并保留上游通知。屏幕 RGB 不代表官方认证或实体颜色等价。具体缺口见[色板来源说明](docs/palette-provenance.md)。

不要提交密钥、个人路径、缓存、虚拟环境或未经授权的素材。素材授权与代码许可分开确认。

## 提交 PR

使用简短、明确的标题。描述用户问题、改动范围、验证命令和已知限制。不要把无关重构与行为修改混在一起。

提交贡献表示你有权贡献相关内容，并同意项目按 MIT License 分发代码。第三方数据和素材保留各自许可，不能仅凭本项目的 MIT License 重新授权。
