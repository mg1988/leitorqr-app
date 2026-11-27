#!/usr/bin/env python3
# 生成官网静态页（ASC 必填的「技术支持网址」「隐私政策网址」都指向这里）。
#
#   python3 scripts/gen_site.py
#
# 输出 docs/：
#   index.html            首页（App 介绍 + 链接）
#   support.html          支持 / 常见问题 + 联系邮箱      → ASC「技术支持网址」
#   privacy-policy.html   隐私政策 + 使用条款（#privacy / #terms）→ ASC「隐私政策网址」
#   assets/icon.png       App 图标（由 AppIcon 缩小）
#   .nojekyll             GitHub Pages 原样发布，不经 Jekyll
#
# 隐私 / 条款正文的真值是 Localizable.xcstrings 的 legal.* 文案（与 App 内 LegalDocumentView 一致），
# App 内文案改了重跑本脚本即可同步。支持页 FAQ 写在本文件 SUPPORT 里。
# 每页四种语言：按浏览器语言自动显示一种，顶部可切换（记在 localStorage）；没有 JS 时全部显示。

import html
import json
import pathlib
import subprocess
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
XCS = ROOT / "LeitorQR" / "Resources" / "Localizable.xcstrings"
ICON = ROOT / "LeitorQR" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"
OUT = ROOT / "docs"

APP_NAME = "Leitor QR"
EMAIL = "genweimi@gmail.com"
# App 上架后填 App Store 链接（例如 "https://apps.apple.com/app/id1234567890"）；None 时显示「即将上架」。
APP_STORE_URL = None

# (xcstrings 语言, 页面锚点 / lang 属性, 切换按钮文字)
LANGS = [("pt-BR", "pt", "Português"), ("en", "en", "English"), ("zh-Hans", "zh", "简体中文"), ("ja", "ja", "日本語")]

data = json.loads(XCS.read_text(encoding="utf-8"))


def xs(key, lang):
    return data["strings"][key]["localizations"][lang]["stringUnit"]["value"]


e = html.escape

UI = {
    "pt": dict(home="Início", support="Suporte", privacy="Privacidade", terms="Termos",
               tagline="Leia e crie códigos QR com segurança.",
               soon="Em breve na App Store", store="Baixar na App Store",
               price="Recursos essenciais gratuitos. O Premium é uma compra única — sem assinatura.",
               faq="Perguntas frequentes", contact_t="Ainda precisa de ajuda?",
               contact_d="Escreva para nós. Para agilizar, inclua o modelo do iPhone, a versão do iOS e, se possível, uma captura de tela.",
               write="Enviar e-mail", legal_t="Privacidade e termos", rights="Todos os direitos reservados."),
    "en": dict(home="Home", support="Support", privacy="Privacy", terms="Terms",
               tagline="Scan and create QR codes, safely.",
               soon="Coming soon to the App Store", store="Download on the App Store",
               price="Core features are free. Premium is a one-time purchase — no subscription.",
               faq="Frequently asked questions", contact_t="Still need help?",
               contact_d="Email us. To help us answer faster, include your iPhone model, iOS version and, if possible, a screenshot.",
               write="Send email", legal_t="Privacy & terms", rights="All rights reserved."),
    "zh": dict(home="首页", support="支持", privacy="隐私", terms="条款",
               tagline="安全地扫码，漂亮地生成二维码。",
               soon="即将登陆 App Store", store="在 App Store 下载",
               price="基础功能免费。高级版一次买断，不是订阅。",
               faq="常见问题", contact_t="还需要帮助？",
               contact_d="给我们发邮件。附上 iPhone 型号、iOS 版本，最好再加一张截图，能更快帮你解决。",
               write="发送邮件", legal_t="隐私与条款", rights="保留所有权利。"),
    "ja": dict(home="ホーム", support="サポート", privacy="プライバシー", terms="利用規約",
               tagline="QRコードを安全に読み取り、美しく作成。",
               soon="App Store にまもなく登場", store="App Store からダウンロード",
               price="基本機能は無料。プレミアムは買い切りで、サブスクリプションではありません。",
               faq="よくある質問", contact_t="解決しない場合",
               contact_d="メールでお問い合わせください。iPhone の機種、iOS のバージョン、可能であればスクリーンショットを添えていただくと早く対応できます。",
               write="メールを送る", legal_t="プライバシーと利用規約", rights="All rights reserved."),
}

FEATURES = {
    "pt": [("Leitura rápida e segura", "Leia códigos QR e de barras pela câmera ou a partir de fotos. Links suspeitos são sinalizados antes de você abrir."),
           ("Códigos QR bonitos", "Crie códigos para sites, Wi‑Fi, contatos e redes sociais, com estilos, cores e o seu logotipo."),
           ("Wi‑Fi num toque", "Leia o código de uma rede e conecte-se sem digitar a senha."),
           ("Privado por padrão", "Tudo fica no seu iPhone. Sem conta, sem rastreamento, sem anúncios.")],
    "en": [("Fast, safe scanning", "Scan QR codes and barcodes with the camera or from photos. Suspicious links are flagged before you open them."),
           ("Beautiful QR codes", "Create codes for websites, Wi‑Fi, contacts and social profiles — with styles, colors and your own logo."),
           ("Wi‑Fi in one tap", "Scan a network's code and join without typing the password."),
           ("Private by design", "Everything stays on your iPhone. No account, no tracking, no ads.")],
    "zh": [("快速、安全地扫码", "用相机或相册图片识别二维码和条形码。可疑链接在打开前就会提醒你。"),
           ("漂亮的二维码", "为网址、Wi‑Fi、名片和社交主页生成二维码，样式、颜色、Logo 都能自己定。"),
           ("一键连 Wi‑Fi", "扫一下网络的二维码，不用输密码就能连上。"),
           ("隐私优先", "所有数据只存在你的 iPhone 上。无需注册，不追踪，没有广告。")],
    "ja": [("すばやく安全に読み取り", "カメラや写真から QR コード・バーコードを読み取り。怪しいリンクは開く前に警告します。"),
           ("美しい QR コード", "Web サイト、Wi‑Fi、連絡先、SNS 用のコードを、スタイル・色・ロゴを選んで作成できます。"),
           ("Wi‑Fi にワンタップで接続", "ネットワークのコードを読み取るだけで、パスワード入力なしで接続できます。"),
           ("プライバシー重視", "データはすべて iPhone の中だけ。アカウント不要、トラッキングなし、広告なし。")],
}

SUPPORT = {
    "pt": [
        ("Como ler um código?", "Abra a aba Ler e aponte a câmera para o código. Para ler a partir de uma imagem, toque no botão de fotos no canto superior direito."),
        ("A câmera não abre", "Vá a Ajustes do iPhone › Leitor QR e ative a Câmera."),
        ("Como conectar a uma rede Wi‑Fi?", "Leia o código Wi‑Fi e toque em Conectar. O iOS pede uma confirmação antes de entrar na rede. Redes corporativas (WPA‑Enterprise) não são suportadas pelo iOS neste modo."),
        ("Onde fica o meu histórico?", "Apenas no seu iPhone. Não fazemos cópias em servidores. Se apagar o app, o histórico é apagado junto."),
        ("O que inclui o Premium?", "Histórico ilimitado, todos os estilos e modelos de QR, logotipo personalizado e o histórico de verificações de segurança. É um pagamento único, válido para sempre no seu Apple ID."),
        ("Comprei o Premium, mas ele não aparece", "Abra a tela do Premium no app e toque em Restaurar compras, usando o mesmo Apple ID da compra."),
        ("Como pedir reembolso?", "Os pagamentos são processados pela Apple. Peça o reembolso em reportaproblem.apple.com."),
        ("Um código que criei não é lido", "Use cores escuras sobre fundo claro e evite contraste baixo. Ao imprimir, não reduza demais o tamanho. Com logotipo, prefira imagens simples."),
    ],
    "en": [
        ("How do I scan a code?", "Open the Scan tab and point the camera at the code. To scan from an image, tap the photos button in the top-right corner."),
        ("The camera doesn't open", "Go to the iPhone Settings › Leitor QR and turn on Camera."),
        ("How do I join a Wi‑Fi network?", "Scan the Wi‑Fi code and tap Connect. iOS asks you to confirm before joining. Enterprise networks (WPA‑Enterprise) aren't supported by iOS in this mode."),
        ("Where is my history stored?", "Only on your iPhone — nothing is copied to a server. Deleting the app also deletes the history."),
        ("What does Premium include?", "Unlimited history, every QR style and template, a custom logo, and security check history. It's a one-time payment that stays with your Apple ID forever."),
        ("I bought Premium but it isn't showing", "Open the Premium screen in the app and tap Restore Purchases, using the same Apple ID you bought with."),
        ("How do I request a refund?", "Payments are handled by Apple. Request a refund at reportaproblem.apple.com."),
        ("A code I created won't scan", "Use dark colors on a light background and avoid low contrast. Don't print it too small. If you add a logo, keep the image simple."),
    ],
    "zh": [
        ("怎么扫码？", "打开「扫码」页，把相机对准二维码即可。要识别图片里的码，点右上角的相册按钮。"),
        ("相机打不开", "前往 iPhone「设置」›「Leitor QR」，打开「相机」。"),
        ("怎么连接 Wi‑Fi？", "扫描 Wi‑Fi 二维码后点「连接」，iOS 会先请你确认。企业网络（WPA‑Enterprise）在这种方式下 iOS 不支持。"),
        ("历史记录存在哪里？", "只存在你的 iPhone 上，不会上传到服务器。删除 App 时历史记录会一起删除。"),
        ("高级版包含什么？", "无限历史记录、全部二维码样式和模板、自定义 Logo，以及安全检测历史。一次付费，永久跟随你的 Apple ID。"),
        ("买了高级版但没有生效", "在 App 里打开高级版页面，点「恢复购买」。请使用购买时的同一个 Apple ID。"),
        ("怎么申请退款？", "付款由 Apple 处理，请在 reportaproblem.apple.com 申请退款。"),
        ("我生成的码扫不出来", "请用深色码点配浅色背景，避免对比度太低；打印时不要缩得太小；加 Logo 时尽量用简单的图案。"),
    ],
    "ja": [
        ("コードの読み取り方は？", "「スキャン」タブを開き、カメラをコードに向けてください。画像から読み取るには、右上の写真ボタンをタップします。"),
        ("カメラが起動しない", "iPhone の「設定」›「Leitor QR」で「カメラ」をオンにしてください。"),
        ("Wi‑Fi に接続するには？", "Wi‑Fi のコードを読み取り「接続」をタップします。接続前に iOS が確認を求めます。企業向けネットワーク（WPA‑Enterprise）は、この方法では iOS が対応していません。"),
        ("履歴はどこに保存されますか？", "iPhone の中だけです。サーバーには一切送信しません。App を削除すると履歴も削除されます。"),
        ("プレミアムの内容は？", "履歴の無制限保存、すべての QR スタイルとテンプレート、ロゴの追加、安全チェックの履歴。一度の支払いで、Apple ID にずっと残ります。"),
        ("購入したのに反映されない", "App のプレミアム画面で「購入を復元」をタップしてください。購入時と同じ Apple ID を使用してください。"),
        ("返金を申請するには？", "支払いは Apple が処理しています。reportaproblem.apple.com から申請してください。"),
        ("作成したコードが読み取れない", "明るい背景に濃い色を使い、コントラストが低くならないようにしてください。印刷時は小さくしすぎないこと。ロゴはシンプルな画像がおすすめです。"),
    ],
}

CSS = """
:root{color-scheme:light dark;--bg:#F4F6FB;--card:#FFFFFF;--text:#111418;--sub:#5B6475;--line:#E3E7EF;--brand:#2A52F0;--fill:#2449E6}
@media (prefers-color-scheme:dark){:root{--bg:#0B0E14;--card:#151A23;--text:#F2F4F8;--sub:#9AA3B2;--line:#2A3140;--brand:#7C9BFF;--fill:#3D63F5}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:16px/1.65 -apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Roboto,"Noto Sans","PingFang SC","Hiragino Sans",sans-serif;-webkit-font-smoothing:antialiased}
a{color:var(--brand);text-decoration:none}a:hover{text-decoration:underline}
.wrap{max-width:46rem;margin:0 auto;padding:0 20px}
.top{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:18px 0;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:10px;font-weight:700;color:var(--text)}
.brand img{width:32px;height:32px;border-radius:8px}
.menu{display:flex;gap:16px;font-size:.95rem}
.langs{display:flex;gap:6px;flex-wrap:wrap;margin:4px 0 8px}
.langs button{font:inherit;font-size:.85rem;padding:5px 12px;border-radius:999px;border:1px solid var(--line);background:var(--card);color:var(--sub);cursor:pointer}
.langs button[aria-pressed=true]{background:var(--fill);border-color:var(--fill);color:#fff}
.hero{text-align:center;padding:48px 0 28px}
.hero img{width:112px;height:112px;border-radius:26px;box-shadow:0 10px 30px rgba(17,20,24,.16)}
.hero h1{font-size:2.1rem;line-height:1.2;margin:22px 0 6px}
.hero p{color:var(--sub);font-size:1.12rem;margin:0}
.cta{display:inline-block;margin-top:24px;padding:12px 22px;border-radius:999px;background:var(--fill);color:#fff;font-weight:600}
.cta.soon{background:var(--card);color:var(--sub);border:1px solid var(--line)}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(15rem,1fr));gap:14px;margin:12px 0 18px}
.card{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:18px 20px}
.card h3{margin:0 0 4px;font-size:1.02rem}.card p{margin:0;color:var(--sub)}
.note{text-align:center;color:var(--sub);font-size:.95rem;margin:8px 0 40px}
h1.page{font-size:1.7rem;margin:28px 0 4px}
h2{font-size:1.25rem;margin:36px 0 10px}
h3{font-size:1.02rem;margin:22px 0 4px}
details{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:14px 18px;margin:10px 0}
summary{cursor:pointer;font-weight:600;list-style-position:outside}
details p{margin:8px 0 0;color:var(--sub)}
.contact{margin:30px 0 10px;text-align:left}
.contact .cta{margin-top:12px}
.updated{color:var(--sub);font-size:.85rem}
.summary{color:var(--sub)}
footer{border-top:1px solid var(--line);margin-top:48px;padding:22px 0 48px;color:var(--sub);font-size:.88rem;display:flex;gap:14px;flex-wrap:wrap;justify-content:space-between}
footer nav{display:flex;gap:14px;flex-wrap:wrap}
.js [data-lang]{display:none}.js [data-lang].on{display:block}.js nav[data-lang].on{display:flex}
"""

JS = """
<script>
(function(){
  var langs=%s, root=document.documentElement; root.classList.add('js');
  function pick(){
    var saved=null; try{saved=localStorage.getItem('lang')}catch(e){}
    if(saved&&langs.indexOf(saved)>=0) return saved;
    var nav=(navigator.languages||[navigator.language||'en']);
    for(var i=0;i<nav.length;i++){var c=(nav[i]||'').slice(0,2).toLowerCase(); if(langs.indexOf(c)>=0) return c;}
    return 'en';
  }
  function show(l){
    document.querySelectorAll('[data-lang]').forEach(function(n){n.classList.toggle('on',n.getAttribute('data-lang')===l)});
    document.querySelectorAll('.langs button').forEach(function(b){b.setAttribute('aria-pressed',b.value===l)});
    root.lang=l; try{localStorage.setItem('lang',l)}catch(e){}
  }
  document.addEventListener('DOMContentLoaded',function(){
    document.querySelectorAll('.langs button').forEach(function(b){b.addEventListener('click',function(){show(b.value)})});
    show(pick());
  });
})();
</script>
""" % json.dumps([a for _, a, _ in LANGS])


def lang_buttons():
    return '<div class="langs" role="group">' + "".join(
        f'<button type="button" value="{a}" aria-pressed="false">{e(label)}</button>' for _, a, label in LANGS
    ) + "</div>"


def chrome(title, body):
    menu = "".join(
        f'<span data-lang="{a}"><a href="index.html">{e(UI[a]["home"])}</a> · <a href="support.html">{e(UI[a]["support"])}</a> · <a href="privacy-policy.html">{e(UI[a]["privacy"])}</a></span>'
        for _, a, _ in LANGS
    )
    foot = "".join(
        f'<nav data-lang="{a}"><a href="support.html">{e(UI[a]["support"])}</a><a href="privacy-policy.html#privacy">{e(UI[a]["privacy"])}</a><a href="privacy-policy.html#terms">{e(UI[a]["terms"])}</a><a href="mailto:{EMAIL}">{EMAIL}</a></nav>'
        for _, a, _ in LANGS
    )
    return f"""<!DOCTYPE html>
<html lang="pt">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(title)}</title>
<link rel="icon" href="assets/icon.png">
<link rel="apple-touch-icon" href="assets/icon.png">
<style>{CSS}</style>
{JS}
</head>
<body>
<div class="wrap">
<header class="top">
  <a class="brand" href="index.html"><img src="assets/icon.png" alt="">{APP_NAME}</a>
  <div class="menu">{menu}</div>
</header>
{lang_buttons()}
{body}
<footer>{foot}<span>© 2026 {APP_NAME}</span></footer>
</div>
</body>
</html>
"""


def index_page():
    blocks = []
    for _, a, _ in LANGS:
        u = UI[a]
        cta = (f'<a class="cta" href="{e(APP_STORE_URL)}">{e(u["store"])}</a>' if APP_STORE_URL
               else f'<span class="cta soon">{e(u["soon"])}</span>')
        cards = "".join(f'<div class="card"><h3>{e(t)}</h3><p>{e(d)}</p></div>' for t, d in FEATURES[a])
        blocks.append(f"""<main data-lang="{a}">
<section class="hero"><img src="assets/icon.png" alt="{APP_NAME}"><h1>{APP_NAME}</h1><p>{e(u["tagline"])}</p>{cta}</section>
<section class="grid">{cards}</section>
<p class="note">{e(u["price"])}</p>
</main>""")
    return chrome(f"{APP_NAME} — {UI['pt']['tagline']}", "\n".join(blocks))


def support_page():
    blocks = []
    for _, a, _ in LANGS:
        u = UI[a]
        faq = "".join(f"<details><summary>{e(q)}</summary><p>{e(ans)}</p></details>" for q, ans in SUPPORT[a])
        blocks.append(f"""<main data-lang="{a}">
<h1 class="page">{e(u["support"])}</h1>
<h2>{e(u["faq"])}</h2>
{faq}
<section class="card contact"><h3>{e(u["contact_t"])}</h3><p>{e(u["contact_d"])}</p>
<a class="cta" href="mailto:{EMAIL}?subject={urllib.parse.quote(APP_NAME + ' - ' + u['support'])}">{e(u["write"])}</a>
<p class="updated">{EMAIL}</p></section>
</main>""")
    return chrome(f"{APP_NAME} — Suporte / Support", "\n".join(blocks))


def legal_doc(prefix, lang, anchor):
    parts = [f'<h2 id="{anchor}">{e(xs(prefix + ".title", lang))}</h2>']
    summary = xs(prefix + ".summary", lang)
    if summary:
        parts.append(f'<p class="summary">{e(summary)}</p>')
    for i in range(1, 6):
        parts.append(f'<h3>{e(xs(f"{prefix}.sec{i}.title", lang))}</h3><p>{e(xs(f"{prefix}.sec{i}.body", lang))}</p>')
    return "\n".join(parts)


def privacy_page():
    blocks = []
    for code, a, _ in LANGS:
        # 锚点 #privacy / #terms 只放在第一个语言块里，避免重复 id；JS 切换语言时按 hash 滚到对应语言里的标题。
        pa = "privacy" if a == "pt" else f"privacy-{a}"
        ta = "terms" if a == "pt" else f"terms-{a}"
        blocks.append(f"""<main data-lang="{a}">
<h1 class="page">{e(UI[a]["legal_t"])}</h1>
<p class="updated">{e(xs("legal.lastUpdated", code))}</p>
{legal_doc("legal.privacy", code, pa)}
{legal_doc("legal.terms", code, ta)}
<h2>{e(xs("legal.contact.title", code))}</h2>
<p>{e(xs("legal.contact.desc", code))}</p>
<p><a href="mailto:{EMAIL}">{EMAIL}</a></p>
</main>""")
    fix = """<script>
document.addEventListener('DOMContentLoaded',function(){
  function go(){var h=location.hash.slice(1); if(!h) return; var l=document.documentElement.lang;
    var t=document.getElementById(l==='pt'?h:h+'-'+l)||document.getElementById(h); if(t) t.scrollIntoView();}
  setTimeout(go,0); document.querySelectorAll('.langs button').forEach(function(b){b.addEventListener('click',function(){setTimeout(go,0)})});
});
</script>"""
    return chrome(f"{APP_NAME} — Política de Privacidade / Privacy Policy", "\n".join(blocks) + fix)


def main():
    (OUT / "assets").mkdir(parents=True, exist_ok=True)
    pages = {"index.html": index_page(), "support.html": support_page(), "privacy-policy.html": privacy_page()}
    for name, page in pages.items():
        (OUT / name).write_text(page, encoding="utf-8")
    (OUT / ".nojekyll").write_text("", encoding="utf-8")
    icon = OUT / "assets" / "icon.png"
    try:
        subprocess.run(["sips", "-Z", "256", str(ICON), "--out", str(icon)], check=True, capture_output=True)
    except Exception:
        pass
    if not icon.exists():
        # 没有 sips（非 macOS）时直接用原图。
        icon.write_bytes(ICON.read_bytes())
    for name, page in pages.items():
        print(f"✅ docs/{name}（{len(page) // 1024} KB）")
    print(f"✅ docs/assets/icon.png（{icon.stat().st_size // 1024} KB）")


if __name__ == "__main__":
    main()
