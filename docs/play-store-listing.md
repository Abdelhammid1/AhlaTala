# Google Play Store Listing — أحلى طلة

Complete copy-and-paste kit for the Play Console submission. Every text field below is ready to drop into the corresponding form.

**Package name:** `ai.manasety.ahlatala`
**Version:** 1.0.0 (versionCode 1)
**AAB:** `mobile/build/app/outputs/bundle/release/app-release.aab` (46.7 MB, signed with `upload-keystore.jks`)

---

## 1. Store listing — عربي (Default language)

**App name** (max 30 chars):
> أحلى طلة

**Short description** (max 80 chars):
> اطلب من مطعم أحلى طلة — مشاوي، شاورما، حلا ومشروبات مع توصيل سريع.

**Full description** (max 4000 chars):
```
مطعم أحلى طلة — كل ما تشتهيه من الأكلات الشهية بين يديك.

تصفح المنيو الكامل، اختر ما يعجبك، خصّصه على ذوقك، وتابع طلبك من التحضير للتسليم مباشرة من التطبيق.

🍽️ منيو متكامل
تشكيلة واسعة من المشاوي، الشاورما، السندوشات، الطواجن، السلطات، الحلا، العصائر الطازجة، والكوكتيلات الخاصة.

⚙️ خصّص طلبك بذوقك
اختر نوع الشاورما، الحجم، الإضافات، أو احذف مكونات لا تحبها — الأسعار تتحدث لك فوراً.

🚚 توصيل أو استلام من الفرع
اختر ما يناسبك: توصيل لباب البيت أو استلام من الفرع.

⭐ نظام نقاط ولاء
كل ريال تصرفه = نقاط تُضاف لرصيدك. استبدلها بخصم على طلباتك القادمة.

🎟️ أكواد خصم
أدخل كود الترويج عند الدفع وشوف السعر ينخفض مباشرة.

🔥 عروض الأسبوع
تابع أحدث عروضنا وأكثر الأصناف طلباً من الشاشة الرئيسية.

🔔 إشعارات فورية
تنبيهات فورية لحالة طلبك: مؤكد، قيد التجهيز، في الطريق، تم التسليم.

📦 سجل طلباتك وأعد الطلب بضغطة
كل طلباتك السابقة محفوظة — أعد نفس الطلب بضغطة واحدة دون تعبئة السلة من جديد.

💳 دفع مرن
كاش عند الاستلام، أو دفع إلكتروني عبر Apple Pay وبطاقة مدى (قريباً).

📱 تسجيل بسيط
جوالك فقط — لا بريد إلكتروني ولا كلمات سر معقدة.

اطلب الآن — أحلى طلة ما تفوّتها 🔥

—
تطوير واستضافة: Manasety · manasety.ai
```

---

## 2. Store listing — English

**App name** (max 30 chars):
> Ahla Tala — أحلى طلة

**Short description** (max 80 chars):
> Order from Ahla Tala: grills, shawarma, desserts & drinks. Fast delivery.

**Full description**:
```
Ahla Tala — order the best flavors, straight from the restaurant to your door.

Browse the full menu, customize every dish to your taste, and track your order from prep to delivery — all in one app.

🍽️ Complete menu
Grills, shawarma, sandwiches, tagines, salads, desserts, fresh juices, and signature cocktails.

⚙️ Customize your order
Pick your variant, size, extras, or remove any ingredient you don't like. Price updates live.

🚚 Delivery or pickup
Choose what fits: home delivery or pickup at the branch.

⭐ Loyalty points
Every riyal spent earns points. Redeem them for discounts on your next order.

🎟️ Discount codes
Enter your promo code at checkout — total updates instantly.

🔥 This week's offers
Follow our latest offers and the most-ordered items right from the home screen.

🔔 Instant notifications
Real-time updates on your order status: confirmed, preparing, on the way, delivered.

📦 Order history + one-tap reorder
All your past orders are saved. Repeat any order with a single tap — no need to rebuild the cart.

💳 Flexible payment
Cash on delivery, or electronic payment via Apple Pay and Mada card (coming soon).

📱 Simple sign-in
Phone number only — no email, no complex passwords.

Order now — Ahla Tala is a bite you don't want to miss 🔥

—
Built and hosted by Manasety · manasety.ai
```

---

## 3. Graphic assets ready to upload

| Play Console slot | Size | File in this repo |
|---|---|---|
| **App icon** | 512×512 PNG | `mobile/assets/play_store_icon_512.png` |
| **Feature graphic** | 1024×500 PNG | `mobile/assets/play_feature_graphic_1024x500.png` |
| **Phone screenshots (2–8)** | portrait, min 320px | *to capture — see §4* |

---

## 4. Screenshot plan — capture 6

Take on the running emulator (Pixel-style 6.7" screen fits perfectly).

1. **الرئيسية** — categories screen with the offers carousel visible + 2–3 category tiles. **Sells the brand identity.**
2. **قائمة الأصناف** — inside ركن الشاورما or المشويات — real items with food photos. **Sells the menu variety.**
3. **تفاصيل صنف** — open شاورما أحلى طلة with all option groups expanded (variant + size + إضافات). **Sells customization.**
4. **السلة** — 2–3 lines with fulfillment picker + total. **Sells the smooth checkout.**
5. **شاشة المراجعة** — with a discount code applied AND loyalty points redemption showing. **Sells the deals.**
6. **تأكيد الطلب** — with the status timeline mid-flow (order in قيد التجهيز). **Sells the transparency.**

Optional 7th: **الملف الشخصي** with saved addresses.

### How to capture

From your PC with the emulator/phone running:
```powershell
adb -s emulator-5554 exec-out screencap -p > screen1.png
```
Repeat per screen.

**Frame tips**: same time (e.g. 9:41), same battery, same signal indicator across all shots — Google's automated screenshot review notices inconsistency.

---

## 5. App Content questionnaires — copy the answers

### Privacy Policy (required)
> **URL:** https://ahlatala.manasety.ai/privacy

*(That page ships in this repo — `backend/app/templates/privacy.html` — served by the `/privacy` route. Restart the production Flask after pulling the latest code so the URL becomes live.)*

### App access
- Login required for some features? → **Yes**
- Reviewer credentials to provide:
  - **Username:** `0500000099` (any Saudi phone works)
  - **Password:** N/A — OTP-based
  - **Instructions:** *"On the login screen, enter the phone and tap Send Code. The 6-digit OTP will appear in a yellow banner (dev mode) or via SMS in production."*
  - *(For production reviewers: temporarily set `OTP_SENDER=logging` on the server, or provide a real test phone the reviewer can SMS.)*

### Ads
- Contains ads? → **No**

### Content rating (IARC)
Complete the questionnaire truthfully. Expected outcome for a food-ordering app:
- Violence / sexual content / profanity / drugs → **No** to all
- User-generated content → **No**
- Location sharing → **No** (address is stored as free text, not GPS)
- Digital purchases → **Yes** (real-money transactions)
- Age gate → **No**
- **Expected rating: Everyone / 3+**

### Target audience & content
- Target age group → **18 and over** (financial transactions)
- Appeals to children? → **No**

### Data safety (critical — Google scrutinizes this most)

**Does your app collect or share any of the required data types?** → **Yes**
**Is all user data collected encrypted in transit?** → **Yes** (HTTPS)
**Do you provide a way for users to request data deletion?** → **Yes** (in-app / email `privacy@manasety.ai`)

**Data collected — mark each with purpose:**

| Data type | Collected | Shared | Optional | Purposes |
|---|---|---|---|---|
| **Personal → Name** | Yes | Yes (delivery driver) | Required | App functionality, Account management |
| **Personal → Phone number** | Yes | Yes (delivery driver) | Required | App functionality, Account management, Fraud prevention |
| **Personal → User IDs** | Yes | No | Required | Account management |
| **Location → Approximate location** | No | — | — | — |
| **Financial → Purchase history** | Yes | No | Required | App functionality, Analytics |
| **Financial → Payment info** | No | — | — | *(gateway handles it)* |
| **App activity → Interactions** | Yes | No | Required | Analytics |
| **App activity → Search history** | No | — | — | — |
| **Device or other IDs** | Yes | Yes (with FCM) | Optional | Push notifications |

---

## 6. Category & tags

- **Category:** Food & Drink
- **Tags:** Restaurant, Delivery, Menu, Ordering
- **Contact email:** `support@manasety.ai`
- **Contact phone:** *(optional — restaurant number)*
- **Website:** `https://ahlatala.manasety.ai`

---

## 7. Countries & pricing

- **Distribution:** Saudi Arabia (add other GCC countries later if desired)
- **Free / Paid:** **Free**
- **In-app purchases:** No (payment is real-world, not a Play in-app product)

---

## 8. Release path — start with Internal testing

**First-time submission: don't go straight to Production.**

1. Play Console → **Testing → Internal testing → Create new release**
2. Upload `app-release.aab`
3. Add **your own Gmail** as a tester (create a tester list first)
4. Save → Review → Rollout
5. Google gives you an **opt-in link** (`https://play.google.com/apps/internaltest/…`) — open it on the tester phone → tap "Become a tester" → install from Play Store

Verify the whole flow works via the Play Store install (icon, splash, login, order, notification). Once solid:

6. **Promote to Closed → Open → Production** through the Play Console UI (the .aab travels — no re-upload).

Production review typically takes **1–7 days** for a first submission (Google verifies identity + policy compliance).

---

## 9. Post-launch maintenance

- **Increment `versionCode`** in `mobile/pubspec.yaml` on every re-upload (`1.0.1+2`, `1.0.2+3`, …)
- **Never lose** `mobile/android/app/upload-keystore.jks` + its password `zaDRugCDVy5eLi76aqMT6qXf` — losing them ends your ability to update this app on Play forever
- Play App Signing (default) — Google holds a copy of the signing key, so lost-upload-keystore recovery is possible via re-key request
- Watch **Play Console → Policy & programs → App content** — Google occasionally requires new questionnaires
- Reply to reviews in **Play Console → Ratings & reviews** — noticeably lifts star ratings

---

## 10. Final upload checklist

- [x] `.aab` built (`app-release.aab`)
- [x] Icon 512×512
- [x] Feature graphic 1024×500
- [ ] 6 phone screenshots (to capture)
- [x] Short + full description Arabic
- [x] Short + full description English
- [ ] Privacy policy URL live at `https://ahlatala.manasety.ai/privacy` (restart production Flask first)
- [x] Data safety form answers drafted
- [ ] Content rating questionnaire answered → **Everyone**
- [ ] Target audience → 18+
- [ ] Category → Food & Drink
- [ ] Distribution → SA (+optional GCC)
- [ ] Reviewer test-account instructions filled
- [ ] Internal testing release uploaded + verified on a real device
- [ ] Promoted to Production

Once submitted, expect to be **live on Google Play within ~3 days** for a first submission.
