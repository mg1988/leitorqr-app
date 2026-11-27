#!/usr/bin/env python3
"""把模拟器截图排成 App Store 6.9" 商店图（1320×2868）。

- 纯色底 + 大标题，不用渐变（产品硬规则）
- 截图按 88% 宽放进圆角卡片，底部出血，视觉上像「露出屏幕」
- 用 Chrome headless 渲染，字体走系统 SF
"""
import base64, json, os, subprocess, sys

W, H = 1320, 2868
OUT = "/Volumes/my_data/qr-scan/.build/store"
RAW = OUT + "/raw"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

SHOTS = [
    # (输出名, 原始截图, 标题, 副标题)
    ("01_risco",    "s1_risk.png",     "Saiba se o link<br>é seguro", "Antes de abrir, não depois."),
    ("02_wifi",     "s2_wifi.png",     "Wi-Fi com<br>um toque",       "Sem digitar senha na mão."),
    ("03_historico","s3_history.png",  "Tudo fica no<br>seu aparelho", "Histórico local, sem conta."),
    ("04_criar",    "s4_studio.png",   "Códigos com a<br>sua cara",   "Cores, pontos, olhos e logo."),
    ("05_tipos",    "s7_create.png",   "18 tipos de<br>código",       "QR, barras, Wi-Fi, contatos e mais."),
    ("06_idiomas",  "s6_languages.png", "30 idiomas,<br>de verdade",   "Troca na hora, sem reiniciar."),
]

HTML = """<!DOCTYPE html>
<html lang="pt-BR"><head><meta charset="utf-8">
<style>
  @page {{ margin: 0; }}
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body {{ width:{W}px; height:{H}px; background:#161E2C; overflow:hidden; }}
  body {{ font-family:-apple-system, "SF Pro Display", "Helvetica Neue", sans-serif; }}

  .title {{
    position:absolute; top:110px; left:0; right:0;
    text-align:center; color:#FFFFFF;
    font-size:96px; line-height:1.14; font-weight:700;
    letter-spacing:-2.5px;
    padding:0 90px;
  }}
  .sub {{
    position:absolute; top:{sub_top}px; left:0; right:0;
    text-align:center; color:#8FA3C8;
    font-size:46px; line-height:1.3; font-weight:500; letter-spacing:-0.5px;
  }}
  .phone {{
    position:absolute; top:{phone_top}px; left:50%; transform:translateX(-50%);
    width:{pw}px; height:{ph}px; border-radius:76px; overflow:hidden;
    background:#000;
    box-shadow:0 40px 120px rgba(0,0,0,.55), 0 0 0 2px rgba(255,255,255,.14);
  }}
  .phone img {{ width:100%; height:100%; display:block; object-fit:cover; }}
</style></head>
<body>
  <div class="title">{title}</div>
  <div class="sub">{sub}</div>
  <div class="phone"><img src="data:image/png;base64,{img}"></div>
</body></html>"""


def build(name, raw, title, sub):
    src = os.path.join(RAW, raw)
    if not os.path.exists(src):
        src = os.path.join("/Volumes/my_data/qr-scan/.build/shots", raw)
    b64 = base64.b64encode(open(src, "rb").read()).decode()
    pw = 1040
    ph = int(pw * 2868 / 1320)           # 保持原始比例
    phone_top = H - ph                   # 卡片完整落在画布内，底部贴边
    html = HTML.format(W=W, H=H, sub_top=phone_top - 92, phone_top=phone_top,
                       pw=pw, ph=ph, title=title, sub=sub, img=b64)
    hp = os.path.join("/tmp/store_html", name + ".html")
    os.makedirs("/tmp/store_html", exist_ok=True)
    open(hp, "w", encoding="utf-8").write(html)
    png = os.path.join(OUT, name + ".png")
    cmd = [CHROME, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
           f"--window-size={W},{H}", "--force-device-scale-factor=1",
           "--virtual-time-budget=4000", f"--screenshot={png}",
           "file://" + hp]
    subprocess.run(cmd, check=False, timeout=90,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = os.path.exists(png)
    print(("OK  " if ok else "FAIL") , os.path.basename(png))
    return ok


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, raw, title, sub in SHOTS:
        build(name, raw, title, sub)
