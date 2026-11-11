# 实施审查与验收记录

日期：2026-11-11。主执行代理亲自审阅核心、编辑入口、Three.js 视图与样式，并执行以下检查。此版本为初始公开版本，不宣称与旧私有实现完全等价。

## 自动化检查

- `npm run build`：通过，包含 TypeScript 类型检查，输出单个约 634 kB 的 `dist/index.html`。
- `npm test`：13 项通过。
- `python -m unittest discover -s tests -v`：16 项通过。
- `python -m ruff check scripts tests`：通过。
- `npm audit --registry=https://registry.npmjs.org`：全依赖零漏洞。
- 12 套 MIT 色板共 1,315 个色号；根目录研究资料 `data/` 已排除，保留本地原件。

## 浏览器实测

Windows、Playwright Chromium，最终构建以 `file://` 打开；保存往返测试启用 `offline=True`。

- 绘制 1 颗 → 撤销 0 → 重做 1。
- 矩形选区填充 9 颗 → 删除 0 → 撤销 9；映射至 Perler Midi 后用量保持 9。
- 3D 编辑空格添加 1 颗（总数 10）→ 撤销回 9。
- Shift 直线绘制 5 颗，套索包围后删除至 0。
- 自制 3×2 透明 PNG 导入后为 2 颗豆和 4 个空格；不透明白色保留为豆。
- 制作标记、矩形旋转后的尺寸及完成数量正确。
- Project JSON 导出、重新导入、再次导出，解析对象完全一致。
- PNG 输出尺寸 96×64，CSV 包含真实用量列。
- 项目名含 `</script>` 与尖括号，导出 HTML 再离线打开后名称和 2 颗豆正确，无脚本注入或页面错误。
- 导出的单文件包含 three.js、beadcolors 的版权声明与完整 MIT 许可。
- 熔豆滑杆可调整至 100，截图中显示白色与红色两颗立体豆及网格；这是外观模拟。
- 390px 窄屏发现横向溢出并修正，复验页面 scrollWidth 为 390px。
- 上述保存往返测试没有 pageerror。

## 审查边界与后续覆盖

- 熔豆不是热力学仿真，不包含旧版全部熔豆样式。
- 选区创建/移动仅限二维；去孤点定义为八邻域均为空的单颗豆。
- 选区移动、平移、孤点清理已实现并静态审阅，未在本轮逐项完成浏览器自动化覆盖。
- 尚未穷尽跨板编辑、WebGL 不可用、打印分页、全部辅助技术与其他浏览器组合。
- 远程 CI 运行状态以 GitHub Actions 实际结果为准。
- 猫咪素材保留维护者提供的 MIT 授权声明；第三方色板来源与许可详见 [palette-provenance.md](palette-provenance.md)。
