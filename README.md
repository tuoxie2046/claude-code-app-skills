# claude-code-app-skills

Claude Code 插件市场（marketplace）：驱动本机桌面应用做自动化的技能集合。

## 安装（推荐：作为受管插件）

```text
/plugin marketplace add tuoxie2046/claude-code-app-skills
/plugin install klingai-video@claude-code-app-skills
/plugin install adobe-creative-control@claude-code-app-skills
```

装好后 `/plugin` 可随时启用/停用/更新；仓库更新后 `/plugin marketplace update claude-code-app-skills` 同步。

> 也可手动安装：把 `plugins/<name>/skills/<name>/` 整个目录拷到 `~/.claude/skills/` 下即可（不走插件管理，不可一键更新）。

## 插件

- **[klingai-video](plugins/klingai-video/skills/klingai-video/)** — 用 klingai.com（可灵 Kling）网页版文生视频：通过一个已登录的专用 Chromium + puppeteer-core 自动「填提示词 → 生成 → 下载 mp4」，支持单条与批量（串行）。详见 [SKILL.md](plugins/klingai-video/skills/klingai-video/SKILL.md)。
- **[adobe-creative-control](plugins/adobe-creative-control/skills/adobe-creative-control/)** — 从命令行驱动 macOS 上的 Adobe 全家桶（PS / AI / InDesign / AE / Premiere / Media Encoder / Acrobat / Animate / Lightroom Classic / Dreamweaver / XD）：经 ExtendScript、BridgeTalk、aerender、JSFL、Lua 插件、UXP 插件、MIDI 等已实测通道做图像/排版/视频渲染转码/批量导图自动化。`selftest.sh` 一键自检。详见 [SKILL.md](plugins/adobe-creative-control/skills/adobe-creative-control/SKILL.md)。

## 结构

```
.claude-plugin/marketplace.json          # 市场清单（列出所有插件）
plugins/<plugin>/
  .claude-plugin/plugin.json             # 插件清单
  skills/<skill>/SKILL.md                # 技能（含 scripts/ 等资源）
```

想加新插件/技能？流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## License

[MIT](LICENSE)
