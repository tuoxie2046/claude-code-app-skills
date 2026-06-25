#!/usr/bin/env node
/*
 * Kling 文生视频自动化 CLI（单条 / 批量）
 * 用法:
 *   node kling.js "提示词"                       # 单条
 *   node kling.js "提示词1" "提示词2" "提示词3"   # 批量排队，依次下载
 *   node kling.js --name 猫咪 "提示词"            # 指定输出名/前缀
 *   node kling.js --file prompts.txt             # 从文件读，每行一条
 * 前提: 已用 ./launch.sh 启动带调试端口(9222)且已登录 klingai 的 Chromium
 * 输出: ~/klingai-automation/outputs/<name>.mp4 (批量为 <name>_1.mp4 ...)
 * 注意: 生成参数(分辨率/时长)沿用浏览器里当前设置，本脚本不改参数。
 */
const pc = require("puppeteer-core");
const fs = require("fs");
const path = require("path");

const sleep = ms => new Promise(r => setTimeout(r, ms));
const MAX_MS = 20 * 60 * 1000;   // 整批最长等 20 分钟
const INTERVAL = 12000;

// ---- 解析参数 ----
const argv = process.argv.slice(2);
let name = null, file = null, dry = false;
const prompts = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === "--name") { name = argv[++i]; }
  else if (argv[i] === "--file") { file = argv[++i]; }
  else if (argv[i] === "--dry" || argv[i] === "--cost") { dry = true; }
  else prompts.push(argv[i]);
}
if (file) {
  fs.readFileSync(file, "utf8").split("\n").map(s => s.trim()).filter(Boolean).forEach(s => prompts.push(s));
}
if (!prompts.length) { console.error('用法: node kling.js "提示词" ["提示词2" ...] [--name 名字] [--file prompts.txt]'); process.exit(1); }

const outDir = path.join(process.env.HOME, "klingai-automation", "outputs");
fs.mkdirSync(outDir, { recursive: true });
const slug = s => s.replace(/[\s,，。.\/\\:：]+/g, "_").replace(/[^\w一-龥]/g, "").slice(0, 20) || "video";
const outNameFor = (i) => {
  if (prompts.length === 1) return name || slug(prompts[0]);
  const base = name || `kling_${Date.now()}`;
  return `${base}_${i + 1}`;
};

(async () => {
  const b = await pc.connect({ browserURL: "http://127.0.0.1:9222", defaultViewport: null });
  const pages = await b.pages();
  let p = pages.find(x => x.url().includes("/app/video")) || pages[0];
  await p.bringToFront();
  if (!p.url().includes("/app/video/new")) {
    await p.goto("https://klingai.com/app/video/new", { waitUntil: "networkidle2" }).catch(() => {});
    await sleep(3000);
  }

  // 当前所有结果缩略图（= 历史已存在的视频），后续匹配时排除，避免误下旧视频
  const collectThumbs = () => p.evaluate(() =>
    [...document.querySelectorAll("img")]
      .filter(i => /upload-ylab-stunt.*output_ff\.jpg/.test(i.src))
      .map(i => i.src.split("?")[0]));
  const seen = new Set(await collectThumbs());

  // 等“生成”按钮可点（适配可灵可能的并发限制：上一条占用时按钮会置灰）
  const waitGenEnabled = async (timeoutMs = 120000) => {
    const t0 = Date.now();
    while (Date.now() - t0 < timeoutMs) {
      const st = await p.evaluate(() => {
        const g = [...document.querySelectorAll("button")].find(b => b.innerText.includes("生成"));
        const lack = /积分不足|余额不足/.test(document.body.innerText);
        return { exists: !!g, enabled: g ? !g.disabled : false, lack };
      });
      if (st.lack) return { ok: false, reason: "积分不足" };
      if (st.exists && st.enabled) return { ok: true };
      await sleep(2000);
    }
    return { ok: false, reason: "生成按钮长时间不可点（可能并发受限）" };
  };

  const typeAndGenerate = async (prompt) => {
    const ed = await p.waitForSelector(".tiptap.ProseMirror", { timeout: 15000 });
    await ed.click(); await sleep(300);
    await p.keyboard.down("Meta"); await p.keyboard.press("KeyA"); await p.keyboard.up("Meta");
    await p.keyboard.press("Backspace");
    await p.type(".tiptap.ProseMirror", prompt, { delay: 10 });
    await sleep(500);
    return p.evaluate(() => {
      const g = [...document.querySelectorAll("button")].find(b => b.innerText.includes("生成"));
      if (g && !g.disabled) { g.click(); return true; } return false;
    });
  };

  // ---- --dry: 只输入提示词读成本，不点生成，不花积分 ----
  if (dry) {
    const ed = await p.waitForSelector(".tiptap.ProseMirror", { timeout: 15000 });
    await ed.click(); await sleep(300);
    await p.keyboard.down("Meta"); await p.keyboard.press("KeyA"); await p.keyboard.up("Meta");
    await p.keyboard.press("Backspace");
    await p.type(".tiptap.ProseMirror", prompts[0], { delay: 10 });
    await sleep(600);
    const info = await p.evaluate(() => {
      const g = [...document.querySelectorAll("button")].find(b => b.innerText.includes("生成"));
      const cost = g ? (g.innerText.match(/\d+/) || ["?"])[0] : "?";
      // 参数栏摘要
      const bar = [...document.querySelectorAll("div")].map(e => e.innerText || "")
        .find(t => /(1080p|720p|4K)/.test(t) && /(3s|5s|15s)/.test(t) && /16:9|1:1|9:16/.test(t) && t.length < 40);
      return { cost, bar: (bar || "").replace(/\s+/g, " ").trim() };
    });
    console.log(`💰 每条成本: ${info.cost} 积分 | 当前参数: ${info.bar || "未读到"}`);
    console.log(`📊 本次将生成 ${prompts.length} 条 → 预计共 ${isNaN(+info.cost) ? "?" : (+info.cost) * prompts.length} 积分`);
    await b.disconnect();
    process.exit(0);
  }

  // ---- 导航容错的 evaluate 包装（页面刷新/跳转会销毁执行上下文）----
  const safeEval = async (fn, arg) => {
    for (let k = 0; k < 4; k++) {
      try { return await p.evaluate(fn, arg); }
      catch (e) {
        if (/context was destroyed|Target closed|Cannot find context|detached|Session closed/i.test(e.message)) {
          await sleep(1500);
          const pgs = await b.pages();
          p = pgs.find(x => x.url().includes("/app/video")) || pgs[0] || p;
          continue;
        }
        throw e;
      }
    }
    throw new Error("safeEval 重试多次仍失败（页面持续导航）");
  };
  const ensureNewPage = async () => {
    if (!p.url().includes("/app/video/new")) {
      await p.goto("https://klingai.com/app/video/new", { waitUntil: "networkidle2" }).catch(() => {});
      await sleep(3000);
    }
  };
  const collectCards = () => safeEval(() => {
    const imgs = [...document.querySelectorAll("img")].filter(i => /upload-ylab-stunt.*output_ff\.jpg/.test(i.src));
    return imgs.map(img => {
      let el = img, text = "";
      for (let i = 0; i < 8 && el; i++) { el = el.parentElement; if (el) { const t = el.innerText || ""; if (t.length > text.length) text = t; } }
      return { thumb: img.src.split("?")[0], text: text.replace(/\s+/g, " ") };
    });
  });

  // ---- 串行：逐条 提交→等待完成→下载 ----
  // 实测可灵不接受“上一条生成中时提交下一条”（第二条会被静默吞掉），故必须串行。
  let done = 0;
  for (let i = 0; i < prompts.length; i++) {
    const prompt = prompts[i], oname = outNameFor(i);
    const key = prompt.replace(/\s+/g, " ").slice(0, 30);
    await ensureNewPage();
    const ready = await waitGenEnabled();
    if (!ready.ok) { console.error(`❌ 第${i + 1}条无法提交：${ready.reason}`); break; }
    if (!(await typeAndGenerate(prompt))) { console.error(`❌ 第${i + 1}条点击生成失败`); break; }
    console.log(`📤 提交 ${i + 1}/${prompts.length}: ${prompt.slice(0, 30)}... 等待完成`);

    const tStart = Date.now();
    let got = null;
    while (Date.now() - tStart < MAX_MS) {
      let cards;
      try { cards = await collectCards(); } catch (e) { console.error("\n轮询出错:", e.message); break; }
      const card = cards.find(c => !seen.has(c.thumb) && c.text.includes(key));
      if (card) { got = card; break; }
      process.stdout.write(`  第${i + 1}条 ...${Math.round((Date.now() - tStart) / 1000)}s\r`);
      await sleep(INTERVAL);
    }
    if (!got) { console.error(`\n⏰ 第${i + 1}条超时未出结果: ${prompt.slice(0, 24)}`); continue; }
    seen.add(got.thumb); // 标记已处理，避免后续条目误匹配到它
    const mp4 = got.thumb.replace(/output_ff\.jpg$/, "output.mp4");
    const r = await safeEval(async (u) => {
      try { const resp = await fetch(u); if (!resp.ok) return { err: "status " + resp.status }; const ab = await resp.arrayBuffer(); return { ok: true, data: Array.from(new Uint8Array(ab)) }; }
      catch (e) { return { err: e.message }; }
    }, mp4);
    if (r.ok) {
      const out = path.join(outDir, `${oname}.mp4`);
      fs.writeFileSync(out, Buffer.from(r.data));
      done++;
      console.log(`\n✅ ${out} (${Math.round(fs.statSync(out).size / 1024)} KB) ← ${prompt.slice(0, 24)}`);
    } else {
      console.error(`\n下载失败(${oname}): ${r.err}`);
    }
  }

  console.log(`\n🎬 完成 ${done}/${prompts.length}，输出目录: ${outDir}`);
  await b.disconnect();
  process.exit(done === prompts.length ? 0 : 3);
})().catch(e => { console.error("ERR", e.message); process.exit(1); });
