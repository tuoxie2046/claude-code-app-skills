# 贡献指南：如何加一个插件/技能

本仓库是 **Claude Code 插件市场**。每个插件是 `plugins/` 下的一个目录，内含一个或多个技能。下面是加一个新插件的完整流程。

## 1. 建插件目录

```
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json         # 必需：插件清单
└── skills/
    └── <skill-name>/
        ├── SKILL.md        # 必需：技能文档（见下方格式）
        └── scripts/        # 可选：技能依赖的脚本/资源（相对 SKILL.md）
```

> 一个插件可放多个技能（`skills/` 下多个目录）。也可附带 `agents/`、`commands/`、`hooks/`、`.mcp.json` 等——这正是插件相比松散技能的优势。

## 2. 写 `plugin.json`

```json
{
  "name": "<plugin-name>",
  "description": "<一句话能力描述>",
  "version": "1.0.0",
  "author": { "name": "<你>" },
  "license": "MIT",
  "keywords": ["...", "..."]
}
```

## 3. 写 `SKILL.md`

开头必须是 YAML frontmatter，然后是正文：

```markdown
---
name: <skill-name>                 # 与技能目录名一致，kebab-case
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

## 4. 登记到市场清单

在 **`.claude-plugin/marketplace.json`** 的 `plugins` 数组追加一项：

```json
{
  "name": "<plugin-name>",
  "source": "./plugins/<plugin-name>",
  "description": "<一句话描述>",
  "keywords": ["...", "..."],
  "category": "..."
}
```

并在 **`README.md`** 的「插件」列表加一行。

## 5. 自检

- [ ] `python3 -c "import json;json.load(open('.claude-plugin/marketplace.json'))"` 通过
- [ ] `plugin.json` 与 `marketplace.json` 里的 `name` 一致；`SKILL.md` 的 `name` 与技能目录名一致
- [ ] 若技能带 `selftest.sh`，跑通且 exit 0
- [ ] 文档无机器特定的绝对路径残留（除非「部署」里明确说明）

## 6. 提交

```bash
git add -A
git commit -m "Add <plugin-name> plugin: <一句话>"   # 纯净说明，不要任何 AI 署名标注
git push origin main
```

## 7. 安装（受管）

```text
/plugin marketplace add tuoxie2046/claude-code-app-skills
/plugin install <plugin-name>@claude-code-app-skills
```
