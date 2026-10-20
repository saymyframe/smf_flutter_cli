## 0.6.0

> Note: This release has breaking changes.

 - **REFACTOR**(contracts): split the checks of the ways to sign in that SonarCloud finds too complex ([#228](https://github.com/saymyframe/smf_flutter_cli/issues/228)). ([bc6709e5](https://github.com/saymyframe/smf_flutter_cli/commit/bc6709e512b306b955bfb64c7daf9951b92afb40))
 - **FEAT**(contracts): the README section "Finish the setup" ([#232](https://github.com/saymyframe/smf_flutter_cli/issues/232)). ([d2114702](https://github.com/saymyframe/smf_flutter_cli/commit/d21147029fedb43e1b8b7f97898096403efd936f))
 - **FEAT**(sign_in): continue with the sign-in methods of the app ([#219](https://github.com/saymyframe/smf_flutter_cli/issues/219)). ([5c2a7051](https://github.com/saymyframe/smf_flutter_cli/commit/5c2a705198ce2e6ad525ed40983e3d8ce5c53db0))
 - **FEAT**(firebase_auth): sign in, link and delete with the credentials of the sign-in methods ([#205](https://github.com/saymyframe/smf_flutter_cli/issues/205)). ([caf1e446](https://github.com/saymyframe/smf_flutter_cli/commit/caf1e446f337171ec212aab9ae82a23b2bad18e9))
 - **FEAT**(contracts): add the push role with the address of the device, its messages and their taps ([#193](https://github.com/saymyframe/smf_flutter_cli/issues/193)). ([1f1a3566](https://github.com/saymyframe/smf_flutter_cli/commit/1f1a3566781392561d7488da6bd8edd95a5b17a3))
 - **FEAT**(contracts): give every app the icons of the status bar as a widget of its own, with a widget test ([#191](https://github.com/saymyframe/smf_flutter_cli/issues/191)). ([4ab6b288](https://github.com/saymyframe/smf_flutter_cli/commit/4ab6b288cd00e6b94a0a4a27d1440480e21d4a30))
 - **FEAT**(contracts): add the notifications role with the permission, showing, scheduling and taps ([#189](https://github.com/saymyframe/smf_flutter_cli/issues/189)). ([26dff4e9](https://github.com/saymyframe/smf_flutter_cli/commit/26dff4e90c6920dc553f4f77c120a3fafec32ccf))
 - **FEAT**(contracts): add the onboarding screen role, to which modules add the steps of the onboarding ([#185](https://github.com/saymyframe/smf_flutter_cli/issues/185)). ([04c269ce](https://github.com/saymyframe/smf_flutter_cli/commit/04c269ceb3003a7993699dc822c25771a8273eae))
 - **BREAKING** **FEAT**(contracts,apple_sign_in): the App ID among the steps by hand ([#234](https://github.com/saymyframe/smf_flutter_cli/issues/234)). ([e0b73a02](https://github.com/saymyframe/smf_flutter_cli/commit/e0b73a0295316ec57d8a50ec8336d076a1182f87))
 - **BREAKING** **FEAT**(contracts,pipeline): steps of an app that its developer does by hand ([#230](https://github.com/saymyframe/smf_flutter_cli/issues/230)). ([542e1089](https://github.com/saymyframe/smf_flutter_cli/commit/542e1089bed294361086f39191529267ab652b95))
 - **BREAKING** **FEAT**(contracts): let modules add components to the Android application ([#201](https://github.com/saymyframe/smf_flutter_cli/issues/201)). ([6dfcaec9](https://github.com/saymyframe/smf_flutter_cli/commit/6dfcaec92bf72dea1922940ea6834b564c24118a))
 - **BREAKING** **FEAT**(contracts): let modules run code in the AppDelegate before launch finishes ([#200](https://github.com/saymyframe/smf_flutter_cli/issues/200)). ([263b3079](https://github.com/saymyframe/smf_flutter_cli/commit/263b307907e85ea4aee51d7c1fa6330712b6cd1f))
 - **BREAKING** **FEAT**(contracts): let modules enable core library desugaring of the Android app ([#199](https://github.com/saymyframe/smf_flutter_cli/issues/199)). ([7f760ba7](https://github.com/saymyframe/smf_flutter_cli/commit/7f760ba7d53081d6023607b045cca7e185d09787))
 - **BREAKING** **FEAT**(contracts): sign in with a credential of an identity provider, and list the ways to sign in of an app ([#197](https://github.com/saymyframe/smf_flutter_cli/issues/197)). ([73e8a21c](https://github.com/saymyframe/smf_flutter_cli/commit/73e8a21cb3807482f53a161baf1b9b0717aea5e4))
 - **BREAKING** **FEAT**(flutter_core): give the fallback start screen only to an app that no route starts ([#192](https://github.com/saymyframe/smf_flutter_cli/issues/192)). ([9cc0a8f1](https://github.com/saymyframe/smf_flutter_cli/commit/9cc0a8f19515e003b50778cb1c5a627aa1f1daa5))
 - **BREAKING** **FEAT**(contracts): give each warning about the app a code, and let a choice report one ([#188](https://github.com/saymyframe/smf_flutter_cli/issues/188)). ([80f2c7ed](https://github.com/saymyframe/smf_flutter_cli/commit/80f2c7edd737e63ea3085b8202bb04a9bc9c4b7b))
 - **BREAKING** **FEAT**(contracts): sign the iOS app with Runner.entitlements and let modules add entitlements ([#187](https://github.com/saymyframe/smf_flutter_cli/issues/187)). ([2f2b0374](https://github.com/saymyframe/smf_flutter_cli/commit/2f2b037442262cec28376137bf2fe35b8adf2852))
 - **BREAKING** **FEAT**(contracts): let a contribution and a symbol of a role depend on what a role chose ([#184](https://github.com/saymyframe/smf_flutter_cli/issues/184)). ([d5deac8e](https://github.com/saymyframe/smf_flutter_cli/commit/d5deac8ef366a40d24b74bb77ae444cf6ced274f))

## 0.5.0

> Note: This release has breaking changes.

 - **FIX**(contracts,go_router): open a page of the flow of a condition over the start screen when a link asks for it ([#166](https://github.com/saymyframe/smf_flutter_cli/issues/166)). ([0c42e365](https://github.com/saymyframe/smf_flutter_cli/commit/0c42e36578dac19accdf3767c7a00a299f50fbf2))
 - **FIX**(go_router): show what push() and replace() ask for when go_router shows its error screen alone ([#165](https://github.com/saymyframe/smf_flutter_cli/issues/165)). ([c55c01e2](https://github.com/saymyframe/smf_flutter_cli/commit/c55c01e2c74ec839e11cef3d5a1bf8a07a7cbc5e))
 - **FIX**(go_router): keep the back button of the system from throwing on the error screen ([#161](https://github.com/saymyframe/smf_flutter_cli/issues/161)). ([5a933e9f](https://github.com/saymyframe/smf_flutter_cli/commit/5a933e9fd848545f747ea4c91749a7d8bcf7a6c7))
 - **FIX**(go_router): drop the pages of every branch when a guard closes and opens in one turn ([#157](https://github.com/saymyframe/smf_flutter_cli/issues/157)). ([976dbad8](https://github.com/saymyframe/smf_flutter_cli/commit/976dbad8458eda9cbaf2dfdb8b48b5008294362b))
 - **FIX**(pipeline): check the machine for a module after the modules it depends on ([#151](https://github.com/saymyframe/smf_flutter_cli/issues/151)). ([494c1eb0](https://github.com/saymyframe/smf_flutter_cli/commit/494c1eb0839d4fba35eac6dca80203d416cabd9d))
 - **FEAT**(contracts): warn of the destinations of an app without a main navigation ([#175](https://github.com/saymyframe/smf_flutter_cli/issues/175)). ([39a624ba](https://github.com/saymyframe/smf_flutter_cli/commit/39a624ba72cb4d4c878409f46bb8b266820d3ebd))
 - **FEAT**(contracts): say how the auth role writes the mode of the app, for a tool that reads it ([#167](https://github.com/saymyframe/smf_flutter_cli/issues/167)). ([c61033c6](https://github.com/saymyframe/smf_flutter_cli/commit/c61033c65a401179eea8c5452e387b44a688047a))
 - **FEAT**(contracts): publish the account condition of the auth role, and warn when no guard stands for it ([#156](https://github.com/saymyframe/smf_flutter_cli/issues/156)). ([b35edee1](https://github.com/saymyframe/smf_flutter_cli/commit/b35edee1dc1838bc960defd4047793fcd7a78f46))
 - **FEAT**(contracts): a condition that only some routes ask for ([#155](https://github.com/saymyframe/smf_flutter_cli/issues/155)). ([9c239fe1](https://github.com/saymyframe/smf_flutter_cli/commit/9c239fe105f8adbc30ae9c98cab63b26e1c234ed))
 - **FEAT**(contracts): add the auth role with the session, the mode and the service of a provider ([#153](https://github.com/saymyframe/smf_flutter_cli/issues/153)). ([3063e085](https://github.com/saymyframe/smf_flutter_cli/commit/3063e085e900eda5b8e9ed41b413165864d1cfeb))
 - **FEAT**(contracts,pipeline): let a role option have modes, with a case of the harness for each ([#149](https://github.com/saymyframe/smf_flutter_cli/issues/149)). ([4fd6a70f](https://github.com/saymyframe/smf_flutter_cli/commit/4fd6a70fef36a8272c8565b8d0b2dea543b3d983))
 - **FEAT**(contracts,pipeline): a post-generation step that continues another may ask its own question ([#147](https://github.com/saymyframe/smf_flutter_cli/issues/147)). ([434fbb27](https://github.com/saymyframe/smf_flutter_cli/commit/434fbb27562d9085ad1d1a33061d8d872c3dab17))
 - **BREAKING** **FEAT**(contracts,go_router): open the flow of a condition over the screen the user is on ([#163](https://github.com/saymyframe/smf_flutter_cli/issues/163)). ([b7f7e655](https://github.com/saymyframe/smf_flutter_cli/commit/b7f7e655374c8109c1daf255cdb43c80a6dc4c67))
 - **BREAKING** **FEAT**(contracts,onboarding): say when a guard is asked and whether it brings the user back ([#152](https://github.com/saymyframe/smf_flutter_cli/issues/152)). ([7b12df77](https://github.com/saymyframe/smf_flutter_cli/commit/7b12df77edbc4a785ae192b8c16bbca0523197ac))
 - **BREAKING** **FEAT**(contracts,onboarding): close the flow of a guard that allows ([#150](https://github.com/saymyframe/smf_flutter_cli/issues/150)). ([731e53f9](https://github.com/saymyframe/smf_flutter_cli/commit/731e53f9bf3c7147f8fa8c6e781788b1ee67b47f))

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
