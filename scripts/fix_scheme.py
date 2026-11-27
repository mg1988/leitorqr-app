#!/usr/bin/env python3
"""修正 XcodeGen 生成的 scheme 中 StoreKit 配置文件的相对路径。

Xcode 要求 identifier 相对于 `*.xcodeproj/xcshareddata/xcschemes/` 三层回到项目根，
而 XcodeGen 2.45 生成的是两层。这里在每次 generate 后校正。
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEME = ROOT / "LeitorQR.xcodeproj" / "xcshareddata" / "xcschemes" / "LeitorQR.xcscheme"
OLD = 'identifier = "../../Support/Products.storekit"'
NEW = 'identifier = "../../../Support/Products.storekit"'


def main() -> int:
    if not SCHEME.exists():
        print(f"找不到 scheme：{SCHEME}", file=sys.stderr)
        return 1

    try:
        text = SCHEME.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"读取 scheme 失败：{exc}", file=sys.stderr)
        return 1

    if OLD not in text:
        if NEW in text:
            print("scheme 中的 StoreKit 路径已正确")
            return 0
        # 升级 XcodeGen 后 scheme 写法可能变化；静默返回 0 会让本地订阅调试
        # 完全读不到价格且无人察觉，这里必须让 postGenCommand 失败。
        print("未找到 StoreKit 配置引用：请检查 scheme 是否仍配置 storeKitConfiguration",
              file=sys.stderr)
        return 1

    try:
        SCHEME.write_text(text.replace(OLD, NEW), encoding="utf-8")
    except OSError as exc:
        print(f"写入 scheme 失败：{exc}", file=sys.stderr)
        return 1
    print("已修正 scheme 中的 StoreKit 配置路径")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
