#!/usr/bin/env python3
"""Generate PDF from Technische_Projektanalyse_NoitaClone.md"""

from pathlib import Path
import re
import sys

try:
    from fpdf import FPDF
except ImportError:
    print("Installing fpdf2...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "fpdf2", "-q"])
    from fpdf import FPDF

DOCS = Path(__file__).resolve().parent
MD_PATH = DOCS / "Technische_Projektanalyse_NoitaClone.md"
PDF_PATH = DOCS / "Technische_Projektanalyse_NoitaClone.pdf"


class AnalysisPDF(FPDF):
    def header(self):
        if self.page_no() > 1:
            self.set_font("Helvetica", "I", 8)
            self.set_text_color(100, 100, 100)
            self.cell(0, 8, "NoitaClone - Technische Projektanalyse (Godot 4.6.1)", align="C")
            self.ln(4)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(100, 100, 100)
        self.cell(0, 10, f"Seite {self.page_no()}", align="C")


def strip_md_inline(text: str) -> str:
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"`(.+?)`", r"\1", text)
    text = re.sub(r"\[(.+?)\]\(.+?\)", r"\1", text)
    return text


def parse_table_row(line: str) -> list[str]:
    line = line.strip()
    if not line.startswith("|"):
        return []
    parts = [strip_md_inline(c.strip()) for c in line.split("|")[1:-1]]
    return parts


def is_table_separator(line: str) -> bool:
    return bool(re.match(r"^\|[\s\-:|]+\|$", line.strip()))


def build_pdf(md_text: str) -> None:
    pdf = AnalysisPDF()
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_page()
    pdf.set_margins(18, 18, 18)

    lines = md_text.splitlines()
    i = 0
    in_code = False
    table_rows: list[list[str]] = []

    def flush_table():
        nonlocal table_rows
        if not table_rows:
            return
        col_count = max(len(r) for r in table_rows)
        col_w = (pdf.w - pdf.l_margin - pdf.r_margin) / col_count
        pdf.set_font("Helvetica", "", 8)
        for ri, row in enumerate(table_rows):
            if ri == 0:
                pdf.set_fill_color(230, 235, 245)
                pdf.set_font("Helvetica", "B", 8)
            else:
                pdf.set_fill_color(255, 255, 255)
                pdf.set_font("Helvetica", "", 8)
            for ci in range(col_count):
                cell = row[ci] if ci < len(row) else ""
                pdf.cell(col_w, 6, cell[:48], border=1, fill=(ri == 0))
            pdf.ln()
        table_rows = []
        pdf.ln(2)

    while i < len(lines):
        line = lines[i]
        raw = line.rstrip()

        if raw.startswith("```"):
            in_code = not in_code
            i += 1
            continue

        if in_code:
            pdf.set_font("Courier", "", 7)
            pdf.set_text_color(40, 40, 40)
            pdf.multi_cell(0, 4, raw[:110] or " ")
            i += 1
            continue

        pdf.set_text_color(0, 0, 0)

        if raw.startswith("|"):
            if is_table_separator(raw):
                i += 1
                continue
            row = parse_table_row(raw)
            if row:
                table_rows.append(row)
            i += 1
            continue
        else:
            flush_table()

        if raw.startswith("# "):
            pdf.ln(4)
            pdf.set_font("Helvetica", "B", 18)
            pdf.multi_cell(0, 10, strip_md_inline(raw[2:]))
            pdf.ln(2)
        elif raw.startswith("## "):
            pdf.ln(3)
            pdf.set_font("Helvetica", "B", 14)
            pdf.multi_cell(0, 8, strip_md_inline(raw[3:]))
            pdf.ln(1)
        elif raw.startswith("### "):
            pdf.ln(2)
            pdf.set_font("Helvetica", "B", 11)
            pdf.multi_cell(0, 7, strip_md_inline(raw[4:]))
        elif raw.startswith("#### "):
            pdf.set_font("Helvetica", "B", 10)
            pdf.multi_cell(0, 6, strip_md_inline(raw[5:]))
        elif raw.startswith("---"):
            pdf.ln(2)
            y = pdf.get_y()
            pdf.set_draw_color(180, 180, 180)
            pdf.line(pdf.l_margin, y, pdf.w - pdf.r_margin, y)
            pdf.ln(4)
        elif raw.startswith("> "):
            pdf.set_font("Helvetica", "I", 9)
            pdf.set_text_color(60, 60, 80)
            pdf.multi_cell(0, 5, strip_md_inline(raw[2:]))
            pdf.set_text_color(0, 0, 0)
        elif raw.startswith("- "):
            pdf.set_font("Helvetica", "", 9)
            pdf.multi_cell(0, 5, "  • " + strip_md_inline(raw[2:]))
        elif re.match(r"^\d+\.\s", raw):
            pdf.set_font("Helvetica", "", 9)
            pdf.multi_cell(0, 5, "  " + strip_md_inline(raw))
        elif raw.strip() == "":
            pdf.ln(2)
        else:
            pdf.set_font("Helvetica", "", 9)
            pdf.multi_cell(0, 5, strip_md_inline(raw))

        i += 1

    flush_table()
    pdf.output(str(PDF_PATH))
    print(f"PDF erstellt: {PDF_PATH}")


def main():
    if not MD_PATH.exists():
        print(f"Markdown nicht gefunden: {MD_PATH}")
        sys.exit(1)
    md_text = MD_PATH.read_text(encoding="utf-8")
    build_pdf(md_text)


if __name__ == "__main__":
    main()
