## 0.7.0

> Note: This release has breaking changes.

 - **REFACTOR**(cli): give addAppTestsTo the file of the values of CI and its mask as one parameter, which SonarCloud finds too many apart. ([8319c535](https://github.com/saymyframe/smf_flutter_cli/commit/8319c535170d1e7671cab16cb73755c058bbc642))
 - **REFACTOR**(cli): split the functions of the matrix that SonarCloud finds too complex. ([e42e9c9f](https://github.com/saymyframe/smf_flutter_cli/commit/e42e9c9f35eb3c9cc1cbb9df2db4ef2f086aa380))
 - **REFACTOR**(contracts,pipeline,cli,sign_in): split the functions that SonarCloud finds too complex ([#240](https://github.com/saymyframe/smf_flutter_cli/issues/240)). ([7055060d](https://github.com/saymyframe/smf_flutter_cli/commit/7055060df967273c99faa10f381fcca99b19955b))
 - **FIX**(contracts): call the env role the env role in messages, not the values in .env role ([#277](https://github.com/saymyframe/smf_flutter_cli/issues/277)). ([90d58df8](https://github.com/saymyframe/smf_flutter_cli/commit/90d58df8d407de3a6058e7b2b9c39c293fc94ec9))
 - **FIX**(firebase_analytics): turn off the screen views that Firebase logs itself ([#273](https://github.com/saymyframe/smf_flutter_cli/issues/273)). ([e90566e0](https://github.com/saymyframe/smf_flutter_cli/commit/e90566e03115e3c61a12984adf6f1e83a8b3d9cb))
 - **FIX**(sign_in): measure the words of a text between every white space but a no-break space, and check where its lines start ([#267](https://github.com/saymyframe/smf_flutter_cli/issues/267)). ([597b5c5f](https://github.com/saymyframe/smf_flutter_cli/commit/597b5c5f9b07f8e1c135eb202a5a2b8ddbfeb839))
 - **FIX**(onboarding): break the titles of the onboarding between words on a small phone with a large text size ([#266](https://github.com/saymyframe/smf_flutter_cli/issues/266)). ([f93373c8](https://github.com/saymyframe/smf_flutter_cli/commit/f93373c8cd343c61f9f1db58202ed21be379749e))
 - **FIX**(contracts): let a call made before the first start of a controller wait in its own zone ([#257](https://github.com/saymyframe/smf_flutter_cli/issues/257)). ([994cb3a6](https://github.com/saymyframe/smf_flutter_cli/commit/994cb3a6c670a6c0219aa9e6e5c91605c1325c87))
 - **FIX**(google_sign_in): let a sign-in after the start of google_sign_in wait in its own zone ([#256](https://github.com/saymyframe/smf_flutter_cli/issues/256)). ([872b148d](https://github.com/saymyframe/smf_flutter_cli/commit/872b148d875c9c32cfe70399a8459c71bcc8f79d))
 - **FEAT**(paywall): add the paywall, its guard of premium and the subscription screen, in a bloc and a riverpod variant ([#265](https://github.com/saymyframe/smf_flutter_cli/issues/265)). ([e65f88ba](https://github.com/saymyframe/smf_flutter_cli/commit/e65f88ba07965ca3923026f3c8aaa7fbc155b1a2))
 - **FEAT**(revenuecat): add RevenueCat as the provider of the purchases role ([#260](https://github.com/saymyframe/smf_flutter_cli/issues/260)). ([f5019461](https://github.com/saymyframe/smf_flutter_cli/commit/f50194614da578baeb86cc2c016946b2bda235db))
 - **FEAT**(dart_define): provide the env role with --dart-define-from-file ([#258](https://github.com/saymyframe/smf_flutter_cli/issues/258)). ([d74bac6d](https://github.com/saymyframe/smf_flutter_cli/commit/d74bac6d3708bfd40e21ddc8db7f6ddd56d41a76))
 - **FEAT**(contracts): say in the README of every app that Say My Frame generated it ([#239](https://github.com/saymyframe/smf_flutter_cli/issues/239)). ([a1e47e53](https://github.com/saymyframe/smf_flutter_cli/commit/a1e47e531aa1e0adbbf9aee74fc4e79402b6ac92))
 - **DOCS**(cli): show the recordings of 0.7 in the READMEs and on pub.dev, and list dart_define, revenuecat and paywall ([#276](https://github.com/saymyframe/smf_flutter_cli/issues/276)). ([64f7e866](https://github.com/saymyframe/smf_flutter_cli/commit/64f7e866f606dfb102a88ad71fc2f1f580bc6427))
 - **DOCS**(paywall): say that the paywall has its close button only over a page. ([c25bfdc6](https://github.com/saymyframe/smf_flutter_cli/commit/c25bfdc6e34c8d83dc7473357e9548794eabae70))
 - **DOCS**(revenuecat): tell that a lifetime plan of Google Play is Non-consumable in RevenueCat. ([352737c6](https://github.com/saymyframe/smf_flutter_cli/commit/352737c630362a263aa3f3b4f663ebf08ddb1259))
 - **DOCS**(revenuecat): name the default offering of RevenueCat in the step by hand and in the READMEs. ([41aa5fff](https://github.com/saymyframe/smf_flutter_cli/commit/41aa5fff56d271622bd53b5ff6021d89c2862174))
 - **BREAKING** **FEAT**(contracts): add the stage offer of the onboarding steps and give the action of a step the context of the onboarding screen ([#247](https://github.com/saymyframe/smf_flutter_cli/issues/247)). ([d054df6f](https://github.com/saymyframe/smf_flutter_cli/commit/d054df6f197d5891c6316167c76f467394465afc))

## 0.6.0

> Note: This release has breaking changes.

 - **REFACTOR**(pipeline,cli): split the functions that SonarCloud finds too complex ([#229](https://github.com/saymyframe/smf_flutter_cli/issues/229)). ([7ebe3a31](https://github.com/saymyframe/smf_flutter_cli/commit/7ebe3a3157ffab1079ab62500f64efc22e1c39fc))
 - **FIX**(sign_in): let the pages of the sign-in scroll under the bar of the home gesture ([#223](https://github.com/saymyframe/smf_flutter_cli/issues/223)). ([9faac56b](https://github.com/saymyframe/smf_flutter_cli/commit/9faac56bec27d7a2038484529241f0a8618e9fa7))
 - **FIX**(firebase_auth): need Firebase CLI 15.34.0, which adds no web app to a project that has apps ([#182](https://github.com/saymyframe/smf_flutter_cli/issues/182)). ([8afc173a](https://github.com/saymyframe/smf_flutter_cli/commit/8afc173a846a6cf6ae3eea227615b902e416932e))
 - **FEAT**(cli): web addresses of the output are links of the terminal ([#237](https://github.com/saymyframe/smf_flutter_cli/issues/237)). ([dad45266](https://github.com/saymyframe/smf_flutter_cli/commit/dad45266f95c773b07f55c14f6ccad20f32dc0f2))
 - **FEAT**(firebase_auth,firebase_analytics): the steps by hand of Apple, Google Play and Analytics ([#236](https://github.com/saymyframe/smf_flutter_cli/issues/236)). ([e009ede2](https://github.com/saymyframe/smf_flutter_cli/commit/e009ede2c1b205763ef4ad05455defb8fcdf8b9e))
 - **FEAT**(firebase_messaging): the APNs key among the steps by hand ([#235](https://github.com/saymyframe/smf_flutter_cli/issues/235)). ([b1e02466](https://github.com/saymyframe/smf_flutter_cli/commit/b1e024661876640c0a88fd35ac99e756e2477299))
 - **FEAT**(cli): the guide of the steps by hand and its catalog ([#233](https://github.com/saymyframe/smf_flutter_cli/issues/233)). ([a744ff20](https://github.com/saymyframe/smf_flutter_cli/commit/a744ff20e7adbb031aa845ff518aee1832ce49b1))
 - **FEAT**(sign_in): continue with the sign-in methods of the app ([#219](https://github.com/saymyframe/smf_flutter_cli/issues/219)). ([5c2a7051](https://github.com/saymyframe/smf_flutter_cli/commit/5c2a705198ce2e6ad525ed40983e3d8ce5c53db0))
 - **FEAT**(google_sign_in): add sign-in with Google ([#216](https://github.com/saymyframe/smf_flutter_cli/issues/216)). ([231156eb](https://github.com/saymyframe/smf_flutter_cli/commit/231156ebe66206968d27022fcff3d6c08e3d03be))
 - **FEAT**(firebase_auth): enable Google, register the debug key and write the URL scheme for the methods of the app ([#214](https://github.com/saymyframe/smf_flutter_cli/issues/214)). ([313fc8c9](https://github.com/saymyframe/smf_flutter_cli/commit/313fc8c98e0a3c48f74b13ad145efaecc0ce5ecb))
 - **FEAT**(firebase_messaging): add Firebase Cloud Messaging as the provider of the push role ([#210](https://github.com/saymyframe/smf_flutter_cli/issues/210)). ([5bbbfa9a](https://github.com/saymyframe/smf_flutter_cli/commit/5bbbfa9ad0835e2344f3241a3f364110796b874e))
 - **FEAT**(apple_sign_in): add Sign in with Apple on iOS ([#212](https://github.com/saymyframe/smf_flutter_cli/issues/212)). ([79b7c4e4](https://github.com/saymyframe/smf_flutter_cli/commit/79b7c4e44294b3c104e45ca474d2e84eac83ec90))
 - **FEAT**(local_notifications): add a provider of the notifications role on flutter_local_notifications ([#206](https://github.com/saymyframe/smf_flutter_cli/issues/206)). ([d16e9a43](https://github.com/saymyframe/smf_flutter_cli/commit/d16e9a4349cf578660660b535744b66490995fb6))
 - **FEAT**(firebase_auth): sign in, link and delete with the credentials of the sign-in methods ([#205](https://github.com/saymyframe/smf_flutter_cli/issues/205)). ([caf1e446](https://github.com/saymyframe/smf_flutter_cli/commit/caf1e446f337171ec212aab9ae82a23b2bad18e9))
 - **FEAT**(onboarding): show the steps that the modules of the app add to the onboarding ([#203](https://github.com/saymyframe/smf_flutter_cli/issues/203)). ([32652cbf](https://github.com/saymyframe/smf_flutter_cli/commit/32652cbf289502cce513a2e2c9a7720d0791fa1c))
 - **FEAT**(contracts): give every app the icons of the status bar as a widget of its own, with a widget test ([#191](https://github.com/saymyframe/smf_flutter_cli/issues/191)). ([4ab6b288](https://github.com/saymyframe/smf_flutter_cli/commit/4ab6b288cd00e6b94a0a4a27d1440480e21d4a30))
 - **DOCS**(cli): show the recordings of 0.6 in the READMEs and on pub.dev ([#224](https://github.com/saymyframe/smf_flutter_cli/issues/224)). ([c517cf2f](https://github.com/saymyframe/smf_flutter_cli/commit/c517cf2f6dabef70cd043174456a2bdb7c06d8d1))
 - **BREAKING** **FEAT**(contracts,apple_sign_in): the App ID among the steps by hand ([#234](https://github.com/saymyframe/smf_flutter_cli/issues/234)). ([e0b73a02](https://github.com/saymyframe/smf_flutter_cli/commit/e0b73a0295316ec57d8a50ec8336d076a1182f87))
 - **BREAKING** **FEAT**(contracts): let modules run code in the AppDelegate before launch finishes ([#200](https://github.com/saymyframe/smf_flutter_cli/issues/200)). ([263b3079](https://github.com/saymyframe/smf_flutter_cli/commit/263b307907e85ea4aee51d7c1fa6330712b6cd1f))
 - **BREAKING** **FEAT**(contracts): sign in with a credential of an identity provider, and list the ways to sign in of an app ([#197](https://github.com/saymyframe/smf_flutter_cli/issues/197)). ([73e8a21c](https://github.com/saymyframe/smf_flutter_cli/commit/73e8a21cb3807482f53a161baf1b9b0717aea5e4))
 - **BREAKING** **FEAT**(flutter_core): give the fallback start screen only to an app that no route starts ([#192](https://github.com/saymyframe/smf_flutter_cli/issues/192)). ([9cc0a8f1](https://github.com/saymyframe/smf_flutter_cli/commit/9cc0a8f19515e003b50778cb1c5a627aa1f1daa5))
 - **BREAKING** **FEAT**(pipeline): stop a --strict run on a warning about what the app is made of ([#190](https://github.com/saymyframe/smf_flutter_cli/issues/190)). ([530c4f88](https://github.com/saymyframe/smf_flutter_cli/commit/530c4f8865b3b8de5c9672e4f3c78ea802951af1))
 - **BREAKING** **FEAT**(contracts): give each warning about the app a code, and let a choice report one ([#188](https://github.com/saymyframe/smf_flutter_cli/issues/188)). ([80f2c7ed](https://github.com/saymyframe/smf_flutter_cli/commit/80f2c7edd737e63ea3085b8202bb04a9bc9c4b7b))
 - **BREAKING** **FEAT**(contracts): sign the iOS app with Runner.entitlements and let modules add entitlements ([#187](https://github.com/saymyframe/smf_flutter_cli/issues/187)). ([2f2b0374](https://github.com/saymyframe/smf_flutter_cli/commit/2f2b037442262cec28376137bf2fe35b8adf2852))

## 0.5.1

 - **FIX**(shared_preferences): keep shared_preferences_android below 2.5.0, whose release builds fail to open the preferences ([#204](https://github.com/saymyframe/smf_flutter_cli/issues/204)). ([2ddbaed2](https://github.com/saymyframe/smf_flutter_cli/commit/2ddbaed27da0031c144abb606c6d192a94a3eda8))

## 0.5.0

> Note: This release has breaking changes.

 - **FIX**(contracts,go_router): open a page of the flow of a condition over the start screen when a link asks for it ([#166](https://github.com/saymyframe/smf_flutter_cli/issues/166)). ([0c42e365](https://github.com/saymyframe/smf_flutter_cli/commit/0c42e36578dac19accdf3767c7a00a299f50fbf2))
 - **FIX**(go_router): show what push() and replace() ask for when go_router shows its error screen alone ([#165](https://github.com/saymyframe/smf_flutter_cli/issues/165)). ([c55c01e2](https://github.com/saymyframe/smf_flutter_cli/commit/c55c01e2c74ec839e11cef3d5a1bf8a07a7cbc5e))
 - **FIX**(go_router): keep the back button of the system from throwing on the error screen ([#161](https://github.com/saymyframe/smf_flutter_cli/issues/161)). ([5a933e9f](https://github.com/saymyframe/smf_flutter_cli/commit/5a933e9fd848545f747ea4c91749a7d8bcf7a6c7))
 - **FIX**(go_router): drop the pages of every branch when a guard closes and opens in one turn ([#157](https://github.com/saymyframe/smf_flutter_cli/issues/157)). ([976dbad8](https://github.com/saymyframe/smf_flutter_cli/commit/976dbad8458eda9cbaf2dfdb8b48b5008294362b))
 - **FEAT**(pipeline): list the steps left for later after the app is created, without a warning ([#176](https://github.com/saymyframe/smf_flutter_cli/issues/176)). ([571c0ace](https://github.com/saymyframe/smf_flutter_cli/commit/571c0acea10fc246ca3cb8dd81b2446d1ed9a00a))
 - **FEAT**(contracts): warn of the destinations of an app without a main navigation ([#175](https://github.com/saymyframe/smf_flutter_cli/issues/175)). ([39a624ba](https://github.com/saymyframe/smf_flutter_cli/commit/39a624ba72cb4d4c878409f46bb8b266820d3ebd))
 - **FEAT**(bloc,riverpod): tell in the agent note how a screen, shared state and an awaited call are written ([#172](https://github.com/saymyframe/smf_flutter_cli/issues/172)). ([6f819423](https://github.com/saymyframe/smf_flutter_cli/commit/6f8194238bcb957d19409d3acf867445e2b3989e))
 - **FEAT**(sign_in): add the account screen and the entry of the settings screen that leads to it ([#171](https://github.com/saymyframe/smf_flutter_cli/issues/171)). ([4d7fac2b](https://github.com/saymyframe/smf_flutter_cli/commit/4d7fac2bf04907ce9c9474b5accbca1247d3fed3))
 - **FEAT**(sign_in): add the module with the screens of sign-in, sign-up and password reset, in a bloc and a riverpod variant ([#170](https://github.com/saymyframe/smf_flutter_cli/issues/170)). ([bfcd9025](https://github.com/saymyframe/smf_flutter_cli/commit/bfcd9025f26b607315846995ed1a2006930a7a0f))
 - **FEAT**(firebase_auth): enable the sign-in methods in Firebase after flutterfire configure ([#168](https://github.com/saymyframe/smf_flutter_cli/issues/168)). ([1d4a1c27](https://github.com/saymyframe/smf_flutter_cli/commit/1d4a1c27b1ea1f63ef866081dbdaa5e5f3e49275))
 - **FEAT**(contracts): say how the auth role writes the mode of the app, for a tool that reads it ([#167](https://github.com/saymyframe/smf_flutter_cli/issues/167)). ([c61033c6](https://github.com/saymyframe/smf_flutter_cli/commit/c61033c65a401179eea8c5452e387b44a688047a))
 - **FEAT**(firebase_auth): provide the auth role with Firebase Authentication ([#162](https://github.com/saymyframe/smf_flutter_cli/issues/162)). ([c541d0d4](https://github.com/saymyframe/smf_flutter_cli/commit/c541d0d4b3ae3a23a148d61293c41338a1bf27a1))
 - **FEAT**(material_theme): give text fields the look of the theme ([#160](https://github.com/saymyframe/smf_flutter_cli/issues/160)). ([2d1d6a24](https://github.com/saymyframe/smf_flutter_cli/commit/2d1d6a2446b29a5a5486aba0a97d34909589186b))
 - **FEAT**(contracts): a condition that only some routes ask for ([#155](https://github.com/saymyframe/smf_flutter_cli/issues/155)). ([9c239fe1](https://github.com/saymyframe/smf_flutter_cli/commit/9c239fe105f8adbc30ae9c98cab63b26e1c234ed))
 - **FEAT**(cli): give the modes of a role option their apps with every module ([#154](https://github.com/saymyframe/smf_flutter_cli/issues/154)). ([19384819](https://github.com/saymyframe/smf_flutter_cli/commit/193848190a66b3301dfc20b4f430ae7e82a62519))
 - **DOCS**(cli): name sign-in in the description of the package ([#177](https://github.com/saymyframe/smf_flutter_cli/issues/177)). ([b137f4dd](https://github.com/saymyframe/smf_flutter_cli/commit/b137f4dd35dfd4d646598b5d99540cc55e8a6913))
 - **DOCS**(cli): show the run of smf create with sign-in and the screens of sign-in in the READMEs and on pub.dev ([#174](https://github.com/saymyframe/smf_flutter_cli/issues/174)). ([e6bbea1f](https://github.com/saymyframe/smf_flutter_cli/commit/e6bbea1fd52f61d6cc14215774e590ac7c01a011))
 - **DOCS**(cli): show the run of smf create of 0.4 in the READMEs and in the screenshot ([#145](https://github.com/saymyframe/smf_flutter_cli/issues/145)). ([1da4e3ac](https://github.com/saymyframe/smf_flutter_cli/commit/1da4e3aca5bf70168aa41869d6ad8086d7edf594))
 - **BREAKING** **FEAT**(contracts,go_router): open the flow of a condition over the screen the user is on ([#163](https://github.com/saymyframe/smf_flutter_cli/issues/163)). ([b7f7e655](https://github.com/saymyframe/smf_flutter_cli/commit/b7f7e655374c8109c1daf255cdb43c80a6dc4c67))
 - **BREAKING** **FEAT**(contracts,onboarding): say when a guard is asked and whether it brings the user back ([#152](https://github.com/saymyframe/smf_flutter_cli/issues/152)). ([7b12df77](https://github.com/saymyframe/smf_flutter_cli/commit/7b12df77edbc4a785ae192b8c16bbca0523197ac))
 - **BREAKING** **FEAT**(contracts,onboarding): close the flow of a guard that allows ([#150](https://github.com/saymyframe/smf_flutter_cli/issues/150)). ([731e53f9](https://github.com/saymyframe/smf_flutter_cli/commit/731e53f9bf3c7147f8fa8c6e781788b1ee67b47f))

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
