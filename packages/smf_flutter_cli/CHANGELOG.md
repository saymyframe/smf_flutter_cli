## 0.4.0

> Note: This release has breaking changes.

 - **REFACTOR**(cli): take the hook request of an app of the matrix from the result of its case. ([dca8e7a5](https://github.com/saymyframe/smf_flutter_cli/commit/dca8e7a57beee67c1912c04641d9942a1dbcc88d))
 - **REFACTOR**(go_router): write AppShell with the name of the layout role ([#63](https://github.com/saymyframe/smf_flutter_cli/issues/63)). ([a1f8ed28](https://github.com/saymyframe/smf_flutter_cli/commit/a1f8ed28e19ffa88bd6dbe63678761139bdccc73))
 - **REFACTOR**(contracts,pipeline,cli): split the functions that SonarCloud finds too complex. ([c3f5aadc](https://github.com/saymyframe/smf_flutter_cli/commit/c3f5aadc0ea6cf6458aa189cdd2936d850c4d1b9))
 - **REFACTOR**(cli): split the two functions of the covering that SonarCloud finds too complex. ([eda050db](https://github.com/saymyframe/smf_flutter_cli/commit/eda050db531140a78dbffb12aa8814f4fda1d8ea))
 - **FIX**(cli): draw the frame of the closing note straight in every terminal ([#133](https://github.com/saymyframe/smf_flutter_cli/issues/133)). ([ba84f066](https://github.com/saymyframe/smf_flutter_cli/commit/ba84f066bf42ece456016dc957a833a541f638db))
 - **FIX**(contracts): keep one provider of analytics or crash reporting from failing the others. ([42c8db26](https://github.com/saymyframe/smf_flutter_cli/commit/42c8db26e9c68c8733bf2d4dcd9e4eb195d861ab))
 - **FIX**(contracts,shared_preferences): correct the texts for coding agents and the READMEs that the reviews found wrong ([#132](https://github.com/saymyframe/smf_flutter_cli/issues/132)). ([7f936e51](https://github.com/saymyframe/smf_flutter_cli/commit/7f936e51b2f2ae2f80eba144f5cf29ae5d7101f9))
 - **FIX**(ci): check that the apps start on devices without the connection of flutter test ([#48](https://github.com/saymyframe/smf_flutter_cli/issues/48)). ([05628617](https://github.com/saymyframe/smf_flutter_cli/commit/05628617185e55a75a3ad318570351ec067d6aa5))
 - **FIX**(cli,ci): stop a timed-out command before the processes it started, and annotate failed tests ([#54](https://github.com/saymyframe/smf_flutter_cli/issues/54)). ([a3fa33b2](https://github.com/saymyframe/smf_flutter_cli/commit/a3fa33b2a3729986299795fa0f7af1a5a5db54ca))
 - **FIX**(go_router): complete push() with the value of its page after a refresh ([#71](https://github.com/saymyframe/smf_flutter_cli/issues/71)). ([ae37c5de](https://github.com/saymyframe/smf_flutter_cli/commit/ae37c5de79b6d387ea3f392461d3ebf5c2c2b9d6))
 - **FIX**(contracts): leave out a provider of analytics or crash reporting that fails to be created. ([52d5b07b](https://github.com/saymyframe/smf_flutter_cli/commit/52d5b07b6804f1459eec52cbd6f880b4b1d57df7))
 - **FIX**(go_router): call each listener of the screen on its own. ([8b44ecd1](https://github.com/saymyframe/smf_flutter_cli/commit/8b44ecd1e02ca5aa01b12f0dbbaba4937c68972e))
 - **FIX**(contracts): say that on<T>() delivers the events fired once its stream is listened to. ([06668c45](https://github.com/saymyframe/smf_flutter_cli/commit/06668c45dd58e3d7de05b71f89c8eb474920ac5b))
 - **FIX**(contracts): give each analytics service a copy of its own of the parameters. ([21c6ca39](https://github.com/saymyframe/smf_flutter_cli/commit/21c6ca39980e3af0446b053dac01267fd26788de))
 - **FEAT**(contracts): remember the language of the app and let the user choose it in the settings ([#120](https://github.com/saymyframe/smf_flutter_cli/issues/120)). ([9f3c847b](https://github.com/saymyframe/smf_flutter_cli/commit/9f3c847bc372a9b6a1d852d7cf6da2a69f172afe))
 - **FEAT**(material_theme): add the module of the Material 3 theme ([#123](https://github.com/saymyframe/smf_flutter_cli/issues/123)). ([9801be57](https://github.com/saymyframe/smf_flutter_cli/commit/9801be57a9523db6cfa1a3ae2a29199c0dd2d0f9))
 - **FEAT**(bottom_tabs,material_theme): draw the bar of the tabs without an indicator, in the colours of the theme ([#136](https://github.com/saymyframe/smf_flutter_cli/issues/136)). ([23fcbb77](https://github.com/saymyframe/smf_flutter_cli/commit/23fcbb77e944a679bdaa391c885c2a76734c8648))
 - **FEAT**(onboarding): show the pages as cells of the periodic table, with motion ([#137](https://github.com/saymyframe/smf_flutter_cli/issues/137)). ([875e738a](https://github.com/saymyframe/smf_flutter_cli/commit/875e738a10c4a002588684119da265d37f9f7a11))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(shared_preferences): add the module that keeps the preferences with shared_preferences ([#113](https://github.com/saymyframe/smf_flutter_cli/issues/113)). ([170c9ff3](https://github.com/saymyframe/smf_flutter_cli/commit/170c9ff307d0bc7a766d4434ec0c46ef572fe6bf))
 - **FEAT**(contracts): add the guide for coding agents to the app entry role ([#110](https://github.com/saymyframe/smf_flutter_cli/issues/110)). ([92b78ad8](https://github.com/saymyframe/smf_flutter_cli/commit/92b78ad863e409806ce491ea463de45c01503030))
 - **FEAT**(settings): add the settings module, a screen for the entries of the modules ([#108](https://github.com/saymyframe/smf_flutter_cli/issues/108)). ([72264395](https://github.com/saymyframe/smf_flutter_cli/commit/722643958073a814660bbf51bd7eb4352dad40e7))
 - **FEAT**(contracts): add the preferences role for the settings of the app that are no secret ([#106](https://github.com/saymyframe/smf_flutter_cli/issues/106)). ([3304ebd2](https://github.com/saymyframe/smf_flutter_cli/commit/3304ebd267731bb624d61d13c5823ace4cfd5b45))
 - **FEAT**(cli): fan out the jobs of CI over a pairwise covering of the apps and shards of the matrices ([#76](https://github.com/saymyframe/smf_flutter_cli/issues/76)). ([423d6056](https://github.com/saymyframe/smf_flutter_cli/commit/423d60567ffaba2ef372eff6a4ef1dfe9c6e76dc))
 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**(material_theme): give the themes a palette, text styles and a bundled font ([#135](https://github.com/saymyframe/smf_flutter_cli/issues/135)). ([f9c6a279](https://github.com/saymyframe/smf_flutter_cli/commit/f9c6a279d9c5fd245d0dded9dca85e028455a934))
 - **FEAT**(home): welcome the developer of the app on the start screen ([#138](https://github.com/saymyframe/smf_flutter_cli/issues/138)). ([0f0c7c86](https://github.com/saymyframe/smf_flutter_cli/commit/0f0c7c864e8b3877c988e905450a968219be054a))
 - **FEAT**(cli): add the tests of the matrix to an app with every module by its name. ([eb20aa70](https://github.com/saymyframe/smf_flutter_cli/commit/eb20aa70053f25ee4ee1787a87865a9048f714e2))
 - **FEAT**(cli): run the probes of the tests of the roles in the start check. ([f7faea4e](https://github.com/saymyframe/smf_flutter_cli/commit/f7faea4e0f5c4553e7cc4f2bad9d12d6efba8ca2))
 - **FEAT**(cli): make an app whose tests must fail an app with every module of its registry. ([86aeabe7](https://github.com/saymyframe/smf_flutter_cli/commit/86aeabe7c23400e36120d36064abe74d72ae183c))
 - **FEAT**(settings,contracts): show the settings as one group, the theme modes as segments and the languages in a sheet ([#140](https://github.com/saymyframe/smf_flutter_cli/issues/140)). ([72a29d05](https://github.com/saymyframe/smf_flutter_cli/commit/72a29d05024e6a5f7326e1c446d9b6833d4a9054))
 - **FEAT**(cli): check that apps of the matrix fail as expected. ([e59e043c](https://github.com/saymyframe/smf_flutter_cli/commit/e59e043ca961d43c8a557f44260388be5f8ada4f))
 - **FEAT**(onboarding): add the onboarding of the first run ([#126](https://github.com/saymyframe/smf_flutter_cli/issues/126)). ([009d74d1](https://github.com/saymyframe/smf_flutter_cli/commit/009d74d11fad0840b883e5cd601872e4d6441700))
 - **FEAT**(pipeline): check that the code of modules takes the names of the classes of roles from the roles, in the fixtures too ([#86](https://github.com/saymyframe/smf_flutter_cli/issues/86)). ([64d130c8](https://github.com/saymyframe/smf_flutter_cli/commit/64d130c829fd87be8924773737237caf29be4923))
 - **FEAT**(contracts,settings): describe the settings screen in the guide for coding agents ([#129](https://github.com/saymyframe/smf_flutter_cli/issues/129)). ([f6353e4d](https://github.com/saymyframe/smf_flutter_cli/commit/f6353e4d8a864949a5b58ce78b8e3c4ddeff7175))
 - **FEAT**(firebase_crashlytics): fix the build phase of Crashlytics from its own module. ([4302a13c](https://github.com/saymyframe/smf_flutter_cli/commit/4302a13c2b7eb657e689f16fe51042eff7d117f7))
 - **FEAT**(cli): write files that the matrix generates from the data of the roles next to the app tests. ([62459045](https://github.com/saymyframe/smf_flutter_cli/commit/624590453f8948317a86e5040c0eef1d69397f23))
 - **FEAT**(settings): read the title of the settings screen in the language of the app ([#128](https://github.com/saymyframe/smf_flutter_cli/issues/128)). ([493dff7b](https://github.com/saymyframe/smf_flutter_cli/commit/493dff7bdb396a6d4ee89cb5220fad22fa9f68bc))
 - **FEAT**(pipeline): check the notes of roles against their providers, and require a note from every role and module ([#131](https://github.com/saymyframe/smf_flutter_cli/issues/131)). ([2980ddc1](https://github.com/saymyframe/smf_flutter_cli/commit/2980ddc13ff7a77be5122b4fe4515ebaa1e1eb70))
 - **FEAT**(gen_l10n): provide the localization role with gen-l10n of Flutter ([#117](https://github.com/saymyframe/smf_flutter_cli/issues/117)). ([36afeb32](https://github.com/saymyframe/smf_flutter_cli/commit/36afeb32e8e21c1a14fb4345bbbbcd252bd7260a))
 - **DOCS**: describe the probes of the roles that the start check runs on devices. ([64fa6e24](https://github.com/saymyframe/smf_flutter_cli/commit/64fa6e24b23db5569227cb02c419949529afbc9e))
 - **DOCS**: describe the plan of CI and the checks of the app tests as they are ([#81](https://github.com/saymyframe/smf_flutter_cli/issues/81)). ([629321e9](https://github.com/saymyframe/smf_flutter_cli/commit/629321e9fb7a4632818d04aa556e73f1c1e3d747))
 - **DOCS**(cli): show the generated app in the READMEs and among the screenshots on pub.dev ([#141](https://github.com/saymyframe/smf_flutter_cli/issues/141)). ([76fef2e2](https://github.com/saymyframe/smf_flutter_cli/commit/76fef2e23be7731095d652f81c41737aa04a1ee0))
 - **BREAKING** **TEST**(cli): run the app tests with the platform mocks of every module of the app, next to other providers of their roles ([#75](https://github.com/saymyframe/smf_flutter_cli/issues/75)). ([87001859](https://github.com/saymyframe/smf_flutter_cli/commit/87001859841890e28f3a9ab2ba685ee32c9bdd87))
 - **BREAKING** **REFACTOR**(cli): group the apps that runMatrix and createEveryModuleApps take into one parameter each ([#97](https://github.com/saymyframe/smf_flutter_cli/issues/97)). ([d60801f2](https://github.com/saymyframe/smf_flutter_cli/commit/d60801f2871dd68eea6b8dddc5339462e02ed280))
 - **BREAKING** **FEAT**(contracts): continue a post-generation step of another module by its id ([#89](https://github.com/saymyframe/smf_flutter_cli/issues/89)). ([cfce8114](https://github.com/saymyframe/smf_flutter_cli/commit/cfce8114f4c1299d98ea3150695c79ae8c8065c8))
 - **BREAKING** **FEAT**(pipeline): build the cases of the roles a module uses with each of their providers ([#88](https://github.com/saymyframe/smf_flutter_cli/issues/88)). ([f5ecbb45](https://github.com/saymyframe/smf_flutter_cli/commit/f5ecbb45eb715f4237a57fb57bef124ef73a6b4a))
 - **BREAKING** **FEAT**(contracts): drop the factory parameters of the DI role ([#64](https://github.com/saymyframe/smf_flutter_cli/issues/64)). ([0c8bc398](https://github.com/saymyframe/smf_flutter_cli/commit/0c8bc3981842e961f69cb4b21a0b26a10feca74d))
 - **BREAKING** **FEAT**(contracts): keep the platforms of the app in AppIdentity ([#58](https://github.com/saymyframe/smf_flutter_cli/issues/58)). ([eb1225ce](https://github.com/saymyframe/smf_flutter_cli/commit/eb1225cea24a9a4e6d5cc0375532ada7d71af96a))
 - **BREAKING** **FEAT**(contracts,flutter_core,home,onboarding,settings): take the symbol of the app and the icons of the status bar from one place each ([#143](https://github.com/saymyframe/smf_flutter_cli/issues/143)). ([43a87a36](https://github.com/saymyframe/smf_flutter_cli/commit/43a87a36c3d847dc1398f415ec64de46a3a1a177))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))
 - **BREAKING** **FEAT**(contracts): require resetDependencies() of the providers of the DI role. ([9911bf11](https://github.com/saymyframe/smf_flutter_cli/commit/9911bf11bdfc654f284cdfaac5015b3ce690dee2))

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**(firebase_analytics): add bloc and riverpod variants of the demo feature ([#24](https://github.com/saymyframe/smf_flutter_cli/issues/24)). ([52212678](https://github.com/saymyframe/smf_flutter_cli/commit/52212678b9bf3bb825cbcf8f86df7953d7dad36e))
 - **FIX**(cli): print the real version in smf --version ([#25](https://github.com/saymyframe/smf_flutter_cli/issues/25)). ([ad569837](https://github.com/saymyframe/smf_flutter_cli/commit/ad569837614518f18f216de17d80ee48f9b0fb83))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

## 0.2.1+1

 - **FIX**(safe-write): correct project name in safe write. ([e1cdb985](https://github.com/saymyframe/smf_flutter_cli/commit/e1cdb98564f302c25485418c1c42f04d8c497524))

## 0.2.1

 - **FIX**: add extra space between emoji and message. ([#11](https://github.com/saymyframe/smf_flutter_cli/issues/11)). ([84535ff4](https://github.com/saymyframe/smf_flutter_cli/commit/84535ff47ac322e587ef3921372060f94f9fd443))
 - **FEAT**: improve UX when cli stop with an error. ([f770f643](https://github.com/saymyframe/smf_flutter_cli/commit/f770f64307515a0ce9252d7c4fd55a3a1d082c84))
 - **FEAT**: firebase crashlytics module. ([9679223f](https://github.com/saymyframe/smf_flutter_cli/commit/9679223f6f635e3d98a88fa671fc9fb6ff1c30fb))

## 0.2.0

> Note: This release has breaking changes.

 - **FIX**(prompt): avoid crash when no module provides an initial route. ([9c295b99](https://github.com/saymyframe/smf_flutter_cli/commit/9c295b997c903792cbafda7ffb7aefcaa0907d5c))
 - **FEAT**: app post gen cta message. ([2bfb7f46](https://github.com/saymyframe/smf_flutter_cli/commit/2bfb7f467c7df6472a756e9f307185d0ad9ff6cb))
 - **FEAT**: app post gen cta message. ([5a714024](https://github.com/saymyframe/smf_flutter_cli/commit/5a71402475e1c022caacb143d4d1c34332b7a28b))
 - **FEAT**: add safe write mechanism. ([e174323a](https://github.com/saymyframe/smf_flutter_cli/commit/e174323a77a297febc13ba1285e992c3f015f297))
 - **DOCS**: add comprehensive API documentation and fix linting issues. ([50dac3d6](https://github.com/saymyframe/smf_flutter_cli/commit/50dac3d656302140dc3191b8e21f104890818a6a))
 - **DOCS**: add comprehensive API documentation and copyright headers. ([5872d386](https://github.com/saymyframe/smf_flutter_cli/commit/5872d3860e5035bd74005f464b77093bd55a58b8))
 - **BREAKING** **FEAT**(cli): adopt factories with ModuleCreator; add --strict and verbose dep logs ([#3](https://github.com/saymyframe/smf_flutter_cli/issues/3)). ([2a669b81](https://github.com/saymyframe/smf_flutter_cli/commit/2a669b8138c4e742622de36741d6d96229b214d2))

## 0.1.0

- Initial version.
