#!/usr/bin/env swift
// 条码验收工具：用 Vision 解码一张图片里所有条码，打印码制与内容。
//
// 用法：
//   swift scripts/decode_barcode.swift .build/barcodes/ean13.png
//   swift scripts/decode_barcode.swift .build/shots/create-ean13.png   # 也能直接吃屏截
//
// 为什么需要它：条形码"看起来像"很容易，能不能被扫出来必须机器判。
// 注意屏截有非整数倍缩放，短码（如 EAN-8）在整屏里可能检不出，
// 这时要判"生成逻辑对不对"，请用 LEITORQR_DUMP_BARCODES=1 导出原始位图再解——
// 相关说明见 LeitorQR/Features/Create/BarcodeDebugDump.swift。

import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count > 1 else {
    print("用法：swift scripts/decode_barcode.swift <图片路径>")
    exit(2)
}

let path = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: path),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("无法读取图片：\(path)")
    exit(1)
}

let request = VNDetectBarcodesRequest()
request.symbologies = [.qr, .aztec, .pdf417, .code128, .ean13, .ean8, .code39]
try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

let results = request.results ?? []
print("found \(results.count)")
for result in results {
    let value = result.payloadStringValue ?? "<nil>"
    print("  \(result.symbology.rawValue) -> \(value)")
}
exit(results.isEmpty ? 1 : 0)
