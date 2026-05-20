# MoodSpend Technical Support

> English | [简体中文](technical-support.zh-Hans.md)

**MoodSpend** (Chinese display name: **花钱了**) is an expense tracker focused on the emotional context behind spending. This document is for end users and testers: features, settings, and troubleshooting.

---

## Contact Us

| Item | Details |
|------|---------|
| Support email | [octboyu@gmail.com](mailto:octboyu@gmail.com) |
| In-app | **Mine → Help & Support → About → Contact** |

When reporting an issue, please include: **device model, iOS version, app version** (shown under About), screenshots if possible, and short steps to reproduce.

---

## Requirements

- **Platform**: iPhone (see App Store listing)
- **iOS**: Minimum version as stated on the App Store product page
- **iCloud** (optional): Sign in with your Apple ID and enable iCloud for cross-device sync

---

## App Name & Languages

| Context | Behavior |
|---------|----------|
| Home Screen icon label | Follows **system language**: e.g. 花钱了 (Chinese), MoodSpend (English) |
| In-app UI language | **Mine → Basic Settings → Language** |

### Supported in-app languages

- **Follow System** (default): picks Simplified Chinese, Traditional Chinese, or English from iOS preferred languages  
- **Simplified Chinese**  
- **Traditional Chinese**  
- **English**

If the device language is not Chinese (e.g. Japanese, French), **Follow System** resolves to **English** for in-app strings.

---

## Quick Start

### Log an expense

1. Tap the **「+」** button in the center of the tab bar  
2. Enter amount, category, mood, and save  
3. Review entries on **Home** and **Bills**

### Main tabs

| Tab | Purpose |
|-----|---------|
| Home | Today’s summary, mood spectrum, recent entries |
| Bills | Full list and filters |
| Analysis | Charts and mood heat ring |
| Mine | Settings, data management, help |

First launch shows **onboarding**; replay via **Mine → Help & Support → View intro**.

---

## Settings

### Appearance

**Mine → Basic Settings → Theme**

- **Follow System** (default): matches iOS light / dark mode  
- **Light** / **Dark**: fixed appearance

### iCloud Sync

**Mine → Advanced → Data Center → Cloud Sync**

| Setting | Behavior |
|---------|----------|
| On | Bills, settings, and notifications sync across devices signed into the same Apple ID |
| Off | New data stays on this device only |

**Important**: After toggling iCloud sync, **fully quit the app and reopen it** (remove from the app switcher, then launch again) so the new configuration applies.

If you see “Not signed in to iCloud”, go to **Settings → Apple ID → iCloud** on your device.

### Emotion alerts & review rules

- **Emotion alerts**: **Mine → Advanced → Emotion notifications**  
- **Review rule sensitivity**: **Mine → Advanced → Review rules** (separate from emotion alerts)

### Backup & export

**Mine → Advanced → Data Center**

- JSON backup export / import, CSV export for bills  
- Back up before using **Clear local data**

### Main currency

**Mine → Advanced → Main currency** — lock a currency or follow the system locale when unlocked.

---

## FAQ

### 1. Data missing after switching phones?

- Ensure **iCloud sync** was enabled on the old device with the **same Apple ID**  
- On the new device, sign in to iCloud and open the app; initial cloud import may take time (you can skip the wait screen if offered)  
- If sync was off, data may exist only on the old device — restore from a **JSON backup** from that device if you made one

### 2. Sync errors or “Sync issue”?

1. Check network connectivity  
2. Verify iCloud account status in iOS Settings  
3. Read the message under **Cloud Sync** in the app  
4. Toggle iCloud sync off/on and **restart the app**  
5. Email support if it persists; avoid sending full transaction details in email

### 3. Home Screen name doesn’t match in-app language?

The icon label follows **system language**, not the in-app Language setting. To show **MoodSpend** on the Home Screen, set iOS preferred language to English.

### 4. Where is the app version?

**Mine → Help & Support → About → Version**

### 5. Privacy Policy / Terms of Use?

Links under **Mine → Help & Support → About** (some content still being finalized).

---

## Data & Privacy (Summary)

- With iCloud sync on, data is stored in **your private iCloud account** (Apple’s sync and encryption stack)  
- With sync off, data remains primarily **on device**  
- We will never ask for your Apple ID password or full financial records via support email

A full Privacy Policy will be linked from the app and this repository when published.

---

## TestFlight

- Build/version is shown under **About**  
- Each upload uses a new build number; install issues may relate to invitation status or iOS version  
- Feedback: email with subject `[TestFlight]`

---

## Document History

| Date | Notes |
|------|-------|
| May 2026 | Initial release for MoodSpend / 花钱了 beta and user support |

If this document conflicts with the App Store build, the **store version** takes precedence.
