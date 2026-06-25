#!/usr/bin/env node
// 用法: node klingen.js "提示词" [输出文件名]
// 前提: 已用 ./launch.sh 启动带调试端口(9222)且已登录 klingai 的 Chromium
const pc = require("puppeteer-core");
const fs = require("fs");
const path = require("path");

const PROMPT = process.argv[2];
const NAME = process.argv[3] || `kling_${Date.now()}`;
if (!PROMPT) { console.error("用法: node klingen.js \"提示词\" [文件名]"); process.exit(1); }

const MAX_MS = 15 * 60 * 1000;
const INTERVAL = 12000;
const sleep = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  const b = await pc.connect({ browserURL: "http://127.0.0.1:9222", defaultViewport: null });
  const pages = await b.pages();
  let p = pages.find(x => x.url().includes("/app/video")) || pages[0];
  await p.bringToFront();
  if (!p.url().includes("/app/video/new")) {
    await p.goto("https://klingai.com/app/video/new", { waitUntil: "networkidle2" }).catch(()=>{});
    await sleep(3000);
  }

  // 记录生成前已存在的结果缩略图，避免误抓旧视频
  const beforeThumbs = await p.evaluate(() =>
    [...document.querySelectorAll("img")].map(i => i.src).filter(s => /upload-ylab-stunt.*output_ff\.jpg/.test(s)).map(s => s.split("?")[0])
  );
  const seen = new Set(beforeThumbs);

  // 输入提示词
  const editor = await p.waitForSelector(".tiptap.ProseMirror", { timeout: 15000 });
  await editor.click(); await sleep(300);
  await p.keyboard.down("Meta"); await p.keyboard.press("KeyA"); await p.keyboard.up("Meta");
  await p.keyboard.press("Backspace");
  await p.type(".tiptap.ProseMirror", PROMPT, { delay: 12 });
  await sleep(500);

  // 点生成
  const clicked = await p.evaluate(() => {
    const g = [...document.querySelectorAll("button")].find(b => b.innerText.includes("生成"));
    if (g && !g.disabled) { g.click(); return true; } return false;
  });
  if (!clicked) { console.error("❌ 没找到可点的生成按钮"); await b.disconnect(); process.exit(2); }
  console.log("已点生成，等待结果...");

  // 轮询新的结果缩略图
  const start = Date.now();
  let mp4 = null;
  while (Date.now() - start < MAX_MS) {
    const st = await p.evaluate(() => {
      const newThumbs = [...document.querySelectorAll("img")].map(i => i.src)
        .filter(s => /upload-ylab-stunt.*output_ff\.jpg/.test(s)).map(s => s.split("?")[0]);
      const t = document.body.innerText;
      const fail = /(生成失败|积分不足|余额不足|审核未通过)/.exec(t);
      return { newThumbs, fail: fail ? fail[0] : null };
    });
    if (st.fail) { console.error("❌", st.fail); await b.disconnect(); process.exit(3); }
    const fresh = st.newThumbs.find(s => !seen.has(s));
    if (fresh) { mp4 = fresh.replace(/output_ff\.jpg$/, "output.mp4"); break; }
    process.stdout.write(`  ...${Math.round((Date.now()-start)/1000)}s\r`);
    await sleep(INTERVAL);
  }
  if (!mp4) { console.error("\n⏰ 超时未拿到结果"); await b.disconnect(); process.exit(4); }
  console.log("\n🎬 视频地址:", mp4);

  // 在页面上下文 fetch（带 cookie），写盘
  const r = await p.evaluate(async (u) => {
    try { const resp = await fetch(u); if (!resp.ok) return { err: "status " + resp.status };
      const ab = await resp.arrayBuffer(); return { ok: true, data: Array.from(new Uint8Array(ab)) };
    } catch (e) { return { err: e.message }; }
  }, mp4);
  if (!r.ok) { console.error("下载失败:", r.err); await b.disconnect(); process.exit(5); }

  const outDir = path.join(process.env.HOME, "klingai-automation", "outputs");
  fs.mkdirSync(outDir, { recursive: true });
  const out = path.join(outDir, `${NAME}.mp4`);
  fs.writeFileSync(out, Buffer.from(r.data));
  console.log(`✅ 已下载: ${out} (${Math.round(fs.statSync(out).size/1024)} KB)`);
  await b.disconnect();
})().catch(e => { console.error("ERR", e.message); process.exit(1); });
