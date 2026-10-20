# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-10-20

### Changes

---

Packages with breaking changes:

 - [`smf_apple_sign_in` - `v0.6.0`](#smf_apple_sign_in---v060)
 - [`smf_firebase_messaging` - `v0.6.0`](#smf_firebase_messaging---v060)
 - [`smf_contracts` - `v0.6.0`](#smf_contracts---v060)
 - [`smf_firebase_auth` - `v0.6.0`](#smf_firebase_auth---v060)
 - [`smf_flutter_cli` - `v0.6.0`](#smf_flutter_cli---v060)
 - [`smf_flutter_core` - `v0.5.0`](#smf_flutter_core---v050)
 - [`smf_gen_l10n` - `v0.5.0`](#smf_gen_l10n---v050)
 - [`smf_go_router` - `v0.6.0`](#smf_go_router---v060)
 - [`smf_home_flutter` - `v0.5.0`](#smf_home_flutter---v050)
 - [`smf_pipeline` - `v0.6.0`](#smf_pipeline---v060)
 - [`smf_sign_in` - `v0.6.0`](#smf_sign_in---v060)

Packages with other changes:

 - [`smf_google_sign_in` - `v0.6.0`](#smf_google_sign_in---v060)
 - [`smf_local_notifications` - `v0.6.0`](#smf_local_notifications---v060)
 - [`smf_firebase_analytics` - `v0.4.2`](#smf_firebase_analytics---v042)
 - [`smf_get_it` - `v0.4.2`](#smf_get_it---v042)
 - [`smf_onboarding` - `v0.5.1`](#smf_onboarding---v051)
 - [`smf_bloc` - `v0.3.3`](#smf_bloc---v033)
 - [`smf_bottom_tabs` - `v0.4.2`](#smf_bottom_tabs---v042)
 - [`smf_event_bus` - `v0.3.3`](#smf_event_bus---v033)
 - [`smf_firebase_core` - `v0.4.2`](#smf_firebase_core---v042)
 - [`smf_firebase_crashlytics` - `v0.4.2`](#smf_firebase_crashlytics---v042)
 - [`smf_material_theme` - `v0.4.2`](#smf_material_theme---v042)
 - [`smf_riverpod` - `v0.3.3`](#smf_riverpod---v033)
 - [`smf_settings` - `v0.4.2`](#smf_settings---v042)
 - [`smf_shared_preferences` - `v0.4.3`](#smf_shared_preferences---v043)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `smf_bloc` - `v0.3.3`
 - `smf_bottom_tabs` - `v0.4.2`
 - `smf_event_bus` - `v0.3.3`
 - `smf_firebase_core` - `v0.4.2`
 - `smf_firebase_crashlytics` - `v0.4.2`
 - `smf_material_theme` - `v0.4.2`
 - `smf_riverpod` - `v0.3.3`
 - `smf_settings` - `v0.4.2`
 - `smf_shared_preferences` - `v0.4.3`

---

#### `smf_apple_sign_in` - `v0.6.0`

 - **FEAT**(apple_sign_in): add Sign in with Apple on iOS ([#212](https://github.com/saymyframe/smf_flutter_cli/issues/212)). ([79b7c4e4](https://github.com/saymyframe/smf_flutter_cli/commit/79b7c4e44294b3c104e45ca474d2e84eac83ec90))
 - **BREAKING** **FEAT**(contracts,apple_sign_in): the App ID among the steps by hand ([#234](https://github.com/saymyframe/smf_flutter_cli/issues/234)). ([e0b73a02](https://github.com/saymyframe/smf_flutter_cli/commit/e0b73a0295316ec57d8a50ec8336d076a1182f87))

#### `smf_firebase_messaging` - `v0.6.0`

 - **FEAT**(firebase_messaging): the APNs key among the steps by hand ([#235](https://github.com/saymyframe/smf_flutter_cli/issues/235)). ([b1e02466](https://github.com/saymyframe/smf_flutter_cli/commit/b1e024661876640c0a88fd35ac99e756e2477299))
 - **FEAT**(firebase_messaging): add Firebase Cloud Messaging as the provider of the push role ([#210](https://github.com/saymyframe/smf_flutter_cli/issues/210)). ([5bbbfa9a](https://github.com/saymyframe/smf_flutter_cli/commit/5bbbfa9ad0835e2344f3241a3f364110796b874e))
 - **BREAKING** **FEAT**(contracts,apple_sign_in): the App ID among the steps by hand ([#234](https://github.com/saymyframe/smf_flutter_cli/issues/234)). ([e0b73a02](https://github.com/saymyframe/smf_flutter_cli/commit/e0b73a0295316ec57d8a50ec8336d076a1182f87))

#### `smf_contracts` - `v0.6.0`

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

#### `smf_firebase_auth` - `v0.6.0`

 - **FIX**(firebase_auth): need Firebase CLI 15.34.0, which adds no web app to a project that has apps ([#182](https://github.com/saymyframe/smf_flutter_cli/issues/182)). ([8afc173a](https://github.com/saymyframe/smf_flutter_cli/commit/8afc173a846a6cf6ae3eea227615b902e416932e))
 - **FEAT**(firebase_auth,firebase_analytics): the steps by hand of Apple, Google Play and Analytics ([#236](https://github.com/saymyframe/smf_flutter_cli/issues/236)). ([e009ede2](https://github.com/saymyframe/smf_flutter_cli/commit/e009ede2c1b205763ef4ad05455defb8fcdf8b9e))
 - **FEAT**(firebase_auth): enable Google, register the debug key and write the URL scheme for the methods of the app ([#214](https://github.com/saymyframe/smf_flutter_cli/issues/214)). ([313fc8c9](https://github.com/saymyframe/smf_flutter_cli/commit/313fc8c98e0a3c48f74b13ad145efaecc0ce5ecb))
 - **FEAT**(apple_sign_in): add Sign in with Apple on iOS ([#212](https://github.com/saymyframe/smf_flutter_cli/issues/212)). ([79b7c4e4](https://github.com/saymyframe/smf_flutter_cli/commit/79b7c4e44294b3c104e45ca474d2e84eac83ec90))
 - **FEAT**(firebase_auth): sign in, link and delete with the credentials of the sign-in methods ([#205](https://github.com/saymyframe/smf_flutter_cli/issues/205)). ([caf1e446](https://github.com/saymyframe/smf_flutter_cli/commit/caf1e446f337171ec212aab9ae82a23b2bad18e9))
 - **BREAKING** **FEAT**(contracts): sign in with a credential of an identity provider, and list the ways to sign in of an app ([#197](https://github.com/saymyframe/smf_flutter_cli/issues/197)). ([73e8a21c](https://github.com/saymyframe/smf_flutter_cli/commit/73e8a21cb3807482f53a161baf1b9b0717aea5e4))

#### `smf_flutter_cli` - `v0.6.0`

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

#### `smf_flutter_core` - `v0.5.0`

 - **FEAT**(contracts): give every app the icons of the status bar as a widget of its own, with a widget test ([#191](https://github.com/saymyframe/smf_flutter_cli/issues/191)). ([4ab6b288](https://github.com/saymyframe/smf_flutter_cli/commit/4ab6b288cd00e6b94a0a4a27d1440480e21d4a30))
 - **BREAKING** **FEAT**(contracts,apple_sign_in): the App ID among the steps by hand ([#234](https://github.com/saymyframe/smf_flutter_cli/issues/234)). ([e0b73a02](https://github.com/saymyframe/smf_flutter_cli/commit/e0b73a0295316ec57d8a50ec8336d076a1182f87))
 - **BREAKING** **FEAT**(contracts): let modules add components to the Android application ([#201](https://github.com/saymyframe/smf_flutter_cli/issues/201)). ([6dfcaec9](https://github.com/saymyframe/smf_flutter_cli/commit/6dfcaec92bf72dea1922940ea6834b564c24118a))
 - **BREAKING** **FEAT**(contracts): let modules run code in the AppDelegate before launch finishes ([#200](https://github.com/saymyframe/smf_flutter_cli/issues/200)). ([263b3079](https://github.com/saymyframe/smf_flutter_cli/commit/263b307907e85ea4aee51d7c1fa6330712b6cd1f))
 - **BREAKING** **FEAT**(contracts): let modules enable core library desugaring of the Android app ([#199](https://github.com/saymyframe/smf_flutter_cli/issues/199)). ([7f760ba7](https://github.com/saymyframe/smf_flutter_cli/commit/7f760ba7d53081d6023607b045cca7e185d09787))
 - **BREAKING** **FEAT**(flutter_core): give the fallback start screen only to an app that no route starts ([#192](https://github.com/saymyframe/smf_flutter_cli/issues/192)). ([9cc0a8f1](https://github.com/saymyframe/smf_flutter_cli/commit/9cc0a8f19515e003b50778cb1c5a627aa1f1daa5))
 - **BREAKING** **FEAT**(contracts): sign the iOS app with Runner.entitlements and let modules add entitlements ([#187](https://github.com/saymyframe/smf_flutter_cli/issues/187)). ([2f2b0374](https://github.com/saymyframe/smf_flutter_cli/commit/2f2b037442262cec28376137bf2fe35b8adf2852))

#### `smf_gen_l10n` - `v0.5.0`

 - **BREAKING** **FEAT**(flutter_core): give the fallback start screen only to an app that no route starts ([#192](https://github.com/saymyframe/smf_flutter_cli/issues/192)). ([9cc0a8f1](https://github.com/saymyframe/smf_flutter_cli/commit/9cc0a8f19515e003b50778cb1c5a627aa1f1daa5))

#### `smf_go_router` - `v0.6.0`

 - **FEAT**(contracts): give every app the icons of the status bar as a widget of its own, with a widget test ([#191](https://github.com/saymyframe/smf_flutter_cli/issues/191)). ([4ab6b288](https://github.com/saymyframe/smf_flutter_cli/commit/4ab6b288cd00e6b94a0a4a27d1440480e21d4a30))
 - **BREAKING** **FEAT**(flutter_core): give the fallback start screen only to an app that no route starts ([#192](https://github.com/saymyframe/smf_flutter_cli/issues/192)). ([9cc0a8f1](https://github.com/saymyframe/smf_flutter_cli/commit/9cc0a8f19515e003b50778cb1c5a627aa1f1daa5))

#### `smf_home_flutter` - `v0.5.0`

 - **BREAKING** **FEAT**(flutter_core): give the fallback start screen only to an app that no route starts ([#192](https://github.com/saymyframe/smf_flutter_cli/issues/192)). ([9cc0a8f1](https://github.com/saymyframe/smf_flutter_cli/commit/9cc0a8f19515e003b50778cb1c5a627aa1f1daa5))

#### `smf_pipeline` - `v0.6.0`

 - **REFACTOR**(pipeline,cli): split the functions that SonarCloud finds too complex ([#229](https://github.com/saymyframe/smf_flutter_cli/issues/229)). ([7ebe3a31](https://github.com/saymyframe/smf_flutter_cli/commit/7ebe3a3157ffab1079ab62500f64efc22e1c39fc))
 - **FIX**(sign_in): let the pages of the sign-in scroll under the bar of the home gesture ([#223](https://github.com/saymyframe/smf_flutter_cli/issues/223)). ([9faac56b](https://github.com/saymyframe/smf_flutter_cli/commit/9faac56bec27d7a2038484529241f0a8618e9fa7))
 - **FIX**(firebase_auth): need Firebase CLI 15.34.0, which adds no web app to a project that has apps ([#182](https://github.com/saymyframe/smf_flutter_cli/issues/182)). ([8afc173a](https://github.com/saymyframe/smf_flutter_cli/commit/8afc173a846a6cf6ae3eea227615b902e416932e))
 - **FEAT**(firebase_auth,firebase_analytics): the steps by hand of Apple, Google Play and Analytics ([#236](https://github.com/saymyframe/smf_flutter_cli/issues/236)). ([e009ede2](https://github.com/saymyframe/smf_flutter_cli/commit/e009ede2c1b205763ef4ad05455defb8fcdf8b9e))
 - **FEAT**(firebase_messaging): the APNs key among the steps by hand ([#235](https://github.com/saymyframe/smf_flutter_cli/issues/235)). ([b1e02466](https://github.com/saymyframe/smf_flutter_cli/commit/b1e024661876640c0a88fd35ac99e756e2477299))
 - **FEAT**(pipeline): the link to the guide of the steps by hand ([#231](https://github.com/saymyframe/smf_flutter_cli/issues/231)). ([c5cde6df](https://github.com/saymyframe/smf_flutter_cli/commit/c5cde6dfaa0d501dd76ec920743580c52bfb0780))
 - **FEAT**(sign_in): continue with the sign-in methods of the app ([#219](https://github.com/saymyframe/smf_flutter_cli/issues/219)). ([5c2a7051](https://github.com/saymyframe/smf_flutter_cli/commit/5c2a705198ce2e6ad525ed40983e3d8ce5c53db0))
 - **FEAT**(google_sign_in): add sign-in with Google ([#216](https://github.com/saymyframe/smf_flutter_cli/issues/216)). ([231156eb](https://github.com/saymyframe/smf_flutter_cli/commit/231156ebe66206968d27022fcff3d6c08e3d03be))
 - **FEAT**(firebase_auth): enable Google, register the debug key and write the URL scheme for the methods of the app ([#214](https://github.com/saymyframe/smf_flutter_cli/issues/214)). ([313fc8c9](https://github.com/saymyframe/smf_flutter_cli/commit/313fc8c98e0a3c48f74b13ad145efaecc0ce5ecb))
 - **FEAT**(firebase_messaging): add Firebase Cloud Messaging as the provider of the push role ([#210](https://github.com/saymyframe/smf_flutter_cli/issues/210)). ([5bbbfa9a](https://github.com/saymyframe/smf_flutter_cli/commit/5bbbfa9ad0835e2344f3241a3f364110796b874e))
 - **FEAT**(apple_sign_in): add Sign in with Apple on iOS ([#212](https://github.com/saymyframe/smf_flutter_cli/issues/212)). ([79b7c4e4](https://github.com/saymyframe/smf_flutter_cli/commit/79b7c4e44294b3c104e45ca474d2e84eac83ec90))
 - **FEAT**(local_notifications): add a provider of the notifications role on flutter_local_notifications ([#206](https://github.com/saymyframe/smf_flutter_cli/issues/206)). ([d16e9a43](https://github.com/saymyframe/smf_flutter_cli/commit/d16e9a4349cf578660660b535744b66490995fb6))
 - **FEAT**(firebase_auth): sign in, link and delete with the credentials of the sign-in methods ([#205](https://github.com/saymyframe/smf_flutter_cli/issues/205)). ([caf1e446](https://github.com/saymyframe/smf_flutter_cli/commit/caf1e446f337171ec212aab9ae82a23b2bad18e9))
 - **FEAT**(onboarding): show the steps that the modules of the app add to the onboarding ([#203](https://github.com/saymyframe/smf_flutter_cli/issues/203)). ([32652cbf](https://github.com/saymyframe/smf_flutter_cli/commit/32652cbf289502cce513a2e2c9a7720d0791fa1c))
 - **FEAT**(contracts): give every app the icons of the status bar as a widget of its own, with a widget test ([#191](https://github.com/saymyframe/smf_flutter_cli/issues/191)). ([4ab6b288](https://github.com/saymyframe/smf_flutter_cli/commit/4ab6b288cd00e6b94a0a4a27d1440480e21d4a30))
 - **BREAKING** **FEAT**(contracts,apple_sign_in): the App ID among the steps by hand ([#234](https://github.com/saymyframe/smf_flutter_cli/issues/234)). ([e0b73a02](https://github.com/saymyframe/smf_flutter_cli/commit/e0b73a0295316ec57d8a50ec8336d076a1182f87))
 - **BREAKING** **FEAT**(contracts,pipeline): steps of an app that its developer does by hand ([#230](https://github.com/saymyframe/smf_flutter_cli/issues/230)). ([542e1089](https://github.com/saymyframe/smf_flutter_cli/commit/542e1089bed294361086f39191529267ab652b95))
 - **BREAKING** **FEAT**(contracts): let modules add components to the Android application ([#201](https://github.com/saymyframe/smf_flutter_cli/issues/201)). ([6dfcaec9](https://github.com/saymyframe/smf_flutter_cli/commit/6dfcaec92bf72dea1922940ea6834b564c24118a))
 - **BREAKING** **FEAT**(contracts): let modules run code in the AppDelegate before launch finishes ([#200](https://github.com/saymyframe/smf_flutter_cli/issues/200)). ([263b3079](https://github.com/saymyframe/smf_flutter_cli/commit/263b307907e85ea4aee51d7c1fa6330712b6cd1f))
 - **BREAKING** **FEAT**(contracts): let modules enable core library desugaring of the Android app ([#199](https://github.com/saymyframe/smf_flutter_cli/issues/199)). ([7f760ba7](https://github.com/saymyframe/smf_flutter_cli/commit/7f760ba7d53081d6023607b045cca7e185d09787))
 - **BREAKING** **FEAT**(contracts): sign in with a credential of an identity provider, and list the ways to sign in of an app ([#197](https://github.com/saymyframe/smf_flutter_cli/issues/197)). ([73e8a21c](https://github.com/saymyframe/smf_flutter_cli/commit/73e8a21cb3807482f53a161baf1b9b0717aea5e4))
 - **BREAKING** **FEAT**(flutter_core): give the fallback start screen only to an app that no route starts ([#192](https://github.com/saymyframe/smf_flutter_cli/issues/192)). ([9cc0a8f1](https://github.com/saymyframe/smf_flutter_cli/commit/9cc0a8f19515e003b50778cb1c5a627aa1f1daa5))
 - **BREAKING** **FEAT**(pipeline): stop a --strict run on a warning about what the app is made of ([#190](https://github.com/saymyframe/smf_flutter_cli/issues/190)). ([530c4f88](https://github.com/saymyframe/smf_flutter_cli/commit/530c4f8865b3b8de5c9672e4f3c78ea802951af1))
 - **BREAKING** **FEAT**(contracts): give each warning about the app a code, and let a choice report one ([#188](https://github.com/saymyframe/smf_flutter_cli/issues/188)). ([80f2c7ed](https://github.com/saymyframe/smf_flutter_cli/commit/80f2c7edd737e63ea3085b8202bb04a9bc9c4b7b))
 - **BREAKING** **FEAT**(contracts): sign the iOS app with Runner.entitlements and let modules add entitlements ([#187](https://github.com/saymyframe/smf_flutter_cli/issues/187)). ([2f2b0374](https://github.com/saymyframe/smf_flutter_cli/commit/2f2b037442262cec28376137bf2fe35b8adf2852))
 - **BREAKING** **FEAT**(contracts): let a contribution and a symbol of a role depend on what a role chose ([#184](https://github.com/saymyframe/smf_flutter_cli/issues/184)). ([d5deac8e](https://github.com/saymyframe/smf_flutter_cli/commit/d5deac8ef366a40d24b74bb77ae444cf6ced274f))

#### `smf_sign_in` - `v0.6.0`

 - **FIX**(sign_in): let the pages of the sign-in scroll under the bar of the home gesture ([#223](https://github.com/saymyframe/smf_flutter_cli/issues/223)). ([9faac56b](https://github.com/saymyframe/smf_flutter_cli/commit/9faac56bec27d7a2038484529241f0a8618e9fa7))
 - **FEAT**(sign_in): continue with the sign-in methods of the app ([#219](https://github.com/saymyframe/smf_flutter_cli/issues/219)). ([5c2a7051](https://github.com/saymyframe/smf_flutter_cli/commit/5c2a705198ce2e6ad525ed40983e3d8ce5c53db0))
 - **BREAKING** **FEAT**(contracts): sign in with a credential of an identity provider, and list the ways to sign in of an app ([#197](https://github.com/saymyframe/smf_flutter_cli/issues/197)). ([73e8a21c](https://github.com/saymyframe/smf_flutter_cli/commit/73e8a21cb3807482f53a161baf1b9b0717aea5e4))
 - **BREAKING** **FEAT**(contracts): give each warning about the app a code, and let a choice report one ([#188](https://github.com/saymyframe/smf_flutter_cli/issues/188)). ([80f2c7ed](https://github.com/saymyframe/smf_flutter_cli/commit/80f2c7edd737e63ea3085b8202bb04a9bc9c4b7b))

#### `smf_google_sign_in` - `v0.6.0`

 - **FEAT**(google_sign_in): add sign-in with Google ([#216](https://github.com/saymyframe/smf_flutter_cli/issues/216)). ([231156eb](https://github.com/saymyframe/smf_flutter_cli/commit/231156ebe66206968d27022fcff3d6c08e3d03be))

#### `smf_local_notifications` - `v0.6.0`

 - **FEAT**(local_notifications): add a provider of the notifications role on flutter_local_notifications ([#206](https://github.com/saymyframe/smf_flutter_cli/issues/206)). ([d16e9a43](https://github.com/saymyframe/smf_flutter_cli/commit/d16e9a4349cf578660660b535744b66490995fb6))

#### `smf_firebase_analytics` - `v0.4.2`

 - **FEAT**(firebase_auth,firebase_analytics): the steps by hand of Apple, Google Play and Analytics ([#236](https://github.com/saymyframe/smf_flutter_cli/issues/236)). ([e009ede2](https://github.com/saymyframe/smf_flutter_cli/commit/e009ede2c1b205763ef4ad05455defb8fcdf8b9e))

#### `smf_get_it` - `v0.4.2`

 - **FEAT**(contracts): give every app the icons of the status bar as a widget of its own, with a widget test ([#191](https://github.com/saymyframe/smf_flutter_cli/issues/191)). ([4ab6b288](https://github.com/saymyframe/smf_flutter_cli/commit/4ab6b288cd00e6b94a0a4a27d1440480e21d4a30))

#### `smf_onboarding` - `v0.5.1`

 - **FEAT**(local_notifications): add a provider of the notifications role on flutter_local_notifications ([#206](https://github.com/saymyframe/smf_flutter_cli/issues/206)). ([d16e9a43](https://github.com/saymyframe/smf_flutter_cli/commit/d16e9a4349cf578660660b535744b66490995fb6))
 - **FEAT**(onboarding): show the steps that the modules of the app add to the onboarding ([#203](https://github.com/saymyframe/smf_flutter_cli/issues/203)). ([32652cbf](https://github.com/saymyframe/smf_flutter_cli/commit/32652cbf289502cce513a2e2c9a7720d0791fa1c))


## 2026-10-17

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`smf_flutter_cli` - `v0.5.1`](#smf_flutter_cli---v051)
 - [`smf_pipeline` - `v0.5.1`](#smf_pipeline---v051)
 - [`smf_shared_preferences` - `v0.4.2`](#smf_shared_preferences---v042)
 - [`smf_sign_in` - `v0.5.1`](#smf_sign_in---v051)

---

#### `smf_flutter_cli` - `v0.5.1`

 - **FIX**(shared_preferences): keep shared_preferences_android below 2.5.0, whose release builds fail to open the preferences ([#204](https://github.com/saymyframe/smf_flutter_cli/issues/204)). ([2ddbaed2](https://github.com/saymyframe/smf_flutter_cli/commit/2ddbaed27da0031c144abb606c6d192a94a3eda8))

#### `smf_pipeline` - `v0.5.1`

 - **FIX**(shared_preferences): keep shared_preferences_android below 2.5.0, whose release builds fail to open the preferences ([#204](https://github.com/saymyframe/smf_flutter_cli/issues/204)). ([2ddbaed2](https://github.com/saymyframe/smf_flutter_cli/commit/2ddbaed27da0031c144abb606c6d192a94a3eda8))

#### `smf_shared_preferences` - `v0.4.2`

 - **FIX**(shared_preferences): keep shared_preferences_android below 2.5.0, whose release builds fail to open the preferences ([#204](https://github.com/saymyframe/smf_flutter_cli/issues/204)). ([2ddbaed2](https://github.com/saymyframe/smf_flutter_cli/commit/2ddbaed27da0031c144abb606c6d192a94a3eda8))

#### `smf_sign_in` - `v0.5.1`

 - **FIX**(shared_preferences): keep shared_preferences_android below 2.5.0, whose release builds fail to open the preferences ([#204](https://github.com/saymyframe/smf_flutter_cli/issues/204)). ([2ddbaed2](https://github.com/saymyframe/smf_flutter_cli/commit/2ddbaed27da0031c144abb606c6d192a94a3eda8))


## 2026-10-12

### Changes

---

Packages with breaking changes:

 - [`smf_contracts` - `v0.5.0`](#smf_contracts---v050)
 - [`smf_flutter_cli` - `v0.5.0`](#smf_flutter_cli---v050)
 - [`smf_go_router` - `v0.5.0`](#smf_go_router---v050)
 - [`smf_onboarding` - `v0.5.0`](#smf_onboarding---v050)
 - [`smf_pipeline` - `v0.5.0`](#smf_pipeline---v050)

Packages with other changes:

 - [`smf_sign_in` - `v0.5.0`](#smf_sign_in---v050)
 - [`smf_firebase_auth` - `v0.5.0`](#smf_firebase_auth---v050)
 - [`smf_bloc` - `v0.3.2`](#smf_bloc---v032)
 - [`smf_firebase_core` - `v0.4.1`](#smf_firebase_core---v041)
 - [`smf_material_theme` - `v0.4.1`](#smf_material_theme---v041)
 - [`smf_riverpod` - `v0.3.2`](#smf_riverpod---v032)
 - [`smf_settings` - `v0.4.1`](#smf_settings---v041)
 - [`smf_bottom_tabs` - `v0.4.1`](#smf_bottom_tabs---v041)
 - [`smf_event_bus` - `v0.3.2`](#smf_event_bus---v032)
 - [`smf_firebase_analytics` - `v0.4.1`](#smf_firebase_analytics---v041)
 - [`smf_firebase_crashlytics` - `v0.4.1`](#smf_firebase_crashlytics---v041)
 - [`smf_flutter_core` - `v0.4.1`](#smf_flutter_core---v041)
 - [`smf_gen_l10n` - `v0.4.1`](#smf_gen_l10n---v041)
 - [`smf_get_it` - `v0.4.1`](#smf_get_it---v041)
 - [`smf_home_flutter` - `v0.4.1`](#smf_home_flutter---v041)
 - [`smf_shared_preferences` - `v0.4.1`](#smf_shared_preferences---v041)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `smf_bottom_tabs` - `v0.4.1`
 - `smf_event_bus` - `v0.3.2`
 - `smf_firebase_analytics` - `v0.4.1`
 - `smf_firebase_crashlytics` - `v0.4.1`
 - `smf_flutter_core` - `v0.4.1`
 - `smf_gen_l10n` - `v0.4.1`
 - `smf_get_it` - `v0.4.1`
 - `smf_home_flutter` - `v0.4.1`
 - `smf_shared_preferences` - `v0.4.1`

---

#### `smf_contracts` - `v0.5.0`

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

#### `smf_flutter_cli` - `v0.5.0`

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

#### `smf_go_router` - `v0.5.0`

 - **FIX**(contracts,go_router): open a page of the flow of a condition over the start screen when a link asks for it ([#166](https://github.com/saymyframe/smf_flutter_cli/issues/166)). ([0c42e365](https://github.com/saymyframe/smf_flutter_cli/commit/0c42e36578dac19accdf3767c7a00a299f50fbf2))
 - **FIX**(go_router): show what push() and replace() ask for when go_router shows its error screen alone ([#165](https://github.com/saymyframe/smf_flutter_cli/issues/165)). ([c55c01e2](https://github.com/saymyframe/smf_flutter_cli/commit/c55c01e2c74ec839e11cef3d5a1bf8a07a7cbc5e))
 - **FIX**(go_router): keep the back button of the system from throwing on the error screen ([#161](https://github.com/saymyframe/smf_flutter_cli/issues/161)). ([5a933e9f](https://github.com/saymyframe/smf_flutter_cli/commit/5a933e9fd848545f747ea4c91749a7d8bcf7a6c7))
 - **FIX**(go_router): drop the pages of every branch when a guard closes and opens in one turn ([#157](https://github.com/saymyframe/smf_flutter_cli/issues/157)). ([976dbad8](https://github.com/saymyframe/smf_flutter_cli/commit/976dbad8458eda9cbaf2dfdb8b48b5008294362b))
 - **FEAT**(contracts): a condition that only some routes ask for ([#155](https://github.com/saymyframe/smf_flutter_cli/issues/155)). ([9c239fe1](https://github.com/saymyframe/smf_flutter_cli/commit/9c239fe105f8adbc30ae9c98cab63b26e1c234ed))
 - **BREAKING** **FEAT**(contracts,go_router): open the flow of a condition over the screen the user is on ([#163](https://github.com/saymyframe/smf_flutter_cli/issues/163)). ([b7f7e655](https://github.com/saymyframe/smf_flutter_cli/commit/b7f7e655374c8109c1daf255cdb43c80a6dc4c67))
 - **BREAKING** **FEAT**(contracts,onboarding): say when a guard is asked and whether it brings the user back ([#152](https://github.com/saymyframe/smf_flutter_cli/issues/152)). ([7b12df77](https://github.com/saymyframe/smf_flutter_cli/commit/7b12df77edbc4a785ae192b8c16bbca0523197ac))
 - **BREAKING** **FEAT**(contracts,onboarding): close the flow of a guard that allows ([#150](https://github.com/saymyframe/smf_flutter_cli/issues/150)). ([731e53f9](https://github.com/saymyframe/smf_flutter_cli/commit/731e53f9bf3c7147f8fa8c6e781788b1ee67b47f))

#### `smf_onboarding` - `v0.5.0`

 - **BREAKING** **FEAT**(contracts,onboarding): say when a guard is asked and whether it brings the user back ([#152](https://github.com/saymyframe/smf_flutter_cli/issues/152)). ([7b12df77](https://github.com/saymyframe/smf_flutter_cli/commit/7b12df77edbc4a785ae192b8c16bbca0523197ac))
 - **BREAKING** **FEAT**(contracts,onboarding): close the flow of a guard that allows ([#150](https://github.com/saymyframe/smf_flutter_cli/issues/150)). ([731e53f9](https://github.com/saymyframe/smf_flutter_cli/commit/731e53f9bf3c7147f8fa8c6e781788b1ee67b47f))

#### `smf_pipeline` - `v0.5.0`

 - **FIX**(contracts,go_router): open a page of the flow of a condition over the start screen when a link asks for it ([#166](https://github.com/saymyframe/smf_flutter_cli/issues/166)). ([0c42e365](https://github.com/saymyframe/smf_flutter_cli/commit/0c42e36578dac19accdf3767c7a00a299f50fbf2))
 - **FIX**(go_router): show what push() and replace() ask for when go_router shows its error screen alone ([#165](https://github.com/saymyframe/smf_flutter_cli/issues/165)). ([c55c01e2](https://github.com/saymyframe/smf_flutter_cli/commit/c55c01e2c74ec839e11cef3d5a1bf8a07a7cbc5e))
 - **FIX**(go_router): keep the back button of the system from throwing on the error screen ([#161](https://github.com/saymyframe/smf_flutter_cli/issues/161)). ([5a933e9f](https://github.com/saymyframe/smf_flutter_cli/commit/5a933e9fd848545f747ea4c91749a7d8bcf7a6c7))
 - **FIX**(go_router): drop the pages of every branch when a guard closes and opens in one turn ([#157](https://github.com/saymyframe/smf_flutter_cli/issues/157)). ([976dbad8](https://github.com/saymyframe/smf_flutter_cli/commit/976dbad8458eda9cbaf2dfdb8b48b5008294362b))
 - **FIX**(pipeline): check the machine for a module after the modules it depends on ([#151](https://github.com/saymyframe/smf_flutter_cli/issues/151)). ([494c1eb0](https://github.com/saymyframe/smf_flutter_cli/commit/494c1eb0839d4fba35eac6dca80203d416cabd9d))
 - **FEAT**(pipeline): list the steps left for later after the app is created, without a warning ([#176](https://github.com/saymyframe/smf_flutter_cli/issues/176)). ([571c0ace](https://github.com/saymyframe/smf_flutter_cli/commit/571c0acea10fc246ca3cb8dd81b2446d1ed9a00a))
 - **FEAT**(bloc,riverpod): tell in the agent note how a screen, shared state and an awaited call are written ([#172](https://github.com/saymyframe/smf_flutter_cli/issues/172)). ([6f819423](https://github.com/saymyframe/smf_flutter_cli/commit/6f8194238bcb957d19409d3acf867445e2b3989e))
 - **FEAT**(sign_in): add the account screen and the entry of the settings screen that leads to it ([#171](https://github.com/saymyframe/smf_flutter_cli/issues/171)). ([4d7fac2b](https://github.com/saymyframe/smf_flutter_cli/commit/4d7fac2bf04907ce9c9474b5accbca1247d3fed3))
 - **FEAT**(sign_in): add the module with the screens of sign-in, sign-up and password reset, in a bloc and a riverpod variant ([#170](https://github.com/saymyframe/smf_flutter_cli/issues/170)). ([bfcd9025](https://github.com/saymyframe/smf_flutter_cli/commit/bfcd9025f26b607315846995ed1a2006930a7a0f))
 - **FEAT**(firebase_auth): enable the sign-in methods in Firebase after flutterfire configure ([#168](https://github.com/saymyframe/smf_flutter_cli/issues/168)). ([1d4a1c27](https://github.com/saymyframe/smf_flutter_cli/commit/1d4a1c27b1ea1f63ef866081dbdaa5e5f3e49275))
 - **FEAT**(contracts): say how the auth role writes the mode of the app, for a tool that reads it ([#167](https://github.com/saymyframe/smf_flutter_cli/issues/167)). ([c61033c6](https://github.com/saymyframe/smf_flutter_cli/commit/c61033c65a401179eea8c5452e387b44a688047a))
 - **FEAT**(firebase_auth): provide the auth role with Firebase Authentication ([#162](https://github.com/saymyframe/smf_flutter_cli/issues/162)). ([c541d0d4](https://github.com/saymyframe/smf_flutter_cli/commit/c541d0d4b3ae3a23a148d61293c41338a1bf27a1))
 - **FEAT**(material_theme): give text fields the look of the theme ([#160](https://github.com/saymyframe/smf_flutter_cli/issues/160)). ([2d1d6a24](https://github.com/saymyframe/smf_flutter_cli/commit/2d1d6a2446b29a5a5486aba0a97d34909589186b))
 - **FEAT**(contracts): a condition that only some routes ask for ([#155](https://github.com/saymyframe/smf_flutter_cli/issues/155)). ([9c239fe1](https://github.com/saymyframe/smf_flutter_cli/commit/9c239fe105f8adbc30ae9c98cab63b26e1c234ed))
 - **FEAT**(cli): give the modes of a role option their apps with every module ([#154](https://github.com/saymyframe/smf_flutter_cli/issues/154)). ([19384819](https://github.com/saymyframe/smf_flutter_cli/commit/193848190a66b3301dfc20b4f430ae7e82a62519))
 - **FEAT**(contracts,pipeline): let a role option have modes, with a case of the harness for each ([#149](https://github.com/saymyframe/smf_flutter_cli/issues/149)). ([4fd6a70f](https://github.com/saymyframe/smf_flutter_cli/commit/4fd6a70fef36a8272c8565b8d0b2dea543b3d983))
 - **FEAT**(contracts,pipeline): a post-generation step that continues another may ask its own question ([#147](https://github.com/saymyframe/smf_flutter_cli/issues/147)). ([434fbb27](https://github.com/saymyframe/smf_flutter_cli/commit/434fbb27562d9085ad1d1a33061d8d872c3dab17))
 - **BREAKING** **FEAT**(contracts,go_router): open the flow of a condition over the screen the user is on ([#163](https://github.com/saymyframe/smf_flutter_cli/issues/163)). ([b7f7e655](https://github.com/saymyframe/smf_flutter_cli/commit/b7f7e655374c8109c1daf255cdb43c80a6dc4c67))
 - **BREAKING** **FEAT**(contracts,onboarding): say when a guard is asked and whether it brings the user back ([#152](https://github.com/saymyframe/smf_flutter_cli/issues/152)). ([7b12df77](https://github.com/saymyframe/smf_flutter_cli/commit/7b12df77edbc4a785ae192b8c16bbca0523197ac))
 - **BREAKING** **FEAT**(contracts,onboarding): close the flow of a guard that allows ([#150](https://github.com/saymyframe/smf_flutter_cli/issues/150)). ([731e53f9](https://github.com/saymyframe/smf_flutter_cli/commit/731e53f9bf3c7147f8fa8c6e781788b1ee67b47f))

#### `smf_sign_in` - `v0.5.0`

 - **FEAT**(contracts): warn of the destinations of an app without a main navigation ([#175](https://github.com/saymyframe/smf_flutter_cli/issues/175)). ([39a624ba](https://github.com/saymyframe/smf_flutter_cli/commit/39a624ba72cb4d4c878409f46bb8b266820d3ebd))
 - **FEAT**(sign_in): add the account screen and the entry of the settings screen that leads to it ([#171](https://github.com/saymyframe/smf_flutter_cli/issues/171)). ([4d7fac2b](https://github.com/saymyframe/smf_flutter_cli/commit/4d7fac2bf04907ce9c9474b5accbca1247d3fed3))
 - **FEAT**(sign_in): add the module with the screens of sign-in, sign-up and password reset, in a bloc and a riverpod variant ([#170](https://github.com/saymyframe/smf_flutter_cli/issues/170)). ([bfcd9025](https://github.com/saymyframe/smf_flutter_cli/commit/bfcd9025f26b607315846995ed1a2006930a7a0f))

#### `smf_firebase_auth` - `v0.5.0`

 - **FEAT**(pipeline): list the steps left for later after the app is created, without a warning ([#176](https://github.com/saymyframe/smf_flutter_cli/issues/176)). ([571c0ace](https://github.com/saymyframe/smf_flutter_cli/commit/571c0acea10fc246ca3cb8dd81b2446d1ed9a00a))
 - **FEAT**(firebase_auth): enable the sign-in methods in Firebase after flutterfire configure ([#168](https://github.com/saymyframe/smf_flutter_cli/issues/168)). ([1d4a1c27](https://github.com/saymyframe/smf_flutter_cli/commit/1d4a1c27b1ea1f63ef866081dbdaa5e5f3e49275))
 - **FEAT**(firebase_auth): provide the auth role with Firebase Authentication ([#162](https://github.com/saymyframe/smf_flutter_cli/issues/162)). ([c541d0d4](https://github.com/saymyframe/smf_flutter_cli/commit/c541d0d4b3ae3a23a148d61293c41338a1bf27a1))

#### `smf_bloc` - `v0.3.2`

 - **FEAT**(bloc,riverpod): tell in the agent note how a screen, shared state and an awaited call are written ([#172](https://github.com/saymyframe/smf_flutter_cli/issues/172)). ([6f819423](https://github.com/saymyframe/smf_flutter_cli/commit/6f8194238bcb957d19409d3acf867445e2b3989e))

#### `smf_firebase_core` - `v0.4.1`

 - **FIX**(pipeline): check the machine for a module after the modules it depends on ([#151](https://github.com/saymyframe/smf_flutter_cli/issues/151)). ([494c1eb0](https://github.com/saymyframe/smf_flutter_cli/commit/494c1eb0839d4fba35eac6dca80203d416cabd9d))
 - **FEAT**(pipeline): list the steps left for later after the app is created, without a warning ([#176](https://github.com/saymyframe/smf_flutter_cli/issues/176)). ([571c0ace](https://github.com/saymyframe/smf_flutter_cli/commit/571c0acea10fc246ca3cb8dd81b2446d1ed9a00a))
 - **FEAT**(firebase_core): a check of the version of the Firebase CLI for the modules that depend on it ([#146](https://github.com/saymyframe/smf_flutter_cli/issues/146)). ([b911fe46](https://github.com/saymyframe/smf_flutter_cli/commit/b911fe46304dabdc4460112d264e7e67191d17b4))

#### `smf_material_theme` - `v0.4.1`

 - **FEAT**(material_theme): give text fields the look of the theme ([#160](https://github.com/saymyframe/smf_flutter_cli/issues/160)). ([2d1d6a24](https://github.com/saymyframe/smf_flutter_cli/commit/2d1d6a2446b29a5a5486aba0a97d34909589186b))

#### `smf_riverpod` - `v0.3.2`

 - **FEAT**(bloc,riverpod): tell in the agent note how a screen, shared state and an awaited call are written ([#172](https://github.com/saymyframe/smf_flutter_cli/issues/172)). ([6f819423](https://github.com/saymyframe/smf_flutter_cli/commit/6f8194238bcb957d19409d3acf867445e2b3989e))

#### `smf_settings` - `v0.4.1`

 - **FEAT**(contracts): warn of the destinations of an app without a main navigation ([#175](https://github.com/saymyframe/smf_flutter_cli/issues/175)). ([39a624ba](https://github.com/saymyframe/smf_flutter_cli/commit/39a624ba72cb4d4c878409f46bb8b266820d3ebd))


## 2026-10-07

### Changes

---

Packages with breaking changes:

 - [`smf_bottom_tabs` - `v0.4.0`](#smf_bottom_tabs---v040)
 - [`smf_contracts` - `v0.4.0`](#smf_contracts---v040)
 - [`smf_contribution_engine` - `v0.3.0`](#smf_contribution_engine---v030)
 - [`smf_firebase_analytics` - `v0.4.0`](#smf_firebase_analytics---v040)
 - [`smf_firebase_core` - `v0.4.0`](#smf_firebase_core---v040)
 - [`smf_firebase_crashlytics` - `v0.4.0`](#smf_firebase_crashlytics---v040)
 - [`smf_flutter_cli` - `v0.4.0`](#smf_flutter_cli---v040)
 - [`smf_flutter_core` - `v0.4.0`](#smf_flutter_core---v040)
 - [`smf_get_it` - `v0.4.0`](#smf_get_it---v040)
 - [`smf_go_router` - `v0.4.0`](#smf_go_router---v040)
 - [`smf_home_flutter` - `v0.4.0`](#smf_home_flutter---v040)
 - [`smf_onboarding` - `v0.4.0`](#smf_onboarding---v040)
 - [`smf_pipeline` - `v0.4.0`](#smf_pipeline---v040)
 - [`smf_settings` - `v0.4.0`](#smf_settings---v040)

Packages with other changes:

 - [`smf_gen_l10n` - `v0.4.0`](#smf_gen_l10n---v040)
 - [`smf_material_theme` - `v0.4.0`](#smf_material_theme---v040)
 - [`smf_shared_preferences` - `v0.4.0`](#smf_shared_preferences---v040)
 - [`smf_bloc` - `v0.3.1`](#smf_bloc---v031)
 - [`smf_event_bus` - `v0.3.1`](#smf_event_bus---v031)
 - [`smf_riverpod` - `v0.3.1`](#smf_riverpod---v031)

---

#### `smf_bottom_tabs` - `v0.4.0`

 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**(bottom_tabs,material_theme): draw the bar of the tabs without an indicator, in the colours of the theme ([#136](https://github.com/saymyframe/smf_flutter_cli/issues/136)). ([23fcbb77](https://github.com/saymyframe/smf_flutter_cli/commit/23fcbb77e944a679bdaa391c885c2a76734c8648))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))

#### `smf_contracts` - `v0.4.0`

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

#### `smf_contribution_engine` - `v0.3.0`

 - **REFACTOR**(contribution_engine): find the body of a method or of a function in one place. ([81e3196f](https://github.com/saymyframe/smf_flutter_cli/commit/81e3196f366fe085e097c82fe245fbfcfbf37c6b))
 - **BREAKING** **REFACTOR**(contribution_engine): patch Dart files with the AST of analyzer 13, which it now needs. ([ca9792f2](https://github.com/saymyframe/smf_flutter_cli/commit/ca9792f20a6b90c8d35c2bb59ba2962e0b429c99))

#### `smf_firebase_analytics` - `v0.4.0`

 - **FIX**(contracts): leave out a provider of analytics or crash reporting that fails to be created. ([52d5b07b](https://github.com/saymyframe/smf_flutter_cli/commit/52d5b07b6804f1459eec52cbd6f880b4b1d57df7))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **BREAKING** **TEST**(cli): run the app tests with the platform mocks of every module of the app, next to other providers of their roles ([#75](https://github.com/saymyframe/smf_flutter_cli/issues/75)). ([87001859](https://github.com/saymyframe/smf_flutter_cli/commit/87001859841890e28f3a9ab2ba685ee32c9bdd87))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))

#### `smf_firebase_core` - `v0.4.0`

 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(firebase_crashlytics): fix the build phase of Crashlytics from its own module. ([4302a13c](https://github.com/saymyframe/smf_flutter_cli/commit/4302a13c2b7eb657e689f16fe51042eff7d117f7))
 - **FEAT**(cli): fan out the jobs of CI over a pairwise covering of the apps and shards of the matrices ([#76](https://github.com/saymyframe/smf_flutter_cli/issues/76)). ([423d6056](https://github.com/saymyframe/smf_flutter_cli/commit/423d60567ffaba2ef372eff6a4ef1dfe9c6e76dc))
 - **BREAKING** **TEST**(cli): run the app tests with the platform mocks of every module of the app, next to other providers of their roles ([#75](https://github.com/saymyframe/smf_flutter_cli/issues/75)). ([87001859](https://github.com/saymyframe/smf_flutter_cli/commit/87001859841890e28f3a9ab2ba685ee32c9bdd87))
 - **BREAKING** **FEAT**(contracts): continue a post-generation step of another module by its id ([#89](https://github.com/saymyframe/smf_flutter_cli/issues/89)). ([cfce8114](https://github.com/saymyframe/smf_flutter_cli/commit/cfce8114f4c1299d98ea3150695c79ae8c8065c8))
 - **BREAKING** **FEAT**(contracts): keep the platforms of the app in AppIdentity ([#58](https://github.com/saymyframe/smf_flutter_cli/issues/58)). ([eb1225ce](https://github.com/saymyframe/smf_flutter_cli/commit/eb1225cea24a9a4e6d5cc0375532ada7d71af96a))

#### `smf_firebase_crashlytics` - `v0.4.0`

 - **FIX**(contracts): leave out a provider of analytics or crash reporting that fails to be created. ([52d5b07b](https://github.com/saymyframe/smf_flutter_cli/commit/52d5b07b6804f1459eec52cbd6f880b4b1d57df7))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(firebase_crashlytics): fix the build phase of Crashlytics from its own module. ([4302a13c](https://github.com/saymyframe/smf_flutter_cli/commit/4302a13c2b7eb657e689f16fe51042eff7d117f7))
 - **BREAKING** **TEST**(cli): run the app tests with the platform mocks of every module of the app, next to other providers of their roles ([#75](https://github.com/saymyframe/smf_flutter_cli/issues/75)). ([87001859](https://github.com/saymyframe/smf_flutter_cli/commit/87001859841890e28f3a9ab2ba685ee32c9bdd87))

#### `smf_flutter_cli` - `v0.4.0`

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

#### `smf_flutter_core` - `v0.4.0`

 - **FIX**(ci): check that the apps start on devices without the connection of flutter test ([#48](https://github.com/saymyframe/smf_flutter_cli/issues/48)). ([05628617](https://github.com/saymyframe/smf_flutter_cli/commit/05628617185e55a75a3ad318570351ec067d6aa5))
 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(contracts): add the guide for coding agents to the app entry role ([#110](https://github.com/saymyframe/smf_flutter_cli/issues/110)). ([92b78ad8](https://github.com/saymyframe/smf_flutter_cli/commit/92b78ad863e409806ce491ea463de45c01503030))
 - **FEAT**(contracts): let the root MaterialApp take themeMode and locale from its context ([#100](https://github.com/saymyframe/smf_flutter_cli/issues/100)). ([3a10b311](https://github.com/saymyframe/smf_flutter_cli/commit/3a10b311d6ea8e5f1a29764c5fa9d90cb093aeb3))
 - **DOCS**: say that smf create adds a provider by itself only while it is the only one ([#55](https://github.com/saymyframe/smf_flutter_cli/issues/55)). ([4d1097d4](https://github.com/saymyframe/smf_flutter_cli/commit/4d1097d48e4bab3f86748b5764d33975614be933))
 - **BREAKING** **FEAT**(contracts,flutter_core,home,onboarding,settings): take the symbol of the app and the icons of the status bar from one place each ([#143](https://github.com/saymyframe/smf_flutter_cli/issues/143)). ([43a87a36](https://github.com/saymyframe/smf_flutter_cli/commit/43a87a36c3d847dc1398f415ec64de46a3a1a177))
 - **BREAKING** **FEAT**(contracts): keep the platforms of the app in AppIdentity ([#58](https://github.com/saymyframe/smf_flutter_cli/issues/58)). ([eb1225ce](https://github.com/saymyframe/smf_flutter_cli/commit/eb1225cea24a9a4e6d5cc0375532ada7d71af96a))

#### `smf_get_it` - `v0.4.0`

 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **DOCS**: say that smf create adds a provider by itself only while it is the only one ([#55](https://github.com/saymyframe/smf_flutter_cli/issues/55)). ([4d1097d4](https://github.com/saymyframe/smf_flutter_cli/commit/4d1097d48e4bab3f86748b5764d33975614be933))
 - **BREAKING** **FEAT**(contracts): require resetDependencies() of the providers of the DI role. ([9911bf11](https://github.com/saymyframe/smf_flutter_cli/commit/9911bf11bdfc654f284cdfaac5015b3ce690dee2))
 - **BREAKING** **FEAT**(contracts): drop the factory parameters of the DI role ([#64](https://github.com/saymyframe/smf_flutter_cli/issues/64)). ([0c8bc398](https://github.com/saymyframe/smf_flutter_cli/commit/0c8bc3981842e961f69cb4b21a0b26a10feca74d))

#### `smf_go_router` - `v0.4.0`

 - **REFACTOR**(go_router): write AppShell with the name of the layout role ([#63](https://github.com/saymyframe/smf_flutter_cli/issues/63)). ([a1f8ed28](https://github.com/saymyframe/smf_flutter_cli/commit/a1f8ed28e19ffa88bd6dbe63678761139bdccc73))
 - **FIX**(go_router): call each listener of the screen on its own. ([8b44ecd1](https://github.com/saymyframe/smf_flutter_cli/commit/8b44ecd1e02ca5aa01b12f0dbbaba4937c68972e))
 - **FIX**(go_router): complete push() with the value of its page after a refresh ([#71](https://github.com/saymyframe/smf_flutter_cli/issues/71)). ([ae37c5de](https://github.com/saymyframe/smf_flutter_cli/commit/ae37c5de79b6d387ea3f392461d3ebf5c2c2b9d6))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(go_router): ask the guards of the routes ([#111](https://github.com/saymyframe/smf_flutter_cli/issues/111)). ([ea4d43f6](https://github.com/saymyframe/smf_flutter_cli/commit/ea4d43f6d39d8036c3763ba01235638adbdb09ee))
 - **DOCS**: say that smf create adds a provider by itself only while it is the only one ([#55](https://github.com/saymyframe/smf_flutter_cli/issues/55)). ([4d1097d4](https://github.com/saymyframe/smf_flutter_cli/commit/4d1097d48e4bab3f86748b5764d33975614be933))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))

#### `smf_home_flutter` - `v0.4.0`

 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**(home): welcome the developer of the app on the start screen ([#138](https://github.com/saymyframe/smf_flutter_cli/issues/138)). ([0f0c7c86](https://github.com/saymyframe/smf_flutter_cli/commit/0f0c7c864e8b3877c988e905450a968219be054a))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **BREAKING** **FEAT**(contracts,flutter_core,home,onboarding,settings): take the symbol of the app and the icons of the status bar from one place each ([#143](https://github.com/saymyframe/smf_flutter_cli/issues/143)). ([43a87a36](https://github.com/saymyframe/smf_flutter_cli/commit/43a87a36c3d847dc1398f415ec64de46a3a1a177))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))
 - **BREAKING** **FEAT**(contracts): keep the platforms of the app in AppIdentity ([#58](https://github.com/saymyframe/smf_flutter_cli/issues/58)). ([eb1225ce](https://github.com/saymyframe/smf_flutter_cli/commit/eb1225cea24a9a4e6d5cc0375532ada7d71af96a))

#### `smf_onboarding` - `v0.4.0`

 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**(onboarding): show the pages as cells of the periodic table, with motion ([#137](https://github.com/saymyframe/smf_flutter_cli/issues/137)). ([875e738a](https://github.com/saymyframe/smf_flutter_cli/commit/875e738a10c4a002588684119da265d37f9f7a11))
 - **FEAT**(onboarding): add the onboarding of the first run ([#126](https://github.com/saymyframe/smf_flutter_cli/issues/126)). ([009d74d1](https://github.com/saymyframe/smf_flutter_cli/commit/009d74d11fad0840b883e5cd601872e4d6441700))
 - **BREAKING** **FEAT**(contracts,flutter_core,home,onboarding,settings): take the symbol of the app and the icons of the status bar from one place each ([#143](https://github.com/saymyframe/smf_flutter_cli/issues/143)). ([43a87a36](https://github.com/saymyframe/smf_flutter_cli/commit/43a87a36c3d847dc1398f415ec64de46a3a1a177))

#### `smf_pipeline` - `v0.4.0`

 - **REFACTOR**(contracts,pipeline,cli): split the functions that SonarCloud finds too complex. ([c3f5aadc](https://github.com/saymyframe/smf_flutter_cli/commit/c3f5aadc0ea6cf6458aa189cdd2936d850c4d1b9))
 - **FIX**(contracts): keep one provider of analytics or crash reporting from failing the others. ([42c8db26](https://github.com/saymyframe/smf_flutter_cli/commit/42c8db26e9c68c8733bf2d4dcd9e4eb195d861ab))
 - **FIX**(contracts,shared_preferences): correct the texts for coding agents and the READMEs that the reviews found wrong ([#132](https://github.com/saymyframe/smf_flutter_cli/issues/132)). ([7f936e51](https://github.com/saymyframe/smf_flutter_cli/commit/7f936e51b2f2ae2f80eba144f5cf29ae5d7101f9))
 - **FIX**(contracts): leave out a provider of analytics or crash reporting that fails to be created. ([52d5b07b](https://github.com/saymyframe/smf_flutter_cli/commit/52d5b07b6804f1459eec52cbd6f880b4b1d57df7))
 - **FIX**(go_router): complete push() with the value of its page after a refresh ([#71](https://github.com/saymyframe/smf_flutter_cli/issues/71)). ([ae37c5de](https://github.com/saymyframe/smf_flutter_cli/commit/ae37c5de79b6d387ea3f392461d3ebf5c2c2b9d6))
 - **FIX**(go_router): call each listener of the screen on its own. ([8b44ecd1](https://github.com/saymyframe/smf_flutter_cli/commit/8b44ecd1e02ca5aa01b12f0dbbaba4937c68972e))
 - **FIX**(contracts): say that on<T>() delivers the events fired once its stream is listened to. ([06668c45](https://github.com/saymyframe/smf_flutter_cli/commit/06668c45dd58e3d7de05b71f89c8eb474920ac5b))
 - **FIX**(pipeline): recognize module packages by their dependency on smf_contracts ([#59](https://github.com/saymyframe/smf_flutter_cli/issues/59)). ([87f45875](https://github.com/saymyframe/smf_flutter_cli/commit/87f45875e420b20fec3c1b8dade0ccd8dbd3a29f))
 - **FIX**(contracts): give each analytics service a copy of its own of the parameters. ([21c6ca39](https://github.com/saymyframe/smf_flutter_cli/commit/21c6ca39980e3af0446b053dac01267fd26788de))
 - **FEAT**(contracts): let the root MaterialApp take themeMode and locale from its context ([#100](https://github.com/saymyframe/smf_flutter_cli/issues/100)). ([3a10b311](https://github.com/saymyframe/smf_flutter_cli/commit/3a10b311d6ea8e5f1a29764c5fa9d90cb093aeb3))
 - **FEAT**(onboarding): add the onboarding of the first run ([#126](https://github.com/saymyframe/smf_flutter_cli/issues/126)). ([009d74d1](https://github.com/saymyframe/smf_flutter_cli/commit/009d74d11fad0840b883e5cd601872e4d6441700))
 - **FEAT**(contracts,settings): describe the settings screen in the guide for coding agents ([#129](https://github.com/saymyframe/smf_flutter_cli/issues/129)). ([f6353e4d](https://github.com/saymyframe/smf_flutter_cli/commit/f6353e4d8a864949a5b58ce78b8e3c4ddeff7175))
 - **FEAT**(settings): read the title of the settings screen in the language of the app ([#128](https://github.com/saymyframe/smf_flutter_cli/issues/128)). ([493dff7b](https://github.com/saymyframe/smf_flutter_cli/commit/493dff7bdb396a6d4ee89cb5220fad22fa9f68bc))
 - **FEAT**(material_theme): add the module of the Material 3 theme ([#123](https://github.com/saymyframe/smf_flutter_cli/issues/123)). ([9801be57](https://github.com/saymyframe/smf_flutter_cli/commit/9801be57a9523db6cfa1a3ae2a29199c0dd2d0f9))
 - **FEAT**(home): welcome the developer of the app on the start screen ([#138](https://github.com/saymyframe/smf_flutter_cli/issues/138)). ([0f0c7c86](https://github.com/saymyframe/smf_flutter_cli/commit/0f0c7c864e8b3877c988e905450a968219be054a))
 - **FEAT**(contracts): remember the language of the app and let the user choose it in the settings ([#120](https://github.com/saymyframe/smf_flutter_cli/issues/120)). ([9f3c847b](https://github.com/saymyframe/smf_flutter_cli/commit/9f3c847bc372a9b6a1d852d7cf6da2a69f172afe))
 - **FEAT**(contracts): tell coding agents about the guards of the routes ([#119](https://github.com/saymyframe/smf_flutter_cli/issues/119)). ([262427e6](https://github.com/saymyframe/smf_flutter_cli/commit/262427e68aa737aa812241867507fbdc48729668))
 - **FEAT**(gen_l10n): provide the localization role with gen-l10n of Flutter ([#117](https://github.com/saymyframe/smf_flutter_cli/issues/117)). ([36afeb32](https://github.com/saymyframe/smf_flutter_cli/commit/36afeb32e8e21c1a14fb4345bbbbcd252bd7260a))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(contracts): guarantee a MaterialApp at the root of the app ([#57](https://github.com/saymyframe/smf_flutter_cli/issues/57)). ([5bc4f0b8](https://github.com/saymyframe/smf_flutter_cli/commit/5bc4f0b8b7f5c7ca003f007b1fb2a711beef7289))
 - **FEAT**(shared_preferences): add the module that keeps the preferences with shared_preferences ([#113](https://github.com/saymyframe/smf_flutter_cli/issues/113)). ([170c9ff3](https://github.com/saymyframe/smf_flutter_cli/commit/170c9ff307d0bc7a766d4434ec0c46ef572fe6bf))
 - **FEAT**(contracts): add the guide for coding agents to the app entry role ([#110](https://github.com/saymyframe/smf_flutter_cli/issues/110)). ([92b78ad8](https://github.com/saymyframe/smf_flutter_cli/commit/92b78ad863e409806ce491ea463de45c01503030))
 - **FEAT**(settings): add the settings module, a screen for the entries of the modules ([#108](https://github.com/saymyframe/smf_flutter_cli/issues/108)). ([72264395](https://github.com/saymyframe/smf_flutter_cli/commit/722643958073a814660bbf51bd7eb4352dad40e7))
 - **FEAT**(contracts,pipeline): add the localization role ([#107](https://github.com/saymyframe/smf_flutter_cli/issues/107)). ([84091023](https://github.com/saymyframe/smf_flutter_cli/commit/840910231936c42fa783f9f9b9a430610a52e003))
 - **FEAT**(contracts): add the preferences role for the settings of the app that are no secret ([#106](https://github.com/saymyframe/smf_flutter_cli/issues/106)). ([3304ebd2](https://github.com/saymyframe/smf_flutter_cli/commit/3304ebd267731bb624d61d13c5823ace4cfd5b45))
 - **FEAT**(contracts,pipeline): let a brick variable depend on the presence of a role ([#104](https://github.com/saymyframe/smf_flutter_cli/issues/104)). ([02677b81](https://github.com/saymyframe/smf_flutter_cli/commit/02677b814381632ea0400126ef59c1ab0c188d76))
 - **FEAT**(contracts,pipeline): let a render hook generate files of the app ([#102](https://github.com/saymyframe/smf_flutter_cli/issues/102)). ([620eb402](https://github.com/saymyframe/smf_flutter_cli/commit/620eb40246af1db18d9a139e67eb39a823c1ce87))
 - **FEAT**(contracts,pipeline): check that a provider of the app entry creates the root where the arguments of the modules read its context ([#101](https://github.com/saymyframe/smf_flutter_cli/issues/101)). ([78293c3c](https://github.com/saymyframe/smf_flutter_cli/commit/78293c3c881dd5471f5b9cce2445a7d437922b0c))
 - **FEAT**(contracts): add the theme role ([#112](https://github.com/saymyframe/smf_flutter_cli/issues/112)). ([822056da](https://github.com/saymyframe/smf_flutter_cli/commit/822056daf2695b8007e30ade24213b4c6252bebf))
 - **FEAT**(cli): fan out the jobs of CI over a pairwise covering of the apps and shards of the matrices ([#76](https://github.com/saymyframe/smf_flutter_cli/issues/76)). ([423d6056](https://github.com/saymyframe/smf_flutter_cli/commit/423d60567ffaba2ef372eff6a4ef1dfe9c6e76dc))
 - **FEAT**(firebase_crashlytics): fix the build phase of Crashlytics from its own module. ([4302a13c](https://github.com/saymyframe/smf_flutter_cli/commit/4302a13c2b7eb657e689f16fe51042eff7d117f7))
 - **FEAT**(bottom_tabs,material_theme): draw the bar of the tabs without an indicator, in the colours of the theme ([#136](https://github.com/saymyframe/smf_flutter_cli/issues/136)). ([23fcbb77](https://github.com/saymyframe/smf_flutter_cli/commit/23fcbb77e944a679bdaa391c885c2a76734c8648))
 - **FEAT**(cli): run the probes of the tests of the roles in the start check. ([f7faea4e](https://github.com/saymyframe/smf_flutter_cli/commit/f7faea4e0f5c4553e7cc4f2bad9d12d6efba8ca2))
 - **FEAT**(pipeline): give the result of a contract case the hook request of its app. ([1b46e2fb](https://github.com/saymyframe/smf_flutter_cli/commit/1b46e2fb6d6ca3a6ede21236f263637bf3551981))
 - **FEAT**(pipeline): keep in the rendered app the order of the contributions of every socket. ([3cd6c981](https://github.com/saymyframe/smf_flutter_cli/commit/3cd6c9819c380fb55f34832b3c15fe6b20791212))
 - **FEAT**(onboarding): show the pages as cells of the periodic table, with motion ([#137](https://github.com/saymyframe/smf_flutter_cli/issues/137)). ([875e738a](https://github.com/saymyframe/smf_flutter_cli/commit/875e738a10c4a002588684119da265d37f9f7a11))
 - **FEAT**(material_theme): give the themes a palette, text styles and a bundled font ([#135](https://github.com/saymyframe/smf_flutter_cli/issues/135)). ([f9c6a279](https://github.com/saymyframe/smf_flutter_cli/commit/f9c6a279d9c5fd245d0dded9dca85e028455a934))
 - **FEAT**(settings,contracts): show the settings as one group, the theme modes as segments and the languages in a sheet ([#140](https://github.com/saymyframe/smf_flutter_cli/issues/140)). ([72a29d05](https://github.com/saymyframe/smf_flutter_cli/commit/72a29d05024e6a5f7326e1c446d9b6833d4a9054))
 - **FEAT**(pipeline): check the notes of roles against their providers, and require a note from every role and module ([#131](https://github.com/saymyframe/smf_flutter_cli/issues/131)). ([2980ddc1](https://github.com/saymyframe/smf_flutter_cli/commit/2980ddc13ff7a77be5122b4fe4515ebaa1e1eb70))
 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**(pipeline): check that the code of modules takes the names of the classes of roles from the roles, in the fixtures too ([#86](https://github.com/saymyframe/smf_flutter_cli/issues/86)). ([64d130c8](https://github.com/saymyframe/smf_flutter_cli/commit/64d130c829fd87be8924773737237caf29be4923))
 - **DOCS**: describe the tests of the roles at run time and the broken providers that they fail on. ([0501c45c](https://github.com/saymyframe/smf_flutter_cli/commit/0501c45c2cfb564e46091d76a88cdd0d849de1d1))
 - **DOCS**: say which expectation gives the reason of a broken provider, and that the app of several providers walks the routes. ([5495f757](https://github.com/saymyframe/smf_flutter_cli/commit/5495f757ea427f7ccf0f9a2991c6d6a5bf8f5694))
 - **DOCS**: describe the plan of CI and the checks of the app tests as they are ([#81](https://github.com/saymyframe/smf_flutter_cli/issues/81)). ([629321e9](https://github.com/saymyframe/smf_flutter_cli/commit/629321e9fb7a4632818d04aa556e73f1c1e3d747))
 - **DOCS**(readme): add the SonarCloud coverage badge ([#99](https://github.com/saymyframe/smf_flutter_cli/issues/99)). ([39c28873](https://github.com/saymyframe/smf_flutter_cli/commit/39c288733a22495b6b90ef6afc67d89704eefcee))
 - **BREAKING** **TEST**(cli): run the app tests with the platform mocks of every module of the app, next to other providers of their roles ([#75](https://github.com/saymyframe/smf_flutter_cli/issues/75)). ([87001859](https://github.com/saymyframe/smf_flutter_cli/commit/87001859841890e28f3a9ab2ba685ee32c9bdd87))
 - **BREAKING** **REFACTOR**(pipeline): index Dart files with the AST of analyzer 13, which it now needs (13.1 or later). ([e4ecaded](https://github.com/saymyframe/smf_flutter_cli/commit/e4ecadeded1ae3a6d7b2d66fc1d7c29a27e0cbfe))
 - **BREAKING** **REFACTOR**(cli): group the apps that runMatrix and createEveryModuleApps take into one parameter each ([#97](https://github.com/saymyframe/smf_flutter_cli/issues/97)). ([d60801f2](https://github.com/saymyframe/smf_flutter_cli/commit/d60801f2871dd68eea6b8dddc5339462e02ed280))
 - **BREAKING** **FEAT**(contracts): continue a post-generation step of another module by its id ([#89](https://github.com/saymyframe/smf_flutter_cli/issues/89)). ([cfce8114](https://github.com/saymyframe/smf_flutter_cli/commit/cfce8114f4c1299d98ea3150695c79ae8c8065c8))
 - **BREAKING** **FEAT**(pipeline): build the cases of the roles a module uses with each of their providers ([#88](https://github.com/saymyframe/smf_flutter_cli/issues/88)). ([f5ecbb45](https://github.com/saymyframe/smf_flutter_cli/commit/f5ecbb45eb715f4237a57fb57bef124ef73a6b4a))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))
 - **BREAKING** **FEAT**(contracts): drop the factory parameters of the DI role ([#64](https://github.com/saymyframe/smf_flutter_cli/issues/64)). ([0c8bc398](https://github.com/saymyframe/smf_flutter_cli/commit/0c8bc3981842e961f69cb4b21a0b26a10feca74d))
 - **BREAKING** **FEAT**(contracts): require the getters that code of a role reads, such as the navigation of the AppShell ([#69](https://github.com/saymyframe/smf_flutter_cli/issues/69)). ([5e5301d8](https://github.com/saymyframe/smf_flutter_cli/commit/5e5301d82120389548d59a8cb44547a71f2f2755))
 - **BREAKING** **FEAT**(contracts): keep the platforms of the app in AppIdentity ([#58](https://github.com/saymyframe/smf_flutter_cli/issues/58)). ([eb1225ce](https://github.com/saymyframe/smf_flutter_cli/commit/eb1225cea24a9a4e6d5cc0375532ada7d71af96a))
 - **BREAKING** **FEAT**(contracts,flutter_core,home,onboarding,settings): take the symbol of the app and the icons of the status bar from one place each ([#143](https://github.com/saymyframe/smf_flutter_cli/issues/143)). ([43a87a36](https://github.com/saymyframe/smf_flutter_cli/commit/43a87a36c3d847dc1398f415ec64de46a3a1a177))
 - **BREAKING** **FEAT**(contracts): let one contributor give the supported locales of the root MaterialApp ([#121](https://github.com/saymyframe/smf_flutter_cli/issues/121)). ([5a440409](https://github.com/saymyframe/smf_flutter_cli/commit/5a4404090da4cfe0892df42916c1b6f1275b3b44))
 - **BREAKING** **FEAT**(contracts): require resetDependencies() of the providers of the DI role. ([9911bf11](https://github.com/saymyframe/smf_flutter_cli/commit/9911bf11bdfc654f284cdfaac5015b3ce690dee2))

#### `smf_settings` - `v0.4.0`

 - **FEAT**(settings,contracts): show the settings as one group, the theme modes as segments and the languages in a sheet ([#140](https://github.com/saymyframe/smf_flutter_cli/issues/140)). ([72a29d05](https://github.com/saymyframe/smf_flutter_cli/commit/72a29d05024e6a5f7326e1c446d9b6833d4a9054))
 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**(contracts,settings): describe the settings screen in the guide for coding agents ([#129](https://github.com/saymyframe/smf_flutter_cli/issues/129)). ([f6353e4d](https://github.com/saymyframe/smf_flutter_cli/commit/f6353e4d8a864949a5b58ce78b8e3c4ddeff7175))
 - **FEAT**(settings): read the title of the settings screen in the language of the app ([#128](https://github.com/saymyframe/smf_flutter_cli/issues/128)). ([493dff7b](https://github.com/saymyframe/smf_flutter_cli/commit/493dff7bdb396a6d4ee89cb5220fad22fa9f68bc))
 - **FEAT**(settings): add the settings module, a screen for the entries of the modules ([#108](https://github.com/saymyframe/smf_flutter_cli/issues/108)). ([72264395](https://github.com/saymyframe/smf_flutter_cli/commit/722643958073a814660bbf51bd7eb4352dad40e7))
 - **DOCS**(settings): say why nothing opens the settings screen of an app without another screen, with any layout. ([696d4ccd](https://github.com/saymyframe/smf_flutter_cli/commit/696d4ccdc457aff78625dfcac08d2adc063619a9))
 - **BREAKING** **FEAT**(contracts,flutter_core,home,onboarding,settings): take the symbol of the app and the icons of the status bar from one place each ([#143](https://github.com/saymyframe/smf_flutter_cli/issues/143)). ([43a87a36](https://github.com/saymyframe/smf_flutter_cli/commit/43a87a36c3d847dc1398f415ec64de46a3a1a177))
 - **BREAKING** **FEAT**(contracts,go_router,bottom_tabs,home,settings): label the destinations in the language of the app ([#127](https://github.com/saymyframe/smf_flutter_cli/issues/127)). ([7cc173f0](https://github.com/saymyframe/smf_flutter_cli/commit/7cc173f0756807c274a98bfceeac3b8db99bb835))

#### `smf_gen_l10n` - `v0.4.0`

 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**(contracts): remember the language of the app and let the user choose it in the settings ([#120](https://github.com/saymyframe/smf_flutter_cli/issues/120)). ([9f3c847b](https://github.com/saymyframe/smf_flutter_cli/commit/9f3c847bc372a9b6a1d852d7cf6da2a69f172afe))
 - **FEAT**(gen_l10n): provide the localization role with gen-l10n of Flutter ([#117](https://github.com/saymyframe/smf_flutter_cli/issues/117)). ([36afeb32](https://github.com/saymyframe/smf_flutter_cli/commit/36afeb32e8e21c1a14fb4345bbbbcd252bd7260a))

#### `smf_material_theme` - `v0.4.0`

 - **FEAT**(flutter_core): give the fallback start screen the look of the app ([#139](https://github.com/saymyframe/smf_flutter_cli/issues/139)). ([75d223f1](https://github.com/saymyframe/smf_flutter_cli/commit/75d223f1644b821594a73f88099fa720c65d673e))
 - **FEAT**(bottom_tabs,material_theme): draw the bar of the tabs without an indicator, in the colours of the theme ([#136](https://github.com/saymyframe/smf_flutter_cli/issues/136)). ([23fcbb77](https://github.com/saymyframe/smf_flutter_cli/commit/23fcbb77e944a679bdaa391c885c2a76734c8648))
 - **FEAT**(material_theme): give the themes a palette, text styles and a bundled font ([#135](https://github.com/saymyframe/smf_flutter_cli/issues/135)). ([f9c6a279](https://github.com/saymyframe/smf_flutter_cli/commit/f9c6a279d9c5fd245d0dded9dca85e028455a934))
 - **FEAT**(settings): read the title of the settings screen in the language of the app ([#128](https://github.com/saymyframe/smf_flutter_cli/issues/128)). ([493dff7b](https://github.com/saymyframe/smf_flutter_cli/commit/493dff7bdb396a6d4ee89cb5220fad22fa9f68bc))
 - **FEAT**(material_theme): add the module of the Material 3 theme ([#123](https://github.com/saymyframe/smf_flutter_cli/issues/123)). ([9801be57](https://github.com/saymyframe/smf_flutter_cli/commit/9801be57a9523db6cfa1a3ae2a29199c0dd2d0f9))

#### `smf_shared_preferences` - `v0.4.0`

 - **FIX**(contracts,shared_preferences): correct the texts for coding agents and the READMEs that the reviews found wrong ([#132](https://github.com/saymyframe/smf_flutter_cli/issues/132)). ([7f936e51](https://github.com/saymyframe/smf_flutter_cli/commit/7f936e51b2f2ae2f80eba144f5cf29ae5d7101f9))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(shared_preferences): add the module that keeps the preferences with shared_preferences ([#113](https://github.com/saymyframe/smf_flutter_cli/issues/113)). ([170c9ff3](https://github.com/saymyframe/smf_flutter_cli/commit/170c9ff307d0bc7a766d4434ec0c46ef572fe6bf))

#### `smf_bloc` - `v0.3.1`

 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))

#### `smf_event_bus` - `v0.3.1`

 - **FIX**(contracts): say that on<T>() delivers the events fired once its stream is listened to. ([06668c45](https://github.com/saymyframe/smf_flutter_cli/commit/06668c45dd58e3d7de05b71f89c8eb474920ac5b))
 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))

#### `smf_riverpod` - `v0.3.1`

 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))


## 2026-09-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`smf_contribution_engine` - `v0.2.2`](#smf_contribution_engine---v022)

---

#### `smf_contribution_engine` - `v0.2.2`

 - **FIX**(contribution_engine): fix the known bugs of the inserts, the widget matching and the formatter ([#46](https://github.com/saymyframe/smf_flutter_cli/issues/46)). ([2b86c053](https://github.com/saymyframe/smf_flutter_cli/commit/2b86c05392a677a4f0539fcb5a0970600e424819))


## 2026-09-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`smf_contribution_engine` - `v0.2.1`](#smf_contribution_engine---v021)

---

#### `smf_contribution_engine` - `v0.2.1`

 - **DOCS**: say that the modules of the SMF CLI do not use the engine, and add an example.

 - **FIX**(contribution_engine): imports, widget edits and mustache rendering ([#27](https://github.com/saymyframe/smf_flutter_cli/issues/27)). ([daa02e56](https://github.com/saymyframe/smf_flutter_cli/commit/daa02e5625f433fdd7a6ed55f1850390102f7748))


## 2026-09-29

### Changes

---

Packages with breaking changes:

 - [`smf_firebase_crashlytics` - `v0.3.0`](#smf_firebase_crashlytics---v030)
 - [`smf_bloc` - `v0.3.0`](#smf_bloc---v030)
 - [`smf_bottom_tabs` - `v0.3.0`](#smf_bottom_tabs---v030)
 - [`smf_contracts` - `v0.3.0`](#smf_contracts---v030)
 - [`smf_event_bus` - `v0.3.0`](#smf_event_bus---v030)
 - [`smf_firebase_analytics` - `v0.3.0`](#smf_firebase_analytics---v030)
 - [`smf_firebase_core` - `v0.3.0`](#smf_firebase_core---v030)
 - [`smf_flutter_cli` - `v0.3.0`](#smf_flutter_cli---v030)
 - [`smf_flutter_core` - `v0.3.0`](#smf_flutter_core---v030)
 - [`smf_get_it` - `v0.3.0`](#smf_get_it---v030)
 - [`smf_go_router` - `v0.3.0`](#smf_go_router---v030)
 - [`smf_home_flutter` - `v0.3.0`](#smf_home_flutter---v030)
 - [`smf_pipeline` - `v0.3.0`](#smf_pipeline---v030)
 - [`smf_riverpod` - `v0.3.0`](#smf_riverpod---v030)

Packages with other changes:

 - There are no other changes in this release.

---

#### `smf_firebase_crashlytics` - `v0.3.0`

 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_bloc` - `v0.3.0`

 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_bottom_tabs` - `v0.3.0`

 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_contracts` - `v0.3.0`

 - **FIX**(go_router,contracts): route merging, guard imports, AppRoutes and camelCase ([#26](https://github.com/saymyframe/smf_flutter_cli/issues/26)). ([abcedc5d](https://github.com/saymyframe/smf_flutter_cli/commit/abcedc5d7b1b704e1626b495f934e050382d9a2c))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_event_bus` - `v0.3.0`

 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_firebase_analytics` - `v0.3.0`

 - **FIX**(firebase_analytics): add bloc and riverpod variants of the demo feature ([#24](https://github.com/saymyframe/smf_flutter_cli/issues/24)). ([52212678](https://github.com/saymyframe/smf_flutter_cli/commit/52212678b9bf3bb825cbcf8f86df7953d7dad36e))
 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **FEAT**: firebase crashlytics module. ([beffc40b](https://github.com/saymyframe/smf_flutter_cli/commit/beffc40bd2c28dcbc07fdf4f63fa22534d2632e3))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_firebase_core` - `v0.3.0`

 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_flutter_cli` - `v0.3.0`

 - **FIX**(firebase_analytics): add bloc and riverpod variants of the demo feature ([#24](https://github.com/saymyframe/smf_flutter_cli/issues/24)). ([52212678](https://github.com/saymyframe/smf_flutter_cli/commit/52212678b9bf3bb825cbcf8f86df7953d7dad36e))
 - **FIX**(cli): print the real version in smf --version ([#25](https://github.com/saymyframe/smf_flutter_cli/issues/25)). ([ad569837](https://github.com/saymyframe/smf_flutter_cli/commit/ad569837614518f18f216de17d80ee48f9b0fb83))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_flutter_core` - `v0.3.0`

 - **FIX**(flutter_core): drop machine-local files from the core brick bundle. ([6f0f3b4b](https://github.com/saymyframe/smf_flutter_cli/commit/6f0f3b4b75063472f9422009a093844d5995159e))
 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **FEAT**: firebase crashlytics module. ([beffc40b](https://github.com/saymyframe/smf_flutter_cli/commit/beffc40bd2c28dcbc07fdf4f63fa22534d2632e3))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_get_it` - `v0.3.0`

 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_go_router` - `v0.3.0`

 - **FIX**(go_router,contracts): route merging, guard imports, AppRoutes and camelCase ([#26](https://github.com/saymyframe/smf_flutter_cli/issues/26)). ([abcedc5d](https://github.com/saymyframe/smf_flutter_cli/commit/abcedc5d7b1b704e1626b495f934e050382d9a2c))
 - **FIX**(go_router): remove unrendered tabs shell when no module adds tabs ([#16](https://github.com/saymyframe/smf_flutter_cli/issues/16)). ([1b42b8cc](https://github.com/saymyframe/smf_flutter_cli/commit/1b42b8cc7391d5424a9497b73a344b98cd9d7e39))
 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **FEAT**: firebase crashlytics module. ([beffc40b](https://github.com/saymyframe/smf_flutter_cli/commit/beffc40bd2c28dcbc07fdf4f63fa22534d2632e3))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_home_flutter` - `v0.3.0`

 - **FIX**(firebase_core): fix Firebase installation process across platforms. ([#14](https://github.com/saymyframe/smf_flutter_cli/issues/14)). ([103a3080](https://github.com/saymyframe/smf_flutter_cli/commit/103a3080f19314d631891e5951a4f6f52d8a6f3e))
 - **FEAT**: firebase crashlytics module. ([beffc40b](https://github.com/saymyframe/smf_flutter_cli/commit/beffc40bd2c28dcbc07fdf4f63fa22534d2632e3))
 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_pipeline` - `v0.3.0`

 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

#### `smf_riverpod` - `v0.3.0`

 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))


## 2025-09-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`smf_flutter_cli` - `v0.2.1+1`](#smf_flutter_cli---v0211)

---

#### `smf_flutter_cli` - `v0.2.1+1`

 - **FIX**(safe-write): correct project name in safe write. ([e1cdb985](https://github.com/saymyframe/smf_flutter_cli/commit/e1cdb98564f302c25485418c1c42f04d8c497524))


## 2025-09-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`smf_flutter_cli` - `v0.2.1`](#smf_flutter_cli---v021)

---

#### `smf_flutter_cli` - `v0.2.1`

 - **FIX**: add extra space between emoji and message. ([#11](https://github.com/saymyframe/smf_flutter_cli/issues/11)). ([84535ff4](https://github.com/saymyframe/smf_flutter_cli/commit/84535ff47ac322e587ef3921372060f94f9fd443))
 - **FEAT**: improve UX when cli stop with an error. ([f770f643](https://github.com/saymyframe/smf_flutter_cli/commit/f770f64307515a0ce9252d7c4fd55a3a1d082c84))
 - **FEAT**: firebase crashlytics module. ([9679223f](https://github.com/saymyframe/smf_flutter_cli/commit/9679223f6f635e3d98a88fa671fc9fb6ff1c30fb))


## 2025-09-01

### Changes

---

Packages with breaking changes:

 - [`smf_flutter_cli` - `v0.2.0`](#smf_flutter_cli---v020)

Packages with other changes:

 - There are no other changes in this release.

---

#### `smf_flutter_cli` - `v0.2.0`

 - **FIX**(prompt): avoid crash when no module provides an initial route. ([9c295b99](https://github.com/saymyframe/smf_flutter_cli/commit/9c295b997c903792cbafda7ffb7aefcaa0907d5c))
 - **FEAT**: app post gen cta message. ([2bfb7f46](https://github.com/saymyframe/smf_flutter_cli/commit/2bfb7f467c7df6472a756e9f307185d0ad9ff6cb))
 - **FEAT**: app post gen cta message. ([5a714024](https://github.com/saymyframe/smf_flutter_cli/commit/5a71402475e1c022caacb143d4d1c34332b7a28b))
 - **FEAT**: add safe write mechanism. ([e174323a](https://github.com/saymyframe/smf_flutter_cli/commit/e174323a77a297febc13ba1285e992c3f015f297))
 - **DOCS**: add comprehensive API documentation and fix linting issues. ([50dac3d6](https://github.com/saymyframe/smf_flutter_cli/commit/50dac3d656302140dc3191b8e21f104890818a6a))
 - **DOCS**: add comprehensive API documentation and copyright headers. ([5872d386](https://github.com/saymyframe/smf_flutter_cli/commit/5872d3860e5035bd74005f464b77093bd55a58b8))
 - **BREAKING** **FEAT**(cli): adopt factories with ModuleCreator; add --strict and verbose dep logs ([#3](https://github.com/saymyframe/smf_flutter_cli/issues/3)). ([2a669b81](https://github.com/saymyframe/smf_flutter_cli/commit/2a669b8138c4e742622de36741d6d96229b214d2))

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-06-XX

### Added
- Initial version of SMF Flutter CLI
- Basic project scaffolding capabilities
- Modular architecture support
