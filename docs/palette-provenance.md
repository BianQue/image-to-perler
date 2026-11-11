# 色板来源与许可

## 工作台内置数据

工作台使用 [maxcleme/beadcolors](https://github.com/maxcleme/beadcolors) 的 12 套社区色板，共 **1,315 个色号条目**。数量于 2026-11-11 按仓库 CSV 实际行数核对；不是跨系列去重后的 RGB 数量，也不是厂商当前在售颜色数。

原始 CSV 位于 [scripts/data/beadcolors](../scripts/data/beadcolors/)，转换入口为 [convert-palettes.mjs](../scripts/convert-palettes.mjs)，生成结果为 [src/palettes.ts](../src/palettes.ts)。在仓库根目录运行 `npm run palettes` 可重建。转换器读取每行原始色号、名称与 RGB 三列，生成六位大写 HEX，并将色号加上 `系列标识:` 前缀；不根据 RGB 合并色号。

| CSV / 系列标识 | 展示名称 | 色号数 |
| --- | --- | ---: |
| artkal_a | Artkal A | 145 |
| artkal_c | Artkal C | 174 |
| artkal_m | Artkal M | 220 |
| artkal_r | Artkal R | 89 |
| artkal_s | Artkal S | 199 |
| hama | Hama Midi | 92 |
| hama_maxi | Hama Maxi | 25 |
| hama_mini | Hama Mini | 78 |
| nabbi | Nabbi | 30 |
| perler | Perler Midi | 103 |
| perler_mini | Perler Mini | 41 |
| yant | Yant | 119 |
| **合计** | **12 套** | **1,315** |

[third_party/beadcolors/LICENSE](../third_party/beadcolors/LICENSE) 保留 `Copyright (c) 2020 maxcleme` 和完整 MIT 条款。分发数据、生成的 TypeScript 或包含这些数据的 HTML 时须保留版权与许可通知。仓库中没有记录本次导入的上游 commit，因此不能声称已经完成固定版本的上游逐字节核验；后续更新应记录 commit 与文件校验值。

这些是第三方屏幕颜色近似值，不是厂商授权认证，不保证实物、批次、材质或品牌间等价。透明、珠光、金属等效果无法由单一 RGB 完整表达。品牌名仅用于标识数据系列。

## 未获确认的数据与发布边界

MARD 各档色板及其他国产品牌映射的来源和再分发许可尚未确认，**不得作为公开工作台的内置数据**。当前生成入口只读取上述 12 套 CSV，不读取旧 `data/palettes.json` 或 `data/palettes/`。

根目录 `data/` 是保留在本地的旧研究资料，含另一条来源链和 MARD CSV；其中的许可标签不是本次已经确认的授权结论。该目录通过根级 `/data/` 忽略规则排除，不随公开仓库或工作台构建分发，磁盘原件保留。发布时应检查暂存区和发布包，确保没有误纳入这些资料；Git 忽略规则不会自动移除已经被跟踪的文件。公开分发只采用上述 12 套 MIT 数据及其许可证。

three.js 等依赖的许可与色板许可分别保留。单文件产物及携带项目的 HTML 导出都需要检查通知是否实际包含，状态见[实施审查清单](implementation-review.md)。

## 自定义 JSON 色板

使用自己拥有权利或已获许可的数据。以下是格式示例，颜色仅用于演示，并非品牌色卡：

```json
{
  "id": "custom-demo",
  "name": "自定义示例",
  "colors": [
    { "id": "custom-demo:white", "name": "白色", "hex": "#FFFFFF" },
    { "id": "custom-demo:black", "name": "黑色", "hex": "#000000" }
  ]
}
```

色号必须唯一并使用当前色板 `id` 加冒号作为前缀；HEX 必须为 `#` 加六位十六进制数。白色是有效豆色，空格由项目的 `null` 表示。该文件是色板对象，不是 Project v1 项目文件。格式校验以 [src/core.ts](../src/core.ts) 为准，界面导入流程仍需浏览器验收。
