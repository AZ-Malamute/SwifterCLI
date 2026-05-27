import zipfile, json, re, html
from pathlib import Path
from datetime import datetime

zip_path = Path("Data/reelgood.com.zip")
out_path = Path("Data/available_titles.json")

titles = []

title_re = re.compile(r"<title>(.*?)</title>", re.I | re.S)
og_title_re = re.compile(r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\'](.*?)["\']', re.I | re.S)
og_image_re = re.compile(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\'](.*?)["\']', re.I | re.S)
desc_re = re.compile(r'<meta[^>]+(?:name|property)=["\'](?:description|og:description)["\'][^>]+content=["\'](.*?)["\']', re.I | re.S)

def clean(s):
    s = html.unescape(s or "")
    s = re.sub(r"\s+", " ", s).strip()
    return s

def infer_year(text, path):
    m = re.search(r"\b(19\d{2}|20\d{2})\b", text + " " + path)
    return int(m.group(1)) if m else None

with zipfile.ZipFile(zip_path) as z:
    html_files = [n for n in z.namelist() if n.endswith(".html") and not Path(n).name.startswith("._") and "__MACOSX" not in n and ("/movie/" in n or n.startswith("movie/") or "/show/" in n or n.startswith("show/"))]

    for name in html_files:
        try:
            raw = z.read(name).decode("utf-8", errors="ignore")
        except Exception:
            continue

        og_title = clean(og_title_re.search(raw).group(1)) if og_title_re.search(raw) else ""
        page_title = clean(title_re.search(raw).group(1)) if title_re.search(raw) else ""
        poster = clean(og_image_re.search(raw).group(1)) if og_image_re.search(raw) else ""
        desc = clean(desc_re.search(raw).group(1)) if desc_re.search(raw) else ""

        title = og_title or page_title
        title = re.sub(r"\s*\|\s*Reelgood.*$", "", title).strip()
        title = re.sub(r"\s*\([^)]*\): Where to Watch and Stream Online$", "", title).strip()
        title = re.sub(r"\s*:\s*Where to Watch and Stream Online$", "", title).strip()
        title = re.sub(r"\s*Where to Watch and Stream Online$", "", title).strip()
        title = re.sub(r"\s*streaming.*$", "", title, flags=re.I).strip()

        if not title:
            stem = Path(name).stem
            title = re.sub(r"-\d{4}$", "", stem).replace("-", " ").title()

        year = infer_year(title + " " + desc, name)

        titles.append({
            "title": title,
            "year": year,
            "description": desc,
            "poster_url": poster,
            "source": "local_reelgood_scrape",
            "source_file": name
        })

seen = set()
deduped = []
for t in titles:
    key = (t["title"].lower(), t["year"])
    if key not in seen:
        seen.add(key)
        deduped.append(t)

payload = {
    "generated_at": datetime.now().isoformat(),
    "source_zip": str(zip_path),
    "count": len(deduped),
    "titles": deduped
}

out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False))
print(f"✅ Extracted {len(deduped)} titles")
print(f"✅ Wrote {out_path}")
