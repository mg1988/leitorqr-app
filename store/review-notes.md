# Leitor QR — App Review 材料

> 用途：ASC「App 审核信息 → 备注」一栏直接粘贴 + 演示视频。
> 备注字段上限 4000 字符，下面这段 3463 字符，留了余量。

---

## 一、审核备注（粘贴到 Notes for Review）

```
Thank you for reviewing Leitor QR.

WHAT THE APP DOES
A QR / barcode reader and code generator. Everything runs on the device.
There is no account, no login, no server, and no third-party SDK.
Primary localization is Portuguese (Brazil); English is included.

1. NO SIGN-IN REQUIRED
There is nothing to log into. All features are reachable from the two
tabs (Scan / Create) and Settings.

2. CAMERA PERMISSION
Used only to scan codes in the live viewfinder. If you decline it, the
scanner still works through "Import from Photos", so the app is fully
reviewable without granting camera access.

3. WI-FI JOIN (please read)
Scanning a "WIFI:" QR shows the network name and password and offers a
one-tap "Join" button that calls NEHotspotConfiguration.
This requires the "Hotspot Configuration" capability on the App ID.
If that capability is not active in your build, iOS returns an error and
the app shows a neutral message asking the user to join manually — this
is expected graceful degradation, not a failure of the feature.
The password is always displayed and can be copied, so the user is never
blocked.

4. LINK SAFETY CHECK IS LOCAL AND ADVISORY
When a scanned code contains a URL, the app runs a local heuristic check
(HTTPS or not, IP address instead of a domain, sensitive keywords,
URL shorteners) and shows a verdict: Safe / Caution / Risk, with the
reasons listed. It is not a virus scanner, it uses no external service,
and it never blocks the user from opening the link. The wording is
advisory by design and is described the same way in the store listing.

5. IN-APP PURCHASE
One non-consumable product only: com.mg.localicard.premium.lifetime
(shown as "Leitor QR Premium"). It unlocks unlimited history, all code
styles and templates, custom logo, and the trusted-domains list.
There is NO auto-renewable subscription, NO consumable, and NO free
trial of any kind. It is the only product configured for this app and
the only one the UI ever requests, prices or displays. Please test with
it; there is no other product to look for.

6. FREE TIER
Scanning is unlimited and free. The free tier caps history at 10 entries
and locks PRO styles, templates and the trusted-domains list. Tapping a
locked item opens the purchase screen; nothing is silently blocked.

7. APP INTENTS / SIRI SHORTCUTS (optional)
Two shortcuts ship with the app: "Scan Wi-Fi code" and "Connect to Wi-Fi".
Look for "Leitor QR" in the Shortcuts app to try them. Both are optional
and not needed to use the app.

8. PRIVACY
No tracking, no analytics, no ads, no network calls for user data.
Scans and generated codes are stored only in a local SwiftData database.
The privacy manifest declares NSPrivacyTracking = false and an empty
collected-data list.

9. HOW TO TEST THE MAIN FLOW IN 60 SECONDS
 a. Open the app and allow camera (or skip it).
 b. Point at any QR code, or use Import from Photos with any image that
    contains one — a Wi-Fi QR is the best demo since it shows the
    network name, the password and the Join button.
 c. Tap Create → pick a type (e.g. Wi-Fi) → fill it in → Generate.
    The second screen is the style editor (dots, corners, colors, eyes,
    logo, templates) with Save to Photos / Share.
 d. Open History to see saved records, search and filters.
 e. Settings shows the purchase entry point and Restore Purchases.

CONTACT
genweimi@gmail.com — happy to answer anything or provide a build with
the Hotspot Configuration capability enabled.
```

---

## 二、内购项目本身的审核备注

ASC 路径：**我的 App → 内购项目 → Leitor QR Premium → App 审核信息**。
那里有两个字段：**审核截图**（必填，1 张）和**备注**。

### 2.1 备注（粘贴到内购项目的 Notes）

```
PRODUCT: Leitor QR Premium — non-consumable, one-time purchase

WHAT IT UNLOCKS
Unlimited scan history (the free tier keeps the 10 most recent scans),
every dot/eye style and all 12 templates, a custom centre logo on
generated codes, and the trusted-domains list used by the link check.

HOW TO REACH IT
1. Settings tab (Ajustes) → the member card → "Comprar".
2. Or scan any code → Create → pick a PRO style or template → the same
   purchase screen opens.
Both routes land on the screen in the attached screenshot. No account
or login is needed to test anything.

AFTER PURCHASE
The entitlement is tied to the Apple ID, not to an app account, so
nothing has to be registered first. The screen switches to "O Premium
já está ativo" and every PRO control unlocks.
"Restaurar Compras" (Restore Purchases) sits on the same screen and in
Settings, and re-checks the Apple ID on a fresh install.

TESTING NOTES
Please test with a Sandbox account. The price line renders the live
StoreKit price; if the product has not loaded yet the app shows
"The price shown in the App Store at the time of purchase applies"
instead of a number and the button re-requests the product on tap.
That is expected behaviour when the device is offline, not a failed
purchase.
This is a one-time purchase: nothing renews, there is no subscription
and no free trial.

CONTACT
genweimi@gmail.com
```

### 2.2 审核截图

`store/review/iap-paywall.png`（1206×2622，可直接上传）。

这张是模拟器里**真实拉到了商品**的付费墙：`US$4.99` 是 StoreKit 返回的当前 storefront 价格，不是写死的文案（仓库里没有任何硬编码金额，商品没拉到时付费墙会显示「以 App Store 当时价格为准」而不是数字）。

> 上传前请确认一件事：截图里显示的是 `US$4.99`，而 App 的目标价是 `9,99 €`。如果这才是你要的定价，去 ASC 检查价格档位（美国店面和葡萄牙店面是分开的）；如果截图要跟葡萄牙价一致，把模拟器 storefront 换成葡萄牙后再截一张。

---

## 三、演示视频

文件：`store/review/demo.mp4` — 720×1566，H.264，28.1 秒，2.1 MB，无声，底部英文字幕。
重新生成：`./scripts/record_demo.sh`（真机素材放 `store/review/real_scan.mp4`，模拟器素材按需重录；只想重剪加 `SKIP_RECORD=1`）。

| 时间 | 画面 | 字幕 |
| --- | --- | --- |
| 0:00 | 片头 | Leitor QR / App Review demo |
| 0:03 | **真机**：摄像头对准二维码 → 识别 → 结果页滑出（appstoreconnect.apple.com，本地判定「无红旗」） | Real device: the camera reads a code |
| 0:08 | 模拟器：取景页 → 扫 Wi-Fi 码 → 结果面板（网络名、明文密码、Join Network） | Wi-Fi codes: join the network with one tap |
| 0:14 | 可疑链接（IP 伪装域名、无 HTTPS 等四条原因）→ Open in Browser | Links are checked on-device before you open them |
| 0:19 | 创建：填内容 → 设计页（大码预览 + 样式分类 + 图案 + Save / Share） | Create your own codes: colors, dots, eyes, logo |
| 0:23 | 历史：统计、筛选胶囊、今天/昨天分组 | History stays on the device, with search |
| 0:26 | 设置：会员卡、Buy Once、自动操作开关 | One-time purchase. No subscription. |

**素材的真实性边界（汇报给审核时不要含糊）**

- 第 2 段（0:03）是**用户真机录屏**，真实摄像头、真实识别。为了看得清，这一段做了两处处理：
  现场光线很暗、二维码几乎不可见，所以把取景那 1.2 秒放慢到 2.2 倍，并**只调了亮度/对比度（+0.10 / 1.08），没有改变画面内容**。
  原片 5 秒后会自己跳到 Safari，剪辑时已切掉。
- 其余各段是**模拟器录屏**：取景背景是 App 内部画的假图（`LEITORQR_FAKE_CAMERA`），识别结果是注入的
  （`LEITORQR_SIMULATE_SCAN`），历史与相册用调试种子数据。
- 仍然**证不了**的一件事：**Wi-Fi 真能一键连上**。模拟器跑不起 `NEHotspotConfiguration`，
  真机那段也没有连 Wi-Fi。这条目前只有结果页 + 明文密码可看。

**还差的一段（可选，补上更稳）**

```
1. 真机装 TestFlight 构建
2. 另一台设备显示一个 Wi-Fi 二维码（可以先用 App 自己生成）
3. 控制中心开屏幕录制 → 对准二维码 → 点 Join Network → 看到连上
4. 把文件发我，我插到 0:08 那段前面
```

## 四、审核前仍需你确认

- [ ] ASC 里 App ID 的 **Hotspot Configuration** capability 已勾选（否则第 3 条会真的失败）
- [ ] ASC 商品清单：**只有** `com.mg.localicard.premium.lifetime` 一个非消耗型项目；没有周卡、没有年/月订阅（2026-11-28 核对：后台确无 week 商品，付费墙 `allProductIDs` 也只请求这一个）
- [ ] **内购项目自己的「审核截图 + 备注」已填**（见第二节；截图 `store/review/iap-paywall.png`，备注直接粘 2.1 那段）
- [ ] 内购价格：截图里 StoreKit 返回的是 **US$4.99**（美国店面），而目标价是 **9,99 €**。先确认 ASC 价格档位是否正确，再决定这张截图能不能直接用
- [ ] 沙盒账号能走完一次完整购买（模拟器已能拉到真实商品，说明商品本身可达；购买流程需真机或沙盒账号验）
