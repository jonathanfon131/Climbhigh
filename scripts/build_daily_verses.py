#!/usr/bin/env python3
"""Builds the app's daily-verse list straight from the official Berean Standard Bible text.

Why a script: every verse shown in the app is copied programmatically from the
publisher's own files, never typed from memory, so the wording is exact.

Source: Berean Standard Bible (BSB), dedicated to the public domain (April 2023).
        USJ files from https://github.com/BSB-publishing/bsb2usfm/releases (BSB_usj.zip).

Usage:
    python3 scripts/build_daily_verses.py <folder with the unzipped *.usj files>

Writes: Packages/ClimbHighCore/Sources/ClimbHighCore/Resources/daily-verses.json
"""

import json
import pathlib
import re
import sys

# One verse (or short passage) per day. Order = the order they appear in the app.
REFERENCES = """
JER 29:11 | PRO 3:5-6 | PHP 4:13 | JOS 1:9 | ISA 40:31 | ROM 8:28 | PSA 23:1-3 | MAT 11:28-30
PHP 4:6-7 | ISA 41:10 | JHN 3:16 | 2TI 1:7 | PSA 46:1 | ROM 12:2 | MAT 6:33 | GAL 6:9
PSA 118:24 | LAM 3:22-23 | 1CO 10:31 | COL 3:23-24 | PRO 16:3 | PSA 37:4 | HEB 11:1 | JAS 1:5
1TI 4:8 | PSA 144:1 | 2CO 12:9 | ISA 26:3 | JHN 14:27 | PSA 27:1 | ROM 15:13 | PRO 4:23
MIC 6:8 | HEB 12:11 | 1CO 6:19-20 | DEU 31:6 | PSA 121:1-2 | MAT 5:16 | EPH 2:10 | PSA 19:14
JHN 16:33 | NEH 8:10 | ROM 5:3-4 | PSA 34:18 | 1PE 5:6-7 | ECC 9:10 | PRO 21:5 | 2CO 5:17
PSA 139:13-14 | ISA 43:18-19 | JHN 15:5 | PRO 27:17 | HEB 13:8 | PSA 16:8 | ZEP 3:17 | GAL 5:22-23
1TH 5:16-18 | PRO 14:23 | JAS 1:2-3 | PSA 55:22 | MAT 19:26 | ISA 40:29 | 1CO 15:58 | EPH 3:20
PSA 37:5 | HAB 3:19 | JHN 10:10 | PRO 16:9 | ROM 8:31 | PSA 28:7 | 2TH 3:3 | COL 3:2
PSA 32:8 | MAT 7:7 | PHP 1:6 | PRO 12:25 | ISA 30:21 | 1JN 4:18 | PSA 90:12 | HEB 4:16
JOS 1:8 | PSA 1:1-2 | MAT 6:34 | PRO 19:21 | ROM 8:38-39 | 1PE 5:10 | PSA 73:26 | ISA 55:8-9
JHN 8:12 | PRO 13:4 | PSA 62:1-2 | 2CO 4:16-17 | JAS 1:12 | DEU 31:8 | PSA 91:1-2 | 1JN 1:9
PRO 22:29 | MAT 5:9 | PSA 103:12 | ROM 12:12 | ISA 41:13 | HEB 10:23 | PSA 34:8 | GAL 2:20
PRO 15:1 | JHN 14:6 | PSA 46:10 | 1CO 9:24 | JER 17:7-8 | PHP 4:8 | PSA 56:3 | EPH 4:32
PRO 16:24 | MRK 9:23 | PSA 40:1-2 | 2TI 4:7 | ISA 43:2 | ROM 5:8 | PSA 119:105 | COL 4:2
PRO 11:25 | MAT 22:37-39 | PSA 145:18 | 1TH 5:11 | JER 33:3 | JHN 15:13 | PSA 86:11 | JAS 4:8
PRO 24:16 | EPH 6:10 | PSA 30:5 | ROM 10:17 | ISA 54:10 | 1PE 4:10 | PSA 4:8 | HEB 12:1-2
PRO 10:4 | LUK 16:10 | PSA 9:9-10 | 2CO 5:7 | NAM 1:7 | JHN 1:5 | PSA 100:4-5 | GAL 6:2
PRO 18:10 | MAT 5:14 | PSA 147:3 | ROM 6:23 | ISA 46:4 | 1JN 4:19 | PSA 18:2 | JAS 1:22
PRO 31:25 | ACT 20:35 | PSA 25:4-5 | EPH 4:29 | ZEC 4:6 | JHN 11:25 | PSA 84:11 | 1TI 4:12
PRO 17:17 | MAT 25:21 | PSA 51:10 | ROM 12:21 | ISA 58:11 | 2CO 9:7 | PSA 27:14 | HEB 11:6
ECC 4:9-10 | LUK 1:37 | PSA 107:1 | PHP 3:13-14 | MAL 3:10 | JHN 13:34-35 | PSA 31:24 | 1CO 16:13-14
PRO 3:27 | MRK 10:45 | PSA 94:19 | ROM 8:18 | ISA 12:2 | JAS 5:16 | PSA 5:3 | EPH 2:8-9
PRO 6:6-8 | MAT 5:6 | PSA 119:11 | 2TI 3:16-17 | JER 31:3 | 1JN 3:18 | PSA 63:1 | COL 2:6-7
PRO 28:13 | JHN 6:35 | PSA 121:7-8 | ROM 8:1 | ISA 9:6 | 1CO 13:4-5 | PSA 16:11 | 2PE 3:9
PRO 13:20 | MAT 7:24 | PSA 42:11 | GAL 5:1 | EXO 14:14 | JHN 14:1 | PSA 34:4 | HEB 13:5
PRO 15:22 | LUK 6:38 | PSA 127:1 | ROM 12:1 | ISA 26:4 | 1TH 4:11-12 | PSA 143:8 | JAS 4:7
PRO 16:18 | MAT 17:20 | PSA 29:11 | 2CO 4:18 | DEU 6:5 | JHN 20:29 | PSA 59:16 | 1PE 2:9
PRO 12:24 | ACT 1:8 | PSA 136:1 | ROM 5:1 | ISA 49:16 | EPH 5:15-16 | PSA 37:7 | 1JN 4:4
PRO 9:10 | MAT 6:6 | PSA 138:8 | 2CO 1:3-4 | LAM 3:25 | JHN 8:32 | PSA 103:1-2 | HEB 4:12
PRO 11:2 | LUK 9:23 | PSA 150:6 | ROM 10:9 | ISA 65:24 | PHP 4:19 | PSA 66:20 | 1CO 15:57
PRO 20:4 | MAT 5:44 | PSA 23:4 | JAS 1:19 | EXO 15:2 | JHN 1:12 | PSA 139:23-24 | 2CO 3:17
PRO 22:6 | MRK 11:24 | PSA 91:11 | ROM 3:23-24 | ISA 64:8 | COL 1:17 | PSA 112:7 | 1JN 5:14
PRO 31:30 | MAT 28:20 | PSA 130:5 | GAL 6:7 | NUM 6:24-26 | JHN 10:11 | PSA 8:3-4 | 1CO 13:13
PRO 2:6 | LUK 12:15 | PSA 119:114 | EPH 1:7 | ISA 35:4 | 2TH 3:13 | PSA 86:5 | HEB 6:19
PRO 17:22 | ACT 4:12 | PSA 20:7 | ROM 15:4 | JER 32:17 | PHP 1:21 | PSA 133:1 | JAS 4:10
PRO 22:1 | MAT 5:8 | PSA 119:165 | 1CO 2:9 | DEU 7:9 | JHN 4:14 | PSA 3:3 | 1PE 1:3
PRO 27:1 | MRK 16:15 | PSA 50:15 | ROM 4:20-21 | ISA 50:7 | 1TH 5:24 | PSA 68:19 | REV 3:20
PRO 30:5 | LUK 6:31 | PSA 113:3 | 2CO 9:8 | 1SA 16:7 | JHN 15:7 | PSA 33:4 | 1JN 3:1
PRO 21:31 | MAT 6:21 | PSA 90:17 | GAL 3:28 | ISA 48:17 | HEB 10:24-25 | PSA 145:3 | 1JN 5:4
PRO 10:22 | ACT 3:19 | PSA 147:11 | ROM 14:8 | HAB 2:3 | JHN 6:37 | PSA 37:23-24 | REV 21:4
PRO 25:28 | MAT 9:37-38 | PSA 71:14 | EPH 4:2-3 | ECC 3:1 | 3JN 1:2 | PSA 18:30 | 2TI 2:15
PRO 14:29 | LUK 11:13 | PSA 36:5 | ROM 13:8 | 2CH 7:14 | JUD 1:24-25 | PSA 89:1 | REV 1:8
PRO 12:1 | MAT 5:5 | PSA 116:1-2 | 1CO 10:13 | GEN 28:15 | JHN 15:12 | PSA 19:1 | REV 21:5
PRO 8:17 | MRK 12:30 | PSA 95:1 | PHP 2:3-4 | ECC 7:8 | ISA 6:8 | PSA 61:2 | COL 3:12
PRO 13:11 | LUK 18:27 | PSA 115:1 | ROM 12:10 | GEN 50:20 | JHN 1:1 | PSA 141:3 | COL 3:15
PRO 19:17 | MAT 5:7 | PSA 92:1-2 | EPH 6:11 | JOS 24:15 | TIT 3:5 | PSA 96:1 | 1TI 6:6
PRO 20:24 | ACT 16:31 | PSA 39:7 | 2CO 10:5 | PSA 34:1 | JHN 3:17 | PSA 119:50 | HEB 13:16
PRO 18:21 | MAT 6:24 | PSA 119:71 | PHP 2:13 | 1CH 16:11 | 1PE 3:15 | PSA 33:22 | JAS 1:17
PRO 23:4 | LUK 12:34 | PSA 22:3 | GAL 6:10 | 2SA 22:31 | 1TI 6:12 | PSA 1:3 | JAS 3:17
PRO 3:9-10 | MAT 7:12 | PSA 20:4 | ROM 15:5 | 1CH 29:11 | 2TI 1:9 | PSA 118:6 | PHP 4:4
PRO 15:3 | EXO 33:14 | PSA 16:1 | 1CH 16:34 | ECC 12:13 | DAN 12:3
"""

BOOK_NAMES = {
    "GEN": "Genesis", "EXO": "Exodus", "NUM": "Numbers", "DEU": "Deuteronomy", "JOS": "Joshua",
    "1SA": "1 Samuel", "2SA": "2 Samuel", "1CH": "1 Chronicles", "2CH": "2 Chronicles", "NEH": "Nehemiah",
    "JOB": "Job", "PSA": "Psalm", "PRO": "Proverbs", "ECC": "Ecclesiastes", "ISA": "Isaiah",
    "JER": "Jeremiah", "LAM": "Lamentations", "EZK": "Ezekiel", "DAN": "Daniel", "MIC": "Micah",
    "NAM": "Nahum", "HAB": "Habakkuk", "ZEP": "Zephaniah", "ZEC": "Zechariah", "MAL": "Malachi",
    "MAT": "Matthew", "MRK": "Mark", "LUK": "Luke", "JHN": "John", "ACT": "Acts", "ROM": "Romans",
    "1CO": "1 Corinthians", "2CO": "2 Corinthians", "GAL": "Galatians", "EPH": "Ephesians",
    "PHP": "Philippians", "COL": "Colossians", "1TH": "1 Thessalonians", "2TH": "2 Thessalonians",
    "1TI": "1 Timothy", "2TI": "2 Timothy", "TIT": "Titus", "HEB": "Hebrews", "JAS": "James",
    "1PE": "1 Peter", "2PE": "2 Peter", "1JN": "1 John", "3JN": "3 John", "JUD": "Jude", "REV": "Revelation",
}

# Paragraph markers that are headings/titles, not verse text.
SKIP_PARAS = {"s", "s1", "s2", "s3", "s4", "r", "ms", "ms1", "ms2", "mr", "sp", "sr", "cl",
              "mt", "mt1", "mt2", "mt3", "h", "toc1", "toc2", "toc3", "ide", "rem", "cd"}
# Psalm titles ("A Psalm of David."): may hold the verse-1 marker, but their words aren't shown.
TITLE_PARAS = {"d"}


def load_verses(usj_dir: pathlib.Path, book: str) -> dict:
    """Returns {"3:16": "For God so loved…", …} for one book."""
    data = json.loads((usj_dir / f"{book}.usj").read_text(encoding="utf-8"))
    verses: dict[str, list[str]] = {}
    state = {"chapter": None, "verse": None, "in_title": False}

    def walk(node):
        if isinstance(node, str):
            if state["verse"] and not state["in_title"]:
                verses.setdefault(state["verse"], []).append(node)
            return
        kind = node.get("type")
        marker = node.get("marker", "")
        if kind == "note":          # footnotes / cross references
            return
        if kind == "chapter":
            state["chapter"] = node.get("number")
            state["verse"] = None
            return
        if kind == "verse":
            state["verse"] = f'{state["chapter"]}:{node.get("number")}'
            return
        if kind == "para" and marker in SKIP_PARAS:
            return
        is_title = kind == "para" and marker in TITLE_PARAS
        if is_title:
            state["in_title"] = True
        for child in node.get("content", []) or []:
            walk(child)
        if is_title:
            state["in_title"] = False
            return
        if kind == "para" and state["verse"]:
            verses.setdefault(state["verse"], []).append(" ")

    walk(data)
    return {key: re.sub(r"\s+", " ", "".join(parts)).strip() for key, parts in verses.items()}


def balance_quotes(text: str) -> str:
    """Excerpts often start or end inside a quotation that spans verses.
    Only the quote marks at the edges are adjusted; the words are never changed."""
    def single_counts(t: str) -> tuple[int, int]:
        opens = t.count("‘")
        # ’ between two letters is an apostrophe (don’t, LORD’s), not a closing quote.
        closes = sum(1 for i, c in enumerate(t) if c == "’" and not (0 < i < len(t) - 1 and t[i - 1].isalpha() and t[i + 1].isalpha()))
        return opens, closes

    t = text
    while t and t[-1] in "”’":
        if t[-1] == "”" and t.count("”") > t.count("“"):
            t = t[:-1]
            continue
        opens, closes = single_counts(t)
        if t[-1] == "’" and closes > opens:
            t = t[:-1]
            continue
        break
    if t.count("“") > t.count("”"):
        t += "”"
    elif t.count("”") > t.count("“"):
        t = "“" + t
    return t


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    usj_dir = pathlib.Path(sys.argv[1])
    references = [r.strip() for r in REFERENCES.replace("\n", "|").split("|") if r.strip()]
    if len(set(references)) != len(references):
        dupes = sorted({r for r in references if references.count(r) > 1})
        sys.exit(f"Duplicate references: {dupes}")

    books: dict[str, dict] = {}
    output = []
    for ref in references:
        book, chapter_verses = ref.split(" ")
        chapter, verse_part = chapter_verses.split(":")
        first, _, last = verse_part.partition("-")
        numbers = range(int(first), int(last or first) + 1)
        if book not in books:
            books[book] = load_verses(usj_dir, book)
        parts = []
        for number in numbers:
            key = f"{chapter}:{number}"
            if key not in books[book] or not books[book][key]:
                sys.exit(f"Missing verse text for {ref} ({key})")
            parts.append(books[book][key])
        name = BOOK_NAMES[book]
        reference = f"{name} {chapter}:{verse_part.replace('-', '–')}"
        output.append({"reference": reference, "text": balance_quotes(" ".join(parts))})

    out = pathlib.Path(__file__).resolve().parent.parent / "Packages/ClimbHighCore/Sources/ClimbHighCore/Resources/daily-verses.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    document = {
        "translation": "Berean Standard Bible (BSB)",
        "license": "Public domain (dedicated April 30, 2023). Source: BSB-publishing/bsb2usfm BSB_usj.zip",
        "verses": output,
    }
    out.write_text(json.dumps(document, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    longest = max(output, key=lambda v: len(v["text"]))
    print(f"Wrote {len(output)} verses to {out}")
    print(f"Longest: {longest['reference']} ({len(longest['text'])} chars)")


if __name__ == "__main__":
    main()
