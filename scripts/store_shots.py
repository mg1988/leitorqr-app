#!/usr/bin/env python3
"""把模拟器截图排成 App Store 商店图。

尺寸按 iPhone Pro（6.3 吋）1206×2622 输出；所有排版数值以 1320 宽为设计基准
等比缩放，换机型只需改 W/H 并**重新抓原始截图**（不要缩放截图）。

- 纯色底 + 大标题，不用渐变（产品硬规则）
- 截图按 79% 宽放进圆角卡片，卡片完整落在画布内
- 用 Chrome headless 渲染，字体走系统 SF
"""
import base64, os, subprocess

W, H = 1206, 2622
OUT = "/Volumes/my_data/qr-scan/.build/store"
RAW = OUT + "/raw"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

S = W / 1320.0          # 等比缩放系数

SHOTS = [
    # (输出名, 原始截图, 标题, 副标题)
    ("01_risco",     "s1_risk.png",      "Saiba se o link<br>é seguro",  "Antes de abrir, não depois."),
    ("02_wifi",      "s2_wifi.png",      "Wi-Fi com<br>um toque",        "Sem digitar senha na mão."),
    ("03_historico", "s3_history.png",   "Tudo fica no<br>seu aparelho", "Histórico local, sem conta."),
    ("04_criar",     "s4_studio.png",    "Códigos com a<br>sua cara",    "Cores, pontos, olhos e logo."),
    ("05_tipos",     "s7_create.png",    "18 tipos de<br>código",        "QR, barras, Wi-Fi, contatos e mais."),
    ("06_idiomas",   "s6_languages.png", "30 idiomas,<br>de verdade",    "Troca na hora, sem reiniciar."),
]

HTML = """<!DOCTYPE html>
<html lang="pt-BR"><head><meta charset="utf-8">
<style>
  @page {{ margin: 0; }}
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html, body {{ width:{W}px; height:{H}px; background:#161E2C; overflow:hidden; }}
  body {{ font-family:-apple-system, "SF Pro Display", "Helvetica Neue", sans-serif; }}

  .title {{
    position:absolute; top:{title_top}px; left:0; right:0;
    text-align:center; color:#FFFFFF;
    font-size:{title_size}px; line-height:1.14; font-weight:700;
    letter-spacing:-{ls}px;
    padding:0 {pad}px;
  }}
  .sub {{
    position:absolute; top:{sub_top}px; left:0; right:0;
    text-align:center; color:#8FA3C8;
    font-size:{sub_size}px; line-height:1.3; font-weight:500; letter-spacing:-0.5px;
  }}
  .phone {{
    position:absolute; top:{phone_top}px; left:50%; transform:translateX(-50%);
    width:{pw}px; height:{ph}px; border-radius:{radius}px; overflow:hidden;
    background:#000;
    box-shadow:0 {shadow}px {shadow2}px rgba(0,0,0,.55), 0 0 0 2px rgba(255,255,255,.14);
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
    pw = round(1040 * S)
    ph = round(pw * H / W)
    phone_top = H - ph
    html = HTML.format(
        W=W, H=H, img=b64, title=title, sub=sub,
        title_top=round(110 * S), title_size=round(96 * S), ls=round(2.5 * S, 2),
        pad=round(90 * S), sub_top=phone_top - round(92 * S), sub_size=round(46 * S),
        phone_top=phone_top, pw=pw, ph=ph, radius=round(76 * S),
        shadow=round(40 * S), shadow2=round(120 * S),
    )
    os.makedirs("/tmp/store_html", exist_ok=True)
    hp = f"/tmp/store_html/{name}.html"
    open(hp, "w", encoding="utf-8").write(html)
    png = os.path.join(OUT, name + ".png")
    cmd = [CHROME, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
           f"--window-size={W},{H}", "--force-device-scale-factor=1",
           "--virtual-time-budget=4000", f"--screenshot={png}", "file://" + hp]
    subprocess.run(cmd, check=False, timeout=90,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = os.path.exists(png)
    print(("OK  " if ok else "FAIL"), os.path.basename(png))
    return ok


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, raw, title, sub in SHOTS:
        build(name, raw, title, sub)
