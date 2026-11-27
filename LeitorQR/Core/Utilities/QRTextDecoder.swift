import Foundation

/// 修复 AVFoundation / Vision 读码的字符集乱码。
///
/// 两个框架对 QR 的解码行为：码内**没有 ECI 段**时，一律按 ISO-8859-1（Latin-1）
/// 每字节一个字符给出来。而绝大多数生成器（含本 App 的 CIFilter 生成路径、微信、
/// 网页生成器）用 UTF-8 写码——一个汉字 3 字节会显示成 3 个拉丁乱码字符
/// （"中" → "ä¸­"）。国产生成器常用 GBK（GB18030 超集），日文旧生成器用
/// Shift JIS，都在这里恢复。
///
/// 策略（保守优先：不确定就不动，宁可保留原样也不把对的改错）：
/// 1. 纯 ASCII 没有编码歧义，快速返回。
/// 2. 字符串里已含非 Latin-1 字符（正常中文、emoji 等）→ 框架已经按多字节编码
///    正确解码过，原样返回。
/// 3. 能无损转回 Latin-1 字节 → 按序尝试 UTF-8 → Shift JIS → GB18030 重新解码，
///    采纳强信号命中的结果；都不行说明它本来就是 Latin-1 文本，原样返回。
enum QRTextDecoder {

    /// Latin-1 高字节占比低于该值时不再尝试 Shift JIS / GB18030：
    /// 几乎纯 ASCII 的文本（混少量重音字母）就是 Latin-1 的正常样子，
    /// 拿去按双字节解码纯属误判风险。
    private static let highByteThreshold = 0.2

    /// GB18030 分支要求解码结果里 CJK 字符至少占三成（GBK 中文码即便混排英文，
    /// 高字节也来自汉字；纯西文不该进这个分支）。
    private static let cjkThreshold = 0.3

    static func decoded(_ raw: String) -> String {
        // 1. 纯 ASCII 快速路径（URL、数字、英文）。
        if raw.allSatisfy({ $0.asciiValue != nil }) { return raw }

        // 2. 含非 Latin-1 字符：框架已正确解码（正确的中文/日文/emoji 都落在这）。
        //    此时字符串已无法无损转回 Latin-1 字节，硬转会破坏正确结果。
        guard let bytes = raw.data(using: .isoLatin1, allowLossyConversion: false) else {
            return raw
        }

        // 3. 全 Latin-1 字符 → 真实内容大概率是多字节编码被拆开了。

        // UTF-8：事实标准，优先。合法 UTF-8 序列被误判的概率可忽略；
        // 反过来，Latin-1 编码的葡语重音（如 ç=0xE7）几乎不可能恰好构成合法
        // UTF-8 序列，所以"解码成功"就是足够强的信号。
        if let utf8 = String(data: bytes, encoding: .utf8), utf8.containsNonASCII {
            return stripBOM(utf8)
        }

        // 高字节太少，不值得继续试双字节编码（见 highByteThreshold 注释）。
        let highBytes = bytes.filter { $0 >= 0x80 }.count
        guard Double(highBytes) >= Double(bytes.count) * highByteThreshold else {
            return raw
        }

        // Shift JIS：QR 规范的默认日文编码。假名是日文独有的强信号；
        // 汉字和 GBK 高度重叠，没有假名就不认，交给 GB18030 兜底。
        if let sjis = String(data: bytes, encoding: .shiftJIS), sjis.containsKana {
            return sjis
        }

        // GB18030：GBK 的超集，国内生成器的主流编码。
        if let gb = String(data: bytes, encoding: .gb18030), gb.cjkRatio >= cjkThreshold {
            return gb
        }

        // 4. 没有任何强信号：它本来就是 Latin-1 文本（老式西文生成器），原样返回。
        return raw
    }

    /// UTF-8 BOM（EF BB BF）被框架同样拆成 "ï»¿"，恢复后留在开头没意义，剥掉。
    private static func stripBOM(_ value: String) -> String {
        if value.hasPrefix("\u{FEFF}") {
            return String(value.dropFirst())
        }
        return value
    }
}

private extension String {
    var containsNonASCII: Bool {
        unicodeScalars.contains { $0.value > 0x7F }
    }

    /// 是否含**全角**假名（平假名/片假名）。
    /// 刻意不认半角假名（U+FF66-FF9D）：GBK 字节流被 Shift JIS 误解码时几乎必然
    /// 落出一堆半角假名垃圾（如 GBK 的"欢迎"→ `»¶` → `ｻｶ`），把半角算进信号
    /// 会让中文 GBK 码被 Shift JIS 分支错误劫持；全角假名则与 GBK 空间基本不重叠。
    var containsKana: Bool {
        unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
    }

    /// CJK 统一表意文字（含扩展 A）占字符的比例。
    var cjkRatio: Double {
        let scalars = Array(unicodeScalars)
        let cjk = scalars.filter {
            (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value)
        }
        return Double(cjk.count) / Double(max(scalars.count, 1))
    }
}

extension String.Encoding {
    /// GB18030（GBK 超集）。Foundation 没有内建常量；kCFStringEncodingGB_18030_2000
    /// 是 CFString.h 里的 C 宏（= 0x0631），Swift 导入不了，直接写字面值。
    static let gb18030 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0631))
    )
}
