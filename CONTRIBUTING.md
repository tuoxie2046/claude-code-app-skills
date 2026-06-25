# 贡献指南：如何加一个技能

本仓库每个技能是一个**顶层目录**，目录名 = 技能名（kebab-case）。下面是加一个新技能的完整流程。

## 1. 建技能目录

```
<skill-name>/
├── SKILL.md            # 必需：技能文档（见下方格式）
└── scripts/            # 可选：技能依赖的脚本/资源
```

## 2. 写 `SKILL.md`

开头必须是 YAML frontmatter，然后是正文：

```markdown
---
name: <skill-name>                 # 与目录名一致，kebab-case
description: <一句话能力描述 + 触发场景>  # 决定 Claude 何时启用该技能，要含中英文触发词
metadata:
  short-description: <更短的标题>
---

# 标题

## 使用流程
...步骤，命令用 `node`/`bash` 等可直接执行的形式...

## 重要事实 / 注意
...成本、权限、坑、登录等...

## 部署（新机器一次性）
...依赖安装、首次配置...
```

要点：
- `description` 是技能被自动触发的依据，写清**用户会怎么说**（含中文口语触发词）。
- 凡是 Claude 要执行的命令，写成**非交互可直接运行**的形式（不要依赖只在用户交互终端才有的 shell 函数/alias）。
- 涉及花钱/外发/不可逆操作，必须在文档里要求"先确认成本/先告知"。
- 跨平台假设要写明（如 macOS 专用的键位、路径）。

## 3. 登记到清单

**`skills.json`** 的 `skills` 数组追加一项：

```json
{
  "name": "<skill-name>",
  "path": "<skill-name>/SKILL.md",
  "description": "<一句话描述>",
  "tags": ["...", "..."],
  "platform": "macOS | cross-platform | ...",
  "entry": "<skill-name>/scripts/<主入口>",   // 没有脚本可省略
  "scripts": ["<skill-name>/scripts/xxx"]      // 没有脚本可省略
}
```

**`README.md`** 的「技能」列表加一行：

```markdown
- **[<skill-name>](<skill-name>/)** — <一句话描述>。详见 [<skill-name>/SKILL.md](<skill-name>/SKILL.md)。
```

## 4. 自检

- [ ] `python3 -c "import json;json.load(open('skills.json'))"` 通过（JSON 合法）
- [ ] `SKILL.md` frontmatter 的 `name` 与目录名、`skills.json` 中的 `name` 三者一致
- [ ] 脚本能在干净环境按「部署」章节跑通（依赖、首次配置都写全了）
- [ ] 文档无机器特定的绝对路径残留（除非「部署」里明确说明）

## 5. 提交

```bash
git add -A
git commit -m "Add <skill-name> skill: <一句话>"   # 纯净说明，不要任何 AI 署名标注
git push origin main
```
