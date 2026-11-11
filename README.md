# image-to-perler

把图片变成可编辑、可保存的拼豆项目。

这是独立重写中的本地拼豆工作台，使用 TypeScript、Vite 和 three.js 开发。交付目标是可直接打开的单文件离线 HTML，保留品牌色板、3D 预览和高级编辑方向，并提供 Trae Skill 入口。无需账号或公共后端。

**初始公开版本。** 已实现图片转换、矩形/套索选区、移动填充删除、色板映射、撤销重做、3D 网格编辑与熔豆外观预览。主执行代理已完成源码审阅、自动化检查与 Chromium 离线保存往返验证；具体覆盖及限制见[验收记录](docs/implementation-review.md)。

[English](README_EN.md) · [贡献指南](CONTRIBUTING.md) · [开发说明](docs/development.md)

## 构建离线工作台

安装 Node.js 24。在仓库根目录运行：

```bash
npm ci
npm run typecheck
npm test
npm run build
```

构建产物为 `dist/index.html`。在浏览器中打开该文件。依赖安装需要网络，离线交付要求最终 HTML 内嵌运行资源，不依赖开发服务器或 CDN。发布前必须断网验证实际产物。

开发时运行 `npm run dev`。开发服务器不是最终用户的运行前提。

## 保存作品

作品以带版本的 Project JSON 保存。单文件 HTML 可以携带项目快照，但不能替代项目文件作为长期存档。

- 豆格使用作品全局坐标，物理板只负责分区、排版和拼接。
- `null` 表示不放豆，白色是有效颜色，两者不可混同。
- 色号属于具体品牌和系列，不能仅凭相同 RGB 合并。
- 制作完成状态按格保存，与颜色编辑分开。

编辑和导出的具体操作以当前界面为准。关闭页面前导出项目，不要把浏览器临时状态当成已保存文件。数据格式见[开发说明](docs/development.md)。

## 在 Trae 中使用

将仓库目录放到项目的 `.trae/skills/image-to-perler`，或当前 Trae 版本支持的个人 skills 目录。按 Trae 的加载方式启用后，上传你有权处理的图片，并说明尺寸、品牌和颜色数要求。

```text
使用 image-to-perler 把这张图片转成拼豆项目，保留透明空格，并说明使用的色板来源。
```

[SKILL.md](SKILL.md) 描述代理流程。Skill 应区分新工作台与下面的 Python 实验转换器，不能把两种产物格式混用。

## 色板与实物

仓库保留了 `beadcolors` 的 12 套 MIT 数据源（共 1,315 个色号条目）和许可证。它们是第三方收集的屏幕色值，不代表厂商官方认证，也不保证实体豆、批次或不同品牌之间的物理等价。

MARD 各档色板和国产品牌映射的再分发许可尚未确认，**不纳入公开工作台内置数据**；根目录 `data/` 为已忽略的本地研究资料，不随公开仓库和构建分发。可通过符合格式的 JSON 色板提供自有或获授权数据。格式、来源与公开版缺口见[色板来源说明](docs/palette-provenance.md)。购买材料前请核对实体色卡，并为损耗预留余量。

## 使用 Python 实验转换器

`scripts/` 保留独立 Python 实验转换器，不是新工作台的构建入口。它使用 Pillow 生成多尺寸网格、通用色号、CSV、预览和旧实验 HTML。其 `boards.json` 不等同于新 Project v1。

安装 Python 3.10 或更高版本，在仓库根目录运行：

```bash
python -m pip install -r requirements.txt
python -m scripts.cli input.png output/my-pattern --boards 36,52,78 --default-size 52 --max-colors 16
python -m scripts.cli --help
```

输出目录必须不存在。实验 HTML 位于 `output/my-pattern/output/pattern.html`。该转换器的 `C01` 等色号不是品牌原生色号。

透明图片按 alpha 区分空格。不透明图片默认仅清理与边缘四连通的近白背景，不能替代通用抠图。使用 `--background none` 保留全部非透明区域。

## 示例与许可

代码采用 [MIT License](LICENSE)。第三方色板保留独立许可，three.js 等依赖遵循各自的许可证。独立重写不复制旧框架代码、字体或图标。

[猫咪实验示例](examples/cat/README.md) 记录了维护者的素材授权声明。本轮重写未重新核实原始授权来源，发布前需完成确认。示例由 Python 实验流程生成，不能作为新工作台已验收的证据。
