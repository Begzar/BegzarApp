<div align="center">

<img width="5760" height="3240" alt="Thumbnail" src="https://github.com/user-attachments/assets/1c5c49fa-a98f-458d-bf9b-942a78a2f298" />

# 🐦 Begzar | Free & Secure Internet Access

**🌐 Free, secure, and reliable access to the internet**

🇮🇷 **[فارسی](README.fa.md)** · 🇬🇧 **English**

[![Android](https://img.shields.io/badge/Platform-Android-green)](https://github.com/Begzar/BegzarApp/releases/latest)
[![Windows](https://img.shields.io/badge/Platform-Windows-blue)](https://github.com/Begzar/BegzarApp/releases/latest)
[![macOS](https://img.shields.io/badge/Platform-macOS-lightgrey)](https://github.com/Begzar/BegzarApp/releases/latest)
[![Telegram](https://img.shields.io/badge/Telegram-@BegzarVPN-blue)](https://t.me/BegzarVPN)

</div>

---

## 📖 About Begzar

**Begzar** is a VPN service built around simplicity, security, and reliability. **Android** and **Windows** builds ship with every GitHub Release; Android is also on [Google Play](https://play.google.com/store/apps/details?id=cloud.begzar.begzar).

Our goal is to provide dependable internet access without technical complexity — fast connections, a clean interface, and automatic server updates are at the core of the experience.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🚀 Fast connection | Connect in just a few steps, automatically |
| 🔒 Security | Advanced encryption protocols |
| 🖥️ User interface | Simple, modern design |
| ⚡ Resource efficiency | Balanced battery and device resource usage |
| 🔄 Server updates | Automatic refresh of active server lists |
| 🆓 Free servers | Free access to the service for all users |
| 🚇 Tunnel mode | The default on Windows until you pick another mode: every app goes through Begzar, and Windows asks for admin permission each time you connect |
| 🌐 Languages | Persian, English, Russian and Chinese — picked on first launch, changeable in Settings |

---

## 📲 Installation

Download the latest build from [📥 Releases](https://github.com/Begzar/BegzarApp/releases/latest).

| Platform | How to install |
|---|---|
| **Android** | [Google Play](https://play.google.com/store/apps/details?id=cloud.begzar.begzar), or install the APK from Releases (Android 7.0+) |
| **Windows** | Run the installer, or unpack the portable ZIP, from Releases (Windows 10+, x64) |
| **macOS** | Not published yet |

---

## 💎 Premium

Begzar includes an optional **Premium** plan.

This plan was introduced to **raise capital** 💰 and **cover infrastructure and server costs** 🖥️, helping us keep the service more stable, faster, and higher quality.

### 📌 Important notes

- 🛡️ **No user data is collected.** Your privacy is our priority.
- 🆓 **Free servers remain active** — the free tier has not been removed.
- ✨ Premium offers additional benefits; subscribing is entirely **optional**.

To support the project and subscribe to Premium, visit our official website:

👉 **[begzar.app/premium](https://begzar.app/premium)**

---

## 🔓 Source Code

The Begzar app's source is available again, under the [PolyForm Noncommercial License](LICENSE.md).

The core engine 🔒, the part that connects and talks to Begzar's servers, stays closed for the same **security** reasons that closed the project at version 5.5.0: it is the part that was misused. Builds from this repository run without it: the app opens, and tells you so when you try to connect.

---

## 🧑‍💻 Building from Source

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.44.2 (stable).

```bash
git clone https://github.com/Begzar/BegzarApp.git
cd BegzarApp
flutter pub get
flutter run
```

- 🔌 **No engine:** the app opens but cannot connect, and says *"This build doesn't include the Begzar engine"*.
- 🔕 **No Firebase:** analytics, push and in-app messages are off. Run `flutterfire configure` to use your own project.
- ✅ `flutter analyze` and `flutter test` pass on a fresh clone.
- 🛡️ Official builds are signed by Begzar and come only from [Releases](https://github.com/Begzar/BegzarApp/releases/latest) and Google Play.

---

## 🛠️ Tech Stack

- 🖥️ **Flutter** — Client application
- ⚡ **Golang** — Core services
- 🌐 **Vue.js** — Website
- 🛡️ **Laravel** — Backend & API

---

## 📜 License

📄 This source is available under the [PolyForm Noncommercial License 1.0.0](LICENSE.md): you may use, change and share it for any noncommercial purpose, but you may not sell it, or anything built from it, or use it to make money. The Begzar engine is not included and remains proprietary. Releases before 5.5.0 were published under MIT and remain so.

---

## 💖 Support the Project

If you use Begzar, you can support us by:

- ⭐ Starring this repository
- 💎 Subscribing to Premium at [begzar.app/premium](https://begzar.app/premium)
- 📢 Recommending Begzar to others

---

## 📞 Contact

| Channel | Address |
|---|---|
| 🌐 Website | [begzar.app](https://begzar.app) |
| 📧 Email | [support@begzar.app](mailto:support@begzar.app) |
| 📢 Telegram | [@BegzarVPN](https://t.me/BegzarVPN) |

---

<div align="center">

🚀 **Begzar — Borderless internet, with security and respect for your privacy** 🚀

</div>
