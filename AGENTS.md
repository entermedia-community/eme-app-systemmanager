# Agent Guidelines

- Authentication uses `eme_app_sdk` only (emailed code, device key, signed `X-tokentype: signature` / `X-token` headers). Follow section 4 of `../eme-app-sdk/AGENTS.md`; do not add Bearer tokens, app passwords or app-local key code.
- `lib/core/api_client.dart` gets headers from `SignedTokenProvider.instance.headers()`; `lib/features/auth/auth_controller.dart` only adapts the SDK's `authProvider`.
- Also follow the other rules in `../eme-app-sdk/AGENTS.md` (no mock or fallback data in `lib/`).
