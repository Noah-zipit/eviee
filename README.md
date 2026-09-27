<p align="center">
  <img src="assets/logo/eviee-launcher-1024.png" width="128" alt="eviee logo" />
</p>

<h1 align="center">eviee</h1>

<p align="center"><em>Your keys, your models, your data.</em></p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/Release-v1.1.3-FF6B35" alt="Release" />
</p>

**eviee** is a bring-your-own-key (BYOK) AI chat app for Android. No accounts, no subscriptions, no middleman — you paste your own API keys and talk to the models directly. Everything stays on your device.

## ✨ Features

- **6 provider presets + custom endpoints** — OpenAI, Anthropic, Gemini, NVIDIA NIM, Groq-style OpenAI-compatible APIs, plus any custom OpenAI-compatible base URL
- **Per-provider model picker** — live model catalogue fetched with your saved key (`GET /models` for OpenAI-compatible providers), with manual model-id entry as fallback
- **Streaming chat** — real-time token streaming over SSE
- **Local-first history** — full conversation history in on-device Drift/SQLite with search
- **Token & cost tracking** — per-provider usage and spend estimates
- **6 themes** — Ember (default), plus five more; no purple-gradient AI slop
- **Private by design** — API keys live in secure storage only and are never sent anywhere except the provider you configured
- **No voice, no mic permission** — text-only, on purpose

## 📲 Install

Grab the APK from the [**latest release**](https://github.com/Noah-zipit/eviee/releases/latest):

| APK | For |
|---|---|
| `eviee-arm64-v1.1.3.apk` | Most modern phones (recommended) |
| `eviee-armeabi-v7a-v1.1.3.apk` | Older 32-bit devices |
| `eviee-x86_64-v1.1.3.apk` | Emulators / x86 devices |

Enable *Install unknown apps* for your browser when prompted, then open the APK.

## 🚀 Setup

1. Open eviee → **Providers** → add a provider (or pick a preset)
2. Paste your API key — it's stored in the device's secure storage
3. Pick a model from the live catalogue (or type a model id manually)
4. Start chatting

## 🔑 Free API keys

eviee is bring-your-own-key — no account needed in the app itself. Grab a free key from either of these, paste it into the matching provider preset, and you're chatting:

- **NVIDIA NIM** — [build.nvidia.com](https://build.nvidia.com/) → sign in with a free NVIDIA account → generate an API key. The NVIDIA NIM preset already points at `https://integrate.api.nvidia.com/v1`.
- **Groq** — [console.groq.com/keys](https://console.groq.com/keys) → free signup → *Create API Key*. The Groq preset already points at `https://api.groq.com/openai/v1`.

Both have generous free tiers. Keys live only in your device's secure storage — never anywhere else.

## 🛠 Build from source

```bash
flutter pub get
flutter analyze
flutter build apk --split-per-abi   # per-architecture APKs in build/app/outputs/flutter-apk/
```

Requires Flutter 3.47+.

## 🗺 Roadmap

- Reasoning-content fallback for thinking models
- Upgrade persistence for keys and chats
- Provider/theme/history/model-picker/stop/regenerate/cost/reasoning test matrix

---

Built by [Ashar Qaisar](https://github.com/Noah-zipit) — founder of [Elevate Mavens](https://elevatemavens.com).
