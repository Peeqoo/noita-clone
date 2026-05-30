/**
 * Markdown → PDF (pure Node.js, no dependencies)
 * Usage: node generate_analysis_pdf.js
 */
const fs = require("fs");
const path = require("path");

const DOCS = __dirname;
const MD_PATH = path.join(DOCS, "Technische_Projektanalyse_NoitaClone.md");
const PDF_PATH = path.join(DOCS, "Technische_Projektanalyse_NoitaClone.pdf");

const PAGE_W = 595.28; // A4 pt
const PAGE_H = 841.89;
const MARGIN_L = 50;
const MARGIN_R = 50;
const MARGIN_T = 55;
const MARGIN_B = 50;
const LINE_H = 11;
const MAX_CHARS = 92;

function stripMd(s) {
  return s
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/`(.+?)`/g, "$1")
    .replace(/\[(.+?)\]\([^)]+\)/g, "$1")
    .replace(/^#+\s*/, "");
}

function wrapLine(text, max = MAX_CHARS) {
  const out = [];
  let t = text.trim();
  if (!t) return [""];
  while (t.length > max) {
    let cut = t.lastIndexOf(" ", max);
    if (cut < 40) cut = max;
    out.push(t.slice(0, cut).trim());
    t = t.slice(cut).trim();
  }
  if (t) out.push(t);
  return out;
}

function parseMd(content) {
  const blocks = [];
  const lines = content.split(/\r?\n/);
  let i = 0;
  let inCode = false;
  let table = [];

  const flushTable = () => {
    if (table.length) {
      blocks.push({ type: "table", rows: table });
      table = [];
    }
  };

  while (i < lines.length) {
    const raw = lines[i];
    const line = raw.trimEnd();

    if (line.startsWith("```")) {
      inCode = !inCode;
      i++;
      continue;
    }
    if (inCode) {
      blocks.push({ type: "code", text: line });
      i++;
      continue;
    }

    if (line.startsWith("|") && line.includes("|")) {
      if (/^\|[\s\-:|]+\|$/.test(line.trim())) {
        i++;
        continue;
      }
      const cells = line
        .split("|")
        .slice(1, -1)
        .map((c) => stripMd(c.trim()));
      table.push(cells);
      i++;
      continue;
    }
    flushTable();

    if (line.startsWith("# ")) blocks.push({ type: "h1", text: stripMd(line) });
    else if (line.startsWith("## ")) blocks.push({ type: "h2", text: stripMd(line) });
    else if (line.startsWith("### ")) blocks.push({ type: "h3", text: stripMd(line) });
    else if (line.startsWith("#### ")) blocks.push({ type: "h4", text: stripMd(line) });
    else if (line === "---") blocks.push({ type: "hr" });
    else if (line.startsWith("> ")) blocks.push({ type: "quote", text: stripMd(line.slice(2)) });
    else if (line.startsWith("- ")) blocks.push({ type: "li", text: stripMd(line.slice(2)) });
    else if (/^\d+\.\s/.test(line)) blocks.push({ type: "li", text: stripMd(line) });
    else if (line.trim() === "") blocks.push({ type: "space" });
    else blocks.push({ type: "p", text: stripMd(line) });

    i++;
  }
  flushTable();
  return blocks;
}

function buildLayout(blocks) {
  const layout = [];
  for (const b of blocks) {
    if (b.type === "space") {
      layout.push({ kind: "space", h: 6 });
      continue;
    }
    if (b.type === "hr") {
      layout.push({ kind: "hr", h: 10 });
      continue;
    }
    if (b.type === "h1") {
      layout.push({ kind: "h1", h: 20, lines: wrapLine(b.text, 70) });
      continue;
    }
    if (b.type === "h2") {
      layout.push({ kind: "h2", h: 16, lines: wrapLine(b.text, 80) });
      continue;
    }
    if (b.type === "h3") {
      layout.push({ kind: "h3", h: 14, lines: wrapLine(b.text, 85) });
      continue;
    }
    if (b.type === "h4") {
      layout.push({ kind: "h4", h: 12, lines: wrapLine(b.text, 88) });
      continue;
    }
    if (b.type === "table") {
      for (let ri = 0; ri < b.rows.length; ri++) {
        const row = b.rows[ri];
        const joined = row.join(" | ");
        const prefix = ri === 0 ? "[HDR] " : "";
        for (const ln of wrapLine(prefix + joined, MAX_CHARS - 2)) {
          layout.push({
            kind: ri === 0 ? "table-h" : "table",
            h: LINE_H,
            lines: [ln.replace("[HDR] ", "")],
          });
        }
      }
      layout.push({ kind: "space", h: 4 });
      continue;
    }
    if (b.type === "code") {
      for (const ln of wrapLine(b.text, 84)) {
        layout.push({ kind: "code", h: LINE_H, lines: [ln] });
      }
      continue;
    }
    if (b.type === "quote") {
      for (const ln of wrapLine(b.text, 86)) {
        layout.push({ kind: "quote", h: LINE_H, lines: ["  " + ln] });
      }
      continue;
    }
    if (b.type === "li") {
      for (const ln of wrapLine(b.text, 86)) {
        layout.push({ kind: "li", h: LINE_H, lines: ["  • " + ln] });
      }
      continue;
    }
    for (const ln of wrapLine(b.text, MAX_CHARS)) {
      layout.push({ kind: "p", h: LINE_H, lines: [ln] });
    }
  }
  return layout;
}

function paginate(layout) {
  const pages = [];
  let y = PAGE_H - MARGIN_T;
  let page = [];

  const newPage = () => {
    if (page.length) pages.push(page);
    page = [];
    y = PAGE_H - MARGIN_T;
  };

  for (const item of layout) {
    const need =
      item.h +
      (item.lines ? item.lines.length * LINE_H : 0) +
      (item.kind === "h1" ? 8 : item.kind === "h2" ? 6 : 0);

    if (y - need < MARGIN_B) {
      newPage();
    }

    if (item.kind === "space") {
      y -= item.h;
      continue;
    }

    if (item.kind === "hr") {
      page.push({ type: "hr", y });
      y -= item.h;
      continue;
    }

    const font =
      item.kind === "h1"
        ? 16
        : item.kind === "h2"
          ? 13
          : item.kind === "h3"
            ? 11
            : item.kind === "h4" || item.kind === "table-h"
              ? 10
              : item.kind === "code"
                ? 8
                : 9;

    const bold = ["h1", "h2", "h3", "h4", "table-h"].includes(item.kind);

    for (const ln of item.lines || []) {
      page.push({ type: "text", y, text: ln, size: font, bold });
      y -= LINE_H;
    }
    if (item.kind === "h1") y -= 4;
    if (item.kind === "h2") y -= 3;
  }

  if (page.length) pages.push(page);
  return pages;
}

function escPdf(s) {
  return s.replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");
}

function latin1(buf) {
  // Replace unsupported chars for WinAnsiEncoding
  return buf
    .replace(/[\u2013\u2014]/g, "-")
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201c\u201d]/g, '"')
    .replace(/[\u2022]/g, "*")
    .replace(/[^\x00-\xff]/g, "?");
}

function makePdf(pages) {
  const objs = [];
  const kids = [];
  let n = 1;

  const add = (body) => {
    objs.push({ id: ++n, body });
    return n;
  };

  const fontRegular = add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");
  const fontBold = add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>");

  for (let pi = 0; pi < pages.length; pi++) {
    const content = [];
    content.push("BT");
    for (const el of pages[pi]) {
      if (el.type === "hr") {
        content.push("ET");
        content.push(
          `${MARGIN_L} ${el.y} m ${PAGE_W - MARGIN_R} ${el.y} l S`
        );
        content.push("BT");
        continue;
      }
      const fontId = el.bold ? fontBold : fontRegular;
      content.push(
        `/F${fontId} ${el.size} Tf ${MARGIN_L} ${el.y} Td (${escPdf(latin1(el.text))}) Tj`
      );
      content.push(`${MARGIN_L} ${el.y} Td`); // reset — use absolute Tm instead
    }
    content.push("ET");

    // Rebuild with Tm for absolute positioning
    const stream = [];
    stream.push("BT");
    for (const el of pages[pi]) {
      if (el.type === "hr") {
        stream.push("ET");
        stream.push(
          `${MARGIN_L} ${el.y} m ${PAGE_W - MARGIN_R} ${el.y} l S`
        );
        stream.push("BT");
        continue;
      }
      const fontId = el.bold ? fontBold : fontRegular;
      stream.push(`/F${fontId} ${el.size} Tf`);
      stream.push(`1 0 0 1 ${MARGIN_L} ${el.y} Tm`);
      stream.push(`(${escPdf(latin1(el.text))}) Tj`);
    }
    stream.push("ET");

    const streamStr = stream.join("\n");
    const streamId = add(
      `<< /Length ${Buffer.byteLength(streamStr, "utf8")} >>\nstream\n${streamStr}\nendstream`
    );

    const pageId = add(
      `<< /Type /Page /Parent 0 0 R /MediaBox [0 0 ${PAGE_W} ${PAGE_H}] /Contents ${streamId} 0 R /Resources << /Font << /F${fontRegular} ${fontRegular} 0 R /F${fontBold} ${fontBold} 0 R >> >> >>`
    );
    kids.push(pageId);
  }

  const pagesId = add(
    `<< /Type /Pages /Kids [${kids.map((k) => `${k} 0 R`).join(" ")}] /Count ${kids.length} >>`
  );

  // Fix parent refs
  for (const o of objs) {
    if (o.body.includes("/Parent 0 0 R")) {
      o.body = o.body.replace("/Parent 0 0 R", `/Parent ${pagesId} 0 R`);
    }
  }

  const catalogId = add(`<< /Type /Catalog /Pages ${pagesId} 0 R >>`);

  let pdf = "%PDF-1.4\n";
  const offsets = [0];

  for (const o of objs) {
    offsets.push(Buffer.byteLength(pdf, "utf8"));
    pdf += `${o.id} 0 obj\n${o.body}\nendobj\n`;
  }

  const xrefPos = Buffer.byteLength(pdf, "utf8");
  pdf += `xref\n0 ${objs.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  for (let i = 1; i <= objs.length; i++) {
    const off = String(offsets[i]).padStart(10, "0");
    pdf += `${off} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objs.length + 1} /Root ${catalogId} 0 R >>\n`;
  pdf += `startxref\n${xrefPos}\n%%EOF\n`;

  return pdf;
}

function main() {
  if (!fs.existsSync(MD_PATH)) {
    console.error("Markdown nicht gefunden:", MD_PATH);
    process.exit(1);
  }
  const md = fs.readFileSync(MD_PATH, "utf8");
  const blocks = parseMd(md);
  const layout = buildLayout(blocks);
  const pages = paginate(layout);
  const pdf = makePdf(pages);
  fs.writeFileSync(PDF_PATH, pdf, "utf8");
  console.log("PDF erstellt:", PDF_PATH);
  console.log("Seiten:", pages.length);
}

main();
