import Foundation

/// 全部用户可见文案的唯一入口，取值来自 `Localizable.xcstrings`（pt-BR / zh-Hans / en / ja）。
/// 页面里禁止出现裸字符串文案——新增文案必须同时补四种语言的翻译。
/// 所有条目都是计算属性，经 `LanguageManager.localized` 动态取当前语言的 Bundle，
/// 用户在设置页切换语言后全文立即生效，无需重启。
enum L10n {

    enum App {
        static var name: String { LanguageManager.localized("app.name", comment: "Nome da aplicação") }
    }

    enum Tab {
        static var scan: String { LanguageManager.localized("tab.scan", comment: "Separador de leitura") }
        static var create: String { LanguageManager.localized("tab.create", comment: "Separador de criação") }
        static var history: String { LanguageManager.localized("tab.history", comment: "Separador de histórico") }
        static var settings: String { LanguageManager.localized("tab.settings", comment: "Separador de definições") }
    }

    enum Common {
        static var cancel: String { LanguageManager.localized("common.cancel", comment: "Cancelar") }
        static var delete: String { LanguageManager.localized("common.delete", comment: "Eliminar") }
        static var done: String { LanguageManager.localized("common.done", comment: "Concluído") }
        static var close: String { LanguageManager.localized("common.close", comment: "Fechar") }
        static var retry: String { LanguageManager.localized("common.retry", comment: "Tentar novamente") }
        static var error: String { LanguageManager.localized("common.error", comment: "Erro") }
        static var ok: String { LanguageManager.localized("common.ok", comment: "OK") }
        static var add: String { LanguageManager.localized("common.add", comment: "Adicionar") }
        static var undo: String { LanguageManager.localized("common.undo", comment: "Desfazer") }
    }

    enum Browser {
        static var openInSafari: String { LanguageManager.localized("browser.openInSafari", comment: "Abrir no Safari") }
        static var back: String { LanguageManager.localized("browser.back", comment: "Voltar") }
        static var forward: String { LanguageManager.localized("browser.forward", comment: "Avançar") }
        static var reload: String { LanguageManager.localized("browser.reload", comment: "Recarregar") }
        static var errorTitle: String { LanguageManager.localized("browser.error.title", comment: "Título de erro do navegador") }
        static var errorMessage: String { LanguageManager.localized("browser.error.message", comment: "Mensagem de erro do navegador") }
    }

    enum Scanner {
        static var hint: String { LanguageManager.localized("scanner.hint", comment: "Instrução de leitura") }
        static var hintDetail: String { LanguageManager.localized("scanner.hint.detail", comment: "Leitura automática, sem tocar") }
        static var hintWiFi: String { LanguageManager.localized("scanner.hint.wifi", comment: "Dica no modo «Ler Wi-Fi» do atalho") }
        static func wifiJoined(_ ssid: String) -> String {
            String(format: LanguageManager.localized("scanner.wifi.joined", comment: "Conectado a %@"), ssid)
        }
        static var detected: String { LanguageManager.localized("scanner.detected", comment: "Código lido") }
        static var flashlight: String { LanguageManager.localized("scanner.flashlight", comment: "Lanterna") }
        static var importFromPhotos: String { LanguageManager.localized("scanner.import", comment: "Importar das Fotografias") }
        static var processing: String { LanguageManager.localized("scanner.processing", comment: "A ler") }
        static var permissionTitle: String { LanguageManager.localized("scanner.permission.title", comment: "Título de permissão da câmara") }
        static var permissionMessage: String { LanguageManager.localized("scanner.permission.message", comment: "Mensagem de permissão da câmara") }
        static var permissionOpenSettings: String { LanguageManager.localized("scanner.permission.openSettings", comment: "Abrir Definições") }
        static var unavailableTitle: String { LanguageManager.localized("scanner.unavailable.title", comment: "Câmara indisponível") }
        static var unavailableMessage: String { LanguageManager.localized("scanner.unavailable.message", comment: "Mensagem de câmara indisponível") }
        static var importEmpty: String { LanguageManager.localized("scanner.import.empty", comment: "Nenhum código na imagem") }
        static var importMultiple: String { LanguageManager.localized("scanner.import.multiple", comment: "Vários códigos encontrados") }
        static var importSheetTitle: String { LanguageManager.localized("scanner.import.sheetTitle", comment: "Título da folha de resultados") }
        static var sessionError: String { LanguageManager.localized("scanner.session.error", comment: "Erro de sessão da câmara") }
        static var connecting: String { LanguageManager.localized("scanner.connecting", comment: "A iniciar a câmara") }
    }

    enum Result {
        static var title: String { LanguageManager.localized("result.title", comment: "Título do resultado") }
        static var open: String { LanguageManager.localized("result.open", comment: "Abrir") }
        static var openExternal: String { LanguageManager.localized("result.openExternal", comment: "Abrir no navegador") }
        static var copy: String { LanguageManager.localized("result.copy", comment: "Copiar") }
        static var share: String { LanguageManager.localized("result.share", comment: "Partilhar") }
        static var save: String { LanguageManager.localized("result.save", comment: "Guardar") }
        static var rescan: String { LanguageManager.localized("result.rescan", comment: "Ler novamente") }
        static var copied: String { LanguageManager.localized("result.copied", comment: "Copiado") }
        static var savedToHistory: String { LanguageManager.localized("result.savedToHistory", comment: "Guardado no histórico") }
        static var saveFailed: String { LanguageManager.localized("result.saveFailed", comment: "Falha ao guardar") }
        static var typeLabel: String { LanguageManager.localized("result.typeLabel", comment: "Tipo") }
        static var formatLabel: String { LanguageManager.localized("result.formatLabel", comment: "Formato") }
        static var sourceLabel: String { LanguageManager.localized("result.sourceLabel", comment: "Origem") }
        static var contentLabel: String { LanguageManager.localized("result.contentLabel", comment: "Conteúdo") }
        static var possibleUnsafeLink: String { LanguageManager.localized("result.possibleUnsafeLink", comment: "Aviso de ligação") }
        static var multipleTitle: String { LanguageManager.localized("result.multipleTitle", comment: "Resultados encontrados") }
        static var wifiConnect: String { LanguageManager.localized("result.wifi.connect", comment: "Ligar à rede Wi-Fi") }
        static var wifiConnecting: String { LanguageManager.localized("result.wifi.connecting", comment: "A ligar à rede Wi-Fi") }
        static var wifiJoined: String { LanguageManager.localized("result.wifi.joined", comment: "Ligação Wi-Fi estabelecida") }
        static var wifiJoinedDetail: String { LanguageManager.localized("result.wifi.joined.detail", comment: "Ligado a %@") }
        static var wifiDenied: String { LanguageManager.localized("result.wifi.denied", comment: "Ligação recusada") }
        static var wifiDeniedDetail: String { LanguageManager.localized("result.wifi.denied.detail", comment: "Permissão recusada nas definições do iPhone") }
        static var wifiFailed: String { LanguageManager.localized("result.wifi.failed", comment: "Falha na ligação Wi-Fi") }
        static var wifiRestricted: String { LanguageManager.localized("result.wifi.restricted", comment: "Não é possível ligar automaticamente") }
        static var wifiRestrictedDetail: String { LanguageManager.localized("result.wifi.restricted.detail", comment: "Ligue-se manualmente em Ajustes › Wi-Fi") }
        static var wifiInfoTitle: String { LanguageManager.localized("result.wifi.info.title", comment: "Detalhes da rede") }
        static var wifiSSID: String { LanguageManager.localized("result.wifi.ssid", comment: "Nome da rede") }
        static var wifiPassword: String { LanguageManager.localized("result.wifi.password", comment: "Palavra-passe") }
        static var wifiSecurityLabel: String { LanguageManager.localized("result.wifi.security", comment: "Segurança") }
        static var wifiHidden: String { LanguageManager.localized("result.wifi.hidden", comment: "Rede oculta") }
        static var wifiCopyPassword: String { LanguageManager.localized("result.wifi.copyPassword", comment: "Copiar palavra-passe") }
        static var wifiManualHint: String { LanguageManager.localized("result.wifi.manualHint", comment: "Se não ligar automaticamente, introduza estes dados em Ajustes › Wi-Fi") }

        // MARK: 联系人（vCard / MECARD）
        static var contactTitle: String { LanguageManager.localized("result.contact.title", comment: "Dados do contacto") }
        static var contactName: String { LanguageManager.localized("result.contact.name", comment: "Nome") }
        static var contactPhone: String { LanguageManager.localized("result.contact.phone", comment: "Telefone") }
        static var contactEmail: String { LanguageManager.localized("result.contact.email", comment: "Email") }
        static var contactOrg: String { LanguageManager.localized("result.contact.org", comment: "Empresa") }
        static var contactAdd: String { LanguageManager.localized("result.contact.add", comment: "Adicionar aos contactos") }
        static var contactAccessDenied: String { LanguageManager.localized("result.contact.accessDenied", comment: "Acesso aos contactos necessário") }
        static var contactAccessDeniedDetail: String { LanguageManager.localized("result.contact.accessDenied.detail", comment: "Autorize o acesso aos contactos em Ajustes") }

        // MARK: 邮件码（MATMSG / 带参数的 mailto）
        static var mailTitle: String { LanguageManager.localized("result.mail.title", comment: "Dados do email") }
        static var mailTo: String { LanguageManager.localized("result.mail.to", comment: "Para") }
        static var mailSubject: String { LanguageManager.localized("result.mail.subject", comment: "Assunto") }
        static var mailBody: String { LanguageManager.localized("result.mail.body", comment: "Mensagem") }

        // MARK: 日历事件（VEVENT）
        static var eventTitle: String { LanguageManager.localized("result.event.title", comment: "Detalhes do evento") }
        static var eventSummary: String { LanguageManager.localized("result.event.summary", comment: "Título") }
        static var eventStart: String { LanguageManager.localized("result.event.start", comment: "Início") }
        static var eventEnd: String { LanguageManager.localized("result.event.end", comment: "Fim") }
        static var eventLocationField: String { LanguageManager.localized("result.event.location", comment: "Local") }
        static var eventAdd: String { LanguageManager.localized("result.event.add", comment: "Adicionar ao calendário") }
        static var eventAccessDenied: String { LanguageManager.localized("result.event.accessDenied", comment: "Acesso ao calendário necessário") }
        static var eventAccessDeniedDetail: String { LanguageManager.localized("result.event.accessDenied.detail", comment: "Autorize o acesso ao calendário em Ajustes") }

        // MARK: EPC / SEPA 付款码
        static var paymentTitle: String { LanguageManager.localized("result.payment.title", comment: "Dados de pagamento") }
        static var paymentRecipient: String { LanguageManager.localized("result.payment.recipient", comment: "Beneficiário") }
        static var paymentIBAN: String { LanguageManager.localized("result.payment.iban", comment: "IBAN") }
        static var paymentAmount: String { LanguageManager.localized("result.payment.amount", comment: "Montante") }
        static var paymentReference: String { LanguageManager.localized("result.payment.reference", comment: "Referência") }
        static var paymentBIC: String { LanguageManager.localized("result.payment.bic", comment: "BIC") }
        static var paymentCopyIBAN: String { LanguageManager.localized("result.payment.copyIBAN", comment: "Copiar IBAN") }
        static var paymentNote: String { LanguageManager.localized("result.payment.note", comment: "O iOS não inicia transferências SEPA; use os dados no seu banco") }

        // MARK: 加密货币支付 URI
        static var cryptoTitle: String { LanguageManager.localized("result.crypto.title", comment: "Endereço de criptomoeda") }
        static var cryptoAddress: String { LanguageManager.localized("result.crypto.address", comment: "Endereço") }
        static var cryptoAmount: String { LanguageManager.localized("result.crypto.amount", comment: "Montante") }
        static var cryptoCopyAddress: String { LanguageManager.localized("result.crypto.copyAddress", comment: "Copiar endereço") }
        static var cryptoOpenWallet: String { LanguageManager.localized("result.crypto.openWallet", comment: "Abrir carteira") }
        static var wifiFailedDetail: String { LanguageManager.localized("result.wifi.failed.detail", comment: "Verifique se a rede está ao alcance") }
        static var wifiInvalidDetail: String { LanguageManager.localized("result.wifi.invalid.detail", comment: "Nome ou palavra-passe inválidos") }
        static var wifiUnsupported: String { LanguageManager.localized("result.wifi.unsupported", comment: "Rede não suportada") }
        static var wifiUnsupportedDetail: String { LanguageManager.localized("result.wifi.unsupported.detail", comment: "Redes empresariais EAP não são suportadas") }
        static var call: String { LanguageManager.localized("result.call", comment: "Ligar") }
        static var sendEmail: String { LanguageManager.localized("result.sendEmail", comment: "Enviar email") }
        static var sendSMS: String { LanguageManager.localized("result.sendSMS", comment: "Enviar SMS") }
        static var openInMaps: String { LanguageManager.localized("result.openInMaps", comment: "Abrir nos Mapas") }
        // MARK: 结果页 PRO 提示（非订阅用户前几次扫描时露出）
        static var proHintTitle: String { LanguageManager.localized("result.proHint.title", comment: "Histórico ilimitado e verificação de links") }
        static var proHintBody: String { LanguageManager.localized("result.proHint.body", comment: "O que o PRO inclui") }
        static var proHintCTA: String { LanguageManager.localized("result.proHint.cta", comment: "Conhecer o PRO") }

        static var actionFailed: String { LanguageManager.localized("result.action.failed", comment: "Não foi possível abrir") }
        static var actionFailedDetail: String { LanguageManager.localized("result.action.failed.detail", comment: "Verifique se tem uma app instalada para este tipo de conteúdo") }
        static var riskTitle: String { LanguageManager.localized("result.risk.title", comment: "Verificar endereço") }
        static var riskLow: String { LanguageManager.localized("result.risk.low", comment: "Sem sinais") }
        static var riskMedium: String { LanguageManager.localized("result.risk.medium", comment: "Atenção") }
        static var riskHigh: String { LanguageManager.localized("result.risk.high", comment: "Muita atenção") }
        static var riskNone: String { LanguageManager.localized("result.risk.none", comment: "Nenhum sinal digno de nota encontrado") }
        static var riskDisclaimer: String { LanguageManager.localized("result.risk.disclaimer", comment: "Aviso de verificação de link") }
        static var riskTrusted: String { LanguageManager.localized("result.risk.trusted", comment: "Confiável") }
        static var riskTrustedDetail: String { LanguageManager.localized("result.risk.trusted.detail", comment: "Este domínio está na sua lista de confiança") }
        static var riskAddWhitelist: String { LanguageManager.localized("result.risk.addWhitelist", comment: "Adicionar à lista de confiança") }
    }

    enum Risk {
        static var insecure: String { LanguageManager.localized("risk.finding.insecure", comment: "Ligação sem HTTPS") }
        static var ip: String { LanguageManager.localized("risk.finding.ip", comment: "Endereço IP em vez de domínio") }
        static var homograph: String { LanguageManager.localized("risk.finding.homograph", comment: "Domínio com caracteres não latinos") }
        static var shortlink: String { LanguageManager.localized("risk.finding.shortlink", comment: "Link curto esconde o destino") }
        static var tld: String { LanguageManager.localized("risk.finding.tld", comment: "Domínio gratuito") }
        static var keyword: String { LanguageManager.localized("risk.finding.keyword", comment: "Palavra sensível no endereço") }
        static var lookalike: String { LanguageManager.localized("risk.finding.lookalike", comment: "Domínio semelhante a marca conhecida") }
        static var hyphens: String { LanguageManager.localized("risk.finding.hyphens", comment: "Muitos hífenes no domínio") }

        /// 从持久化的规则 key 还原文案（历史页/批量页用）。
        static func finding(forKey key: String) -> String {
            LanguageManager.localized(key, comment: "")
        }
    }

    enum Security {
        static var title: String { LanguageManager.localized("security.title", comment: "Segurança") }
        static var sectionTitle: String { LanguageManager.localized("security.section.title", comment: "Secção de segurança") }
        static var sectionTools: String { LanguageManager.localized("security.section.tools", comment: "Ferramentas PRO") }
        static var settingsFooter: String { LanguageManager.localized("security.settings.footer", comment: "Verificação básica gratuita") }
        static var footer: String { LanguageManager.localized("security.footer", comment: "As ferramentas PRO exigem subscrição") }
        static var footerPaid: String { LanguageManager.localized("security.footer.paid", comment: "As ferramentas PRO estão incluídas na sua subscrição") }
        static var privacyNote: String { LanguageManager.localized("security.privacy.note", comment: "Nota de privacidade da segurança") }

        static var historyTitle: String { LanguageManager.localized("security.history.title", comment: "Histórico de verificações") }
        static var historySubtitle: String { LanguageManager.localized("security.history.subtitle", comment: "Consulte as verificações anteriores") }
        static var historyCount: String { LanguageManager.localized("security.history.count", comment: "%d verificações") }
        static var historyEmptyTitle: String { LanguageManager.localized("security.history.empty.title", comment: "Sem verificações") }
        static var historyEmptyDesc: String { LanguageManager.localized("security.history.empty.desc", comment: "Os links verificados aparecem aqui") }
        static var clear: String { LanguageManager.localized("security.clear", comment: "Limpar histórico") }
        static var clearConfirmTitle: String { LanguageManager.localized("security.clear.confirm.title", comment: "Limpar histórico?") }
        static var clearConfirmMessage: String { LanguageManager.localized("security.clear.confirm.message", comment: "Todas as verificações serão removidas deste dispositivo") }

        static var whitelistTitle: String { LanguageManager.localized("security.whitelist.title", comment: "Domínios de confiança") }
        static var whitelistSubtitle: String { LanguageManager.localized("security.whitelist.subtitle", comment: "Domínios que não apresentam avisos") }
        static var whitelistSection: String { LanguageManager.localized("security.whitelist.section", comment: "Domínios confiáveis") }
        static var whitelistFooter: String { LanguageManager.localized("security.whitelist.footer", comment: "Subdomínios também são confiáveis") }
        static var whitelistPlaceholder: String { LanguageManager.localized("security.whitelist.placeholder", comment: "exemplo.com") }
        static var whitelistAddTitle: String { LanguageManager.localized("security.whitelist.add.title", comment: "Adicionar domínio") }
        static var whitelistInvalid: String { LanguageManager.localized("security.whitelist.invalid", comment: "Introduza um domínio válido") }

        static var batchTitle: String { LanguageManager.localized("security.batch.title", comment: "Verificação em massa") }
        static var batchSubtitle: String { LanguageManager.localized("security.batch.subtitle", comment: "Verifique várias imagens de uma vez") }
        static var batchEmptyTitle: String { LanguageManager.localized("security.batch.empty.title", comment: "Verifique várias imagens") }
        static var batchEmptyDesc: String { LanguageManager.localized("security.batch.empty.desc", comment: "Selecione fotos com códigos QR; os links são verificados no seu dispositivo") }
        static var batchPick: String { LanguageManager.localized("security.batch.pick", comment: "Selecionar fotos") }
        static var batchPickMore: String { LanguageManager.localized("security.batch.pickMore", comment: "Adicionar mais fotos") }
        static var batchProcessing: String { LanguageManager.localized("security.batch.processing", comment: "A verificar imagens...") }
        static var batchImageName: String { LanguageManager.localized("security.batch.imageName", comment: "Imagem %d") }
        static var batchNoURL: String { LanguageManager.localized("security.batch.noURL", comment: "Não foram encontrados links nas imagens") }
        static var batchTrusted: String { LanguageManager.localized("security.batch.trusted", comment: "Confiável") }
    }

    enum ResultType {
        static var url: String { LanguageManager.localized("result.type.url", comment: "Ligação") }
        static var text: String { LanguageManager.localized("result.type.text", comment: "Texto") }
        static var wifi: String { LanguageManager.localized("result.type.wifi", comment: "Wi-Fi") }
        static var email: String { LanguageManager.localized("result.type.email", comment: "Email") }
        static var phone: String { LanguageManager.localized("result.type.phone", comment: "Telefone") }
        static var sms: String { LanguageManager.localized("result.type.sms", comment: "SMS") }
        static var contact: String { LanguageManager.localized("result.type.contact", comment: "Contacto") }
        static var location: String { LanguageManager.localized("result.type.location", comment: "Localização") }
        static var barcode: String { LanguageManager.localized("result.type.barcode", comment: "Código de barras") }
        static var event: String { LanguageManager.localized("result.type.event", comment: "Evento") }
        static var payment: String { LanguageManager.localized("result.type.payment", comment: "Pagamento") }
        static var crypto: String { LanguageManager.localized("result.type.crypto", comment: "Criptomoeda") }
    }

    enum Source {
        static var camera: String { LanguageManager.localized("source.camera", comment: "Câmara") }
        static var photos: String { LanguageManager.localized("source.photos", comment: "Fotografia") }
        static var generator: String { LanguageManager.localized("source.generator", comment: "Criado na app") }
    }

    enum Create {
        static var title: String { LanguageManager.localized("create.title", comment: "Título Criar") }
        static var subtitle: String { LanguageManager.localized("create.subtitle", comment: "Crie o seu código QR") }
        static var add: String { LanguageManager.localized("create.add", comment: "Botão flutuante de criação livre") }
        static var customTitle: String { LanguageManager.localized("create.custom.title", comment: "Código personalizado") }

        // 分区
        static var sectionSocial: String { LanguageManager.localized("create.section.social", comment: "Secção redes sociais") }
        static var sectionQR: String { LanguageManager.localized("create.section.qr", comment: "Secção códigos QR") }
        static var sectionBarcode: String { LanguageManager.localized("create.section.barcode", comment: "Secção códigos de barras") }
        static var sectionRecent: String { LanguageManager.localized("create.section.recent", comment: "Criados recentemente") }
        static var previewLive: String { LanguageManager.localized("create.preview.live", comment: "Pré-visualização ao vivo") }

        // 类型名
        static var typeInstagram: String { LanguageManager.localized("create.type.instagram", comment: "Instagram") }
        static var typeTikTok: String { LanguageManager.localized("create.type.tiktok", comment: "TikTok") }
        static var typeYouTube: String { LanguageManager.localized("create.type.youtube", comment: "YouTube") }
        static var typeFacebook: String { LanguageManager.localized("create.type.facebook", comment: "Facebook") }
        static var typeWhatsApp: String { LanguageManager.localized("create.type.whatsapp", comment: "WhatsApp") }
        static var typeTelegram: String { LanguageManager.localized("create.type.telegram", comment: "Telegram") }
        static var typeLinkedIn: String { LanguageManager.localized("create.type.linkedin", comment: "LinkedIn") }
        static var typeX: String { LanguageManager.localized("create.type.x", comment: "X") }
        static var typeWeChat: String { LanguageManager.localized("create.type.wechat", comment: "WeChat") }
        static var typeXiaohongshu: String { LanguageManager.localized("create.type.xiaohongshu", comment: "Xiaohongshu") }
        static var typeWebsite: String { LanguageManager.localized("create.type.website", comment: "Website") }
        static var typeText: String { LanguageManager.localized("create.type.text", comment: "Texto") }
        static var typeEmail: String { LanguageManager.localized("create.type.email", comment: "Email") }
        static var typeSMS: String { LanguageManager.localized("create.type.sms", comment: "SMS") }
        static var typePhone: String { LanguageManager.localized("create.type.phone", comment: "Telefone") }
        static var typeWiFi: String { LanguageManager.localized("create.type.wifi", comment: "Wi-Fi") }
        static var typeContact: String { LanguageManager.localized("create.type.contact", comment: "Contacto") }
        static var typeLocation: String { LanguageManager.localized("create.type.location", comment: "Localização") }

        // 标签与占位符
        static var websiteLabel: String { LanguageManager.localized("create.label.website", comment: "Endereço") }
        static var websitePlaceholder: String { LanguageManager.localized("create.placeholder.website", comment: "Exemplo de URL") }
        static var textLabel: String { LanguageManager.localized("create.label.text", comment: "Conteúdo") }
        static var textPlaceholder: String { LanguageManager.localized("create.placeholder.text", comment: "Texto a codificar") }
        static var placeholderHandle: String { LanguageManager.localized("create.placeholder.handle", comment: "Exemplo de utilizador") }
        static var placeholderWeChat: String { LanguageManager.localized("create.placeholder.wechat", comment: "Exemplo de ID WeChat") }
        static var labelPhone: String { LanguageManager.localized("create.label.phone", comment: "Número de telefone") }
        static var placeholderPhone: String { LanguageManager.localized("create.placeholder.phone", comment: "Exemplo de número") }
        static var labelEmail: String { LanguageManager.localized("create.label.email", comment: "Email") }
        static var placeholderEmail: String { LanguageManager.localized("create.placeholder.email", comment: "Exemplo de email") }
        static var labelMessage: String { LanguageManager.localized("create.label.message", comment: "Mensagem") }
        static var placeholderMessage: String { LanguageManager.localized("create.placeholder.message", comment: "Texto da mensagem") }
        static var labelName: String { LanguageManager.localized("create.label.name", comment: "Nome") }
        static var placeholderName: String { LanguageManager.localized("create.placeholder.name", comment: "Exemplo de nome") }
        static var labelOrganisation: String { LanguageManager.localized("create.label.organisation", comment: "Organização") }
        static var placeholderOrganisation: String { LanguageManager.localized("create.placeholder.organisation", comment: "Exemplo de organização") }
        static var labelSSID: String { LanguageManager.localized("create.label.ssid", comment: "Nome da rede") }
        static var placeholderSSID: String { LanguageManager.localized("create.placeholder.ssid", comment: "Exemplo de SSID") }
        static var labelSecurity: String { LanguageManager.localized("create.label.security", comment: "Segurança") }
        static var labelPassword: String { LanguageManager.localized("create.label.password", comment: "Palavra-passe") }
        static var placeholderPassword: String { LanguageManager.localized("create.placeholder.password", comment: "Palavra-passe do Wi-Fi") }
        static var labelHiddenNetwork: String { LanguageManager.localized("create.label.hiddenNetwork", comment: "Rede oculta") }
        static var labelLatitude: String { LanguageManager.localized("create.label.latitude", comment: "Latitude") }
        static var placeholderLatitude: String { LanguageManager.localized("create.placeholder.latitude", comment: "Exemplo de latitude") }
        static var labelLongitude: String { LanguageManager.localized("create.label.longitude", comment: "Longitude") }
        static var placeholderLongitude: String { LanguageManager.localized("create.placeholder.longitude", comment: "Exemplo de longitude") }
        static var locationHint: String { LanguageManager.localized("create.location.hint", comment: "Como obter coordenadas") }

        static var wifiSecurityWPA: String { LanguageManager.localized("create.wifi.security.wpa", comment: "WPA/WPA2") }
        static var wifiSecurityWEP: String { LanguageManager.localized("create.wifi.security.wep", comment: "WEP") }
        static var wifiSecurityNone: String { LanguageManager.localized("create.wifi.security.none", comment: "Sem palavra-passe") }

        // 码制
        static var formatTitle: String { LanguageManager.localized("create.format.title", comment: "Formato do código") }
        static var formatFooter: String { LanguageManager.localized("create.format.footer", comment: "Limites dos códigos de barras") }

        // 样式
        static var style: String { LanguageManager.localized("create.style", comment: "Botão de estilo") }
        static var styleTitle: String { LanguageManager.localized("create.style.title", comment: "Título do painel de estilo") }
        static var styleForeground: String { LanguageManager.localized("create.style.foreground", comment: "Cor dos pontos") }
        static var styleBars: String { LanguageManager.localized("create.style.bars", comment: "Cor das barras") }
        static var styleBackground: String { LanguageManager.localized("create.style.background", comment: "Cor do fundo") }
        static var styleShape: String { LanguageManager.localized("create.style.shape", comment: "Forma dos pontos") }
        static var styleLogo: String { LanguageManager.localized("create.style.logo", comment: "Ícone ao centro") }
        static var styleLogoHint: String { LanguageManager.localized("create.style.logoHint", comment: "Nota sobre o ícone") }
        static var styleLowContrast: String { LanguageManager.localized("create.style.lowContrast", comment: "Aviso de contraste") }
        static var shapeSquare: String { LanguageManager.localized("create.shape.square", comment: "Quadrado") }
        static var shapeRounded: String { LanguageManager.localized("create.shape.rounded", comment: "Arredondado") }
        static var shapeCircle: String { LanguageManager.localized("create.shape.circle", comment: "Círculo") }
        static var drawerExpand: String { LanguageManager.localized("create.drawer.expand", comment: "Expandir") }
        static var drawerCollapse: String { LanguageManager.localized("create.drawer.collapse", comment: "Recolher") }
        static var tabPresets: String { LanguageManager.localized("create.tab.presets", comment: "Estilos") }
        static var tabDots: String { LanguageManager.localized("create.tab.dots", comment: "Pontos") }
        static var tabEyes: String { LanguageManager.localized("create.tab.eyes", comment: "Cantos") }
        static var tabColors: String { LanguageManager.localized("create.tab.colors", comment: "Cores") }
        static var tabLogo: String { LanguageManager.localized("create.tab.logo", comment: "Ícone") }
        static var tabTemplates: String { LanguageManager.localized("create.tab.templates", comment: "Modelos") }
        static var undo: String { LanguageManager.localized("create.undo", comment: "Desfazer") }
        static var eyeFrame: String { LanguageManager.localized("create.eye.frame", comment: "Moldura") }
        static var eyeBall: String { LanguageManager.localized("create.eye.ball", comment: "Centro") }
        static var colorEyes: String { LanguageManager.localized("create.color.eyes", comment: "Cor dos cantos") }
        static var colorMatch: String { LanguageManager.localized("create.color.match", comment: "Igual aos pontos") }
        static var presetInk: String { LanguageManager.localized("create.preset.ink", comment: "Tinta") }
        static var presetMidnight: String { LanguageManager.localized("create.preset.midnight", comment: "Meia-noite") }
        static var presetCoral: String { LanguageManager.localized("create.preset.coral", comment: "Coral") }
        static var presetForest: String { LanguageManager.localized("create.preset.forest", comment: "Floresta") }
        static var presetBordeaux: String { LanguageManager.localized("create.preset.bordeaux", comment: "Bordô") }
        static var shapeDots: String { LanguageManager.localized("create.shape.dots", comment: "Pontos") }
        static var shapeClassy: String { LanguageManager.localized("create.shape.classy", comment: "Elegante") }
        static var eyeDrop: String { LanguageManager.localized("create.eye.drop", comment: "Gota") }
        static var stepFill: String { LanguageManager.localized("create.step.fill", comment: "Preencher") }
        static var stepDesign: String { LanguageManager.localized("create.step.design", comment: "Design") }
        static var generate: String { LanguageManager.localized("create.generate", comment: "Gerar") }
        static var present: String { LanguageManager.localized("create.present", comment: "Mostrar") }
        static var presetsTitle: String { LanguageManager.localized("create.presets.title", comment: "Estilos") }
        static var presetsMore: String { LanguageManager.localized("create.presets.more", comment: "Mais") }
        static var presetClassic: String { LanguageManager.localized("create.preset.classic", comment: "Clássico") }
        static var presetSoft: String { LanguageManager.localized("create.preset.soft", comment: "Suave") }
        static var presetSapphire: String { LanguageManager.localized("create.preset.sapphire", comment: "Safira") }
        static var presetFluid: String { LanguageManager.localized("create.preset.fluid", comment: "Fluido") }
        static var presetOcean: String { LanguageManager.localized("create.preset.ocean", comment: "Oceano") }
        static var presetBerry: String { LanguageManager.localized("create.preset.berry", comment: "Frutos") }
        static var presetViolet: String { LanguageManager.localized("create.preset.violet", comment: "Violeta") }
        static var presetGraphite: String { LanguageManager.localized("create.preset.graphite", comment: "Grafite") }
        static var shapeFluid: String { LanguageManager.localized("create.shape.fluid", comment: "Fluido") }
        static var shapeBars: String { LanguageManager.localized("create.shape.bars", comment: "Barras") }
        static var styleEyes: String { LanguageManager.localized("create.style.eyes", comment: "Cantos") }
        static var eyeSquare: String { LanguageManager.localized("create.eye.square", comment: "Retos") }
        static var eyeRounded: String { LanguageManager.localized("create.eye.rounded", comment: "Arredondados") }
        static var eyeCircle: String { LanguageManager.localized("create.eye.circle", comment: "Círculo") }
        static var eyeLeaf: String { LanguageManager.localized("create.eye.leaf", comment: "Folha") }
        static var proPreviewTitle: String { LanguageManager.localized("create.pro.previewTitle", comment: "A pré-visualizar um estilo PRO") }
        static var proPreviewBody: String { LanguageManager.localized("create.pro.previewBody", comment: "Experimente à vontade; compre uma vez para guardar e partilhar.") }
        static var proUnlock: String { LanguageManager.localized("create.pro.unlock", comment: "Desbloquear") }
        static var showcaseHint: String { LanguageManager.localized("create.showcase.hint", comment: "Toque para fechar · brilho no máximo para facilitar a leitura") }
        static var previewTapToShow: String { LanguageManager.localized("create.preview.tapToShow", comment: "Toque para mostrar") }
        static var styleProHint: String { LanguageManager.localized("create.style.proHint", comment: "Pode pré-visualizar estilos PRO; o desbloqueio só é pedido ao guardar ou partilhar.") }

        // 中心图标来源
        static var logoNone: String { LanguageManager.localized("create.logo.none", comment: "Sem ícone") }
        static var logoBrand: String { LanguageManager.localized("create.logo.brand", comment: "Ícone da marca") }
        static var logoCustom: String { LanguageManager.localized("create.logo.custom", comment: "A minha imagem") }
        static var logoPick: String { LanguageManager.localized("create.logo.pick", comment: "Escolher imagem") }
        static var logoReplace: String { LanguageManager.localized("create.logo.replace", comment: "Trocar imagem") }
        static var logoRemove: String { LanguageManager.localized("create.logo.remove", comment: "Remover imagem") }
        static var logoUnavailable: String { LanguageManager.localized("create.logo.unavailable", comment: "Imagem indisponível") }

        // 备注
        static var noteLabel: String { LanguageManager.localized("create.note.label", comment: "Nota") }
        static var notePlaceholder: String { LanguageManager.localized("create.note.placeholder", comment: "Exemplo de nota") }

        // 预览与操作
        static var previewTitle: String { LanguageManager.localized("create.preview.title", comment: "Pré-visualização") }
        static var previewEmpty: String { LanguageManager.localized("create.preview.empty", comment: "Sem pré-visualização") }
        static var saved: String { LanguageManager.localized("create.saved", comment: "Código guardado") }
        static var saveFailed: String { LanguageManager.localized("create.saveFailed", comment: "Falha ao guardar imagem") }

        // 错误
        static var errorEmpty: String { LanguageManager.localized("create.error.empty", comment: "Conteúdo vazio") }
        static var errorInvalidURL: String { LanguageManager.localized("create.error.invalidURL", comment: "URL inválido") }
        static var errorInvalidHandle: String { LanguageManager.localized("create.error.invalidHandle", comment: "Utilizador inválido") }
        static var errorInvalidPhone: String { LanguageManager.localized("create.error.invalidPhone", comment: "Número inválido") }
        static var errorInvalidEmail: String { LanguageManager.localized("create.error.invalidEmail", comment: "Email inválido") }
        static var errorInvalidCoordinates: String { LanguageManager.localized("create.error.invalidCoordinates", comment: "Coordenadas inválidas") }
        static var errorTooLong: String { LanguageManager.localized("create.error.tooLong", comment: "Conteúdo demasiado longo") }
        static var errorFailed: String { LanguageManager.localized("create.error.failed", comment: "Falha ao gerar") }
        static var errorChecksum: String { LanguageManager.localized("create.error.checksum", comment: "Dígito de controlo errado") }

        /// 「需要 12/13 位数字」——EAN-13 / EAN-8 的硬性位数要求（可带校验位，也可不带）。
        static func errorNeedsDigits(_ counts: String) -> String {
            String(
                format: LanguageManager.localized("create.error.needsDigits", comment: "Dígitos necessários"),
                counts
            )
        }

        /// 「包含不支持的字符，可用：0-9 A-Z」——Code 39 / EAN 的字符集限制。
        static func errorUnsupportedChars(_ allowed: String) -> String {
            String(
                format: LanguageManager.localized("create.error.unsupportedChars", comment: "Caracteres não suportados"),
                allowed
            )
        }

        // 头部副标题
        static var subtitleSocial: String { LanguageManager.localized("create.subtitle.social", comment: "Subtítulo para redes sociais") }
        static var subtitleWiFi: String { LanguageManager.localized("create.subtitle.wifi", comment: "Subtítulo para Wi-Fi") }
        static var subtitleContact: String { LanguageManager.localized("create.subtitle.contact", comment: "Subtítulo para contacto vCard") }
        static var subtitleGeneric: String { LanguageManager.localized("create.subtitle.generic", comment: "Subtítulo genérico para QR") }
        static var subtitleBarcode: String { LanguageManager.localized("create.subtitle.barcode", comment: "Subtítulo para código de barras") }
        static var subtitleCustom: String { LanguageManager.localized("create.subtitle.custom", comment: "Subtítulo para código personalizado") }

        // 顶部精选轮播
        enum Carousel {
            static var badgePopular: String { LanguageManager.localized("create.carousel.badge.popular", comment: "Etiqueta Popular") }
            static var titleWifi: String { LanguageManager.localized("create.carousel.wifi.title", comment: "Título Partilhar Wi-Fi") }
            static var subtitleWifi: String { LanguageManager.localized("create.carousel.wifi.subtitle", comment: "Subtítulo Wi-Fi") }
            static var buttonWifi: String { LanguageManager.localized("create.carousel.wifi.button", comment: "Botão Wi-Fi") }

            static var badgeSocial: String { LanguageManager.localized("create.carousel.badge.social", comment: "Etiqueta Redes Sociais") }
            static var titleInstagram: String { LanguageManager.localized("create.carousel.instagram.title", comment: "Título Instagram") }
            static var subtitleInstagram: String { LanguageManager.localized("create.carousel.instagram.subtitle", comment: "Subtítulo Instagram") }
            static var buttonInstagram: String { LanguageManager.localized("create.carousel.instagram.button", comment: "Botão Instagram") }

            static var badgeBusiness: String { LanguageManager.localized("create.carousel.badge.business", comment: "Etiqueta Profissional") }
            static var titleVCard: String { LanguageManager.localized("create.carousel.vcard.title", comment: "Título vCard") }
            static var subtitleVCard: String { LanguageManager.localized("create.carousel.vcard.subtitle", comment: "Subtítulo vCard") }
            static var buttonVCard: String { LanguageManager.localized("create.carousel.vcard.button", comment: "Botão vCard") }

            static var badgeRetail: String { LanguageManager.localized("create.carousel.badge.retail", comment: "Etiqueta Retalho") }
            static var titleEAN13: String { LanguageManager.localized("create.carousel.ean13.title", comment: "Título EAN-13") }
            static var subtitleEAN13: String { LanguageManager.localized("create.carousel.ean13.subtitle", comment: "Subtítulo EAN-13") }
            static var buttonEAN13: String { LanguageManager.localized("create.carousel.ean13.button", comment: "Botão EAN-13") }
        }
    }

    /// 二维码模板选择器。成套预设 + 分类 + 手动微调共用一套文案。
    enum Templates {
        static var title: String { LanguageManager.localized("templates.title", comment: "Modelos") }
        static var apply: String { LanguageManager.localized("templates.apply", comment: "Aplicar") }
        static var all: String { LanguageManager.localized("templates.all", comment: "Todos") }
        static var classic: String { LanguageManager.localized("templates.classic", comment: "Clássicos") }
        static var social: String { LanguageManager.localized("templates.social", comment: "Social") }
        static var holiday: String { LanguageManager.localized("templates.holiday", comment: "Festas") }
        static var love: String { LanguageManager.localized("templates.love", comment: "Amor") }
        static var birthday: String { LanguageManager.localized("templates.birthday", comment: "Aniversário") }
        static var none: String { LanguageManager.localized("templates.none", comment: "Sem modelo") }
        static var manual: String { LanguageManager.localized("templates.manual", comment: "Ajuste manual") }
        static var adjustHint: String { LanguageManager.localized("templates.adjustHint", comment: "Alterar manualmente limpa o modelo") }
        static var custom: String { LanguageManager.localized("templates.custom", comment: "Personalizado") }
        static var defaultCategory: String { LanguageManager.localized("templates.defaultCategory", comment: "Padrão") }

        static var nameClassicInk: String { LanguageManager.localized("templates.name.classicInk", comment: "Tinta") }
        static var nameClassicBlue: String { LanguageManager.localized("templates.name.classicBlue", comment: "Azul") }
        static var nameSocialGreen: String { LanguageManager.localized("templates.name.socialGreen", comment: "Verde") }
        static var nameSocialNight: String { LanguageManager.localized("templates.name.socialNight", comment: "Noite") }
        static var nameSocialSunset: String { LanguageManager.localized("templates.name.socialSunset", comment: "Pôr do sol") }
        static var nameSocialComic: String { LanguageManager.localized("templates.name.socialComic", comment: "Balão Pop") }
        static var nameHolidayPumpkin: String { LanguageManager.localized("templates.name.holidayPumpkin", comment: "Abóbora") }
        static var nameHolidayGhost: String { LanguageManager.localized("templates.name.holidayGhost", comment: "Fantasma") }
        static var nameHolidaySnow: String { LanguageManager.localized("templates.name.holidaySnow", comment: "Neve") }
        static var nameLoveHeart: String { LanguageManager.localized("templates.name.loveHeart", comment: "Coração") }
        static var nameLoveRose: String { LanguageManager.localized("templates.name.loveRose", comment: "Rosa") }
        static var nameBirthdayBalloons: String { LanguageManager.localized("templates.name.birthdayBalloons", comment: "Balões") }
        static var nameBirthdayGift: String { LanguageManager.localized("templates.name.birthdayGift", comment: "Presente") }
    }

    enum History {
        static var title: String { LanguageManager.localized("history.title", comment: "Histórico") }
        static var emptyTitle: String { LanguageManager.localized("history.empty.title", comment: "Sem resultados") }
        static var emptyMessage: String { LanguageManager.localized("history.empty.message", comment: "Mensagem de histórico vazio") }
        static var freeLimitNotice: String { LanguageManager.localized("history.freeLimit.notice", comment: "Aviso de limite gratuito") }
        static var clear: String { LanguageManager.localized("history.clear", comment: "Limpar histórico") }
        static var clearTitle: String { LanguageManager.localized("history.clear.title", comment: "Confirmar limpeza") }
        static var clearMessage: String { LanguageManager.localized("history.clear.message", comment: "Aviso de limpeza") }
        static var sectionRecent: String { LanguageManager.localized("history.section.recent", comment: "Registos recentes") }
        static var sectionToday: String { LanguageManager.localized("history.section.today", comment: "Hoje") }
        static var sectionYesterday: String { LanguageManager.localized("history.section.yesterday", comment: "Ontem") }
        static var sectionEarlier: String { LanguageManager.localized("history.section.earlier", comment: "Anterior") }
        static var sectionThisWeek: String { LanguageManager.localized("history.section.thisWeek", comment: "Esta semana") }
        static var quotaTitle: String { LanguageManager.localized("history.quota.title", comment: "Título da barra de quota gratuita") }
        static var heroUnit: String { LanguageManager.localized("history.hero.unit", comment: "Unidade após o número total") }
        static var heroScanned: String { LanguageManager.localized("history.hero.scanned", comment: "Lidos") }
        static var heroCreated: String { LanguageManager.localized("history.hero.created", comment: "Criados") }
        static var heroWeek: String { LanguageManager.localized("history.hero.week", comment: "Esta semana") }
        static var heroUnlimited: String { LanguageManager.localized("history.hero.unlimited", comment: "Histórico ilimitado ativo") }
        static func deletedCount(_ count: Int) -> String {
            String(format: LanguageManager.localized("history.deleted.count", comment: "N registos eliminados (com desfazer)"), count)
        }
        static var menuFilterTitle: String { LanguageManager.localized("history.menu.filter", comment: "Filtrar por") }
        static var menuSortTitle: String { LanguageManager.localized("history.menu.sort", comment: "Ordenar por") }
        static var clearFilter: String { LanguageManager.localized("history.menu.clearFilter", comment: "Limpar filtro") }
        static var claimPremium: String { LanguageManager.localized("history.claimPremium", comment: "Desbloquear histórico ilimitado") }
        static var detailTitle: String { LanguageManager.localized("history.detail.title", comment: "Título do detalhe") }
        static var codeTitle: String { LanguageManager.localized("history.detail.code", comment: "Secção do código") }
        static var noteLabel: String { LanguageManager.localized("history.note.label", comment: "Nota do registo") }
        static var notePlaceholder: String { LanguageManager.localized("history.note.placeholder", comment: "Adicionar nota") }
        static var noteHint: String { LanguageManager.localized("history.note.hint", comment: "Ajuda da nota") }
        static var noCodeImage: String { LanguageManager.localized("history.detail.noCode", comment: "Código não redesenhável") }

        // 列表与搜索
        static var searchPrompt: String { LanguageManager.localized("history.search.prompt", comment: "Pesquisar histórico") }
        static var addRecord: String { LanguageManager.localized("history.addRecord", comment: "Adicionar registo") }
        static var filterAll: String { LanguageManager.localized("history.filter.all", comment: "Todos") }
        static var filterQR: String { LanguageManager.localized("history.filter.qr", comment: "Código QR") }
        static var filterBarcode: String { LanguageManager.localized("history.filter.barcode", comment: "Código de barras") }
        static var filterWebsite: String { LanguageManager.localized("history.filter.website", comment: "Website") }
        static var filterWiFi: String { LanguageManager.localized("history.filter.wifi", comment: "Wi-Fi") }
        static var filterHasNote: String { LanguageManager.localized("history.filter.hasNote", comment: "Com nota") }

        // 排序与多维筛选
        static var sortMenuTitle: String { LanguageManager.localized("history.sort.title", comment: "Ordenar") }
        static var sortNewest: String { LanguageManager.localized("history.sort.newest", comment: "Mais recentes") }
        static var sortOldest: String { LanguageManager.localized("history.sort.oldest", comment: "Mais antigos") }
        static var sortTitle: String { LanguageManager.localized("history.sort.name", comment: "Nome (A-Z)") }
        static var sortFormat: String { LanguageManager.localized("history.sort.format", comment: "Tipo de código") }

        static var sourceFilterTitle: String { LanguageManager.localized("history.source.title", comment: "Origem") }
        static var sourceAll: String { LanguageManager.localized("history.source.all", comment: "Todas as origens") }
        static var sourceCamera: String { LanguageManager.localized("history.source.camera", comment: "Câmara") }
        static var sourcePhotos: String { LanguageManager.localized("history.source.photos", comment: "Fotografias") }
        static var sourceGenerator: String { LanguageManager.localized("history.source.generator", comment: "Criado/Manual") }

        // 卡片操作与徽标
        static var quickCopy: String { LanguageManager.localized("history.card.copy", comment: "Copiar") }
        static var quickShare: String { LanguageManager.localized("history.card.share", comment: "Partilhar") }
        static var viewDetails: String { LanguageManager.localized("history.card.details", comment: "Detalhes") }
        static var noteBadge: String { LanguageManager.localized("history.card.noteBadge", comment: "Nota") }
        static var a11ySelected: String { LanguageManager.localized("history.a11y.selected", comment: "VoiceOver: linha selecionada") }
        static var a11yUnselected: String { LanguageManager.localized("history.a11y.unselected", comment: "VoiceOver: linha não selecionada") }

        static var copy: String { LanguageManager.localized("history.copy", comment: "Copiar") }
        static var viewDetail: String { LanguageManager.localized("history.viewDetail", comment: "Ver detalhes") }
        static var copyContent: String { LanguageManager.localized("history.copyContent", comment: "Copiar conteúdo") }
        static var shareImage: String { LanguageManager.localized("history.shareImage", comment: "Partilhar imagem") }
        static var deleteRecord: String { LanguageManager.localized("history.deleteRecord", comment: "Eliminar registo") }
        static var deleteConfirmTitle: String { LanguageManager.localized("history.deleteConfirm.title", comment: "Eliminar histórico") }
        static var deleteConfirmMessage: String { LanguageManager.localized("history.deleteConfirm.message", comment: "Confirmar eliminação") }

        // 批量选择 / 侧滑删除
        static var selectTitle: String { LanguageManager.localized("history.select.title", comment: "Selecionar registos") }
        static var selectDone: String { LanguageManager.localized("history.select.done", comment: "Concluído") }
        static var selectAll: String { LanguageManager.localized("history.select.all", comment: "Selecionar todos") }
        static var selectNone: String { LanguageManager.localized("history.select.none", comment: "Limpar seleção") }
        static var selectDelete: String { LanguageManager.localized("history.select.delete", comment: "Eliminar selecionados") }
        static func selectCount(_ count: Int) -> String {
            String(format: LanguageManager.localized("history.select.count", comment: "N selecionados"), count)
        }
        static var selectDeleteTitle: String { LanguageManager.localized("history.select.deleteTitle", comment: "Confirmar eliminação múltipla") }
        static func selectDeleteMessage(_ count: Int) -> String {
            String(format: LanguageManager.localized("history.select.deleteMessage", comment: "Aviso de eliminação múltipla"), count)
        }

        // 空状态与操作
        static var scanNow: String { LanguageManager.localized("history.empty.scanNow", comment: "Escanear agora") }
        static var manualEntry: String { LanguageManager.localized("history.empty.manualEntry", comment: "Registo manual") }
        static var searchEmptyTitle: String { LanguageManager.localized("history.searchEmpty.title", comment: "Nenhum resultado encontrado") }
        static var clearSearch: String { LanguageManager.localized("history.searchEmpty.clear", comment: "Limpar pesquisa") }

        static func searchEmptyMessage(_ query: String) -> String {
            String(
                format: LanguageManager.localized("history.searchEmpty.message", comment: "Sem resultados para pesquisa"),
                query
            )
        }

        static func recordsCount(_ count: Int) -> String {
            String(
                format: LanguageManager.localized("history.recordsCount", comment: "Contagem de registos"),
                count
            )
        }

        // 手工录入弹窗
        enum Add {
            static var title: String { LanguageManager.localized("history.add.title", comment: "Novo registo") }
            static var kindCategory: String { LanguageManager.localized("history.add.kindCategory", comment: "Tipo de código") }
            static var qr: String { LanguageManager.localized("history.add.qr", comment: "Código QR") }
            static var barcode: String { LanguageManager.localized("history.add.barcode", comment: "Código de barras") }
            static var contentType: String { LanguageManager.localized("history.add.contentType", comment: "Tipo de conteúdo") }
            static var barcodeFormat: String { LanguageManager.localized("history.add.barcodeFormat", comment: "Formato do código de barras") }
            static var typeSelection: String { LanguageManager.localized("history.add.typeSelection", comment: "Seleção do tipo") }
            static var content: String { LanguageManager.localized("history.add.content", comment: "Conteúdo") }
            static var note: String { LanguageManager.localized("history.add.note", comment: "Nota") }
            static var notePlaceholder: String { LanguageManager.localized("history.add.notePlaceholder", comment: "Adicionar nota (opcional)") }
            static var preview: String { LanguageManager.localized("history.add.preview", comment: "Pré-visualização") }
            static var previewEmpty: String { LanguageManager.localized("history.add.previewEmpty", comment: "Insira conteúdo para pré-visualizar") }
            static var paste: String { LanguageManager.localized("history.add.paste", comment: "Colar") }
            static var wifiSSID: String { LanguageManager.localized("history.add.wifiSSID", comment: "Nome da rede (SSID)") }
            static var wifiPassword: String { LanguageManager.localized("history.add.wifiPassword", comment: "Palavra-passe do Wi-Fi") }
        }
    }

    enum Settings {
        static var title: String { LanguageManager.localized("settings.title", comment: "Definições") }
        static var premium: String { LanguageManager.localized("settings.premium", comment: "Premium") }
        static var premiumInactive: String { LanguageManager.localized("settings.premium.inactive", comment: "Versão gratuita") }
        static var subscription: String { LanguageManager.localized("settings.subscription", comment: "Subscrição") }
        static var restore: String { LanguageManager.localized("settings.restore", comment: "Restaurar compras") }
        static var sectionLegal: String { LanguageManager.localized("settings.section.legal", comment: "Secção legal") }
        static var sectionAbout: String { LanguageManager.localized("settings.section.about", comment: "Secção sobre") }
        static var sectionScan: String { LanguageManager.localized("settings.section.scan", comment: "Secção de leitura") }
        static var scanSound: String { LanguageManager.localized("settings.scanSound", comment: "Som ao ler um código") }
        static var scanSoundFooter: String { LanguageManager.localized("settings.scanSound.footer", comment: "Descrição do som de leitura") }
        static var privacy: String { LanguageManager.localized("settings.privacy", comment: "Política de Privacidade") }
        static var terms: String { LanguageManager.localized("settings.terms", comment: "Termos de Utilização") }
        static var support: String { LanguageManager.localized("settings.support", comment: "Contactar suporte") }
        static var version: String { LanguageManager.localized("settings.version", comment: "Versão") }
        static var sectionAppearance: String { LanguageManager.localized("settings.section.appearance", comment: "Aparência") }
        static var appearanceSystem: String { LanguageManager.localized("settings.appearance.system", comment: "Sistema") }
        static var appearanceLight: String { LanguageManager.localized("settings.appearance.light", comment: "Claro") }
        static var appearanceDark: String { LanguageManager.localized("settings.appearance.dark", comment: "Escuro") }
        static var sectionGeneral: String { LanguageManager.localized("settings.section.general", comment: "Secção geral") }
        static var language: String { LanguageManager.localized("settings.language", comment: "Idioma") }
        static var languageFooter: String { LanguageManager.localized("settings.language.footer", comment: "Ajuda para alterar o idioma") }
        static var heroTitle: String { LanguageManager.localized("settings.hero.title", comment: "Leitor QR — privado e simples") }
        static var heroPrivacy: String { LanguageManager.localized("settings.hero.privacy", comment: "Privacidade") }
        static var heroNoAds: String { LanguageManager.localized("settings.hero.noAds", comment: "Sem anúncios") }
        static var heroOnDevice: String { LanguageManager.localized("settings.hero.onDevice", comment: "Processado no dispositivo") }
        static func cardDaysLeft(_ days: Int) -> String {
            String(format: LanguageManager.localized("settings.card.daysLeft", comment: "Dias restantes da experiência"), days)
        }
        static var cardUpgrade: String { LanguageManager.localized("settings.card.upgrade", comment: "Tornar vitalício") }
        static var cardLifetimeDetail: String { LanguageManager.localized("settings.card.lifetimeDetail", comment: "Tudo desbloqueado para sempre") }
        static var cardLifetimeBadge: String { LanguageManager.localized("settings.card.lifetimeBadge", comment: "Membro vitalício") }
        static var cardPerkHistory: String { LanguageManager.localized("settings.card.perkHistory", comment: "Histórico") }
        static var cardPerkStyles: String { LanguageManager.localized("settings.card.perkStyles", comment: "Estilos") }
        static var cardPerkSecurity: String { LanguageManager.localized("settings.card.perkSecurity", comment: "Segurança") }
        static var sectionAutoAction: String { LanguageManager.localized("settings.section.autoAction", comment: "Ações automáticas") }
        static var autoWifi: String { LanguageManager.localized("settings.auto.wifi", comment: "Ligar a Wi-Fi automaticamente") }
        static var autoWifiDesc: String { LanguageManager.localized("settings.auto.wifi.desc", comment: "Ao ler um código Wi-Fi, tentar ligar sem abrir o resultado") }
        static var autoWebsite: String { LanguageManager.localized("settings.auto.website", comment: "Abrir sites automaticamente") }
        static var autoWebsiteDesc: String { LanguageManager.localized("settings.auto.website.desc", comment: "Abrir links seguros no navegador; links suspeitos pedem confirmação") }
        static var autoLink: String { LanguageManager.localized("settings.auto.link", comment: "Abrir telefone, SMS, e-mail e mapas automaticamente") }
        static var autoLinkDesc: String { LanguageManager.localized("settings.auto.link.desc", comment: "Abre a app correspondente sem mostrar o resultado") }
        static var autoActionFooter: String { LanguageManager.localized("settings.auto.footer", comment: "Desativado por predefinição. Endereços suspeitos nunca são abertos automaticamente.") }
    }

    /// 语言选择页文案
    enum Language {
        static var section: String { LanguageManager.localized("language.section", comment: "Idioma da aplicação") }
        static var footer: String { LanguageManager.localized("language.footer", comment: "A alteração é aplicada imediatamente em todo o aplicativo.") }
        static var search: String { LanguageManager.localized("language.search", comment: "Campo de pesquisa na lista de idiomas") }
    }

    enum Pro {
        static var entry: String { LanguageManager.localized("pro.entry", comment: "Entrada PRO (canto superior)") }
        static var active: String { LanguageManager.localized("pro.active", comment: "Subscrição ativa") }
        static var inactive: String { LanguageManager.localized("pro.inactive", comment: "Sem subscrição") }
    }

    enum Subscription {
        static var title: String { LanguageManager.localized("subscription.title", comment: "Subscrição") }
        static var statusTitle: String { LanguageManager.localized("subscription.status.title", comment: "Estado") }
        static var statusTrial: String { LanguageManager.localized("subscription.status.trial", comment: "Período experimental ativo") }
        static var statusActive: String { LanguageManager.localized("subscription.status.active", comment: "Subscrição ativa") }
        static var statusCancelled: String { LanguageManager.localized("subscription.status.cancelled", comment: "Renovação cancelada") }
        static var statusExpired: String { LanguageManager.localized("subscription.status.expired", comment: "Subscrição expirada") }
        static var statusBilling: String { LanguageManager.localized("subscription.status.billing", comment: "Problema de faturação") }
        static var statusLifetime: String { LanguageManager.localized("subscription.status.lifetime", comment: "Vitalício") }
        static var statusWeeklyPass: String { LanguageManager.localized("subscription.status.weeklypass", comment: "Estado da experiência de 7 dias") }
        static var statusNone: String { LanguageManager.localized("subscription.status.none", comment: "Sem subscrição") }
        static var statusUnknown: String { LanguageManager.localized("subscription.status.unknown", comment: "A verificar") }
        static var planTitle: String { LanguageManager.localized("subscription.plan.title", comment: "Plano atual") }
        static var planFree: String { LanguageManager.localized("subscription.plan.free", comment: "Versão gratuita") }
        static var price: String { LanguageManager.localized("subscription.price", comment: "Preço") }
        static var period: String { LanguageManager.localized("subscription.period", comment: "Período") }
        static var trialEnd: String { LanguageManager.localized("subscription.trialEnd", comment: "Fim do período experimental") }
        static var renewalDate: String { LanguageManager.localized("subscription.renewalDate", comment: "Próxima renovação") }
        static var expiryDate: String { LanguageManager.localized("subscription.expiryDate", comment: "Fim do período atual") }
        static var autoRenew: String { LanguageManager.localized("subscription.autoRenew", comment: "Renovação automática") }
        static var autoRenewOn: String { LanguageManager.localized("subscription.autoRenew.on", comment: "Ativa") }
        static var autoRenewOff: String { LanguageManager.localized("subscription.autoRenew.off", comment: "Desativada") }
        static var manage: String { LanguageManager.localized("subscription.manage", comment: "Gerir ou cancelar subscrição") }
        static var manageFallback: String { LanguageManager.localized("subscription.manage.fallback", comment: "Página de subscrições da Apple") }
        static var infoTitle: String { LanguageManager.localized("subscription.info.title", comment: "Cancelar ou pedir reembolso") }
        static var cancelInfo: String { LanguageManager.localized("subscription.info.cancel", comment: "Como cancelar") }
        static var refundInfo: String { LanguageManager.localized("subscription.info.refund", comment: "Como pedir reembolso") }
        static var unavailable: String { LanguageManager.localized("subscription.unavailable", comment: "Informação indisponível") }
        static var upgrade: String { LanguageManager.localized("subscription.upgrade", comment: "Conhecer o Premium") }
        static var refresh: String { LanguageManager.localized("subscription.refresh", comment: "Atualizar estado") }
        static var statusLabel: String { LanguageManager.localized("subscription.status.label", comment: "Estado") }
    }

    enum Paywall {
        static var title: String { LanguageManager.localized("paywall.title", comment: "Título do paywall") }

        // 情境化标题：付费点贴着用户刚发生的动作，而不是泛泛的「解锁 PRO」。
        static var contextScanTitle: String { LanguageManager.localized("paywall.context.scan.title", comment: "Título contextual após scans") }
        static var contextScanSubtitle: String { LanguageManager.localized("paywall.context.scan.subtitle", comment: "Subtítulo contextual após scans") }
        static var contextLimitTitle: String { LanguageManager.localized("paywall.context.limit.title", comment: "Título contextual histórico cheio") }
        static var contextLimitSubtitle: String { LanguageManager.localized("paywall.context.limit.subtitle", comment: "Subtítulo histórico cheio") }
        static var contextFeatureTitle: String { LanguageManager.localized("paywall.context.feature.title", comment: "Título contextual funcionalidade bloqueada") }
        static var contextFeatureSubtitle: String { LanguageManager.localized("paywall.context.feature.subtitle", comment: "Subtítulo funcionalidade bloqueada") }
        static var contextOnboardingTitle: String { LanguageManager.localized("paywall.context.onboarding.title", comment: "Título contextual (após a introdução)") }
        static var contextOnboardingSubtitle: String { LanguageManager.localized("paywall.context.onboarding.subtitle", comment: "Subtítulo contextual (após a introdução)") }
        static var unlockedTitle: String { LanguageManager.localized("paywall.unlocked.title", comment: "Título quando já é Premium") }
        static var unlockedContinue: String { LanguageManager.localized("paywall.unlocked.continue", comment: "Botão continuar quando já é Premium") }
        static var templateHint: String { LanguageManager.localized("paywall.template.hint", comment: "Dica dos modelos PRO") }
        static var planWeekly: String { LanguageManager.localized("paywall.plan.weekly", comment: "Plano de experiência de 7 dias") }
        static var planWeeklyNote: String { LanguageManager.localized("paywall.plan.weekly.note", comment: "Nota do plano de experiência") }
        static var subtitle: String { LanguageManager.localized("paywall.subtitle", comment: "Subtítulo do paywall") }
        static var benefitHistory: String { LanguageManager.localized("paywall.benefit.history", comment: "Histórico ilimitado") }
        static var benefitHistoryDesc: String { LanguageManager.localized("paywall.benefit.history.desc", comment: "Descrição do histórico ilimitado") }
        static var benefitTemplates: String { LanguageManager.localized("paywall.benefit.templates", comment: "Modelos avançados") }
        static var benefitTemplatesDesc: String { LanguageManager.localized("paywall.benefit.templates.desc", comment: "Descrição dos modelos avançados") }
        static var benefitCustom: String { LanguageManager.localized("paywall.benefit.custom", comment: "Cores personalizadas") }
        static var benefitCustomDesc: String { LanguageManager.localized("paywall.benefit.custom.desc", comment: "Descrição de personalização") }
        static var benefitPure: String { LanguageManager.localized("paywall.benefit.pure", comment: "Experiência sem anúncios") }
        static var benefitPureDesc: String { LanguageManager.localized("paywall.benefit.pure.desc", comment: "Descrição de experiência pura") }
        static var benefitMore: String { LanguageManager.localized("paywall.benefit.more", comment: "Mais opções de criação") }
        static var proBadge: String { LanguageManager.localized("paywall.badge.pro", comment: "PRO") }
        static var benefitSecurity: String { LanguageManager.localized("paywall.benefit.security", comment: "Histórico e verificação de segurança") }
        static var unlockFeature: String { LanguageManager.localized("paywall.unlockFeature", comment: "Aviso de funcionalidade bloqueada") }
        static var redeemCode: String { LanguageManager.localized("paywall.redeemCode", comment: "Resgatar Código") }
        static var restoring: String { LanguageManager.localized("paywall.restoring", comment: "A restaurar") }
        static var purchaseFailed: String { LanguageManager.localized("paywall.purchase.failed", comment: "Falha na compra") }
        static var purchasePending: String { LanguageManager.localized("paywall.purchase.pending", comment: "Compra pendente") }
        static var purchaseSuccess: String { LanguageManager.localized("paywall.purchase.success", comment: "Compra concluída") }
        static var planLifetime: String { LanguageManager.localized("paywall.plan.lifetime", comment: "Compra única") }
        static var planBestValue: String { LanguageManager.localized("paywall.plan.bestValue", comment: "Melhor valor") }
        static var planLifetimeNote: String { LanguageManager.localized("paywall.plan.lifetime.note", comment: "Pague uma vez, use para sempre") }
        static var ctaBuy: String { LanguageManager.localized("paywall.cta.buy", comment: "Comprar") }
        static var priceNoteLifetime: String { LanguageManager.localized("paywall.priceNote.lifetime", comment: "Nota de preço da compra única") }
        static var priceNotePending: String { LanguageManager.localized("paywall.priceNote.pending", comment: "Nota de preço quando o produto ainda não carregou") }
        static var perMonth: String { LanguageManager.localized("paywall.perMonth", comment: "Equivalente mensal") }
        static var perYearUnit: String { LanguageManager.localized("paywall.per.year", comment: "Unidade após o preço: / ano") }
        static var perMonthUnit: String { LanguageManager.localized("paywall.per.month", comment: "Unidade após o preço: / mês") }
        static var planPopular: String { LanguageManager.localized("paywall.plan.popular", comment: "Etiqueta Mais Popular") }
    }

    enum Period {
        static var daySingular: String { LanguageManager.localized("period.day.singular", comment: "1 dia") }
        static var dayPlural: String { LanguageManager.localized("period.day.plural", comment: "%d dias") }
        static var monthSingular: String { LanguageManager.localized("period.month.singular", comment: "1 mês") }
        static var monthPlural: String { LanguageManager.localized("period.month.plural", comment: "%d meses") }
        static var yearSingular: String { LanguageManager.localized("period.year.singular", comment: "1 ano") }
        static var yearPlural: String { LanguageManager.localized("period.year.plural", comment: "%d anos") }
    }

    enum Error {
        static var invalidImage: String { LanguageManager.localized("error.invalidImage", comment: "Imagem inválida") }
        static var noCodeFound: String { LanguageManager.localized("error.noCodeFound", comment: "Nenhum código encontrado") }
        static var scanFailed: String { LanguageManager.localized("error.scanFailed", comment: "Falha ao ler") }
    }

    enum Legal {
        static var termsTitle: String { LanguageManager.localized("legal.terms.title", comment: "Termos de Utilização") }
        static var privacyTitle: String { LanguageManager.localized("legal.privacy.title", comment: "Política de Privacidade") }
        static var lastUpdated: String { LanguageManager.localized("legal.lastUpdated", comment: "Última atualização: Novembro de 2026") }
        static var contactTitle: String { LanguageManager.localized("legal.contact.title", comment: "Dúvidas e Suporte") }
        static var contactDesc: String { LanguageManager.localized("legal.contact.desc", comment: "Descrição do contacto") }
        static var sendEmail: String { LanguageManager.localized("legal.sendEmail", comment: "Enviar Email") }
        static var copyEmail: String { LanguageManager.localized("legal.copyEmail", comment: "Copiar Email") }
        static var emailCopied: String { LanguageManager.localized("legal.emailCopied", comment: "Email copiado") }

        // Privacy
        static var privacySummary: String { LanguageManager.localized("legal.privacy.summary", comment: "Resumo da privacidade") }
        static var privacySec1Title: String { LanguageManager.localized("legal.privacy.sec1.title", comment: "Secção 1 Privacidade") }
        static var privacySec1Body: String { LanguageManager.localized("legal.privacy.sec1.body", comment: "Texto 1 Privacidade") }
        static var privacySec2Title: String { LanguageManager.localized("legal.privacy.sec2.title", comment: "Secção 2 Privacidade") }
        static var privacySec2Body: String { LanguageManager.localized("legal.privacy.sec2.body", comment: "Texto 2 Privacidade") }
        static var privacySec3Title: String { LanguageManager.localized("legal.privacy.sec3.title", comment: "Secção 3 Privacidade") }
        static var privacySec3Body: String { LanguageManager.localized("legal.privacy.sec3.body", comment: "Texto 3 Privacidade") }
        static var privacySec4Title: String { LanguageManager.localized("legal.privacy.sec4.title", comment: "Secção 4 Privacidade") }
        static var privacySec4Body: String { LanguageManager.localized("legal.privacy.sec4.body", comment: "Texto 4 Privacidade") }
        static var privacySec5Title: String { LanguageManager.localized("legal.privacy.sec5.title", comment: "Secção 5 Privacidade") }
        static var privacySec5Body: String { LanguageManager.localized("legal.privacy.sec5.body", comment: "Texto 5 Privacidade") }

        // Terms
        static var termsSummary: String { LanguageManager.localized("legal.terms.summary", comment: "Resumo dos termos") }
        static var termsSec1Title: String { LanguageManager.localized("legal.terms.sec1.title", comment: "Secção 1 Termos") }
        static var termsSec1Body: String { LanguageManager.localized("legal.terms.sec1.body", comment: "Texto 1 Termos") }
        static var termsSec2Title: String { LanguageManager.localized("legal.terms.sec2.title", comment: "Secção 2 Termos") }
        static var termsSec2Body: String { LanguageManager.localized("legal.terms.sec2.body", comment: "Texto 2 Termos") }
        static var termsSec3Title: String { LanguageManager.localized("legal.terms.sec3.title", comment: "Secção 3 Termos") }
        static var termsSec3Body: String { LanguageManager.localized("legal.terms.sec3.body", comment: "Texto 3 Termos") }
        static var termsSec4Title: String { LanguageManager.localized("legal.terms.sec4.title", comment: "Secção 4 Termos") }
        static var termsSec4Body: String { LanguageManager.localized("legal.terms.sec4.body", comment: "Texto 4 Termos") }
        static var termsSec5Title: String { LanguageManager.localized("legal.terms.sec5.title", comment: "Secção 5 Termos") }
        static var termsSec5Body: String { LanguageManager.localized("legal.terms.sec5.body", comment: "Texto 5 Termos") }
    }

    enum Onboarding {
        static var skip: String { LanguageManager.localized("onboarding.skip", comment: "Saltar") }
        static var next: String { LanguageManager.localized("onboarding.next", comment: "Continuar") }
        static var start: String { LanguageManager.localized("onboarding.start", comment: "Começar a ler") }
        static var scanTitle: String { LanguageManager.localized("onboarding.scan.title", comment: "Leia qualquer código") }
        static var scanBody: String { LanguageManager.localized("onboarding.scan.body", comment: "QR, códigos de barras, Wi‑Fi e contactos. Os links suspeitos são assinalados antes de os abrir.") }
        static var scanBadge: String { LanguageManager.localized("onboarding.scan.badge", comment: "Link seguro") }
        static var createTitle: String { LanguageManager.localized("onboarding.create.title", comment: "Crie códigos bonitos") }
        static var createBody: String { LanguageManager.localized("onboarding.create.body", comment: "Escolha estilos, cores e o seu logótipo. Partilhe ou guarde nas Fotografias.") }
        static var privacyTitle: String { LanguageManager.localized("onboarding.privacy.title", comment: "Privado por defeito") }
        static var privacyBody: String { LanguageManager.localized("onboarding.privacy.body", comment: "Tudo fica no seu iPhone.") }
        static var privacyNoAccount: String { LanguageManager.localized("onboarding.privacy.noAccount", comment: "Sem conta") }
        static var privacyNoTracking: String { LanguageManager.localized("onboarding.privacy.noTracking", comment: "Sem rastreio nem anúncios") }
        static var privacyLocal: String { LanguageManager.localized("onboarding.privacy.local", comment: "Histórico só no dispositivo") }
        static var cameraNote: String { LanguageManager.localized("onboarding.camera.note", comment: "A seguir pedimos acesso à câmara, usada apenas para ler códigos em tempo real.") }
    }
}
