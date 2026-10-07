## 0.4.0

> Note: This release has breaking changes.

 - **FEAT**: describe the roles and the modules in the guide for coding agents ([#114](https://github.com/saymyframe/smf_flutter_cli/issues/114)). ([6b300074](https://github.com/saymyframe/smf_flutter_cli/commit/6b3000741ecfae8e17b390738e9e797518be630f))
 - **FEAT**(firebase_crashlytics): fix the build phase of Crashlytics from its own module. ([4302a13c](https://github.com/saymyframe/smf_flutter_cli/commit/4302a13c2b7eb657e689f16fe51042eff7d117f7))
 - **FEAT**(cli): fan out the jobs of CI over a pairwise covering of the apps and shards of the matrices ([#76](https://github.com/saymyframe/smf_flutter_cli/issues/76)). ([423d6056](https://github.com/saymyframe/smf_flutter_cli/commit/423d60567ffaba2ef372eff6a4ef1dfe9c6e76dc))
 - **BREAKING** **TEST**(cli): run the app tests with the platform mocks of every module of the app, next to other providers of their roles ([#75](https://github.com/saymyframe/smf_flutter_cli/issues/75)). ([87001859](https://github.com/saymyframe/smf_flutter_cli/commit/87001859841890e28f3a9ab2ba685ee32c9bdd87))
 - **BREAKING** **FEAT**(contracts): continue a post-generation step of another module by its id ([#89](https://github.com/saymyframe/smf_flutter_cli/issues/89)). ([cfce8114](https://github.com/saymyframe/smf_flutter_cli/commit/cfce8114f4c1299d98ea3150695c79ae8c8065c8))
 - **BREAKING** **FEAT**(contracts): keep the platforms of the app in AppIdentity ([#58](https://github.com/saymyframe/smf_flutter_cli/issues/58)). ([eb1225ce](https://github.com/saymyframe/smf_flutter_cli/commit/eb1225cea24a9a4e6d5cc0375532ada7d71af96a))

## 0.3.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: compose apps from roles and sockets ([#31](https://github.com/saymyframe/smf_flutter_cli/issues/31)). ([7cf4d4a4](https://github.com/saymyframe/smf_flutter_cli/commit/7cf4d4a4b58a14e2b497b4e817f04ef466872c01))

## 0.2.1+1

 - **FIX**(firebase_core): check if Firebase CLI is installed. ([4462df06](https://github.com/saymyframe/smf_modules/commit/4462df06601637af1c5b3661dbdd1688735ad54f))

## 0.2.1

- **FIX**(firebase_core): fix Firebase installation process across
  platforms. ([#14](https://github.com/saymyframe/smf_modules/issues/14)). ([6b50f3e9](https://github.com/saymyframe/smf_modules/commit/6b50f3e95f9332bd79c42c1d506076ac8372b623))

## 0.2.0

> Note: This release has breaking changes.

- **REFACTOR**: remove hardcoded values and fix Firebase/Home module
  dependencies. ([f60c4f94](https://github.com/saymyframe/smf_modules/commit/f60c4f94e80c5a19cadd30a96ae2d65555037970))
- **BREAKING** **FEAT**(modules): migrate modules to factories with profile
  support. ([b94a95dd](https://github.com/saymyframe/smf_modules/commit/b94a95ddacf7eeeafadf86abd163c73e394331a6))

## 0.1.0

- Initial version.
