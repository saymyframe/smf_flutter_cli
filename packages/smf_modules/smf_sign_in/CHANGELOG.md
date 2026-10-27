## 0.6.1

 - **REFACTOR**(contracts,pipeline,cli,sign_in): split the functions that SonarCloud finds too complex ([#240](https://github.com/saymyframe/smf_flutter_cli/issues/240)). ([7055060d](https://github.com/saymyframe/smf_flutter_cli/commit/7055060df967273c99faa10f381fcca99b19955b))
 - **FIX**(sign_in): measure the words of a text between every white space but a no-break space, and check where its lines start ([#267](https://github.com/saymyframe/smf_flutter_cli/issues/267)). ([597b5c5f](https://github.com/saymyframe/smf_flutter_cli/commit/597b5c5f9b07f8e1c135eb202a5a2b8ddbfeb839))

## 0.6.0

> Note: This release has breaking changes.

 - **FIX**(sign_in): let the pages of the sign-in scroll under the bar of the home gesture ([#223](https://github.com/saymyframe/smf_flutter_cli/issues/223)). ([9faac56b](https://github.com/saymyframe/smf_flutter_cli/commit/9faac56bec27d7a2038484529241f0a8618e9fa7))
 - **FEAT**(sign_in): continue with the sign-in methods of the app ([#219](https://github.com/saymyframe/smf_flutter_cli/issues/219)). ([5c2a7051](https://github.com/saymyframe/smf_flutter_cli/commit/5c2a705198ce2e6ad525ed40983e3d8ce5c53db0))
 - **BREAKING** **FEAT**(contracts): sign in with a credential of an identity provider, and list the ways to sign in of an app ([#197](https://github.com/saymyframe/smf_flutter_cli/issues/197)). ([73e8a21c](https://github.com/saymyframe/smf_flutter_cli/commit/73e8a21cb3807482f53a161baf1b9b0717aea5e4))
 - **BREAKING** **FEAT**(contracts): give each warning about the app a code, and let a choice report one ([#188](https://github.com/saymyframe/smf_flutter_cli/issues/188)). ([80f2c7ed](https://github.com/saymyframe/smf_flutter_cli/commit/80f2c7edd737e63ea3085b8202bb04a9bc9c4b7b))

## 0.5.1

 - **FIX**(shared_preferences): keep shared_preferences_android below 2.5.0, whose release builds fail to open the preferences ([#204](https://github.com/saymyframe/smf_flutter_cli/issues/204)). ([2ddbaed2](https://github.com/saymyframe/smf_flutter_cli/commit/2ddbaed27da0031c144abb606c6d192a94a3eda8))

## 0.5.0

 - **FEAT**(contracts): warn of the destinations of an app without a main navigation ([#175](https://github.com/saymyframe/smf_flutter_cli/issues/175)). ([39a624ba](https://github.com/saymyframe/smf_flutter_cli/commit/39a624ba72cb4d4c878409f46bb8b266820d3ebd))
 - **FEAT**(sign_in): add the account screen and the entry of the settings screen that leads to it ([#171](https://github.com/saymyframe/smf_flutter_cli/issues/171)). ([4d7fac2b](https://github.com/saymyframe/smf_flutter_cli/commit/4d7fac2bf04907ce9c9474b5accbca1247d3fed3))
 - **FEAT**(sign_in): add the module with the screens of sign-in, sign-up and password reset, in a bloc and a riverpod variant ([#170](https://github.com/saymyframe/smf_flutter_cli/issues/170)). ([bfcd9025](https://github.com/saymyframe/smf_flutter_cli/commit/bfcd9025f26b607315846995ed1a2006930a7a0f))

