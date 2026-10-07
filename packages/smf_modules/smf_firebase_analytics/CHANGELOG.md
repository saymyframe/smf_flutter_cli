## 0.4.0

> Note: This release has breaking changes.

 - **FIX**(contracts): leave out a provider of analytics or crash reporting that fails to be created. ([52d5b07b](https://github.com/saymyframe/smf_flutter_cli/commit/52d5b07b6804f1459eec52cbd6f880b4b1d57df7))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **BREAKING** **TEST**(cli): run the app tests with the platform mocks of every module of the app, next to other providers of their roles ([#75](https://github.com/saymyframe/smf_flutter_cli/issues/75)). ([87001859](https://github.com/saymyframe/smf_flutter_cli/commit/87001859841890e28f3a9ab2ba685ee32c9bdd87))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**(firebase_analytics): add bloc and riverpod variants of the demo feature ([#24](https://github.com/saymyframe/smf_flutter_cli/issues/24)). ([52212678](https://github.com/saymyframe/smf_flutter_cli/commit/52212678b9bf3bb825cbcf8f86df7953d7dad36e))
 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **FEAT**: firebase crashlytics module. ([beffc40b](https://github.com/saymyframe/smf_flutter_cli/commit/beffc40bd2c28dcbc07fdf4f63fa22534d2632e3))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

## 0.2.0

> Note: This release has breaking changes.

 - **REFACTOR**: remove hardcoded values and fix Firebase/Home module dependencies. ([f60c4f94](https://github.com/saymyframe/smf_modules/commit/f60c4f94e80c5a19cadd30a96ae2d65555037970))
 - **BREAKING** **FEAT**(modules): migrate modules to factories with profile support. ([b94a95dd](https://github.com/saymyframe/smf_modules/commit/b94a95ddacf7eeeafadf86abd163c73e394331a6))

## 0.1.0

- Initial version.
