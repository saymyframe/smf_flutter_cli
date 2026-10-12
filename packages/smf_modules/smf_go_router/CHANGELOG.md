## 0.5.0

> Note: This release has breaking changes.

 - **FIX**(contracts,go_router): open a page of the flow of a condition over the start screen when a link asks for it ([#166](https://github.com/saymyframe/smf_flutter_cli/issues/166)). ([0c42e365](https://github.com/saymyframe/smf_flutter_cli/commit/0c42e36578dac19accdf3767c7a00a299f50fbf2))
 - **FIX**(go_router): show what push() and replace() ask for when go_router shows its error screen alone ([#165](https://github.com/saymyframe/smf_flutter_cli/issues/165)). ([c55c01e2](https://github.com/saymyframe/smf_flutter_cli/commit/c55c01e2c74ec839e11cef3d5a1bf8a07a7cbc5e))
 - **FIX**(go_router): keep the back button of the system from throwing on the error screen ([#161](https://github.com/saymyframe/smf_flutter_cli/issues/161)). ([5a933e9f](https://github.com/saymyframe/smf_flutter_cli/commit/5a933e9fd848545f747ea4c91749a7d8bcf7a6c7))
 - **FIX**(go_router): drop the pages of every branch when a guard closes and opens in one turn ([#157](https://github.com/saymyframe/smf_flutter_cli/issues/157)). ([976dbad8](https://github.com/saymyframe/smf_flutter_cli/commit/976dbad8458eda9cbaf2dfdb8b48b5008294362b))
 - **FEAT**(contracts): a condition that only some routes ask for ([#155](https://github.com/saymyframe/smf_flutter_cli/issues/155)). ([9c239fe1](https://github.com/saymyframe/smf_flutter_cli/commit/9c239fe105f8adbc30ae9c98cab63b26e1c234ed))
 - **BREAKING** **FEAT**(contracts,go_router): open the flow of a condition over the screen the user is on ([#163](https://github.com/saymyframe/smf_flutter_cli/issues/163)). ([b7f7e655](https://github.com/saymyframe/smf_flutter_cli/commit/b7f7e655374c8109c1daf255cdb43c80a6dc4c67))
 - **BREAKING** **FEAT**(contracts,onboarding): say when a guard is asked and whether it brings the user back ([#152](https://github.com/saymyframe/smf_flutter_cli/issues/152)). ([7b12df77](https://github.com/saymyframe/smf_flutter_cli/commit/7b12df77edbc4a785ae192b8c16bbca0523197ac))
 - **BREAKING** **FEAT**(contracts,onboarding): close the flow of a guard that allows ([#150](https://github.com/saymyframe/smf_flutter_cli/issues/150)). ([731e53f9](https://github.com/saymyframe/smf_flutter_cli/commit/731e53f9bf3c7147f8fa8c6e781788b1ee67b47f))

## 0.4.0

> Note: This release has breaking changes.

 - **REFACTOR**(go_router): write AppShell with the name of the layout role ([#63](https://github.com/saymyframe/smf_flutter_cli/issues/63)). ([a1f8ed28](https://github.com/saymyframe/smf_flutter_cli/commit/a1f8ed28e19ffa88bd6dbe63678761139bdccc73))
 - **FIX**(go_router): call each listener of the screen on its own. ([8b44ecd1](https://github.com/saymyframe/smf_flutter_cli/commit/8b44ecd1e02ca5aa01b12f0dbbaba4937c68972e))
 - **FIX**(go_router): complete push() with the value of its page after a refresh ([#71](https://github.com/saymyframe/smf_flutter_cli/issues/71)). ([ae37c5de](https://github.com/saymyframe/smf_flutter_cli/commit/ae37c5de79b6d387ea3f392461d3ebf5c2c2b9d6))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(go_router): ask the guards of the routes ([#111](https://github.com/saymyframe/smf_flutter_cli/issues/111)). ([ea4d43f6](https://github.com/saymyframe/smf_flutter_cli/commit/ea4d43f6d39d8036c3763ba01235638adbdb09ee))
 - **DOCS**: say that smf create adds a provider by itself only while it is the only one ([#55](https://github.com/saymyframe/smf_flutter_cli/issues/55)). ([4d1097d4](https://github.com/saymyframe/smf_flutter_cli/commit/4d1097d48e4bab3f86748b5764d33975614be933))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**(go_router,contracts): route merging, guard imports, AppRoutes and camelCase ([#26](https://github.com/saymyframe/smf_flutter_cli/issues/26)). ([abcedc5d](https://github.com/saymyframe/smf_flutter_cli/commit/abcedc5d7b1b704e1626b495f934e050382d9a2c))
 - **FIX**(go_router): remove unrendered tabs shell when no module adds tabs ([#16](https://github.com/saymyframe/smf_flutter_cli/issues/16)). ([1b42b8cc](https://github.com/saymyframe/smf_flutter_cli/commit/1b42b8cc7391d5424a9497b73a344b98cd9d7e39))
 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **FEAT**: firebase crashlytics module. ([beffc40b](https://github.com/saymyframe/smf_flutter_cli/commit/beffc40bd2c28dcbc07fdf4f63fa22534d2632e3))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

## 0.2.0

> Note: This release has breaking changes.

 - **REFACTOR**: remove hardcoded values and fix Firebase/Home module dependencies. ([f60c4f94](https://github.com/saymyframe/smf_modules/commit/f60c4f94e80c5a19cadd30a96ae2d65555037970))
 - **BREAKING** **FEAT**(modules): migrate modules to factories with profile support. ([b94a95dd](https://github.com/saymyframe/smf_modules/commit/b94a95ddacf7eeeafadf86abd163c73e394331a6))

## 0.1.0

- Initial version.
