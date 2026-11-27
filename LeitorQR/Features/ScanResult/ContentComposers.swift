import Contacts
import ContactsUI
import EventKit
import EventKitUI
import SwiftUI

// 把扫到的负载交给系统自己的编辑器：新建联系人用 `CNContactViewController`，
// 新建日程用 `EKEventEditViewController`。
//
// 为什么不自建表单：这两个界面由系统提供，字段校验、账户选择、"存储到哪个日历"
// 都是系统在管；自己拼一个表单再去写库，等于把权限、去重、多账户这些坑全部重踩一遍。
// App 只负责把解析结果预填进去，用户在系统界面里确认后由系统落库。

// MARK: - 权限

enum ContactAccess {
    /// 写通讯录只需要普通 contacts 权限（iOS 18 的 limited 也算）。
    static func request() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .authorized { return true }
        if #available(iOS 18.0, *), status == .limited { return true }
        guard status == .notDetermined else { return false }

        let store = CNContactStore()
        return await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}

enum CalendarAccess {
    /// 只要写权限：iOS 17 起 `requestWriteOnlyAccessToEvents` 不会让用户把
    /// 整本日历交出来，加一个日程没必要读别人的安排。
    static func requestWriteOnly() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .writeOnly { return true }
        guard status == .notDetermined else { return false }

        let store = EKEventStore()
        do {
            return try await store.requestWriteOnlyAccessToEvents()
        } catch {
            return false
        }
    }
}

// MARK: - 新建联系人

struct ContactComposer: UIViewControllerRepresentable {
    let card: ContactCard
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        // 解析器已把 vCard 的 `N:Sobrenome;Nome` 拼成「名 姓」，
        // 这里按第一个空格切开只是给系统一个合理默认值，用户可在界面里改。
        let parts = card.name.split(separator: " ", maxSplits: 1).map(String.init)
        contact.givenName = parts.first ?? ""
        if parts.count > 1 { contact.familyName = parts[1] }
        if !card.organization.isEmpty { contact.organizationName = card.organization }
        if !card.phone.isEmpty {
            contact.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMobile,
                               value: CNPhoneNumber(stringValue: card.phone))
            ]
        }
        if !card.email.isEmpty {
            contact.emailAddresses = [
                CNLabeledValue(label: CNLabelHome, value: card.email as NSString)
            ]
        }

        let controller = CNContactViewController(forNewContact: contact)
        controller.contactStore = CNContactStore()
        controller.delegate = context.coordinator
        // 新建时没有可执行的关联动作（呼叫/发信），关掉免得出现空面板。
        controller.allowsActions = false
        controller.allowsEditing = true

        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.prefersLargeTitles = false
        return navigation
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func contactViewController(_ controller: CNContactViewController,
                                   didCompleteWith contact: CNContact?) {
            // 取消和保存都走这里，SwiftUI 侧只负责关掉 sheet。
            onFinish()
        }
    }
}

// MARK: - 新建日程

struct EventComposer: UIViewControllerRepresentable {
    let event: CalendarEvent
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let item = EKEvent(eventStore: store)
        item.title = event.summary

        // 没有开始时间就按「现在」起算一小时：比报错让用户自己填要好。
        // 结束时间再兜一次底——解析层已经滤掉 DTEND ≤ DTSTART，但「只有 DTEND
        // 没有 DTSTART」这种脏数据仍会算出早于开始的结束时间，EventKit 会拒收。
        let start = event.start ?? Date()
        var end = event.end ?? start.addingTimeInterval(3600)
        if end <= start { end = start.addingTimeInterval(3600) }
        item.startDate = start
        item.endDate = end
        if !event.location.isEmpty { item.location = event.location }
        if !event.notes.isEmpty { item.notes = event.notes }
        item.calendar = store.defaultCalendarForNewEvents

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = item
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            // 保存/取消/删除都由系统处理完，这里只关掉 SwiftUI 的 sheet。
            onFinish()
        }
    }
}
