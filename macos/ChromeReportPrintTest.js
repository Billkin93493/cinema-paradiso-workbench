const { spawnSync } = require("node:child_process");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const report = {
  version: 1,
  generatedAt: "2026-06-09T00:00:00Z",
  generatedDate: "2026/06/09",
  project: {
    name: "自动测试影片",
    duration: 39,
    mode: "local",
  },
  shots: Array.from({ length: 6 }, (_, index) => {
    const notes = [
      "人物停在门口后没有立刻进入，镜头保留空间距离，让迟疑先于对白出现。",
      "",
      "固定机位让两人的停顿成为主要动作，背景亮度变化承担时间流逝。",
      "前景遮挡将视线切成两部分，人物虽然处在同一空间，关系仍然没有真正靠近。",
      "",
      "最后一个镜头在动作完成后继续停留，让空画面接住前面没有说完的情绪。",
    ];
    const sizes = ["全景", "中景", "中景", "近景", "特写", "全景"];
    const movements = ["固定", "推镜", "固定", "横移", "固定", "固定"];
    const start = index * 6.5;
    return {
      key: `shot-${index}`,
      number: index + 1,
      start,
      end: start + 6.5,
      size: sizes[index],
      angle: index === 3 ? "俯视" : "平视",
      movement: movements[index],
      action: "",
      sound: "",
      dialogueItems:
        index === 0
          ? [
              {
                primary: "我不知道你会不会来。",
                secondary: "I didn't know if you'd come.",
              },
              {
                primary: "但我还是等了。",
                secondary: "But I waited anyway.",
              },
            ]
          : index === 1
            ? [{ primary: "我也不知道。", secondary: "Neither did I." }]
            : index === 2
              ? [{ primary: "这是中文字幕。", secondary: "" }]
              : [],
      dialogueText:
        index === 0
          ? "我不知道你会不会来。\n原文：I didn't know if you'd come.\n\n但我还是等了。\n原文：But I waited anyway."
          : index === 1
            ? "我也不知道。\n原文：Neither did I."
            : index === 2
              ? "这是中文字幕。"
              : "",
      note: notes[index],
      imageUrl:
        index === 0
          ? "http://127.0.0.1:4173/preview/assets/still-01.png"
          : index === 3
            ? "http://127.0.0.1:4173/preview/assets/still-07.png"
            : "",
    };
  }),
  noteCount: 4,
  frameCount: 2,
  coverImageUrl: "http://127.0.0.1:4173/preview/assets/still-01.png",
};

const encoded = Buffer.from(JSON.stringify(report)).toString("base64url");
const url = `http://127.0.0.1:4173/report/index.html?pages=cover,overview,shots&fields=images,sound,analysis#data=${encoded}`;
const output = path.join(root, "tmp/pdfs/真实拉片报告-Chrome打印测试.pdf");
const chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const result = spawnSync(
  chrome,
  [
    "--headless=new",
    "--disable-gpu",
    "--no-pdf-header-footer",
    `--print-to-pdf=${output}`,
    url,
  ],
  { encoding: "utf8", timeout: 30000 },
);

if (result.status !== 0) {
  process.stderr.write(result.stderr || "Chrome PDF test failed\n");
  process.exit(result.status || 1);
}

process.stdout.write(`${output}\n`);
