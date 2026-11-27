#!/usr/bin/env python3
"""校验 LeitorQR 的本地化资源（pt-PT + zh-Hans），只读、不写文件。

用法：
    python3 scripts/gen_localization.py

为什么不再生成：xcstrings 由 Xcode 维护，里面还有 comment / extractionState /
自动提取的格式串与 CFBundleDisplayName 等条目。早期版本用内置字典整文件覆盖，
字典落后于 L10n.swift 后不仅必然报错，还会丢掉 Xcode 维护的元数据。
本脚本现在以 xcstrings 为真值，只做三件事：
- 反向扫描 L10n.swift，确认每个用到的 key 都在 Localizable.xcstrings 里；
- 确认这些 key 的 pt-PT / zh-Hans 都有非空译文；
- 确认 InfoPlist.xcstrings 里权限文案两语言齐全。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
XCSTRINGS = ROOT / "LeitorQR" / "Resources" / "Localizable.xcstrings"
INFO_XCSTRINGS = ROOT / "LeitorQR" / "Resources" / "InfoPlist.xcstrings"
SHORTCUTS_XCSTRINGS = ROOT / "LeitorQR" / "Resources" / "AppShortcuts.xcstrings"
L10N_SWIFT = ROOT / "LeitorQR" / "Core" / "Utilities" / "L10n.swift"

SOURCE_LANGUAGE = "pt-BR"
# 与 LanguageManager.AppLanguage 一一对应：App 内可切换的全部语言，每个都必须有译文。
LANGUAGES = (
    "pt-BR", "en", "en-GB", "es", "es-419", "fr", "fr-CA", "de", "it", "pt-PT",
    "nl", "pl", "sv", "da", "nb", "fi", "ru", "uk", "tr", "ar", "he", "hi",
    "id", "ms", "vi", "th", "ko", "ja", "zh-Hans", "zh-Hant",
)

# key -> 欧洲葡萄牙语文案
PT_STRINGS: dict[str, str] = {
    # 通用
    "app.name": "Leitor QR",
    "tab.scan": "Ler",
    "tab.create": "Criar",
    "tab.history": "Histórico",
    "tab.settings": "Definições",
    "common.cancel": "Cancelar",
    "common.delete": "Eliminar",
    "common.done": "Concluído",
    "common.close": "Fechar",
    "common.retry": "Tentar novamente",
    "common.error": "Erro",
    "common.ok": "OK",
    # 扫描
    "scanner.hint": "Aponte a câmara para um código QR ou de barras.",
    "scanner.detected": "Código lido",
    "scanner.flashlight": "Lanterna",
    "scanner.import": "Importar das Fotografias",
    "scanner.processing": "A ler…",
    "scanner.connecting": "A iniciar a câmara…",
    "scanner.permission.title": "Acesso à câmara necessário",
    "scanner.permission.message": "Permita o acesso à câmara para ler códigos QR.",
    "scanner.permission.openSettings": "Abrir Definições",
    "scanner.unavailable.title": "Câmara indisponível",
    "scanner.unavailable.message": "Não foi possível iniciar a câmara neste dispositivo. Pode importar uma fotografia.",
    "scanner.import.empty": "Não foi encontrado nenhum código nesta imagem.",
    "scanner.import.multiple": "Foram encontrados vários códigos. Escolha um.",
    "scanner.import.sheetTitle": "Códigos encontrados",
    "scanner.session.error": "Ocorreu um problema com a câmara. Tente novamente.",
    # 结果
    "result.title": "Resultado",
    "browser.openInSafari": "Abrir no Safari",
    "browser.back": "Voltar",
    "browser.forward": "Avançar",
    "browser.reload": "Recarregar",
    "browser.error.title": "Não foi possível abrir a página",
    "browser.error.message": "Verifique a ligação à Internet e tente novamente.",
    "result.open": "Abrir",
    "result.copy": "Copiar",
    "result.share": "Partilhar",
    "result.save": "Guardar",
    "result.rescan": "Ler novamente",
    "result.copied": "Copiado",
    "result.savedToHistory": "Guardado no histórico",
    "result.saveFailed": "Não foi possível guardar.",
    "result.typeLabel": "Tipo",
    "result.formatLabel": "Formato",
    "result.sourceLabel": "Origem",
    "result.contentLabel": "Conteúdo",
    "result.possibleUnsafeLink": "Confirme o endereço antes de abrir. Esta aplicação não verifica se o site é seguro.",
    "result.multipleTitle": "Resultados encontrados",
    "result.type.url": "Ligação",
    "result.type.text": "Texto",
    "result.type.wifi": "Wi-Fi",
    "result.type.email": "Email",
    "result.type.phone": "Telefone",
    "result.type.sms": "SMS",
    "result.type.contact": "Contacto",
    "result.type.location": "Localização",
    "result.type.barcode": "Código de barras",
    # 来源
    "source.camera": "Câmara",
    "source.photos": "Fotografia",
    "source.generator": "Criado na app",
    # 创建
    "create.title": "Criar",
    "create.type.website": "Website",
    "create.type.text": "Texto",
    "create.placeholder.website": "https://exemplo.pt",
    "create.placeholder.text": "Escreva o texto a codificar",
    "create.label.website": "Endereço",
    "create.label.text": "Conteúdo",
    "create.preview.title": "Pré-visualização",
    "create.preview.empty": "O código QR aparece aqui.",
    "create.error.empty": "Introduza um conteúdo para gerar o código.",
    "create.error.invalidURL": "Introduza um endereço válido, por exemplo https://exemplo.pt.",
    "create.error.tooLong": "O conteúdo é demasiado longo para um código QR.",
    "create.error.failed": "Não foi possível gerar o código QR.",
    "create.saved": "Código QR guardado nas Fotografias.",
    "create.saveFailed": "Não foi possível guardar a imagem. Verifique o acesso às Fotografias.",
    "create.subtitle": "Crie o seu código QR.",
    "create.add": "Criar código",
    "create.custom.title": "Código personalizado",
    "create.section.social": "Redes sociais",
    "create.section.qr": "Código QR",
    "create.section.barcode": "Código de barras",
    "create.type.instagram": "Instagram",
    "create.type.tiktok": "TikTok",
    "create.type.youtube": "YouTube",
    "create.type.facebook": "Facebook",
    "create.type.whatsapp": "WhatsApp",
    "create.type.telegram": "Telegram",
    "create.type.linkedin": "LinkedIn",
    "create.type.x": "X",
    "create.type.wifi": "Wi-Fi",
    "create.type.contact": "Contacto",
    "create.type.wechat": "WeChat",
    "create.type.xiaohongshu": "Xiaohongshu",
    "create.type.email": "Email",
    "create.type.sms": "SMS",
    "create.type.phone": "Telefone",
    "create.type.location": "Localização",
    "create.placeholder.handle": "o.seu.nome",
    "create.label.phone": "Número de telefone",
    "create.placeholder.phone": "+351 912 345 678",
    "create.label.email": "Email",
    "create.placeholder.email": "nome@exemplo.pt",
    "create.label.name": "Nome",
    "create.placeholder.name": "Ana Silva",
    "create.label.organisation": "Organização",
    "create.placeholder.organisation": "Empresa ou associação",
    "create.label.ssid": "Nome da rede (SSID)",
    "create.placeholder.ssid": "A minha rede",
    "create.label.security": "Segurança",
    "create.label.password": "Palavra-passe",
    "create.placeholder.password": "Palavra-passe do Wi-Fi",
    "create.label.hiddenNetwork": "Rede oculta",
    "create.wifi.security.wpa": "WPA/WPA2",
    "create.wifi.security.wep": "WEP",
    "create.wifi.security.none": "Aberta",
    "create.error.invalidHandle": "Nome de utilizador inválido.",
    "create.error.invalidPhone": "Número demasiado curto.",
    "create.error.invalidEmail": "Introduza um email válido, por exemplo nome@exemplo.pt.",
    "create.error.invalidCoordinates": "As coordenadas não são válidas. A latitude vai de -90 a 90 e a longitude de -180 a 180.",
    "create.error.needsDigits": "Este formato precisa de %@ dígitos.",
    "create.error.checksum": "O dígito de controlo não confere. Confirme o número.",
    "create.error.unsupportedChars": "Este formato não aceita todos estes caracteres. Use: %@.",
    "create.placeholder.wechat": "o_seu_id",
    "create.label.message": "Mensagem",
    "create.placeholder.message": "Escreva a mensagem (opcional)",
    "create.label.latitude": "Latitude",
    "create.placeholder.latitude": "38,7222",
    "create.label.longitude": "Longitude",
    "create.placeholder.longitude": "-9,1397",
    "create.location.hint": "Toque sem soltar num ponto do Google Maps ou do Apple Maps para copiar as coordenadas.",
    "create.format.title": "Formato",
    "create.format.footer": "Códigos de barras (1D) só aceitam números ou letras latinas. Para links e texto use QR.",
    "create.style": "Estilo",
    "create.style.title": "Estilo do código",
    "create.style.foreground": "Cor dos pontos",
    "create.style.bars": "Cor das barras",
    "create.style.background": "Cor do fundo",
    "create.style.shape": "Forma dos pontos",
    "create.style.logo": "Ícone ao centro",
    "create.style.logoHint": "O ícone tapa parte do código. A correção de erros está no nível máximo para o leitor continuar a funcionar.",
    "create.style.lowContrast": "Estas duas cores têm pouco contraste. O código pode não ser lido.",
    "create.shape.square": "Quadrado",
    "create.shape.rounded": "Arredondado",
    "create.shape.circle": "Círculo",
    "create.logo.none": "Sem ícone",
    "create.logo.brand": "Ícone da marca",
    "create.logo.custom": "A minha imagem",
    "create.logo.pick": "Escolher imagem",
    "create.logo.replace": "Trocar imagem",
    "create.logo.remove": "Remover",
    "create.logo.unavailable": "Não foi possível abrir essa imagem.",
    "create.note.label": "Nota",
    "create.note.placeholder": "Ex.: Wi-Fi do escritório",
    # 历史
    "history.title": "Histórico",
    "history.empty.title": "Sem resultados",
    "history.empty.message": "Os códigos que ler aparecem aqui.",
    "history.freeLimit.notice": "Na versão gratuita guardamos os últimos 10 códigos.",
    "history.clear": "Limpar histórico",
    "history.clear.title": "Limpar todo o histórico?",
    "history.clear.message": "Esta ação não pode ser anulada.",
    "history.section.recent": "Registos recentes",
    "history.claimPremium": "Desbloquear histórico ilimitado",
    "history.detail.title": "Detalhe",
    "history.detail.code": "Código",
    "history.detail.noCode": "Este formato não pode ser redesenhado na app. O conteúdo continua disponível abaixo.",
    "history.note.label": "Nota",
    "history.note.placeholder": "Adicionar uma nota",
    "history.note.hint": "Guardada apenas neste dispositivo.",
    # 设置
    "settings.title": "Definições",
    "settings.premium": "Premium",
    "settings.premium.active": "Premium ativo",
    "settings.premium.inactive": "Versão gratuita",
    "settings.subscription": "Subscrição",
    "settings.restore": "Restaurar compras",
    "settings.restored": "Compras restauradas.",
    "settings.restore.failed": "Não foi possível restaurar as compras.",
    "settings.section.subscription": "Subscrição",
    "settings.section.legal": "Informação legal",
    "settings.section.about": "Sobre",
    # 扫描反馈
    "settings.section.scan": "Leitura",
    "settings.scanSound": "Som ao ler um código",
    "settings.scanSound.footer": "Um sinal sonoro curto quando um código é lido.",
    "settings.section.appearance": "Aparência",
    "settings.appearance.system": "Sistema",
    "settings.appearance.light": "Claro",
    "settings.appearance.dark": "Escuro",
    "settings.privacy": "Política de Privacidade",
    "settings.terms": "Termos de Utilização",
    "settings.support": "Contactar suporte",
    "settings.version": "Versão",
    # 订阅中心
    "subscription.title": "Subscrição",
    "subscription.status.title": "Estado",
    "subscription.status.label": "Estado atual",
    "subscription.status.trial": "Período experimental ativo",
    "subscription.status.active": "Subscrição ativa",
    "subscription.status.cancelled": "Renovação cancelada",
    "subscription.status.expired": "Subscrição expirada",
    "subscription.status.billing": "Problema de faturação",
    "subscription.status.none": "Sem subscrição ativa",
    "subscription.status.unknown": "A verificar…",
    "subscription.plan.title": "Plano atual",
    "subscription.plan.free": "Versão gratuita",
    "subscription.price": "Preço",
    "subscription.period": "Período",
    "subscription.trialEnd": "Fim do período experimental",
    "subscription.renewalDate": "Próxima renovação",
    "subscription.expiryDate": "Fim do período atual",
    "subscription.autoRenew": "Renovação automática",
    "subscription.autoRenew.on": "Ativa",
    "subscription.autoRenew.off": "Desativada",
    "subscription.manage": "Gerir ou cancelar subscrição",
    "subscription.manage.fallback": "Abrir a página de subscrições da Apple",
    "subscription.info.title": "Cancelar ou pedir reembolso",
    "subscription.info.cancel": "Pode cancelar a renovação automática através da Apple. Depois de cancelar, continuará a ter acesso às funcionalidades Premium até ao final do período já pago.",
    "subscription.info.refund": "Para pedir um reembolso, contacte a Apple através dos canais oficiais de suporte. Cancelar a renovação não equivale a um pedido de reembolso.",
    "subscription.unavailable": "A informação da subscrição não está disponível neste momento.",
    "subscription.upgrade": "Conhecer o Premium",
    "subscription.refresh": "Atualizar estado",
    # Paywall
    "paywall.title": "Desbloqueie o Leitor QR Premium",
    "paywall.subtitle": "Mais opções para criar e guardar os seus códigos.",
    "paywall.benefit.history": "Histórico ilimitado",
    "paywall.benefit.more": "Mais opções de criação",
    "paywall.benefit.custom": "Cores personalizadas",
    "paywall.benefit.templates": "Modelos avançados",
    "paywall.cta.trial": "Começar período experimental",
    "paywall.cta.subscribe": "Subscrever",
    "paywall.priceNote.trial": "3 dias grátis. Depois, %@ por ano, com renovação automática. Cancele antes da renovação para evitar a próxima cobrança.",
    "paywall.priceNote.plain": "%@ por ano, com renovação automática. Cancele antes da renovação para evitar a próxima cobrança.",
    "paywall.restoring": "A restaurar compras…",
    "paywall.purchase.failed": "Não foi possível concluir a compra.",
    "paywall.purchase.pending": "A compra está pendente de aprovação.",
    "paywall.purchase.success": "Premium ativado.",
    "paywall.legalNote": "A subscrição é renovada automaticamente até ser cancelada. A gestão é feita na sua conta Apple.",
    # 周期
    "period.day.singular": "1 dia",
    "period.day.plural": "%d dias",
    "period.month.singular": "1 mês",
    "period.month.plural": "%d meses",
    "period.year.singular": "1 ano",
    "period.year.plural": "%d anos",
    # 错误
    "error.invalidImage": "Não foi possível ler esta imagem.",
    "error.noCodeFound": "Não foi encontrado nenhum código nesta imagem.",
    "error.scanFailed": "Ocorreu um erro ao ler o código.",
    # 二维码模板
    "templates.title": "Modelos",
    "templates.apply": "Aplicar",
    "templates.all": "Todos",
    "templates.classic": "Clássicos",
    "templates.social": "Social",
    "templates.holiday": "Festas",
    "templates.love": "Amor",
    "templates.birthday": "Aniversário",
    "templates.none": "Sem modelo",
    "templates.manual": "Ajuste manual",
    "templates.adjustHint": "Pode ajustar as cores e a forma dos pontos sem perder a decoração do modelo.",
    "templates.name.classicInk": "Tinta",
    "templates.name.classicBlue": "Azul",
    "templates.name.socialGreen": "Verde",
    "templates.name.socialNight": "Noite",
    "templates.name.socialSunset": "Pôr do sol",
    "templates.name.holidayPumpkin": "Abóbora",
    "templates.name.holidayGhost": "Fantasma",
    "templates.name.holidaySnow": "Neve",
    "templates.name.loveHeart": "Coração",
    "templates.name.loveRose": "Rosa",
    "templates.name.birthdayBalloons": "Balões",
    "templates.name.birthdayGift": "Presente",
}

# key -> 简体中文文案（与 PT_STRINGS 一一对应）
ZH_STRINGS: dict[str, str] = {
    # 通用
    "app.name": "Leitor QR",
    "tab.scan": "扫描",
    "tab.create": "创建",
    "tab.history": "历史",
    "tab.settings": "设置",
    "common.cancel": "取消",
    "common.delete": "删除",
    "common.done": "完成",
    "common.close": "关闭",
    "common.retry": "重试",
    "common.error": "错误",
    "common.ok": "好",
    # 扫描
    "scanner.hint": "将摄像头对准二维码或条形码。",
    "scanner.detected": "识别成功",
    "scanner.flashlight": "手电筒",
    "scanner.import": "从相册导入",
    "scanner.processing": "正在识别…",
    "scanner.connecting": "正在启动摄像头…",
    "scanner.permission.title": "需要摄像头权限",
    "scanner.permission.message": "请允许访问摄像头以扫描二维码。",
    "scanner.permission.openSettings": "打开设置",
    "scanner.unavailable.title": "摄像头不可用",
    "scanner.unavailable.message": "无法在此设备上启动摄像头。你仍可从相册导入图片。",
    "scanner.import.empty": "这张图片里没有找到任何码。",
    "scanner.import.multiple": "找到多个码，请选择一个。",
    "scanner.import.sheetTitle": "找到的码",
    "scanner.session.error": "摄像头出现问题，请重试。",
    # 结果
    "result.title": "扫描结果",
    "browser.openInSafari": "在 Safari 中打开",
    "browser.back": "后退",
    "browser.forward": "前进",
    "browser.reload": "刷新",
    "browser.error.title": "无法打开页面",
    "browser.error.message": "请检查网络连接后重试。",
    "result.open": "打开",
    "result.copy": "复制",
    "result.share": "分享",
    "result.save": "存储",
    "result.rescan": "重新扫描",
    "result.copied": "已复制",
    "result.savedToHistory": "已保存到历史",
    "result.saveFailed": "保存失败。",
    "result.typeLabel": "类型",
    "result.formatLabel": "格式",
    "result.sourceLabel": "来源",
    "result.contentLabel": "内容",
    "result.possibleUnsafeLink": "打开前请确认网址。本应用不会检测网站是否安全。",
    "result.multipleTitle": "找到的结果",
    "result.type.url": "链接",
    "result.type.text": "文本",
    "result.type.wifi": "Wi-Fi",
    "result.type.email": "邮件",
    "result.type.phone": "电话",
    "result.type.sms": "短信",
    "result.type.contact": "联系人",
    "result.type.location": "定位",
    "result.type.barcode": "条形码",
    # 来源
    "source.camera": "摄像头",
    "source.photos": "照片",
    "source.generator": "应用内创建",
    # 创建
    "create.title": "创建",
    "create.type.website": "网址",
    "create.type.text": "文本",
    "create.placeholder.website": "https://example.com",
    "create.placeholder.text": "输入要编码的文本",
    "create.label.website": "地址",
    "create.label.text": "内容",
    "create.preview.title": "预览",
    "create.preview.empty": "二维码将显示在这里。",
    "create.error.empty": "请输入要生成的内容。",
    "create.error.invalidURL": "请输入有效的网址，例如 https://example.com。",
    "create.error.tooLong": "内容过长，无法生成二维码。",
    "create.error.failed": "无法生成二维码。",
    "create.saved": "二维码已保存到相册。",
    "create.saveFailed": "无法保存图片，请检查相册访问权限。",
    "create.subtitle": "创建你的二维码。",
    "create.add": "新建码",
    "create.custom.title": "自定义二维码",
    "create.section.social": "社交平台",
    "create.section.qr": "二维码",
    "create.section.barcode": "条形码",
    "create.type.instagram": "Instagram",
    "create.type.tiktok": "TikTok",
    "create.type.youtube": "YouTube",
    "create.type.facebook": "Facebook",
    "create.type.whatsapp": "WhatsApp",
    "create.type.telegram": "Telegram",
    "create.type.linkedin": "LinkedIn",
    "create.type.x": "X",
    "create.type.wifi": "Wi-Fi",
    "create.type.contact": "联系人",
    "create.type.wechat": "微信",
    "create.type.xiaohongshu": "小红书",
    "create.type.email": "邮箱",
    "create.type.sms": "短信",
    "create.type.phone": "电话",
    "create.type.location": "定位",
    "create.placeholder.handle": "yourname",
    "create.label.phone": "手机号",
    "create.placeholder.phone": "+86 138 0000 0000",
    "create.label.email": "邮箱",
    "create.placeholder.email": "name@example.com",
    "create.label.name": "姓名",
    "create.placeholder.name": "张三",
    "create.label.organisation": "组织",
    "create.placeholder.organisation": "公司或组织名称",
    "create.label.ssid": "网络名称（SSID）",
    "create.placeholder.ssid": "我的 Wi-Fi",
    "create.label.security": "加密方式",
    "create.label.password": "密码",
    "create.placeholder.password": "Wi-Fi 密码",
    "create.label.hiddenNetwork": "隐藏网络",
    "create.wifi.security.wpa": "WPA/WPA2",
    "create.wifi.security.wep": "WEP",
    "create.wifi.security.none": "无密码",
    "create.error.invalidHandle": "用户名格式不正确。",
    "create.error.invalidPhone": "号码太短了。",
    "create.error.invalidEmail": "请输入有效的邮箱，例如 name@example.com。",
    "create.error.invalidCoordinates": "经纬度不合法：纬度范围 -90 到 90，经度范围 -180 到 180。",
    "create.error.needsDigits": "这个码制需要 %@ 位数字。",
    "create.error.checksum": "校验位不对，请核对号码。",
    "create.error.unsupportedChars": "这个码制不支持部分字符。可用：%@。",
    "create.placeholder.wechat": "your_wechat_id",
    "create.label.message": "短信内容",
    "create.placeholder.message": "输入要发送的内容（可选）",
    "create.label.latitude": "纬度",
    "create.placeholder.latitude": "39,9044",
    "create.label.longitude": "经度",
    "create.placeholder.longitude": "116,4074",
    "create.location.hint": "在地图 App 里长按某个地点即可复制经纬度。",
    "create.format.title": "码制",
    "create.format.footer": "条形码（一维码）只接受数字或拉丁字母。链接和文字请用二维码。",
    "create.style": "样式",
    "create.style.title": "码样式",
    "create.style.foreground": "码点颜色",
    "create.style.bars": "条码颜色",
    "create.style.background": "背景颜色",
    "create.style.shape": "点形状",
    "create.style.logo": "中心图标",
    "create.style.logoHint": "图标会遮住部分码点，已自动使用最高纠错级别，不影响识别。",
    "create.style.lowContrast": "这两种颜色对比度太低，可能扫不出来。",
    "create.shape.square": "方形",
    "create.shape.rounded": "圆角",
    "create.shape.circle": "圆点",
    "create.logo.none": "不放图标",
    "create.logo.brand": "品牌图标",
    "create.logo.custom": "我的图片",
    "create.logo.pick": "选择图片",
    "create.logo.replace": "更换图片",
    "create.logo.remove": "移除",
    "create.logo.unavailable": "无法读取这张图片。",
    "create.note.label": "备注",
    "create.note.placeholder": "例如：办公室 WiFi",
    # 历史
    "history.title": "历史",
    "history.empty.title": "暂无记录",
    "history.empty.message": "你扫描过的码会显示在这里。",
    "history.freeLimit.notice": "免费版仅保留最近 10 条记录。",
    "history.clear": "清空历史",
    "history.clear.title": "清空全部历史？",
    "history.clear.message": "此操作无法撤销。",
    "history.section.recent": "最近记录",
    "history.claimPremium": "解锁无限历史",
    "history.detail.title": "详情",
    "history.detail.code": "码图",
    "history.detail.noCode": "这种码制无法在 App 内重绘，内容仍可在下方查看。",
    "history.note.label": "备注",
    "history.note.placeholder": "添加备注",
    "history.note.hint": "仅保存在本机。",
    # 设置
    "settings.title": "设置",
    "settings.premium": "Premium",
    "settings.premium.active": "Premium 已生效",
    "settings.premium.inactive": "免费版",
    "settings.subscription": "订阅",
    "settings.restore": "恢复购买",
    "settings.restored": "已恢复购买。",
    "settings.restore.failed": "无法恢复购买。",
    "settings.section.subscription": "订阅",
    "settings.section.legal": "法律信息",
    "settings.section.about": "关于",
    # 扫描反馈
    "settings.section.scan": "扫描",
    "settings.scanSound": "识别提示音",
    "settings.scanSound.footer": "识别成功时播放一声短提示音。",
    "settings.section.appearance": "外观",
    "settings.appearance.system": "跟随系统",
    "settings.appearance.light": "浅色",
    "settings.appearance.dark": "深色",
    "settings.privacy": "隐私政策",
    "settings.terms": "使用条款",
    "settings.support": "联系支持",
    "settings.version": "版本",
    # 订阅中心
    "subscription.title": "订阅",
    "subscription.status.title": "状态",
    "subscription.status.label": "当前状态",
    "subscription.status.trial": "试用期进行中",
    "subscription.status.active": "订阅有效",
    "subscription.status.cancelled": "已取消自动续订",
    "subscription.status.expired": "订阅已过期",
    "subscription.status.billing": "账单问题",
    "subscription.status.none": "当前无有效订阅",
    "subscription.status.unknown": "正在检查…",
    "subscription.plan.title": "当前方案",
    "subscription.plan.free": "免费版",
    "subscription.price": "价格",
    "subscription.period": "周期",
    "subscription.trialEnd": "试用结束日期",
    "subscription.renewalDate": "下次续费日期",
    "subscription.expiryDate": "当前周期结束",
    "subscription.autoRenew": "自动续订",
    "subscription.autoRenew.on": "已开启",
    "subscription.autoRenew.off": "已关闭",
    "subscription.manage": "管理或取消订阅",
    "subscription.manage.fallback": "打开 Apple 订阅管理页面",
    "subscription.info.title": "取消与退款",
    "subscription.info.cancel": "你可以通过 Apple 取消自动续订。取消后，仍可使用 Premium 功能，直到当前付费周期结束。",
    "subscription.info.refund": "如需退款，请通过 Apple 官方支持渠道申请。取消续订不等同于退款申请。",
    "subscription.unavailable": "暂时无法获取订阅信息。",
    "subscription.upgrade": "了解 Premium",
    "subscription.refresh": "刷新状态",
    # Paywall
    "paywall.title": "解锁 Leitor QR Premium",
    "paywall.subtitle": "创建和保存二维码的更多选择。",
    "paywall.benefit.history": "无限历史记录",
    "paywall.benefit.more": "更多创建类型",
    "paywall.benefit.custom": "自定义颜色",
    "paywall.benefit.templates": "高级模板",
    "paywall.cta.trial": "开始 3 天免费试用",
    "paywall.cta.subscribe": "订阅",
    "paywall.priceNote.trial": "免费试用 3 天。之后每年 %@，自动续订。请在续订前取消，以免产生下一次扣费。",
    "paywall.priceNote.plain": "每年 %@，自动续订。请在续订前取消，以免产生下一次扣费。",
    "paywall.restoring": "正在恢复购买…",
    "paywall.purchase.failed": "无法完成购买。",
    "paywall.purchase.pending": "购买待批准。",
    "paywall.purchase.success": "Premium 已开通。",
    "paywall.legalNote": "订阅将自动续订，直至取消。订阅管理在你的 Apple 账户中进行。",
    # 周期
    "period.day.singular": "1 天",
    "period.day.plural": "%d 天",
    "period.month.singular": "1 个月",
    "period.month.plural": "%d 个月",
    "period.year.singular": "1 年",
    "period.year.plural": "%d 年",
    # 错误
    "error.invalidImage": "无法读取这张图片。",
    "error.noCodeFound": "这张图片里没有找到任何码。",
    "error.scanFailed": "识别时出错。",
    # 二维码模板
    "templates.title": "模板",
    "templates.apply": "应用",
    "templates.all": "全部",
    "templates.classic": "经典",
    "templates.social": "社交",
    "templates.holiday": "节日",
    "templates.love": "恋爱",
    "templates.birthday": "生日",
    "templates.none": "无模板",
    "templates.manual": "手动微调",
    "templates.adjustHint": "可以微调颜色和点形状，模板装饰会保留。",
    "templates.name.classicInk": "墨黑",
    "templates.name.classicBlue": "海蓝",
    "templates.name.socialGreen": "青绿",
    "templates.name.socialNight": "夜色",
    "templates.name.socialSunset": "暖橙",
    "templates.name.holidayPumpkin": "南瓜",
    "templates.name.holidayGhost": "幽灵",
    "templates.name.holidaySnow": "雪夜",
    "templates.name.loveHeart": "心动",
    "templates.name.loveRose": "玫瑰",
    "templates.name.birthdayBalloons": "气球",
    "templates.name.birthdayGift": "礼物",
}

STRINGS_BY_LANGUAGE: dict[str, dict[str, str]] = {
    "pt-PT": PT_STRINGS,
    "zh-Hans": ZH_STRINGS,
}

# 系统权限弹窗（Info.plist 的 key），不参与 L10n.swift 的覆盖检查
INFO_PLIST_STRINGS: dict[str, dict[str, str]] = {
    "NSCameraUsageDescription": {
        "pt-PT": "Permita o acesso à câmara para ler códigos QR.",
        "zh-Hans": "请允许访问摄像头以扫描二维码。",
    },
    "NSPhotoLibraryAddUsageDescription": {
        "pt-PT": "Guarde os códigos QR que criar na sua fototeca.",
        "zh-Hans": "将你创建的二维码保存到相册。",
    },
}


def build_catalog(entries: dict[str, dict[str, str]]) -> dict:
    return {
        "sourceLanguage": SOURCE_LANGUAGE,
        "strings": {
            key: {
                "localizations": {
                    language: {
                        "stringUnit": {"state": "translated", "value": value}
                    }
                    for language, value in per_language.items()
                }
            }
            for key, per_language in entries.items()
        },
        "version": "1.0",
    }


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    """只读校验；任何缺失都以非零退出码报出。"""
    for path in (XCSTRINGS, INFO_XCSTRINGS, SHORTCUTS_XCSTRINGS, L10N_SWIFT):
        if not path.exists():
            print(f"找不到 {path}", file=sys.stderr)
            return 1

    source = L10N_SWIFT.read_text(encoding="utf-8")
    # L10n.swift 的条目统一走 LanguageManager.localized("key", comment: "...")
    used_keys = set(re.findall(r'LanguageManager\.localized\("([^"]+)"', source))
    catalog = json.loads(XCSTRINGS.read_text(encoding="utf-8"))
    strings = catalog.get("strings", {})

    missing = sorted(used_keys - set(strings))
    if missing:
        print(f"{len(missing)} 个 key 在 L10n.swift 中使用但不在 xcstrings：", file=sys.stderr)
        for key in missing[:20]:
            print(f"  - {key}", file=sys.stderr)
        return 1

    def translated(entry: dict, language: str) -> bool:
        value = (entry.get("localizations", {})
                 .get(language, {})
                 .get("stringUnit", {})
                 .get("value"))
        return bool(value)

    incomplete = [
        f"{key} [{language}]"
        for key in sorted(used_keys)
        for language in LANGUAGES
        if not translated(strings[key], language)
    ]
    if incomplete:
        print(f"{len(incomplete)} 处缺少译文：", file=sys.stderr)
        for item in incomplete[:20]:
            print(f"  - {item}", file=sys.stderr)
        return 1

    info = json.loads(INFO_XCSTRINGS.read_text(encoding="utf-8"))
    info_strings = info.get("strings", {})
    # CFBundleName / CFBundleDisplayName 由 Xcode 提取，允许只有 source language。
    info_incomplete = [
        f"{key} [{language}]"
        for key, entry in sorted(info_strings.items())
        if key.startswith("NS")
        for language in LANGUAGES
        if not translated(entry, language)
    ]
    if info_incomplete:
        print(f"权限文案缺少译文：{', '.join(info_incomplete)}", file=sys.stderr)
        return 1

    sc = json.loads(SHORTCUTS_XCSTRINGS.read_text(encoding="utf-8"))
    sc_incomplete = [
        f"{key} [{language}]"
        for key, entry in sorted(sc.get("strings", {}).items())
        for language in LANGUAGES
        if not translated(entry, language)
    ]
    if sc_incomplete:
        print(f"App Shortcuts 缺少译文：{', '.join(sc_incomplete)}", file=sys.stderr)
        return 1

    print(f"校验通过：{len(used_keys)} 个 L10n key × {len(LANGUAGES)} 语言齐全；"
          f"InfoPlist 权限文案与 App Shortcuts 齐全。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
