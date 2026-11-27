import ImageIO
import UIKit
import Vision

enum ImageScannerError: LocalizedError {
    case invalidImage
    case noCodeFound
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return L10n.Error.invalidImage
        case .noCodeFound:
            return L10n.Error.noCodeFound
        case .failed:
            return L10n.Error.scanFailed
        }
    }
}

/// 相册图片识别（Vision）。不申请完整照片库权限、不上传图片、不保存原图。
struct ImageScannerService {

    /// 识别图片中所有受支持的码制。识别不到时抛 `noCodeFound`。
    func scan(image: UIImage) async throws -> [ScanContent] {
        guard let cgImage = image.cgImage else {
            throw ImageScannerError.invalidImage
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectBarcodesRequest()
                request.symbologies = BarcodeFormat.allCases.map(\.vnSymbology)

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: orientation,
                    options: [:]
                )

                do {
                    try handler.perform([request])
                    let observations = request.results ?? []

                    var seen = Set<String>()
                    var contents: [ScanContent] = []
                    for observation in observations {
                        // 与相机路径相同的问题：Vision 对无 ECI 段的 QR 按 Latin-1 解码，
                        // 中文/GBK 内容是乱码，统一恢复。
                        let payload = QRTextDecoder.decoded(observation.payloadStringValue ?? "")
                        guard !payload.isEmpty,
                              seen.insert(payload).inserted else { continue }
                        contents.append(
                            ScanContent(
                                rawValue: payload,
                                barcodeFormat: BarcodeFormat.from(vnSymbology: observation.symbology),
                                source: .photos
                            )
                        )
                    }

                    if contents.isEmpty {
                        continuation.resume(throwing: ImageScannerError.noCodeFound)
                    } else {
                        continuation.resume(returning: contents)
                    }
                } catch {
                    continuation.resume(throwing: ImageScannerError.failed(error.localizedDescription))
                }
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
