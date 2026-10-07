## 0.4.0

> Note: This release has breaking changes.

 - **REFACTOR**(contracts,pipeline,cli): split the functions that SonarCloud finds too complex. ([c3f5aadc](https://github.com/saymyframe/smf_flutter_cli/commit/c3f5aadc0ea6cf6458aa189cdd2936d850c4d1b9))
 - **FIX**(contracts): tell that a dispose function gets its service, not the dependencies ([#84](https://github.com/saymyframe/smf_flutter_cli/issues/84)). ([433f5709](https://github.com/saymyframe/smf_flutter_cli/commit/433f57091e512f8b5c60eb98a16835901be5543f))
 - **FIX**(contracts,shared_preferences): correct the texts for coding agents and the READMEs that the reviews found wrong ([#132](https://github.com/saymyframe/smf_flutter_cli/issues/132)). ([7f936e51](https://github.com/saymyframe/smf_flutter_cli/commit/7f936e51b2f2ae2f80eba144f5cf29ae5d7101f9))
 - **FIX**(contracts): say that on<T>() delivers the events fired once its stream is listened to. ([06668c45](https://github.com/saymyframe/smf_flutter_cli/commit/06668c45dd58e3d7de05b71f89c8eb474920ac5b))
 - **FIX**(go_router): call each listener of the screen on its own. ([8b44ecd1](https://github.com/saymyframe/smf_flutter_cli/commit/8b44ecd1e02ca5aa01b12f0dbbaba4937c68972e))
 - **FIX**(cli,ci): stop a timed-out command before the processes it started, and annotate failed tests ([#54](https://github.com/saymyframe/smf_flutter_cli/issues/54)). ([a3fa33b2](https://github.com/saymyframe/smf_flutter_cli/commit/a3fa33b2a3729986299795fa0f7af1a5a5db54ca))
 - **FIX**(contracts): leave out a provider of analytics or crash reporting that fails to be created. ([52d5b07b](https://github.com/saymyframe/smf_flutter_cli/commit/52d5b07b6804f1459eec52cbd6f880b4b1d57df7))
 - **FIX**(contracts): give each analytics service a copy of its own of the parameters. ([21c6ca39](https://github.com/saymyframe/smf_flutter_cli/commit/21c6ca39980e3af0446b053dac01267fd26788de))
 - **FIX**(contracts): keep one provider of analytics or crash reporting from failing the others. ([42c8db26](https://github.com/saymyframe/smf_flutter_cli/commit/42c8db26e9c68c8733bf2d4dcd9e4eb195d861ab))
 - **FEAT**(pipeline): check the notes of roles against their providers, and require a note from every role and module ([#131](https://github.com/saymyframe/smf_flutter_cli/issues/131)). ([2980ddc1](https://github.com/saymyframe/smf_flutter_cli/commit/2980ddc13ff7a77be5122b4fe4515ebaa1e1eb70))
 - **FEAT**(contracts): guarantee a MaterialApp at the root of the app ([#57](https://github.com/saymyframe/smf_flutter_cli/issues/57)). ([5bc4f0b8](https://github.com/saymyframe/smf_flutter_cli/commit/5bc4f0b8b7f5c7ca003f007b1fb2a711beef7289))
 - **FEAT**(contracts,settings): describe the settings screen in the guide for coding agents ([#129](https://github.com/saymyframe/smf_flutter_cli/issues/129)). ([f6353e4d](https://github.com/saymyframe/smf_flutter_cli/commit/f6353e4d8a864949a5b58ce78b8e3c4ddeff7175))
 - **FEAT**(contracts): remember the language of the app and let the user choose it in the settings ([#120](https://github.com/saymyframe/smf_flutter_cli/issues/120)). ([9f3c847b](https://github.com/saymyframe/smf_flutter_cli/commit/9f3c847bc372a9b6a1d852d7cf6da2a69f172afe))
 - **FEAT**(contracts): tell coding agents about the guards of the routes ([#119](https://github.com/saymyframe/smf_flutter_cli/issues/119)). ([262427e6](https://github.com/saymyframe/smf_flutter_cli/commit/262427e68aa737aa812241867507fbdc48729668))
 - **FEAT**(gen_l10n): provide the localization role with gen-l10n of Flutter ([#117](https://github.com/saymyframe/smf_flutter_cli/issues/117)). ([36afeb32](https://github.com/saymyframe/smf_flutter_cli/commit/36afeb32e8e21c1a14fb4345bbbbcd252bd7260a))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(contracts): add the theme role ([#112](https://github.com/saymyframe/smf_flutter_cli/issues/112)). ([822056da](https://github.com/saymyframe/smf_flutter_cli/commit/822056daf2695b8007e30ade24213b4c6252bebf))
 - **FEAT**(shared_preferences): add the module that keeps the preferences with shared_preferences ([#113](https://github.com/saymyframe/smf_flutter_cli/issues/113)). ([170c9ff3](https://github.com/saymyframe/smf_flutter_cli/commit/170c9ff307d0bc7a766d4434ec0c46ef572fe6bf))
 - **FEAT**(contracts): check that the provider of the DI role renders every registration ([#90](https://github.com/saymyframe/smf_flutter_cli/issues/90)). ([e905d406](https://github.com/saymyframe/smf_flutter_cli/commit/e905d40625a8ae674c94aa8ee74fe1ab548bd3d6))
 - **FEAT**(contracts): add guards of routes to the router role ([#109](https://github.com/saymyframe/smf_flutter_cli/issues/109)). ([b86cb319](https://github.com/saymyframe/smf_flutter_cli/commit/b86cb3193872185840b001f9a9236dde6f0049f7))
 - **FEAT**(contracts,pipeline): add the localization role ([#107](https://github.com/saymyframe/smf_flutter_cli/issues/107)). ([84091023](https://github.com/saymyframe/smf_flutter_cli/commit/840910231936c42fa783f9f9b9a430610a52e003))
 - **FEAT**(contracts): add the preferences role for the settings of the app that are no secret ([#106](https://github.com/saymyframe/smf_flutter_cli/issues/106)). ([3304ebd2](https://github.com/saymyframe/smf_flutter_cli/commit/3304ebd267731bb624d61d13c5823ace4cfd5b45))
 - **FEAT**(contracts): add the settings screen role ([#105](https://github.com/saymyframe/smf_flutter_cli/issues/105)). ([4577c781](https://github.com/saymyframe/smf_flutter_cli/commit/4577c78121add85f715677fd4b8d20b19bf6f348))
 - **FEAT**(contracts,pipeline): let a brick variable depend on the presence of a role ([#104](https://github.com/saymyframe/smf_flutter_cli/issues/104)). ([02677b81](https://github.com/saymyframe/smf_flutter_cli/commit/02677b814381632ea0400126ef59c1ab0c188d76))
 - **FEAT**(contracts): add the guide for coding agents to the app entry role ([#110](https://github.com/saymyframe/smf_flutter_cli/issues/110)). ([92b78ad8](https://github.com/saymyframe/smf_flutter_cli/commit/92b78ad863e409806ce491ea463de45c01503030))
 - **FEAT**(contracts,pipeline): check that a provider of the app entry creates the root where the arguments of the modules read its context ([#101](https://github.com/saymyframe/smf_flutter_cli/issues/101)). ([78293c3c](https://github.com/saymyframe/smf_flutter_cli/commit/78293c3c881dd5471f5b9cce2445a7d437922b0c))
 - **FEAT**(contracts): let the root MaterialApp take themeMode and locale from its context ([#100](https://github.com/saymyframe/smf_flutter_cli/issues/100)). ([3a10b311](https://github.com/saymyframe/smf_flutter_cli/commit/3a10b311d6ea8e5f1a29764c5fa9d90cb093aeb3))
 - **FEAT**(contracts): check that the tags of the phases of start-up are in the body of bootstrap(). ([149aede7](https://github.com/saymyframe/smf_flutter_cli/commit/149aede761f3ed27bc5890675b7056b5315aea60))
 - **FEAT**(settings,contracts): show the settings as one group, the theme modes as segments and the languages in a sheet ([#140](https://github.com/saymyframe/smf_flutter_cli/issues/140)). ([72a29d05](https://github.com/saymyframe/smf_flutter_cli/commit/72a29d05024e6a5f7326e1c446d9b6833d4a9054))
 - **FEAT**(contracts,pipeline): let a render hook generate files of the app ([#102](https://github.com/saymyframe/smf_flutter_cli/issues/102)). ([620eb402](https://github.com/saymyframe/smf_flutter_cli/commit/620eb40246af1db18d9a139e67eb39a823c1ce87))
 - **DOCS**(readme): add the SonarCloud coverage badge ([#99](https://github.com/saymyframe/smf_flutter_cli/issues/99)). ([39c28873](https://github.com/saymyframe/smf_flutter_cli/commit/39c288733a22495b6b90ef6afc67d89704eefcee))
 - **BREAKING** **FEAT**(contracts,flutter_core,home,onboarding,settings): take the symbol of the app and the icons of the status bar from one place each ([#143](https://github.com/saymyframe/smf_flutter_cli/issues/143)). ([43a87a36](https://github.com/saymyframe/smf_flutter_cli/commit/43a87a36c3d847dc1398f415ec64de46a3a1a177))
 - **BREAKING** **FEAT**(contracts): continue a post-generation step of another module by its id ([#89](https://github.com/saymyframe/smf_flutter_cli/issues/89)). ([cfce8114](https://github.com/saymyframe/smf_flutter_cli/commit/cfce8114f4c1299d98ea3150695c79ae8c8065c8))
 - **BREAKING** **FEAT**(contracts): let one contributor give the supported locales of the root MaterialApp ([#121](https://github.com/saymyframe/smf_flutter_cli/issues/121)). ([5a440409](https://github.com/saymyframe/smf_flutter_cli/commit/5a4404090da4cfe0892df42916c1b6f1275b3b44))
 - **BREAKING** **FEAT**(contracts): drop the factory parameters of the DI role ([#64](https://github.com/saymyframe/smf_flutter_cli/issues/64)). ([0c8bc398](https://github.com/saymyframe/smf_flutter_cli/commit/0c8bc3981842e961f69cb4b21a0b26a10feca74d))
 - **BREAKING** **FEAT**(contracts): require the getters that code of a role reads, such as the navigation of the AppShell ([#69](https://github.com/saymyframe/smf_flutter_cli/issues/69)). ([5e5301d8](https://github.com/saymyframe/smf_flutter_cli/commit/5e5301d82120389548d59a8cb44547a71f2f2755))
 - **BREAKING** **FEAT**(contracts): keep the platforms of the app in AppIdentity ([#58](https://github.com/saymyframe/smf_flutter_cli/issues/58)). ([eb1225ce](https://github.com/saymyframe/smf_flutter_cli/commit/eb1225cea24a9a4e6d5cc0375532ada7d71af96a))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))
 - **BREAKING** **FEAT**(contracts): move the composition file out of the core into the DI role ([#56](https://github.com/saymyframe/smf_flutter_cli/issues/56)). ([84e85d07](https://github.com/saymyframe/smf_flutter_cli/commit/84e85d079b01150ee28405eaea42c599f7278c38))
 - **BREAKING** **FEAT**(contracts): require resetDependencies() of the providers of the DI role. ([9911bf11](https://github.com/saymyframe/smf_flutter_cli/commit/9911bf11bdfc654f284cdfaac5015b3ce690dee2))

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**(go_router,contracts): route merging, guard imports, AppRoutes and camelCase ([#26](https://github.com/saymyframe/smf_flutter_cli/issues/26)). ([abcedc5d](https://github.com/saymyframe/smf_flutter_cli/commit/abcedc5d7b1b704e1626b495f934e050382d9a2c))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

# Changelog

## [0.2.0] - 2025-09-01



### Chore
- Enable Melos (dev dep + melos.version settings). (cf61e67)


### Documentation
- Add comprehensive API documentation and copyright headers. (5d7a228)


### Features
- Add StateManager enum for bloc and riverpod support. (2ca5a99)

## [0.1.0] - 2025-09-01

- Initial version.
