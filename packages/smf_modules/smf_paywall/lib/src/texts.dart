import 'package:smf_contracts/smf_contracts.dart';

/// The texts of the paywall and of the screen of the subscription, which
/// every app with the module has, in English and in Ukrainian.
///
/// A text has no parameters, so what depends on a plan comes from closed
/// sets: a name and a suffix of the price for each period that a plan is
/// billed by, and a length for each length of an intro offer that the
/// stores have, which the paywall puts together with the price that the
/// store gives.
const paywallTexts = TextsData([
  LocalizedText('close', en: 'Close', translations: {'uk': 'Закрити'}),
  LocalizedText('premium', en: 'Premium', translations: {'uk': 'Преміум'}),
  LocalizedText(
    'benefitAll',
    en: 'Every feature of the app, without limits',
    translations: {'uk': 'Усі можливості застосунку без обмежень'},
  ),
  LocalizedText(
    'benefitNew',
    en: 'New features as soon as they arrive',
    translations: {'uk': 'Нові можливості, щойно вони з’являються'},
  ),
  LocalizedText(
    'benefitSupport',
    en: 'Support for the work on the app',
    translations: {'uk': 'Підтримка роботи над застосунком'},
  ),
  LocalizedText(
    'bestValue',
    en: 'Best value',
    translations: {'uk': 'Найвигідніше'},
  ),
  LocalizedText('planWeekly', en: 'Weekly', translations: {'uk': 'Щотижня'}),
  LocalizedText(
    'planMonthly',
    en: 'Monthly',
    translations: {'uk': 'Щомісяця'},
  ),
  LocalizedText(
    'planTwoMonths',
    en: 'Every 2 months',
    translations: {'uk': 'Кожні 2 місяці'},
  ),
  LocalizedText(
    'planThreeMonths',
    en: 'Every 3 months',
    translations: {'uk': 'Кожні 3 місяці'},
  ),
  LocalizedText(
    'planSixMonths',
    en: 'Every 6 months',
    translations: {'uk': 'Кожні 6 місяців'},
  ),
  LocalizedText('planYearly', en: 'Yearly', translations: {'uk': 'Щороку'}),
  LocalizedText(
    'planLifetime',
    en: 'Lifetime',
    translations: {'uk': 'Назавжди'},
  ),
  LocalizedText('perWeek', en: '/ week', translations: {'uk': '/ тиждень'}),
  LocalizedText('perMonth', en: '/ month', translations: {'uk': '/ місяць'}),
  LocalizedText(
    'perTwoMonths',
    en: '/ 2 months',
    translations: {'uk': '/ 2 місяці'},
  ),
  LocalizedText(
    'perThreeMonths',
    en: '/ 3 months',
    translations: {'uk': '/ 3 місяці'},
  ),
  LocalizedText(
    'perSixMonths',
    en: '/ 6 months',
    translations: {'uk': '/ 6 місяців'},
  ),
  LocalizedText('perYear', en: '/ year', translations: {'uk': '/ рік'}),
  LocalizedText('once', en: 'once', translations: {'uk': 'один раз'}),
  LocalizedText('threeDays', en: '3 days', translations: {'uk': '3 дні'}),
  LocalizedText('oneWeek', en: '1 week', translations: {'uk': '1 тиждень'}),
  LocalizedText('twoWeeks', en: '2 weeks', translations: {'uk': '2 тижні'}),
  LocalizedText('oneMonth', en: '1 month', translations: {'uk': '1 місяць'}),
  LocalizedText(
    'twoMonths',
    en: '2 months',
    translations: {'uk': '2 місяці'},
  ),
  LocalizedText(
    'threeMonths',
    en: '3 months',
    translations: {'uk': '3 місяці'},
  ),
  LocalizedText(
    'sixMonths',
    en: '6 months',
    translations: {'uk': '6 місяців'},
  ),
  LocalizedText('oneYear', en: '1 year', translations: {'uk': '1 рік'}),
  LocalizedText('free', en: 'free', translations: {'uk': 'безкоштовно'}),
  LocalizedText('forLength', en: 'for', translations: {'uk': 'на'}),
  LocalizedText('then', en: 'then', translations: {'uk': 'далі'}),
  LocalizedText(
    'freeTrial',
    en: 'Free trial',
    translations: {'uk': 'Безкоштовний пробний період'},
  ),
  LocalizedText(
    'introPrice',
    en: 'Introductory price',
    translations: {'uk': 'Вступна ціна'},
  ),
  LocalizedText(
    'startTrial',
    en: 'Start free trial',
    translations: {'uk': 'Спробувати безкоштовно'},
  ),
  LocalizedText(
    'subscribe',
    en: 'Subscribe',
    translations: {'uk': 'Підписатися'},
  ),
  LocalizedText('buy', en: 'Buy', translations: {'uk': 'Купити'}),
  LocalizedText(
    'termsApple',
    en: 'The plan renews automatically until you cancel it. Payment is '
        'charged to your Apple Account. Cancel at least 24 hours before the '
        'period ends, in the settings of the App Store.',
    translations: {
      'uk': 'План поновлюється автоматично, доки ви його не скасуєте. Оплату '
          'знімають з вашого облікового запису Apple. Скасуйте щонайменше за '
          '24 години до кінця періоду, у налаштуваннях App Store.',
    },
  ),
  LocalizedText(
    'termsGoogle',
    en: 'The plan renews automatically until you cancel it. Cancel anytime '
        'in Google Play, under Payments & subscriptions.',
    translations: {
      'uk': 'План поновлюється автоматично, доки ви його не скасуєте. '
          'Скасувати можна будь-коли в Google Play, у розділі «Платежі й '
          'підписки».',
    },
  ),
  LocalizedText(
    'termsTrial',
    en: 'Unless you cancel before the free trial ends, the full price is '
        'charged then.',
    translations: {
      'uk': 'Якщо не скасувати до кінця безкоштовного періоду, тоді буде '
          'знято повну ціну.',
    },
  ),
  LocalizedText(
    'termsIntro',
    en: 'After the introductory price, the full price is charged for each '
        'period.',
    translations: {
      'uk': 'Після вступної ціни за кожен період знімають повну ціну.',
    },
  ),
  LocalizedText(
    'termsLifetime',
    en: 'One-time payment. No subscription.',
    translations: {'uk': 'Одноразовий платіж. Без підписки.'},
  ),
  LocalizedText(
    'restore',
    en: 'Restore purchases',
    translations: {'uk': 'Відновити покупки'},
  ),
  LocalizedText(
    'terms',
    en: 'Terms of Use',
    translations: {'uk': 'Умови використання'},
  ),
  LocalizedText(
    'privacy',
    en: 'Privacy Policy',
    translations: {'uk': 'Політика конфіденційності'},
  ),
  LocalizedText(
    'nothingToRestore',
    en: 'No purchases to restore.',
    translations: {'uk': 'Немає покупок для відновлення.'},
  ),
  LocalizedText(
    'pendingNotice',
    en: 'Your purchase is waiting for approval. Premium unlocks once it goes '
        'through.',
    translations: {
      'uk': 'Покупка чекає на підтвердження. Преміум відкриється, щойно її '
          'підтвердять.',
    },
  ),
  LocalizedText(
    'plansUnavailable',
    en: 'Plans are not available right now.',
    translations: {'uk': 'Плани зараз недоступні.'},
  ),
  LocalizedText(
    'tryAgain',
    en: 'Try again',
    translations: {'uk': 'Спробувати ще раз'},
  ),
  LocalizedText(
    'failureNetwork',
    en: 'No connection. Check the internet and try again.',
    translations: {
      'uk': 'Немає зв’язку. Перевірте інтернет і спробуйте ще раз.',
    },
  ),
  LocalizedText(
    'failureOwned',
    en: 'Your store account owns this plan already. Restore purchases to '
        'unlock premium.',
    translations: {
      'uk': 'Ваш обліковий запис у магазині вже має цей план. Відновіть '
          'покупки, щоб відкрити преміум.',
    },
  ),
  LocalizedText(
    'failureNotAllowed',
    en: 'Purchases are not allowed on this device.',
    translations: {'uk': 'На цьому пристрої покупки заборонені.'},
  ),
  LocalizedText(
    'failureUnavailable',
    en: 'This plan is not available on this device.',
    translations: {'uk': 'Цей план недоступний на цьому пристрої.'},
  ),
  LocalizedText(
    'failureStore',
    en: 'The store had a problem. Try again later.',
    translations: {'uk': 'У магазині сталася помилка. Спробуйте пізніше.'},
  ),
  LocalizedText(
    'failureNotSetUp',
    en: 'Purchases are unavailable right now.',
    translations: {'uk': 'Покупки зараз недоступні.'},
  ),
  LocalizedText(
    'failureUnknown',
    en: 'Something went wrong. Try again.',
    translations: {'uk': 'Щось пішло не так. Спробуйте ще раз.'},
  ),
  LocalizedText(
    'subscriptionTitle',
    en: 'Subscription',
    translations: {'uk': 'Підписка'},
  ),
  LocalizedText(
    'subscriptionIntro',
    en: 'Thank you for your support. Premium is unlocked.',
    translations: {'uk': 'Дякуємо за підтримку. Преміум відкрито.'},
  ),
  LocalizedText('unlocked', en: 'Unlocked', translations: {'uk': 'Відкрито'}),
  LocalizedText('planLabel', en: 'Plan', translations: {'uk': 'План'}),
  LocalizedText(
    'renewsOn',
    en: 'Renews on',
    translations: {'uk': 'Поновиться'},
  ),
  LocalizedText('endsOn', en: 'Ends on', translations: {'uk': 'Закінчиться'}),
  LocalizedText(
    'trialEndsOn',
    en: 'Trial ends on',
    translations: {'uk': 'Пробний період закінчиться'},
  ),
  LocalizedText(
    'lifetimeAccess',
    en: 'Lifetime access',
    translations: {'uk': 'Доступ назавжди'},
  ),
  LocalizedText(
    'manage',
    en: 'Manage subscription',
    translations: {'uk': 'Керувати підпискою'},
  ),
  LocalizedText(
    'manageHint',
    en: 'Cancel anytime in the store where you subscribed.',
    translations: {
      'uk': 'Скасувати можна будь-коли в магазині, де ви підписалися.',
    },
  ),
]);

/// The texts of the entry of the settings screen, which only an app with a
/// settings screen has.
const entryTexts = TextsData([
  LocalizedText(
    'settingTitle',
    en: 'Subscription',
    translations: {'uk': 'Підписка'},
  ),
  LocalizedText(
    'settingActive',
    en: 'Active',
    translations: {'uk': 'Активна'},
  ),
  LocalizedText(
    'settingInactive',
    en: 'Not active',
    translations: {'uk': 'Не активна'},
  ),
]);

/// The title of the step of the onboarding that offers premium access,
/// which only an app with an onboarding has.
const stepTitle = LocalizedText(
  'stepTitle',
  en: 'Unlock premium',
  translations: {'uk': 'Відкрийте преміум'},
);

/// The text of the step of the onboarding, below its title.
const stepText = LocalizedText(
  'stepText',
  en: 'Get every feature of the app, and the new ones as they arrive.',
  translations: {
    'uk': 'Отримайте всі можливості застосунку й нові, щойно вони '
        'з’являться.',
  },
);

/// The label of the button of the step that shows the paywall.
const stepAction = LocalizedText(
  'stepAction',
  en: 'See plans',
  translations: {'uk': 'Переглянути плани'},
);

/// The label of the button of the step that goes on without the paywall.
const stepLater = LocalizedText(
  'stepLater',
  en: 'Not now',
  translations: {'uk': 'Не зараз'},
);

/// The texts of the step of the onboarding, which only an app with an
/// onboarding has.
const onboardingStepTexts = TextsData([
  stepTitle,
  stepText,
  stepAction,
  stepLater,
]);
