# claude-code-app-skills

Claude Code 技能集合。

## 技能

- **[klingai-video](klingai-video/)** — 用 klingai.com（可灵 Kling）网页版文生视频：通过一个已登录的专用 Chromium + puppeteer-core 自动「填提示词 → 生成 → 下载 mp4」，支持单条与批量（串行）。详见 [klingai-video/SKILL.md](klingai-video/SKILL.md)。
- **[adobe-creative-control](adobe-creative-control/)** — 从命令行驱动 macOS 上的 Adobe 全家桶（PS / AI / InDesign / AE / Premiere / Media Encoder / Acrobat / Animate / Lightroom Classic / Dreamweaver / XD）：经 ExtendScript、BridgeTalk、aerender、JSFL、Lua 插件、UXP 插件、MIDI 等已实测通道做图像/排版/视频渲染转码/批量导图自动化。`selftest.sh` 一键自检。详见 [adobe-creative-control/SKILL.md](adobe-creative-control/SKILL.md)。

机器可读的技能清单见 [`skills.json`](skills.json)。

想加新技能？流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## License

[MIT](LICENSE)
