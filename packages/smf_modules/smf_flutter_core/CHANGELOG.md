## 0.6.0

> Note: This release has breaking changes.

 - **FEAT**(contracts): say in the README of every app that Say My Frame generated it ([#239](https://github.com/saymyframe/smf_flutter_cli/issues/239)). ([a1e47e53](https://github.com/saymyframe/smf_flutter_cli/commit/a1e47e531aa1e0adbbf9aee74fc4e79402b6ac92))
 - **BREAKING** **FEAT**(contracts): add a .gitignore socket to the app entry role ([#243](https://github.com/saymyframe/smf_flutter_cli/issues/243)). ([27879740](https://github.com/saymyframe/smf_flutter_cli/commit/278797409cae63825923bd95865fca6d70a9d736))

## 0.5.0

> Note: This release has breaking changes.

 - **FEAT**(contracts): give every app the icons of the status bar as a widget of its own, with a widget test ([#191](https://github.com/saymyframe/smf_flutter_cli/issues/191)). ([4ab6b288](https://github.com/saymyframe/smf_flutter_cli/commit/4ab6b288cd00e6b94a0a4a27d1440480e21d4a30))
 - **BREAKING** **FEAT**(contracts,apple_sign_in): the App ID among the steps by hand ([#234](https://github.com/saymyframe/smf_flutter_cli/issues/234)). ([e0b73a02](https://github.com/saymyframe/smf_flutter_cli/commit/e0b73a0295316ec57d8a50ec8336d076a1182f87))
 - **BREAKING** **FEAT**(contracts): let modules add components to the Android application ([#201](https://github.com/saymyframe/smf_flutter_cli/issues/201)). ([6dfcaec9](https://github.com/saymyframe/smf_flutter_cli/commit/6dfcaec92bf72dea1922940ea6834b564c24118a))
 - **BREAKING** **FEAT**(contracts): let modules run code in the AppDelegate before launch finishes ([#200](https://github.com/saymyframe/smf_flutter_cli/issues/200)). ([263b3079](https://github.com/saymyframe/smf_flutter_cli/commit/263b307907e85ea4aee51d7c1fa6330712b6cd1f))
 - **BREAKING** **FEAT**(contracts): let modules enable core library desugaring of the Android app ([#199](https://github.com/saymyframe/smf_flutter_cli/issues/199)). ([7f760ba7](https://github.com/saymyframe/smf_flutter_cli/commit/7f760ba7d53081d6023607b045cca7e185d09787))
 - **BREAKING** **FEAT**(flutter_core): give the fallback start screen only to an app that no route starts ([#192](https://github.com/saymyframe/smf_flutter_cli/issues/192)). ([9cc0a8f1](https://github.com/saymyframe/smf_flutter_cli/commit/9cc0a8f19515e003b50778cb1c5a627aa1f1daa5))
 - **BREAKING** **FEAT**(contracts): sign the iOS app with Runner.entitlements and let modules add entitlements ([#187](https://github.com/saymyframe/smf_flutter_cli/issues/187)). ([2f2b0374](https://github.com/saymyframe/smf_flutter_cli/commit/2f2b037442262cec28376137bf2fe35b8adf2852))

## 0.4.1

 - Update a dependency to the latest release.

## 0.4.0

> Note: This release has breaking changes.

 - **FIX**(ci): check that the apps start on devices without the connection of flutter test ([#48](https://github.com/saymyframe/smf_flutter_cli/issues/48)). ([05628617](https://github.com/saymyframe/smf_flutter_cli/commit/05628617185e55a75a3ad318570351ec067d6aa5))
 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(contracts): add the guide for coding agents to the app entry role ([#110](https://github.com/saymyframe/smf_flutter_cli/issues/110)). ([92b78ad8](https://github.com/saymyframe/smf_flutter_cli/commit/92b78ad863e409806ce491ea463de45c01503030))
 - **FEAT**(contracts): let the root MaterialApp take themeMode and locale from its context ([#100](https://github.com/saymyframe/smf_flutter_cli/issues/100)). ([3a10b311](https://github.com/saymyframe/smf_flutter_cli/commit/3a10b311d6ea8e5f1a29764c5fa9d90cb093aeb3))
 - **DOCS**: say that smf create adds a provider by itself only while it is the only one ([#55](https://github.com/saymyframe/smf_flutter_cli/issues/55)). ([4d1097d4](https://github.com/saymyframe/smf_flutter_cli/commit/4d1097d48e4bab3f86748b5764d33975614be933))
 - **BREAKING** **FEAT**(contracts,flutter_core,home,onboarding,settings): take the symbol of the app and the icons of the status bar from one place each ([#143](https://github.com/saymyframe/smf_flutter_cli/issues/143)). ([43a87a36](https://github.com/saymyframe/smf_flutter_cli/commit/43a87a36c3d847dc1398f415ec64de46a3a1a177))
 - **BREAKING** **FEAT**(contracts): keep the platforms of the app in AppIdentity ([#58](https://github.com/saymyframe/smf_flutter_cli/issues/58)). ([eb1225ce](https://github.com/saymyframe/smf_flutter_cli/commit/eb1225cea24a9a4e6d5cc0375532ada7d71af96a))

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**(flutter_core): drop machine-local files from the core brick bundle. ([6f0f3b4b](https://github.com/saymyframe/smf_flutter_cli/commit/6f0f3b4b75063472f9422009a093844d5995159e))
 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **FEAT**: firebase crashlytics module. ([beffc40b](https://github.com/saymyframe/smf_flutter_cli/commit/beffc40bd2c28dcbc07fdf4f63fa22534d2632e3))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

## 0.2.0+1

 - **FIX**: add flutter_riverpod dependency to the core module. ([2ee5ca1b](https://github.com/saymyframe/smf_modules/commit/2ee5ca1b688005ccfb033b1899ed6b7b83feba17))

## 0.2.0

> Note: This release has breaking changes.

 - **DOCS**: add comprehensive API documentation and copyright headers. ([b2cd22b2](https://github.com/saymyframe/smf_modules/commit/b2cd22b23986f25dd611e52a65801e7518dc0e5d))
 - **BREAKING** **FEAT**(modules): migrate modules to factories with profile support. ([b94a95dd](https://github.com/saymyframe/smf_modules/commit/b94a95ddacf7eeeafadf86abd163c73e394331a6))

## 0.1.0

- Initial version.
