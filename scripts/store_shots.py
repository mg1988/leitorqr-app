#!/usr/bin/env python3
"""把模拟器截图排成 App Store 商店图（1206×2622，iPhone Pro 6.3"），支持多语言。

排法（2026-11-28 重做）：
- 纯色深蓝底 + 大标题，不用渐变（产品硬规则）。
- 截图**不加手机外壳**，直接做一张 1020 宽的圆角卡片，底边留 30px。
  加外壳会额外吃掉 20% 宽高，缩到 App Store 搜索结果的缩略图尺寸后字就看不清了。
- 截图只裁掉顶部状态栏（raw y 0–200），其余 1:1 呈现，操作栏不会被切。
- 标题一律写两行：版面高度固定，卡片位置也就固定，不用逐张调。

用法：先用 `store/listing.md` 第四节里的命令抓原始截图，再跑
    python3 scripts/store_shots.py            # 全部语言
    python3 scripts/store_shots.py en         # 只出英文
"""
import base64, os, subprocess, sys

W, H = 1206, 2622
CROP_TOP = 200          # 裁掉状态栏（raw 像素）
CARD_W = 1020
CARD_H = round(CARD_W * (H - CROP_TOP) / W)   # 2048
CARD_BOTTOM = 30

BG = "#0E1526"
ROOT = "/Volumes/my_data/qr-scan"
OUT_BASE = ROOT + "/.build/store"
SRC = ROOT + "/.build/shots"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 每个语言一套：原始截图后缀（pt-BR 用裸文件名）+ 文案。
# 文案规则：标题写「能替我干什么」，不写功能名；副标题要具体到能在脑子里出画面。
LOCALES = {
    "pt-BR": {
        "raw_suffix": "",
        "shots": [
            ("01_criar", "s_studio", "Códigos com<br>a sua cara", "Cores, pontos, olhos, logo e modelos."),
            ("02_codigo_barras", "s_barcode", "Lê QR e<br>código de barras", "EAN-13, Code 128, Code 39 e mais."),
            ("03_risco", "s_risk", "Confere o link<br>antes de abrir", "Avisa domínio falso, sem HTTPS, golpe."),
            ("04_historico", "s_history", "Nunca perca<br>um código", "Histórico no aparelho, com busca e filtros."),
            ("05_privacidade", "s_privacy", "Sem conta.<br>Sem anúncio.", "Nenhum dado sai do aparelho."),
            ("06_preco", "s_price", "Pague uma vez.<br>Use sempre.", "Sem assinatura, sem cobrança mensal."),
        ],
    },
    "en": {
        "raw_suffix": "_en",
        "shots": [
            ("01_criar", "s_studio", "Codes that<br>look like you", "Colors, dots, eyes, logo and templates."),
            ("02_codigo_barras", "s_barcode", "Reads QR<br>and barcodes", "EAN-13, Code 128, Code 39 and more."),
            ("03_risco", "s_risk", "Check the link<br>before you open", "Flags fake domains, no HTTPS, scam words."),
            ("04_historico", "s_history", "Never lose<br>a code again", "On-device history with search and filters."),
            ("05_privacidade", "s_privacy", "No account.<br>No ads.", "Nothing ever leaves your phone."),
            ("06_preco", "s_price", "Pay once.<br>Use forever.", "No subscription, no monthly bill."),
        ],
    },
}

HTML = """<!DOCTYPE html>
<html lang="{lang}" spellcheck="false"><head><meta charset="utf-8">
<style>
  @page {{ margin: 0; }}
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  /* Chrome 会给葡语等词加红色拼写波浪线，出图前关掉 */
  ::spelling-error {{ text-decoration:none; }}
  ::grammar-error {{ text-decoration:none; }}
  html, body {{ width:{W}px; height:{H}px; background:{BG}; overflow:hidden; }}
  body {{ font-family:-apple-system, "SF Pro Display", "Helvetica Neue", sans-serif; position:relative; }}

  .title {{
    position:absolute; top:104px; left:0; right:0;
    text-align:center; color:#FFFFFF;
    font-size:104px; line-height:1.13; font-weight:800;
    letter-spacing:-3.4px; padding:0 96px;
  }}
  .sub {{
    position:absolute; top:{sub_top}px; left:0; right:0;
    text-align:center; color:#93A7CC;
    font-size:43px; line-height:1.24; font-weight:500;
    letter-spacing:-0.4px; padding:0 110px;
  }}
  .card {{
    position:absolute; left:{CARD_LEFT}px; bottom:{CARD_BOTTOM}px;
    width:{CARD_W}px; height:{CARD_H}px; border-radius:56px; overflow:hidden;
    background:#FFFFFF;
    box-shadow:0 26px 70px rgba(0,0,0,.45);
  }}
  .card img {{ width:{CARD_W}px; display:block; margin-top:-{crop_scaled}px; }}
</style></head>
<body spellcheck="false">
  <div class="title" spellcheck="false">{title}</div>
  <div class="sub" spellcheck="false">{sub}</div>
  <div class="card"><img src="data:image/png;base64,{img}"></div>
</body></html>"""


def build(lang, name, raw_stem, title, sub):
    src = os.path.join(SRC, raw_stem + LOCALES[lang]["raw_suffix"] + ".png")
    if not os.path.exists(src):
        print("MISS", os.path.basename(src))
        return False
    b64 = base64.b64encode(open(src, "rb").read()).decode()
    card_scale = CARD_W / W
    sub_top = 104 + round(104 * 1.13 * 2) + 30     # 标题两行之后
    html = HTML.format(
        W=W, H=H, BG=BG, img=b64, title=title, sub=sub, lang=lang,
        sub_top=sub_top, CARD_W=CARD_W, CARD_H=CARD_H, CARD_BOTTOM=CARD_BOTTOM,
        CARD_LEFT=(W - CARD_W) // 2,
        crop_scaled=round(CROP_TOP * card_scale),
    )
    os.makedirs("/tmp/store_html", exist_ok=True)
    hp = f"/tmp/store_html/{lang}_{name}.html"
    open(hp, "w", encoding="utf-8").write(html)
    out_dir = os.path.join(OUT_BASE, lang)
    os.makedirs(out_dir, exist_ok=True)
    png = os.path.join(out_dir, name + ".png")
    cmd = [CHROME, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
           f"--window-size={W},{H}", "--force-device-scale-factor=1",
           "--virtual-time-budget=4000", f"--screenshot={png}", "file://" + hp]
    subprocess.run(cmd, check=False, timeout=90,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = os.path.exists(png)
    print(("OK  " if ok else "FAIL"), lang, os.path.basename(png))
    return ok


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(LOCALES)
    for lang in wanted:
        for name, raw_stem, title, sub in LOCALES[lang]["shots"]:
            build(lang, name, raw_stem, title, sub)
