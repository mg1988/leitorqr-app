import SwiftData
import SwiftUI
import UIKit

/// 历史记录日期分组模型
struct HistoryDateSection: Identifiable {
    let id: String
    let title: String
    let records: [ScanRecord]
}

/// 历史记录视图。
///
/// 2026-11-27 重设计：
/// - 搜索框下方一排**类型筛选芯片**（选中块 matchedGeometry 滑动），排序 / 来源仍在右上角菜单。
/// - 列表改用 `List`：之前 `LazyVStack` 上挂的 `.swipeActions` 根本不生效（只有 List 行支持），
///   换成 List 后左滑删除、右滑复制都是系统手感，增删也有原生行动画；分组表头吸顶。
/// - 按「今天 / 昨天 / 本周 / 更早」分组。
/// - 删除改为**可撤销**：先从列表里隐藏（软删除），底部玻璃提示 4 秒内可撤销，到期才真正落库；
///   离开页面或进入后台时立即提交，不会留下悬空状态。
/// - 顶部 hero 卡片（11-27）：总数 + 扫描 / 生成 / 本周三项统计 + 右侧玻璃插画；免费用户带配额条和升级按钮，
///   替代原来列表底部的配额卡。纯色底、不用渐变；搜索 / 批量选择时收起。筛选芯片移进列表，跟着一起滚。
/// - 升级入口统一走全局付费墙（`PaywallTriggerManager`），不再在导航栈里 push 付费墙。
struct HistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var subscriptions: SubscriptionManager

    @Query(sort: \ScanRecord.createdAt, order: .reverse)
    private var records: [ScanRecord]

    @Namespace private var heroNamespace
    @Namespace private var chipNamespace
    @State private var selected: ScanRecord?
    @State private var showClearConfirm = false
    @State private var showAddSheet = false

    // 批量选择：共享 Set<UUID>，卡片只负责渲染勾选态，删除动作集中在页面里。
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    // 搜索、排序与过滤状态
    @State private var searchText = ""
    @State private var selectedFilter: HistoryCategoryFilter = .all
    @State private var selectedSort: HistorySortOption = .newest
    @State private var selectedSource: HistorySourceFilter = .all

    // 可撤销删除：先隐藏，计时结束再落库。
    @State private var pendingDeletion: Set<UUID> = []
    @State private var commitTask: Task<Void, Never>?
    @State private var toast: HistoryToast?
    @State private var toastTask: Task<Void, Never>?


    /// 来源筛选在菜单里，激活时用指示条提示；类型筛选有常驻芯片，不再重复提示。
    private var isSourceFiltered: Bool {
        selectedSource != .all
    }

    /// 排除软删除中的记录后的全部记录。
    private var liveRecords: [ScanRecord] {
        pendingDeletion.isEmpty ? records : records.filter { !pendingDeletion.contains($0.id) }
    }

    /// 免费版最多展示 10 条（Premium 不限）
    private var visibleRecords: [ScanRecord] {
        #if DEBUG
        if DebugLaunchOptions.historyEmpty { return [] }
        #endif
        let live = liveRecords
        return subscriptions.isPremium ? live : Array(live.prefix(HistoryStore.freeLimit))
    }

    /// 根据搜索词、来源、分类及排序综合处理后的记录列表
    private var filteredRecords: [ScanRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = visibleRecords.filter { record in
            guard selectedFilter.matches(record) else { return false }
            guard selectedSource.matches(record) else { return false }
            guard !query.isEmpty else { return true }

            return record.rawValue.lowercased().contains(query)
                || (record.note?.lowercased().contains(query) ?? false)
                || record.displayTitle.lowercased().contains(query)
                || record.displaySubtitle.lowercased().contains(query)
                || record.contentType.localizedName.lowercased().contains(query)
                || (record.barcodeFormat?.displayName.lowercased().contains(query) ?? false)
        }

        return filtered.sorted { a, b in
            switch selectedSort {
            case .newest:
                return a.createdAt > b.createdAt
            case .oldest:
                return a.createdAt < b.createdAt
            case .title:
                let titleA = a.trimmedNote ?? a.displayTitle
                let titleB = b.trimmedNote ?? b.displayTitle
                return titleA.localizedCaseInsensitiveCompare(titleB) == .orderedAscending
            case .format:
                let formatA = badgeText(for: a)
                let formatB = badgeText(for: b)
                return formatA.localizedCaseInsensitiveCompare(formatB) == .orderedAscending
            }
        }
    }

    /// 按时间自然分组（今天、昨天、本周、更早）；若按名称/格式排序则单一平铺。
    private var groupedSections: [HistoryDateSection] {
        guard selectedSort == .newest || selectedSort == .oldest else {
            return [HistoryDateSection(id: "all", title: "", records: filteredRecords)]
        }

        let calendar = Calendar.current
        let now = Date()
        var buckets: [String: [ScanRecord]] = [:]
        var order: [String] = []

        for record in filteredRecords {
            let key: String
            if calendar.isDateInToday(record.createdAt) {
                key = "today"
            } else if calendar.isDateInYesterday(record.createdAt) {
                key = "yesterday"
            } else if calendar.isDate(record.createdAt, equalTo: now, toGranularity: .weekOfYear) {
                key = "week"
            } else {
                key = "earlier"
            }
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(record)
        }

        return order.map { key in
            let title: String
            switch key {
            case "today": title = L10n.History.sectionToday
            case "yesterday": title = L10n.History.sectionYesterday
            case "week": title = L10n.History.sectionThisWeek
            default: title = L10n.History.sectionEarlier
            }
            return HistoryDateSection(id: key, title: title, records: buckets[key] ?? [])
        }
    }

    /// 搜索和批量选择时收起 hero，把空间让给结果。
    private var showsHero: Bool {
        searchText.isEmpty && !isSelecting
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleRecords.isEmpty {
                    // 空状态快捷入口：接上已实现的手工录入弹窗，别让按钮点了没反应。
                    HistoryEmptyPlaceholderView {
                        showAddSheet = true
                    }
                    .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        if isSourceFiltered {
                            activeFilterIndicator
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if isSelecting {
                            selectionBar
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if filteredRecords.isEmpty && !searchText.isEmpty {
                            SearchEmptyStateView(query: searchText) {
                                searchText = ""
                            }
                        } else {
                            cardFeed
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Theme.Palette.background.ignoresSafeArea() }
            .overlay(alignment: .bottom) { toastOverlay }
            .animation(motion(Theme.Motion.smooth), value: isSelecting)
            .animation(motion(Theme.Motion.smooth), value: isSourceFiltered)
            .animation(motion(Theme.Motion.smooth), value: showsHero)
            .navigationTitle(L10n.History.title)
            .searchable(text: $searchText, prompt: L10n.History.searchPrompt)
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L10n.History.selectDone) { exitSelectionMode() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.History.selectDelete, role: .destructive) {
                            deleteSelected()
                        }
                        .disabled(selectedIDs.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProCrownButton()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        menuButton
                    }
                }
            }
            .alert(L10n.History.clearTitle, isPresented: $showClearConfirm) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Common.delete, role: .destructive) {
                    commitPendingDeletion()
                    withAnimation(motion(Theme.Motion.smooth)) {
                        HistoryStore.clearAll(in: modelContext)
                    }
                }
            } message: {
                Text(L10n.History.clearMessage)
            }
            .navigationDestination(item: $selected) { record in
                destinationView(for: record)
            }
            .sheet(isPresented: $showAddSheet) {
                AddHistoryRecordSheet()
            }
            .sensoryFeedback(.selection, trigger: selectedFilter)
            .onChange(of: records.count) { _, _ in
                openDetailIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                // 进入后台前把待删除的落库：用户可能就此杀掉 App。
                if phase != .active { commitPendingDeletion() }
            }
            .onAppear {
                seedIfNeeded()
                seedGeneratedIfNeeded()
                openDetailIfNeeded()
                applyDebugOptions()
            }
            .onDisappear {
                commitPendingDeletion()
            }
        }
    }

    private func motion(_ animation: Animation) -> Animation {
        Theme.Motion.resolve(animation, reduceMotion: reduceMotion)
    }

    // MARK: - 类型筛选芯片

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(HistoryCategoryFilter.allCases) { filter in
                    let isOn = selectedFilter == filter
                    Button {
                        withAnimation(motion(Theme.Motion.snappy)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let tint = filter.tint {
                                Circle()
                                    .fill(isOn ? Theme.Palette.background : tint)
                                    .frame(width: 7, height: 7)
                            }
                            Text(filter.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isOn ? Theme.Palette.background : Theme.Palette.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background {
                            if isOn {
                                Capsule(style: .continuous)
                                    .fill(Theme.Palette.textPrimary)
                                    .matchedGeometryEffect(id: "chip.selection", in: chipNamespace)
                            } else {
                                Capsule(style: .continuous)
                                    .fill(Theme.Palette.surface)
                                    .overlay(Capsule(style: .continuous).strokeBorder(Theme.Palette.border, lineWidth: 1))
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .scrollClipDisabled()
    }

    private var filterEmptyState: some View {
        EmptyStateView(
            title: L10n.History.searchEmptyTitle,
            message: selectedFilter.title,
            actionTitle: L10n.History.clearFilter,
            action: {
                withAnimation(motion(Theme.Motion.snappy)) {
                    selectedFilter = .all
                    selectedSource = .all
                }
            }
        ) {
            Image(systemName: selectedFilter.icon)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .transition(.opacity)
    }

    // MARK: - 导航栏右上角极简原生菜单

    private var menuButton: some View {
        Menu {
            // 排序选项
            Section(L10n.History.menuSortTitle) {
                Picker(L10n.History.menuSortTitle, selection: $selectedSort.animation(motion(Theme.Motion.smooth))) {
                    ForEach(HistorySortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            // 来源筛选（类型筛选已经是常驻芯片）
            Section(L10n.History.sourceFilterTitle) {
                Picker(L10n.History.sourceFilterTitle, selection: $selectedSource.animation(motion(Theme.Motion.smooth))) {
                    ForEach(HistorySourceFilter.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
            }

            // 批量选择：进入后卡片左侧出现勾选圈，右上角换成「完成 / 删除所选」。
            if !visibleRecords.isEmpty {
                Section {
                    Button {
                        enterSelectionMode()
                    } label: {
                        Label(L10n.History.selectTitle, systemImage: "checkmark.circle")
                    }
                }
            }

            // 清空全部（仅在有记录时可用；不可撤销，保留二次确认）
            if !visibleRecords.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label(L10n.History.clear, systemImage: "trash")
                    }
                }
            }
        } label: {
            // 与旁边 3D 银色皇冠统一到同一灰阶；来源筛选激活时用主色提示状态。
            Image(systemName: isSourceFiltered ? "line.3.horizontal.decrease.circle.fill" : "ellipsis.circle")
                .font(.system(size: 19))
                .foregroundStyle(isSourceFiltered ? Theme.Palette.primary : Theme.Palette.textSecondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(L10n.History.sortMenuTitle)
    }

    // MARK: - 批量选择

    private var selectionBar: some View {
        HStack(spacing: 8) {
            Text(L10n.History.selectCount(selectedIDs.count))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.primary)
                .contentTransition(.numericText())

            Spacer()

            Button {
                let allIDs = Set(filteredRecords.map(\.id))
                withAnimation(motion(Theme.Motion.snappy)) {
                    selectedIDs = selectedIDs.count == allIDs.count ? [] : allIDs
                }
            } label: {
                Text(selectedIDs.count == filteredRecords.count && !filteredRecords.isEmpty
                     ? L10n.History.selectNone : L10n.History.selectAll)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.Palette.primarySoft))
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.vertical, 6)
    }

    private func enterSelectionMode() {
        withAnimation(motion(Theme.Motion.smooth)) {
            isSelecting = true
            selectedIDs = []
        }
    }

    private func exitSelectionMode() {
        withAnimation(motion(Theme.Motion.smooth)) {
            isSelecting = false
            selectedIDs = []
        }
    }

    private func toggleSelection(_ record: ScanRecord) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(motion(Theme.Motion.snappy)) {
            if selectedIDs.contains(record.id) {
                selectedIDs.remove(record.id)
            } else {
                selectedIDs.insert(record.id)
            }
        }
    }

    // MARK: - 可撤销删除

    private func deleteRecord(_ record: ScanRecord) {
        scheduleDeletion([record.id])
    }

    private func deleteSelected() {
        let ids = selectedIDs
        guard !ids.isEmpty else { return }
        scheduleDeletion(ids)
        exitSelectionMode()
    }

    /// 先从列表里隐藏，4 秒后落库。连续删除会合并成一批、重新计时，提示里的数字跟着滚动。
    private func scheduleDeletion(_ ids: Set<UUID>) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(motion(Theme.Motion.smooth)) {
            pendingDeletion.formUnion(ids)
        }
        showToast(.deleted(pendingDeletion.count), duration: 4)

        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            commitPendingDeletion()
        }
    }

    private func undoDeletion() {
        commitTask?.cancel()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(motion(Theme.Motion.smooth)) {
            pendingDeletion.removeAll()
        }
        hideToast()
    }

    /// 真正落库。计时到期、离开页面、进入后台、清空全部之前都会调用。
    private func commitPendingDeletion() {
        commitTask?.cancel()
        commitTask = nil
        guard !pendingDeletion.isEmpty else { return }
        let ids = pendingDeletion
        HistoryStore.delete(ids: ids, in: modelContext)
        pendingDeletion.removeAll()
        if case .deleted = toast { hideToast() }
    }

    private func copyRecord(_ record: ScanRecord) {
        // Wi-Fi 记录原文里带密码，走敏感剪贴板；其余内容保留普通复制。
        if record.contentType == .wifi {
            SensitivePasteboard.copy(record.rawValue)
        } else {
            UIPasteboard.general.string = record.rawValue
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast(.copied, duration: 1.6)
    }

    // MARK: - 提示

    private func showToast(_ next: HistoryToast, duration: Double) {
        withAnimation(motion(Theme.Motion.success)) {
            toast = next
        }
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            hideToast()
        }
    }

    private func hideToast() {
        toastTask?.cancel()
        withAnimation(motion(Theme.Motion.fade)) {
            toast = nil
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast {
            Group {
                switch toast {
                case .deleted(let count):
                    FeedbackToast(
                        systemImage: "trash",
                        message: L10n.History.deletedCount(count),
                        tint: Theme.Palette.error,
                        actionTitle: L10n.Common.undo,
                        action: undoDeletion
                    )
                case .copied:
                    FeedbackToast(systemImage: "checkmark.circle.fill", message: L10n.Result.copied)
                }
            }
            .padding(.bottom, Theme.Spacing.s)
            .padding(.horizontal, Theme.Spacing.pageMargin)
            .transition(.toast)
            .id(toast.kind)
        }
    }

    // MARK: - 来源筛选指示条

    private var activeFilterIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: selectedSource.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Palette.primary)

            Text(selectedSource.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Palette.primary)

            Spacer()

            Button {
                withAnimation(motion(Theme.Motion.snappy)) {
                    selectedSource = .all
                }
            } label: {
                HStack(spacing: 4) {
                    Text(L10n.History.clearFilter)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Theme.Palette.textSecondary)
            }
            .sensoryFeedback(.selection, trigger: selectedSource)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.Palette.primarySoft))
        .padding(.horizontal, Theme.Spacing.pageMargin)
        .padding(.bottom, 6)
    }

    // MARK: - 列表

    private var cardFeed: some View {
        // 分组只算一次：`groupedSections` 里含过滤 + 排序，body 里反复取会白白重算。
        let sections = groupedSections
        return List {
            if showsHero {
                HistoryHeroCard(
                    total: visibleRecords.count,
                    scanned: visibleRecords.filter { $0.source != .generator }.count,
                    created: visibleRecords.filter { $0.source == .generator }.count,
                    thisWeek: visibleRecords.filter {
                        Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .weekOfYear)
                    }.count,
                    quotaUsed: subscriptions.isPremium ? nil : min(liveRecords.count, HistoryStore.freeLimit),
                    quotaLimit: HistoryStore.freeLimit,
                    onUpgrade: { PaywallTriggerManager.shared.triggerUsageLimit() }
                )
                .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.pageMargin, bottom: Theme.Spacing.xxs, trailing: Theme.Spacing.pageMargin))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .transition(.lift)
            }

            // 筛选芯片跟着列表一起滚动，hero 在它上面。
            filterChips
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if sections.isEmpty {
                filterEmptyState
                    .frame(minHeight: 260)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.records) { record in
                        row(for: record)
                    }
                } header: {
                    if !section.title.isEmpty {
                        Text(section.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .textCase(nil)
                            .padding(.leading, Theme.Spacing.xxs)
                    }
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.bottom, toast == nil ? Theme.Spacing.m : 72, for: .scrollContent)
    }

    private func row(for record: ScanRecord) -> some View {
        HistoryCardView(
            record: record,
            isSelecting: isSelecting,
            isSelected: selectedIDs.contains(record.id),
            onSelect: {
                if isSelecting {
                    toggleSelection(record)
                } else {
                    selected = record
                }
            },
            onDelete: {
                deleteRecord(record)
            }
        )
        .heroTransitionSource(id: record.id.uuidString, in: heroNamespace)
        .listRowInsets(EdgeInsets(top: 5, leading: Theme.Spacing.pageMargin, bottom: 5, trailing: Theme.Spacing.pageMargin))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        // 侧滑：只在非选择态启用，避免和勾选手势冲突。
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isSelecting {
                Button(role: .destructive) {
                    deleteRecord(record)
                } label: {
                    Label(L10n.Common.delete, systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isSelecting {
                Button {
                    copyRecord(record)
                } label: {
                    Label(L10n.History.copy, systemImage: "doc.on.doc")
                }
                .tint(Theme.Palette.primaryFill)
            }
        }
    }

    // MARK: - 目标页面（iOS 18+ Hero 缩放动效）

    @ViewBuilder
    private func destinationView(for record: ScanRecord) -> some View {
        if #available(iOS 18.0, *) {
            HistoryDetailView(record: record)
                .navigationTransition(.zoom(sourceID: record.id.uuidString, in: heroNamespace))
        } else {
            HistoryDetailView(record: record)
        }
    }

    // MARK: - 格式化辅助

    private func badgeText(for record: ScanRecord) -> String {
        if let format = record.barcodeFormat {
            return format.displayName
        }
        return record.contentType.localizedName
    }

    // MARK: - Debug 自动化辅助

    private func applyDebugOptions() {
        #if DEBUG
        if DebugLaunchOptions.historySelectMode {
            isSelecting = true
            selectedIDs = Set(visibleRecords.prefix(DebugLaunchOptions.historySelectCount).map(\.id))
        }
        if let query = DebugLaunchOptions.historySearch {
            searchText = query
        }
        if let sortRaw = DebugLaunchOptions.historySort,
           let sort = HistorySortOption(rawValue: sortRaw) {
            selectedSort = sort
        }
        if let sourceRaw = DebugLaunchOptions.historySource,
           let source = HistorySourceFilter(rawValue: sourceRaw) {
            selectedSource = source
        }
        if let filterRaw = DebugLaunchOptions.historyFilter,
           let filter = HistoryCategoryFilter(rawValue: filterRaw) {
            selectedFilter = filter
        }
        #endif
    }

    private func seedIfNeeded() {
        #if DEBUG
        guard !DebugLaunchOptions.historyEmpty else { return }
        guard DebugLaunchOptions.seedHistory, records.isEmpty else { return }
        let now = Date()
        let samples: [(String, BarcodeFormat, ScanSource, Date)] = [
            ("https://exemplo.pt/menu", .qrCode, .camera, now),
            ("5901234123457", .ean13, .camera, now.addingTimeInterval(-86400)), // 昨天
            ("Bem-vindo ao Leitor QR", .qrCode, .photos, now.addingTimeInterval(-86400 * 3)) // 更早
        ]
        for index in 0..<max(1, DebugLaunchOptions.seedHistoryCount) {
            let sample = samples[index % samples.count]
            let record = ScanContent(
                rawValue: sample.0,
                barcodeFormat: sample.1,
                source: sample.2
            )
            HistoryStore.save(record, in: modelContext, isPremium: true)
        }
        #endif
    }

    private func seedGeneratedIfNeeded() {
        #if DEBUG
        guard !DebugLaunchOptions.historyEmpty else { return }
        guard DebugLaunchOptions.seedGenerated, records.isEmpty else { return }

        var navyCircle = QRCodeStyle()
        navyCircle.dotShape = .circle
        navyCircle.foregroundHex = 0x1B2A4A
        navyCircle.backgroundHex = 0xF7F3EA
        navyCircle.logoSource = .brand

        var brandRounded = QRCodeStyle()
        brandRounded.dotShape = .rounded
        brandRounded.foregroundHex = 0x246BCE

        var tintedBars = QRCodeStyle()
        tintedBars.foregroundHex = 0x0E5C55
        tintedBars.backgroundHex = 0xEFF2F6

        let pumpkinStyle = CodeTemplate.withID("holiday-pumpkin")?
            .applying(to: QRCodeStyle()) ?? QRCodeStyle()
        let snowStyle = CodeTemplate.withID("holiday-snow")?
            .applying(to: QRCodeStyle()) ?? QRCodeStyle()

        let brandLogo = BrandMarkRenderer.logo(
            for: .instagram,
            side: 84,
            color: navyCircle.foreground
        )

        let samples: [(String, BarcodeKind, String, QRCodeStyle, UIImage?)] = [
            ("Bem-vindo ao Leitor QR", .qr, "", QRCodeStyle(), nil),
            ("https://exemplo.pt", .aztec, "Cartão de visita", QRCodeStyle(), nil),
            ("5901234123457", .ean13, "Código do produto", tintedBars, nil),
            ("https://leitorqr.app/menu", .qr, "Menu do restaurante", brandRounded, nil),
            ("https://leitorqr.app/festas", .qr, "Convite da festa", pumpkinStyle, nil),
            ("https://leitorqr.app/inverno", .qr, "Cartão de inverno", snowStyle, nil),
            ("WIFI:T:WPA;S:LeitorQR-Office;P:segredo123;;", .qr, "Wi-Fi do escritório", navyCircle, brandLogo)
        ]
        for (value, kind, note, style, logo) in samples {
            HistoryStore.saveGenerated(
                value: value,
                kind: kind,
                note: note,
                style: style,
                logo: logo,
                in: modelContext,
                isPremium: true
            )
        }
        #endif
    }

    private func openDetailIfNeeded() {
        #if DEBUG
        guard DebugLaunchOptions.openDetail, selected == nil else { return }
        for delay in [0.5, 1.0, 1.8, 2.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if selected == nil, let first = visibleRecords.first {
                    withAnimation(Theme.Motion.smooth) {
                        selected = first
                    }
                }
            }
        }
        #endif
    }
}

// MARK: - Hero 卡片

/// 历史页顶部的 hero 卡片。
///
/// - 纯色底（浅色冰蓝 / 深色午夜蓝，与设置页会员卡片同一套颜色），**不用渐变**；右侧是透明底的玻璃插画。
/// - 左上大数字是当前可见的记录总数，数字变化（删除 / 撤销）用 numericText 滚动。
/// - 下面三项统计：扫描、生成、本周。
/// - 免费用户底部是配额条 + 升级按钮（iOS 26 原生 `.glassProminent`）；已购用户是一行「无限历史已解锁」。
private struct HistoryHeroCard: View {
    let total: Int
    let scanned: Int
    let created: Int
    let thisWeek: Int
    /// nil = 已购（不限条数）。
    let quotaUsed: Int?
    let quotaLimit: Int
    let onUpgrade: () -> Void

    private static let base = Color(light: 0xE6F6FB, dark: 0x0B1730)
    private static let ink = Color(light: 0x0B1F3A, dark: 0xFFFFFF)
    private static let inkSecondary = Color(light: 0x3D5A73, dark: 0xB7C4DA)
    private static let track = Color(light: 0xFFFFFF, dark: 0x22304D)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(total, format: .number)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Self.ink)
                            .contentTransition(.numericText(value: Double(total)))
                        Text(L10n.History.heroUnit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Self.inkSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 18) {
                        stat(scanned, L10n.History.heroScanned)
                        stat(created, L10n.History.heroCreated)
                        stat(thisWeek, L10n.History.heroWeek)
                    }
                }

                Spacer(minLength: 0)
            }
            .overlay(alignment: .topTrailing) {
                // 完整放在卡片内边距里，不再往外探（之前 offset 出去，看起来像被裁了）。
                Image("HistoryHeroArt")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
            }

            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.base, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(Theme.Motion.smooth, value: total)
        .accessibilityElement(children: .contain)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Self.ink)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.caption)
                .foregroundStyle(Self.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var footer: some View {
        if let used = quotaUsed {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L10n.History.quotaTitle)
                        Spacer(minLength: 4)
                        Text(verbatim: "\(used) / \(quotaLimit)")
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(used)))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(used >= quotaLimit ? Theme.Palette.warning : Self.inkSecondary)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Self.track)
                            Capsule()
                                .fill(used >= quotaLimit ? Theme.Palette.warning : Theme.Palette.primary)
                                .frame(width: proxy.size.width * CGFloat(used) / CGFloat(max(quotaLimit, 1)))
                        }
                    }
                    .frame(height: 6)
                }

                Button(action: onUpgrade) {
                    Text(L10n.History.claimPremium)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .modifier(HeroButtonStyle())
            }
        } else {
            Label(L10n.History.heroUnlimited, systemImage: "infinity")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Palette.primary)
        }
    }
}

/// hero 卡片里的升级按钮：iOS 26 原生 `.glassProminent`；低版本实心胶囊。
private struct HeroButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.Palette.primaryFill)
                .foregroundStyle(.white)
        } else {
            content
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Theme.Palette.primaryFill, in: Capsule(style: .continuous))
                .buttonStyle(PressableButtonStyle())
        }
    }
}

/// 历史页底部提示的种类。
private enum HistoryToast: Equatable {
    case deleted(Int)
    case copied

    /// 种类不变时（连续删除）只更新数字，不重播入场动画。
    var kind: String {
        switch self {
        case .deleted: return "deleted"
        case .copied: return "copied"
        }
    }
}

private extension HistoryCategoryFilter {
    /// 芯片上的类型色点。「全部」不带点。
    var tint: Color? {
        switch self {
        case .all: return nil
        case .qr: return Theme.Palette.primary
        case .barcode: return ScanContentType.barcode.tint
        case .website: return ScanContentType.url.tint
        case .wifi: return ScanContentType.wifi.tint
        case .hasNote: return Theme.Palette.warning
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(SubscriptionManager())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
