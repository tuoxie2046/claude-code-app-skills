---
name: klingai-video
description: Generate videos from text prompts on klingai.com (可灵 Kling) by driving a dedicated logged-in Chromium via puppeteer-core, then download the result mp4(s). Use whenever the user wants to create / generate a video from a text description with Kling/可灵, e.g. "生成一个视频", "用可灵做个视频", "文生视频", "kling 生成", "批量生成视频", or gives one or more video prompts. Supports single and batch (multiple prompts queued).
metadata:
  short-description: Generate Kling text-to-video and download mp4
---

# Kling 文生视频（klingai.com）

通过一个**专用的、已登录 klingai 的 Chromium**（独立于用户日常 Chrome）+ puppeteer-core 驱动网页版可灵，自动「填提示词 → 点生成 → 等待 → 下载 mp4」。环境在 `~/klingai-automation/`。

## 使用流程

> ⚠️ **Claude 自己执行时必须用 `node` 形式**（下方），不要用 `klingen`——`klingen` 是用户 `~/.zshrc` 里的 shell 函数，只在用户的**交互终端**有效，Claude 的非交互 Bash 里 `command not found`。

1. **确保浏览器在线**（每次生成前）：
   ```bash
   curl -s --max-time 2 http://127.0.0.1:9222/json/version >/dev/null || bash ~/klingai-automation/launch.sh
   ```
   `launch.sh` 幂等（端口 9222 已通则直接返回）。若启动后页面弹「欢迎登录」，让用户在该窗口手动登录。
2. **先确认成本**：`node ~/klingai-automation/kling.js --dry "提示词" ...` 读出真实积分并告知用户（详见下方「重要事实」）。
3. **生成**（Claude 用这个）：
   ```bash
   node ~/klingai-automation/kling.js "提示词"                       # 单条
   node ~/klingai-automation/kling.js "提示词1" "提示词2" "提示词3"   # 批量
   node ~/klingai-automation/kling.js --name 猫咪 "提示词"            # 指定输出名/前缀
   node ~/klingai-automation/kling.js --file prompts.txt             # 从文件读，每行一条
   ```
   会阻塞直到全部下载完（单条≈5–9 分钟，批量更久）→ **务必用 `run_in_background` 后台跑**，完成通知后读输出文件。
   - 批量是**串行**的：提交一条→等它完成下载→再提交下一条。**实测 klingai 不接受并发提交**（上一条生成中时点生成，第二条会被静默吞掉、不建任务也不扣费），所以必须串行；N 条耗时≈N×单条。脚本对页面导航/刷新有容错（safeEval 重连上下文）。
   - （用户在自己终端里的等价快捷方式是 `klingen "提示词" ...`，会自动起浏览器再调上面的脚本。）
4. **取结果**：视频在 `~/klingai-automation/outputs/<name>.mp4`（批量为 `<前缀>_1.mp4`、`_2.mp4` …）。可 `ffmpeg -i x.mp4 -vframes 1 frame.png` 抽帧给用户预览确认内容。

## 重要事实 / 注意

- **消耗积分（= 用户的钱）**：成本随参数变，**不要假设固定值**（实测过浏览器参数会漂移回 1080p）。参考：720p·5s ≈ 45，1080p·5s ≈ 60；批量按条数倍增。**生成前务必先用 `--dry` 读真实成本并告知用户**：
  ```bash
  node ~/klingai-automation/kling.js --dry "提示词" ["第二条" ...]   # 只读成本，不点生成，不花积分
  ```
  它会打印「每条成本 / 当前参数 / 预计总积分」。余额在网页左下角。
- **参数**：脚本沿用浏览器里**当前**的分辨率/时长设置，不自己改。Claude 要改参数必须用**坐标点击**（纯 CSS 选择器点击不可靠）：先取「参数栏摘要」(含 1080p/5s/16:9 的最短文本元素) 的 bbox 中心、`mouse.click` 打开弹层，再 `mouse.click` 目标 `.inner` 选项(如 720p)的 bbox 中心，最后再点摘要栏收起；改完用 `--dry` 复核。弹层选项：分辨率 720p/1080p/4K、时长 3s/5s/15s、比例 16:9/1:1/9:16、数量 1–4。
- **登录**：专用 Chromium 的 profile 长期保留 klingai 登录，正常无需重登。若 launch 后页面弹「欢迎登录」，让用户在该窗口手动登录（手机验证码或扫码），**绝不替用户填手机号/验证码**。
- **不要用用户的日常 Chrome**：新版 Chrome 禁止对默认 profile 远程调试，且会打断用户浏览。
- **下载原理**（排障用）：网页里 `<video>` 的 src 是不可 fetch 的 MSE `blob:`；真正地址由缩略图推导 `...output_ff.jpg` → `...output.mp4`（同路径，`p1/p2-kling.klingai.com`），并在**页面上下文内 fetch**（带 cookie，避免 403）后写盘。批量时按任务卡文字里包含的提示词来匹配对应视频。

## 关键文件

- `~/klingai-automation/launch.sh` — 启动带调试端口的专用 Chromium
- `~/klingai-automation/kling.js` — 单条/批量 CLI（主入口）
- `~/klingai-automation/klingen.js` — 早期单条版（kling.js 已覆盖其功能）
- `~/klingai-automation/outputs/` — 输出视频
- shell 函数 `klingen`（在 `~/.zshrc`）— 自动起浏览器 + 调 kling.js

## 部署（新机器一次性）

本目录 `scripts/` 是脚本源；安装即把它们放到 `~/klingai-automation/` 并备好运行环境：

```bash
mkdir -p ~/klingai-automation/profile
cp scripts/* ~/klingai-automation/
cd ~/klingai-automation
npm init -y >/dev/null && npm i puppeteer-core            # 驱动库
npx @puppeteer/browsers install chrome@stable --path ./browser   # 下载独立 Chromium（自动化专用，不动日常 Chrome）
bash launch.sh                                            # 启动并打开 klingai → 在弹出的窗口里手动登录一次（手机验证码/扫码）
```

可选：把 shell 快捷方式加进 `~/.zshrc`（用户交互终端用；Claude 自己仍用 `node` 形式）：

```bash
klingen() {
  local DIR="$HOME/klingai-automation"
  curl -s --max-time 1 http://127.0.0.1:9222/json/version >/dev/null 2>&1 || bash "$DIR/launch.sh" || return 1
  node "$DIR/kling.js" "$@"
}
```

依赖：Node.js（建议 ≥18）、macOS（脚本用了 `Meta`/`Cmd` 快捷键与 mac 路径，其他平台需改键位与浏览器路径）、ffmpeg（可选，用于抽帧预览）。登录态保存在 `~/klingai-automation/profile/`，长期有效。
