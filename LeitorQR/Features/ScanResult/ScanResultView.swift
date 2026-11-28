import SwiftData
import SwiftUI
import UIKit

/// 单条结果详情（sheet）。
///
/// 2026-11-27 重构：没有导航标题，只有右上角一枚关闭钮（iOS 26 自动是玻璃）。
/// 正文由 `ScanResultContent(pinsActions: true)` 自己滚动，操作栏钉在底部，
/// 默认高度下主操作永远在拇指区。
struct ScanResultView: View {
    let content: ScanContent
    /// 刚扫到的结果（区别于从历史点进来的）。为 true 时播放入场动画并显示「已存历史」。
    var justScanned: Bool = false

    @Environment(\.dismiss) private var dismiss

    /// 出商店图时用 `LEITORQR_SHEET_LARGE=1` 直接以全高呈现：
    /// 默认的 64% 高度会让内容下方留一大片空白，放进商店图里像是页面没做完。
    @State private var detent: PresentationDetent = {
        #if DEBUG
        if DebugLaunchOptions.sheetLarge { return .large }
        #endif
        return .fraction(0.64)
    }()

    var body: some View {
        NavigationStack {
            ScanResultContent(content: content, justScanned: justScanned, canRescan: true, pinsActions: true)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .accessibilityLabel(L10n.Common.close)
                    }
                }
        }
        .presentationDetents([.fraction(0.64), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .modifier(ResultSheetBackground())
    }
}

/// 一张图片里识别到多个码时的选择列表。
struct ScanResultListView: View {
    let results: [ScanContent]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(results) { item in
                NavigationLink {
                    ScrollView {
                        ScanResultContent(content: item, canRescan: true)
                            .padding(.horizontal, Theme.Spacing.pageMargin)
                            .padding(.vertical, Theme.Spacing.m)
                    }
                    .screenBackground()
                    .navigationTitle(L10n.Result.title)
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        ContentTypeBadge(type: item.type, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayHost ?? item.type.localizedName)
                                .font(Theme.Typography.bodyEmphasis)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .lineLimit(1)
                            Text(item.summary)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xxs)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(L10n.Result.multipleTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                        .font(Theme.Typography.bodyEmphasis)
                }
            }
        }
        .presentationDetents([.large])
        .modifier(ResultSheetBackground())
    }
}

/// 结果 sheet 的底。iOS 26 起 sheet 自带液态玻璃，不能再铺不透明底（会把玻璃盖死）；
/// 低版本没有玻璃，铺一层页面底色，让白色卡片有层次。
private struct ResultSheetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.presentationBackground(Theme.Palette.background)
        }
    }
}

/// 结果正文：类型、内容、操作。历史和扫描共用。
struct ScanResultContent: View {
    let content: ScanContent
    /// 刚扫到的结果：在头部补一条「已存历史」，让"保存"这件事看得见，
    /// 而不是要用户自己切到 Histórico 去确认。
    var justScanned: Bool = false
    /// 旧参数，保留给调用点兼容。重构后不再有「重新扫描」按钮（下拉 / 关闭就是再扫一次）。
    var canRescan: Bool = false
    /// sheet 模式：正文自己滚动、操作栏钉在底部；inline 模式（历史详情 / 多码列表）：操作栏跟在正文后面。
    var pinsActions: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 入场：判定环从 0 画到 1，各段「对焦」进场。只在刚扫到时播放。
    @State private var entered = false
    @State private var ringProgress: CGFloat = 0

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptions: SubscriptionManager

    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?
    @State private var didCopyPassword = false
    @State private var copyPasswordTask: Task<Void, Never>?
    @State private var stampVisible = false
    @State private var isConnectingWiFi = false
    @State private var wifiAlert: WiFiJoinAlert?
    @State private var trustedHosts = RiskStore.whitelist

    /// 联系人 / 日程走系统编辑器。用枚举而不是两个 Bool：
    /// `sheet(isPresented:)` 里再判 `if let`，解析失败就会弹出一个空白 sheet。
    private enum ComposerSheet: Identifiable {
        case contact(ContactCard)
        case event(CalendarEvent)

        var id: String {
            switch self {
            case .contact(let card):
                return "contact-\(card.name)-\(card.phone)"
            case .event(let event):
                return "event-\(event.summary)-\(event.start?.timeIntervalSince1970 ?? 0)"
            }
        }
    }

    @State private var composer: ComposerSheet?
    /// 结果卡片里被复制的字段（IBAN / 加密地址）。共用一份状态，只允许一个高亮。
    @State private var copiedField: String?
    @State private var copyFieldTask: Task<Void, Never>?
    /// 结果页 PRO 提示已经露出的次数。只在前几次扫描时出现，之后彻底消失——
    /// 每次都弹就变成骚扰，和「不搞套路」的定位冲突。
    @AppStorage("scan.proHint.count") private var proHintCount = 0

    private var parsedWiFi: WiFiNetwork? {
        guard content.type == .wifi else { return nil }
        return WiFiNetwork.parse(content.rawValue)
    }

    private var parsedContact: ContactCard? {
        guard content.type == .contact else { return nil }
        return ContactCard.parse(content.rawValue)
    }

    private var parsedEvent: CalendarEvent? {
        guard content.type == .event else { return nil }
        return CalendarEvent.parse(content.rawValue)
    }

    /// 邮件码一律拆成收件人/主题/正文来显示。
    /// 之前只在这两项非空时才拆，结果 `mailto:a@b.pt` 会退回「内容: mailto:a@b.pt」——
    /// 明明能解析出收件人，没必要把协议头摊给用户看。
    private var parsedMail: MailMessage? {
        guard content.type == .email else { return nil }
        return MailMessage.parse(content.rawValue)
    }

    private var parsedPayment: SEPAPayment? {
        guard content.type == .payment else { return nil }
        return SEPAPayment.parse(content.rawValue)
    }

    private var parsedCrypto: CryptoPayment? {
        guard content.type == .crypto else { return nil }
        return CryptoPayment.parse(content.rawValue)
    }

    private func isTrusted(_ host: String?) -> Bool {
        guard let host else { return false }
        let lower = host.lowercased()
        return trustedHosts.contains { lower == $0 || lower.hasSuffix(".\($0)") }
    }

    /// 刚扫到且没开「减弱动态效果」才播入场；其余情况直接显示最终状态。
    private var animatesEntrance: Bool { justScanned && !reduceMotion }
    private var isEntered: Bool { entered || !animatesEntrance }

    var body: some View {
        Group {
            if pinsActions {
                ScrollView {
                    mainColumn
                        .padding(.horizontal, Theme.Spacing.pageMargin)
                        .padding(.top, Theme.Spacing.xxs)
                        .padding(.bottom, Theme.Spacing.l)
                }
                .scrollBounceBehavior(.basedOnSize)
                .modifier(
                    BottomActionBar {
                        actionBar
                            .padding(.horizontal, Theme.Spacing.pageMargin)
                            .padding(.top, Theme.Spacing.s)
                            .padding(.bottom, Theme.Spacing.xs)
                            .focusIn(3, active: isEntered, reduceMotion: reduceMotion)
                    }
                )
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    mainColumn
                    actionBar
                }
            }
        }
        .onAppear(perform: runEntrance)
        // 计数放在 onDisappear：放 onAppear 会在第 3 次扫描时把 count 顶到 3，
        // 触发 body 重算，提示当场闪一下就消失。
        .onDisappear {
            if justScanned && !subscriptions.isPremium {
                proHintCount += 1
            }
        }
        .alert(item: $wifiAlert) { alert in
            let message = alert.detail.map { Text($0) }
            if alert.opensSettings {
                return Alert(
                    title: Text(alert.title),
                    message: message,
                    primaryButton: .default(Text(L10n.Scanner.permissionOpenSettings)) { openSystemSettings() },
                    secondaryButton: .cancel(Text(L10n.Common.cancel))
                )
            }
            return Alert(title: Text(alert.title), message: message,
                         dismissButton: .default(Text(L10n.Common.ok)))
        }
        // 系统编辑器用一个枚举承载：`isPresented + if let` 在解析失败时会弹出空白 sheet。
        .sheet(item: $composer) { sheet in
            switch sheet {
            case .contact(let card):
                ContactComposer(card: card) { composer = nil }
                    .ignoresSafeArea()
            case .event(let event):
                EventComposer(event: event) { composer = nil }
                    .ignoresSafeArea()
            }
        }
        #if DEBUG
        // `LEITORQR_WIFI_ALERT=restricted|failed` 直接弹对应提示，用于验收文案
        // （simctl 点不了按钮，真实连接在模拟器上也没什么可连的）。
        // 必须延后一拍：alert 的 presentation 在视图刚挂载时还没就绪，同步赋值会被吞掉。
        .task {
            let demo = DebugLaunchOptions.wifiAlert
            guard demo == "restricted" || demo == "failed" else { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
            if demo == "restricted" {
                wifiAlert = WiFiJoinAlert(title: L10n.Result.wifiRestricted,
                                          detail: L10n.Result.wifiRestrictedDetail)
            } else {
                wifiAlert = WiFiJoinAlert(title: L10n.Result.wifiFailed,
                                          detail: L10n.Result.wifiFailedDetail)
            }
        }
        // 系统编辑器同样点不出来，这里直接拉起用于截图验收。
        .task {
            guard let compose = DebugLaunchOptions.autoCompose else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            switch compose {
            case "contact":
                if let card = parsedContact { composer = .contact(card) }
            case "event":
                if let event = parsedEvent { composer = .event(event) }
            default:
                break
            }
        }
        #endif
    }

    // MARK: - 正文

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            hero
                .focusIn(0, active: isEntered, reduceMotion: reduceMotion)

            // 网址先给判定细节，再给内容：quishing 防护的价值必须在第一屏被看见。
            if content.type == .url {
                riskCard
                    .focusIn(1, active: isEntered, reduceMotion: reduceMotion)
            }

            contentCard
                .focusIn(2, active: isEntered, reduceMotion: reduceMotion)

            if showsProHint {
                proHint
                    .focusIn(3, active: isEntered, reduceMotion: reduceMotion)
            }
        }
    }

    private func runEntrance() {
        guard animatesEntrance, !entered else { return }
        // sheet 正在升起：内容跟着「对焦」进场，判定环随后画完一圈。
        entered = true
        withAnimation(Theme.Motion.draw.delay(0.18)) {
            ringProgress = 1
        }
    }

    // MARK: - 头部（判定环 + 标题）

    /// 居中的头部：判定环里是类型图标，环的颜色就是结论（网址 = 风险等级，其余 = 类型色）；
    /// 下面一行元信息，再下面是最重要的那一句（域名 / Wi-Fi 名 / 姓名 / 日程标题…）。
    private var hero: some View {
        VStack(spacing: Theme.Spacing.s) {
            VerdictRing(
                type: content.type,
                ringColor: verdictColor,
                badgeSymbol: verdictBadge,
                progress: animatesEntrance ? ringProgress : 1
            )

            VStack(spacing: 6) {
                Text(metaLine)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(heroTitle)
                    .font(
                        content.type == .url
                            ? .system(size: 24, weight: .bold, design: .monospaced)
                            : .system(size: 26, weight: .bold)
                    )
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if justScanned {
                savedStamp
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xs)
    }

    /// 头部大标题：网址显示真实域名（等宽，quishing 的核心就是让人看清真实目标），其余用解析后的一句话。
    private var heroTitle: String {
        if content.type == .url, let host = content.displayHost { return host }
        let summary = content.readableSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? content.type.localizedName : summary
    }

    private var metaLine: String {
        [content.type.localizedName, content.barcodeFormat?.displayName, content.source.localizedName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// 网址的风险等级（白名单命中按低风险算）；其余类型为 nil。
    private var verdictLevel: QRRiskLevel? {
        guard content.type == .url, let url = content.openableURL else { return nil }
        return isTrusted(url.host) ? .low : QRRiskAnalyzer.analyze(url).level
    }

    private var verdictColor: Color {
        verdictLevel.map { riskFill($0) } ?? content.type.tint
    }

    private var verdictBadge: String? {
        switch verdictLevel {
        case .low?: return "checkmark.circle.fill"
        case .medium?: return "exclamationmark.circle.fill"
        case .high?: return "xmark.circle.fill"
        case nil: return nil
        }
    }

    /// 「已存历史」提示。带一点入场动画：稍晚出现、从上方落位，
    /// 让人感觉"刚刚存进去"，而不是页面上本来就印着一行字。
    private var savedStamp: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.success)
                    .frame(width: 14, height: 14)
                    .scaleEffect(stampVisible ? 1 : 0.4)
                CheckmarkMark(size: 8)
                    .foregroundStyle(Color.white)
            }
            Text(L10n.Result.savedToHistory)
        }
        .font(Theme.Typography.caption.weight(.medium))
        .foregroundStyle(Theme.Palette.successText)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, 5)
        .background(Theme.Palette.success.opacity(0.14), in: Capsule())
        .opacity(stampVisible ? 1 : 0)
        .offset(y: stampVisible ? 0 : -6)
        .onAppear {
            withAnimation(Theme.Motion.success.delay(0.15)) {
                stampVisible = true
            }
        }
    }

    private var contentCard: some View {
        Group {
            if let network = parsedWiFi {
                wifiCard(network)
            } else if let card = parsedContact {
                contactCard(card)
            } else if let event = parsedEvent {
                eventCard(event)
            } else if let payment = parsedPayment {
                paymentCard(payment)
            } else if let crypto = parsedCrypto {
                cryptoCard(crypto)
            } else if let mail = parsedMail {
                mailCard(mail)
            } else {
                genericContentCard
            }
        }
    }

    /// Wi-Fi 结果不能摊原始负载：`WIFI:T:WPA;S:…;P:…;;` 对用户等于乱码，
    /// 而且自动连接失败时（自签名没有 Hotspot 权限）他得靠这页的信息手动加入网络，
    /// 所以 SSID、密码、加密方式必须拆开逐行给出，密码还得能一键复制。
    private func wifiCard(_ network: WiFiNetwork) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "wifi")
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.Result.wifiInfoTitle)
                    .font(Theme.Typography.caption.weight(.semibold))
                Spacer(minLength: 0)
                if network.isHidden {
                    Text(L10n.Result.wifiHidden)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Palette.textSecondary.opacity(0.12), in: Capsule())
                }
            }
            .foregroundStyle(Theme.Palette.textSecondary)

            wifiRow(L10n.Result.wifiSSID, value: network.ssid)

            if !network.password.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(L10n.Result.wifiPassword)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .frame(width: 68, alignment: .leading)

                    Text(network.password)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: Theme.Spacing.xs)

                    Button {
                        // 密码来自二维码：不进跨设备接力、90 秒过期，避免被其他 App 捞走。
                        SensitivePasteboard.copy(network.password)
                        withAnimation(Theme.Motion.fade) { didCopyPassword = true }
                        copyPasswordTask?.cancel()
                        copyPasswordTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_400_000_000)
                            guard !Task.isCancelled else { return }
                            withAnimation(Theme.Motion.fade) { didCopyPassword = false }
                        }
                    } label: {
                        Image(systemName: didCopyPassword ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(didCopyPassword ? Theme.Palette.success : Theme.Palette.primary)
                            .frame(width: 28, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Result.wifiCopyPassword)
                }
            }

            wifiRow(L10n.Result.wifiSecurityLabel, value: wifiSecurityText(network.security))

            Text(L10n.Result.wifiManualHint)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .card()
    }

    private func wifiRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 68, alignment: .leading)

            Text(value)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func wifiSecurityText(_ security: WiFiNetwork.Security) -> String {
        switch security {
        case .wpa: return L10n.Create.wifiSecurityWPA
        case .wep: return L10n.Create.wifiSecurityWEP
        case .open: return L10n.Create.wifiSecurityNone
        case .enterprise: return "EAP"
        }
    }

    // MARK: - 结构化内容卡片（联系人 / 日程 / 转账 / 加密地址）

    /// 卡片标题行。`trailing` 用来放币种、金额这类短标记。
    private func cardHeader(_ title: String, symbol: String, trailing: String? = nil) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(Theme.Typography.caption.weight(.semibold))
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.Palette.textSecondary.opacity(0.12), in: Capsule())
            }
        }
        .foregroundStyle(Theme.Palette.textSecondary)
    }

    /// 字段用「标签在上、值在下」的竖排：`Beneficiário` / `Recipient` / `受益者` 长短
    /// 差得多，固定标签宽度在某个语言下必然被挤断。
    private func infoField(
        _ title: String,
        value: String,
        monospaced: Bool = false,
        copyKey: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(value)
                    .font(monospaced ? .system(.body, design: .monospaced) : Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if let copyKey {
                    copyFieldButton(key: copyKey, value: value)
                }
            }
        }
    }

    private func copyFieldButton(key: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            withAnimation(Theme.Motion.fade) { copiedField = key }
            copyFieldTask?.cancel()
            copyFieldTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(Theme.Motion.fade) { copiedField = nil }
            }
        } label: {
            Image(systemName: copiedField == key ? "checkmark" : "doc.on.doc")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(copiedField == key ? Theme.Palette.success : Theme.Palette.primary)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Result.copy)
    }

    /// 联系人：先把「这是谁」摊清楚。加通讯录是写入操作，必须让用户看完再决定。
    private func contactCard(_ card: ContactCard) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            cardHeader(L10n.Result.contactTitle, symbol: "person.crop.circle")

            if !card.name.isEmpty {
                infoField(L10n.Result.contactName, value: card.name)
            }
            if !card.phone.isEmpty {
                infoField(L10n.Result.contactPhone, value: card.phone, monospaced: true)
            }
            if !card.email.isEmpty {
                infoField(L10n.Result.contactEmail, value: card.email)
            }
            if !card.organization.isEmpty {
                infoField(L10n.Result.contactOrg, value: card.organization)
            }
        }
        .card()
    }

    /// 日程：时间必须写清楚，用户点「加入日历」前得知道会不会冲突。
    private func eventCard(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            cardHeader(L10n.Result.eventTitle, symbol: "calendar")

            infoField(L10n.Result.eventSummary, value: event.summary)

            if let start = event.start {
                infoField(L10n.Result.eventStart, value: dateText(start))
            }
            if let end = event.end {
                infoField(L10n.Result.eventEnd, value: dateText(end))
            }
            if !event.location.isEmpty {
                infoField(L10n.Result.eventLocationField, value: event.location)
            }
        }
        .card()
    }

    /// 欧洲账单付款码。iOS 起不了 SEPA 转账（没有开放银行接口），
    /// 这页的实际用途是「把 IBAN / 金额 / 参考号抄进手机银行」，所以字段要可复制。
    private func paymentCard(_ payment: SEPAPayment) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            cardHeader(L10n.Result.paymentTitle, symbol: "eurosign.circle",
                       trailing: payment.displayAmount.isEmpty ? nil : payment.displayAmount)

            if !payment.recipient.isEmpty {
                infoField(L10n.Result.paymentRecipient, value: payment.recipient)
            }
            infoField(L10n.Result.paymentIBAN, value: payment.iban,
                      monospaced: true, copyKey: "iban")
            if !payment.bic.isEmpty {
                infoField(L10n.Result.paymentBIC, value: payment.bic, monospaced: true)
            }
            if !payment.reference.isEmpty {
                infoField(L10n.Result.paymentReference, value: payment.reference)
            }

            Text(L10n.Result.paymentNote)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .card()
    }

    /// 加密地址：地址长且不可逆，抄错一位钱就没了，所以整段等宽展示 + 一键复制。
    private func cryptoCard(_ crypto: CryptoPayment) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            cardHeader(L10n.Result.cryptoTitle, symbol: "bitcoinsign.circle",
                       trailing: crypto.currencyName)

            infoField(L10n.Result.cryptoAddress, value: crypto.address,
                      monospaced: true, copyKey: "address")

            if !crypto.amount.isEmpty {
                infoField(L10n.Result.cryptoAmount, value: crypto.amount)
            }
        }
        .card()
    }

    /// 邮件码：收件人 / 主题 / 正文。正文可能很长，允许换行。
    private func mailCard(_ mail: MailMessage) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            cardHeader(L10n.Result.mailTitle, symbol: "envelope")

            infoField(L10n.Result.mailTo, value: mail.recipient)
            if !mail.subject.isEmpty {
                infoField(L10n.Result.mailSubject, value: mail.subject)
            }
            if !mail.body.isEmpty {
                infoField(L10n.Result.mailBody, value: mail.body)
            }
        }
        .card()
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var genericContentCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(L10n.Result.contentLabel)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)

            Text(content.rawValue)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if let host = content.displayHost, host != content.rawValue {
                Text(host)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .card()
    }

    /// 端侧链接特征核对。只提示值得核对的点，不拦截、不判定安全。
    /// 真实域名用等宽大字突出——quishing 的核心就是让人看不清实际目标。
    /// 判定用整块浅色铺底（安全=薄荷、待核对=琥珀、风险=红），一眼就能分出三态。
    private var riskCard: some View {
        let assessment = content.openableURL.map { QRRiskAnalyzer.analyze($0) }
        return Group {
            if let url = content.openableURL, let assessment {
                let trusted = isTrusted(url.host)
                let tone = trusted ? QRRiskLevel.low : assessment.level
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack(alignment: .center, spacing: Theme.Spacing.xs) {
                        Image(systemName: trusted ? "checkmark.shield.fill" : riskSymbol(assessment.level))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(riskColor(tone))
                            .symbolEffect(.bounce, value: trusted)
                        Text(L10n.Result.riskTitle)
                            .font(Theme.Typography.bodyEmphasis)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer(minLength: 0)
                        Text(trusted ? L10n.Result.riskTrusted : riskLabel(assessment.level))
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(riskColor(tone))
                            .contentTransition(.opacity)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, Theme.Spacing.xxs)
                            .background(riskFill(tone).opacity(0.18), in: Capsule())
                    }

                    if trusted {
                        Text(L10n.Result.riskTrustedDetail)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    } else if assessment.findings.isEmpty {
                        Text(L10n.Result.riskNone)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            ForEach(assessment.findings.prefix(4), id: \.key) { finding in
                                HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                    Circle()
                                        .fill(riskFill(finding.level))
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 5)
                                    Text(finding.localized)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Palette.textPrimary.opacity(0.82))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // 加白名单：仅 PRO。用户主动点开付费墙，不受冷却期限制。
                    if !trusted, let host = url.host {                        Button {
                            if subscriptions.isPremium {
                                withAnimation(Theme.Motion.smooth) { addToWhitelist(host) }
                            } else {
                                PaywallTriggerManager.shared.triggerFeatureGate("security.whitelist")
                            }
                        } label: {
                            Label(whitelistActionLabel, systemImage: "checkmark.shield")
                                .font(Theme.Typography.caption.weight(.semibold))
                        }
                        .buttonStyle(TextButtonStyle())
                    }

                    Text(L10n.Result.riskDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    riskFill(tone).opacity(0.11),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(riskFill(tone).opacity(0.22), lineWidth: 1)
                )
                .animation(Theme.Motion.smooth, value: trusted)
                .sensoryFeedback(.success, trigger: trusted) { _, new in new }
                .task(id: url.absoluteString) {
                    // 每次展示结果页记一条核对历史；白名单命中也要记，便于回溯。
                    RiskStore.record(assessment: assessment, url: url, in: modelContext)
                }
            }
        }
    }

    /// 高风险且未信任的网址：主按钮降级成危险色描边，不再用实心主色诱导点击。
    private var isHighRiskURL: Bool {
        guard let url = content.openableURL, !isTrusted(url.host) else { return false }
        return QRRiskAnalyzer.analyze(url).level == .high
    }

    private func addToWhitelist(_ host: String) {
        guard RiskStore.addToWhitelist(host) else { return }
        trustedHosts = RiskStore.whitelist
    }

    /// 「加入信任」按钮的文案。
    ///
    /// 资产里这条串自带 `(PRO)` 后缀（用来告诉免费用户这是付费功能），
    /// 但已购用户看到的是「（付费功能标记）」，读起来像功能还没解锁。
    /// `PRO` 是品牌词、所有语言都保持原文，所以直接按括号切掉是安全的；
    /// 免费用户仍然看到完整标注。
    private var whitelistActionLabel: String {
        let full = L10n.Result.riskAddWhitelist
        guard subscriptions.isPremium else { return full }
        return full.replacingOccurrences(
            of: #"\s*[（(]\s*PRO\s*[）)]"#,
            with: "",
            options: .regularExpression
        )
    }

    /// 文字 / 图标用的风险色（安全态用对比度足够的 successText）。
    private func riskColor(_ level: QRRiskLevel) -> Color {
        switch level {
        case .low: return Theme.Palette.successText
        case .medium: return Theme.Palette.warning
        case .high: return Theme.Palette.error
        }
    }

    /// 铺底 / 圆点用的风险色。
    private func riskFill(_ level: QRRiskLevel) -> Color {
        switch level {
        case .low: return Theme.Palette.success
        case .medium: return Theme.Palette.warning
        case .high: return Theme.Palette.error
        }
    }

    private func riskLabel(_ level: QRRiskLevel) -> String {
        switch level {
        case .low: return L10n.Result.riskLow
        case .medium: return L10n.Result.riskMedium
        case .high: return L10n.Result.riskHigh
        }
    }

    private func riskSymbol(_ level: QRRiskLevel) -> String {
        switch level {
        case .low: return "shield.checkered"
        case .medium: return "exclamationmark.shield"
        case .high: return "exclamationmark.shield.fill"
        }
    }

    /// Day 0 软钩子。
    ///
    /// RevenueCat 2026 的数据：89.4% 的试用启动发生在安装当天，当天没开始就基本不再回来。
    /// 而原本的付费墙要等「历史满 10 条」才出现，绝大多数用户一辈子见不到。
    /// 这里在**刚扫完的结果页**补一条提示：不拦截、不倒计时、不遮挡任何按钮，
    /// 用户点不点都能继续用——硬付费墙转化是 freemium 的 5 倍，但那是另一门生意。
    private var proHint: some View {
        Button {
            PaywallTriggerManager.shared.triggerFeatureGate("result.proHint")
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(width: 26, height: 26)
                    .background(Theme.Palette.primary.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.Result.proHintTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(L10n.Result.proHintBody)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Theme.Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.Palette.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                    .strokeBorder(Theme.Palette.primary.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.Result.proHintCTA)
    }

    /// 只在前 3 次「扫描后弹出的结果页」露出，历史详情里不出现。
    private var showsProHint: Bool {
        justScanned && !subscriptions.isPremium && proHintCount < 3
    }

    // MARK: - 操作栏

    /// 一个按内容类型变化的主操作。
    private struct ResultAction: Identifiable {
        let id: String
        let title: String
        let symbol: String
        var isCaution = false
        var isBusy = false
        let perform: () -> Void
    }

    /// 本条内容可用的主操作，按重要性排序。第一个做成大按钮，其余收进左侧的玻璃圆钮。
    private var primaryActions: [ResultAction] {
        var list: [ResultAction] = []
        if let url = content.openableURL {
            list.append(ResultAction(
                id: "open",
                title: L10n.Result.openExternal,
                symbol: isHighRiskURL ? "exclamationmark.triangle" : "safari",
                isCaution: isHighRiskURL
            ) { openExternally(url) })
        }
        if let network = parsedWiFi {
            list.append(ResultAction(
                id: "wifi",
                title: isConnectingWiFi ? L10n.Result.wifiConnecting : L10n.Result.wifiConnect,
                symbol: "wifi",
                isBusy: isConnectingWiFi
            ) { Task { await connect(network) } })
        }
        if let action = content.externalAction {
            list.append(ResultAction(id: "external", title: action.title, symbol: action.symbol) {
                openExternally(action)
            })
        }
        if let card = parsedContact {
            list.append(ResultAction(id: "contact", title: L10n.Result.contactAdd, symbol: "person.crop.circle.badge.plus") {
                addContact(card)
            })
        }
        if let event = parsedEvent {
            list.append(ResultAction(id: "event", title: L10n.Result.eventAdd, symbol: "calendar.badge.plus") {
                addEvent(event)
            })
        }
        if let crypto = parsedCrypto {
            list.append(ResultAction(id: "wallet", title: L10n.Result.cryptoOpenWallet, symbol: "wallet.pass") {
                openWallet(crypto)
            })
        }
        return list
    }

    /// 左边一排玻璃圆钮（其余操作 · 复制 · 分享），右边一颗撑满的主按钮。
    /// 纯文本 / 条码没有主操作时，「复制」升为主按钮。
    private var actionBar: some View {
        let actions = primaryActions
        let main = actions.first
        let extras = actions.dropFirst()

        // 同一排的玻璃钮放进一个 GlassEffectContainer：系统统一计算折射，
        // 「复制 → 已复制」这类形状变化时相邻玻璃会自然融合 / 分离（Liquid Glass 的原生形变）。
        return GlassGroup(spacing: 10) {
        HStack(spacing: 10) {
            ForEach(Array(extras)) { action in
                circleButton(symbol: action.symbol, label: action.title, action: action.perform)
            }

            if main != nil {
                circleButton(
                    symbol: didCopy ? "checkmark" : "doc.on.doc",
                    label: didCopy ? L10n.Result.copied : L10n.Result.copy,
                    highlighted: didCopy,
                    action: copyValue
                )
            }

            ShareLink(item: content.rawValue) {
                circleIcon(symbol: "square.and.arrow.up", highlighted: false)
            }
            .modifier(GlassCircleStyle())
            .accessibilityLabel(L10n.Result.share)

            if let main {
                mainButton(main)
            } else {
                mainButton(ResultAction(
                    id: "copy",
                    title: didCopy ? L10n.Result.copied : L10n.Result.copy,
                    symbol: didCopy ? "checkmark" : "doc.on.doc"
                ) { copyValue() })
            }
        }
        }
        .sensoryFeedback(.success, trigger: didCopy) { _, new in new }
        .animation(Theme.Motion.snappy, value: didCopy)
        .animation(Theme.Motion.snappy, value: isConnectingWiFi)
    }

    private func mainButton(_ action: ResultAction) -> some View {
        Button(action: action.perform) {
            HStack(spacing: 8) {
                if action.isBusy {
                    ProgressView().tint(action.isCaution ? Theme.Palette.error : .white)
                } else {
                    Image(systemName: action.symbol)
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(action.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .contentTransition(.opacity)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 30)
            .contentShape(Capsule())
        }
        .modifier(MainActionStyle(isCaution: action.isCaution))
        .disabled(action.isBusy)
    }

    private func circleButton(
        symbol: String,
        label: String,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            circleIcon(symbol: symbol, highlighted: highlighted)
        }
        .modifier(GlassCircleStyle())
        .accessibilityLabel(label)
    }

    private func circleIcon(symbol: String, highlighted: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(highlighted ? Theme.Palette.successText : Theme.Palette.textPrimary)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 30, height: 30)
            .contentShape(Circle())
    }

    private func openExternally(_ url: URL) {
        guard UIApplication.shared.canOpenURL(url) else {
            wifiAlert = WiFiJoinAlert(title: L10n.Result.actionFailed,
                                      detail: L10n.Result.actionFailedDetail)
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            guard !success else { return }
            Task { @MainActor in
                wifiAlert = WiFiJoinAlert(title: L10n.Result.actionFailed,
                                          detail: L10n.Result.actionFailedDetail)
            }
        }
    }

    private func openExternally(_ action: ScanExternalAction) {
        openExternally(action.url)
    }

    /// 加密钱包的 scheme（`bitcoin:` 等）不在 `LSApplicationQueriesSchemes` 里，
    /// `canOpenURL` 一律返回 false，所以这里**不能**先探测，只能直接 open 再处理失败。
    private func openWallet(_ crypto: CryptoPayment) {
        // 走 openURI：剥掉 r=/req-* 参数，别让钱包去拉攻击者可控的支付请求 URL。
        guard let url = crypto.openURI else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            guard !success else { return }
            Task { @MainActor in
                wifiAlert = WiFiJoinAlert(title: L10n.Result.actionFailed,
                                          detail: L10n.Result.actionFailedDetail)
            }
        }
    }

    // 两个 add 都要标 @MainActor：`Task { }` 继承创建时的 actor 上下文，
    // 方法不加隔离的话，`await` 回来再改 @State 就不保证在主线程上。
    @MainActor
    private func addContact(_ card: ContactCard) {
        Task {
            guard await ContactAccess.request() else {
                wifiAlert = WiFiJoinAlert(title: L10n.Result.contactAccessDenied,
                                          detail: L10n.Result.contactAccessDeniedDetail,
                                          opensSettings: true)
                return
            }
            composer = .contact(card)
        }
    }

    @MainActor
    private func addEvent(_ event: CalendarEvent) {
        Task {
            guard await CalendarAccess.requestWriteOnly() else {
                wifiAlert = WiFiJoinAlert(title: L10n.Result.eventAccessDenied,
                                          detail: L10n.Result.eventAccessDeniedDetail,
                                          opensSettings: true)
                return
            }
            composer = .event(event)
        }
    }

    /// 权限被拒时唯一的出路就是系统设置。少了这个按钮，用户只能自己去找。
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func connect(_ network: WiFiNetwork) async {
        isConnectingWiFi = true
        defer { isConnectingWiFi = false }
        let result = await WiFiConnector.join(network)
        switch result {
        case .joined:
            wifiAlert = WiFiJoinAlert(title: L10n.Result.wifiJoined,
                                      detail: String(format: L10n.Result.wifiJoinedDetail, network.ssid))
        case .userDenied:
            wifiAlert = WiFiJoinAlert(title: L10n.Result.wifiDenied,
                                      detail: L10n.Result.wifiDeniedDetail)
        case .invalidCredentials:
            wifiAlert = WiFiJoinAlert(title: L10n.Result.wifiFailed,
                                      detail: L10n.Result.wifiInvalidDetail)
        case .unsupported:
            wifiAlert = WiFiJoinAlert(title: L10n.Result.wifiUnsupported,
                                      detail: L10n.Result.wifiUnsupportedDetail)
        case .notPermitted:
            // 自签名 / 个人账号没有 Hotspot Configuration 权限。
            // 别报「请检查网络是否在范围内」——网络可能就在手边，是 App 连不了。
            wifiAlert = WiFiJoinAlert(title: L10n.Result.wifiRestricted,
                                      detail: L10n.Result.wifiRestrictedDetail)
        case .failed:
            wifiAlert = WiFiJoinAlert(title: L10n.Result.wifiFailed,
                                      detail: L10n.Result.wifiFailedDetail)
        }
    }

    private func copyValue() {
        // Wi-Fi 码的原文里带密码，走敏感剪贴板；其余内容保留普通复制的跨设备接力。
        if content.type == .wifi {
            SensitivePasteboard.copy(content.rawValue)
        } else {
            UIPasteboard.general.string = content.rawValue
        }
        withAnimation(Theme.Motion.fade) { didCopy = true }

        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Theme.Motion.fade) { didCopy = false }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

// MARK: - 判定环

/// 头部的判定环：圆形类型图标外面一圈环，入场时从 12 点钟方向画满一圈；
/// 画满的那一刻图标弹一下，网址类型右下角再弹出结论角标（✓ / ! / ×）。
/// 环的颜色就是结论：网址按风险等级（薄荷 / 琥珀 / 红），其余类型用类型色。
private struct VerdictRing: View {
    let type: ScanContentType
    let ringColor: Color
    let badgeSymbol: String?
    let progress: CGFloat

    private var isComplete: Bool { progress >= 1 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.16), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(type.tint.opacity(0.14))
                .padding(9)
            Image(systemName: type.icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(type.tint)
                .symbolEffect(.bounce, value: isComplete)
        }
        .frame(width: 80, height: 80)
        .overlay(alignment: .bottomTrailing) {
            if let badgeSymbol, isComplete {
                Image(systemName: badgeSymbol)
                    .font(.system(size: 22, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, ringColor)
                    .offset(x: 2, y: 2)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.success, value: isComplete)
        .accessibilityHidden(true)
    }
}

// MARK: - 对焦式入场

/// 「对焦」入场：从轻微模糊、略小、略低的位置变清晰，像镜头对上焦。按序号错开 70ms。
/// 减弱动态效果时只做淡入。
private struct FocusIn: ViewModifier {
    let index: Int
    let active: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(active ? 1 : 0)
            .blur(radius: active || reduceMotion ? 0 : 8)
            .scaleEffect(active || reduceMotion ? 1 : 0.97, anchor: .top)
            .offset(y: active || reduceMotion ? 0 : 12)
            .animation(
                Theme.Motion.resolve(Theme.Motion.smooth, reduceMotion: reduceMotion)
                    .delay(reduceMotion ? 0 : 0.06 + Double(index) * 0.07),
                value: active
            )
    }
}

private extension View {
    func focusIn(_ index: Int, active: Bool, reduceMotion: Bool) -> some View {
        modifier(FocusIn(index: index, active: active, reduceMotion: reduceMotion))
    }
}

// MARK: - 操作栏样式

/// 主按钮：iOS 26 用系统 `.glassProminent`（品牌蓝液态玻璃，原生按压形变）；高风险或低版本用实心 / 描边胶囊。
private struct MainActionStyle: ViewModifier {
    let isCaution: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !isCaution {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Theme.Palette.primaryFill)
                // `.glassProminent` 在深色模式会把前景压成次级灰，显式白色。
                .foregroundStyle(.white)
        } else {
            content.buttonStyle(PrimaryButtonStyle(isCaution: isCaution))
        }
    }
}

/// 钉在底部的操作栏。iOS 26 用系统 `safeAreaBar`：滚动内容经过时自带原生的 scroll edge 柔化，
/// 不需要自己垫渐变；iOS 17–25 用 `safeAreaInset` + 系统材质底。
private struct BottomActionBar<Bar: View>: ViewModifier {
    @ViewBuilder var bar: () -> Bar

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .bottom, spacing: 0) { bar() }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                bar().background(.bar)
            }
        }
    }
}

/// 圆形玻璃按钮：iOS 26 用系统 `.glass` 按钮样式 + 圆形边框（原生液态玻璃、原生按压形变）；
/// 低版本退回材质圆钮。`.controlSize(.large)` 让圆钮约 54pt，和主按钮等高。
private struct GlassCircleStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
        } else {
            content
                .padding(12)
                .buttonStyle(PressableButtonStyle(scale: 0.9))
                .glassSurface(.circle, interactive: true)
        }
    }
}

/// 结果页的图标次要操作：圆形凹陷底 + 图标 + 小字。复制成功时图标原地替换成对勾并染成薄荷绿。
struct ResultActionIcon: View {
    let systemImage: String
    let title: String
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isHighlighted ? Theme.Palette.successText : Theme.Palette.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 52, height: 52)
                .background(
                    Circle().fill(isHighlighted ? Theme.Palette.success.opacity(0.16) : Theme.Palette.surfaceSunken)
                )
                .overlay(Circle().strokeBorder(Theme.Palette.border.opacity(isHighlighted ? 0 : 1), lineWidth: 1))
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Palette.textSecondary)
                .contentTransition(.opacity)
                .lineLimit(1)
        }
        .frame(minWidth: 64)
        .contentShape(Rectangle())
        .animation(Theme.Motion.snappy, value: isHighlighted)
    }
}

/// 连接结果弹窗。成功时带 SSID，失败时给出可执行的下一步。
struct WiFiJoinAlert: Identifiable {
    let id = UUID()
    let title: String
    let detail: String?
    /// 权限类提示额外给一个「打开设置」入口，普通提示只留 OK。
    var opensSettings: Bool = false
}

#Preview {
    ScanResultView(
        content: ScanContent(
            rawValue: "https://exemplo.pt/menu",
            barcodeFormat: .qrCode,
            source: .camera
        )
    )
}
