// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FluFrame App';

  @override
  String get homeTab => 'Home';

  @override
  String get settingsTab => 'Settings';

  @override
  String get homeGreeting => 'Welcome to FluFrame App!';

  @override
  String get homeDescription =>
      'A production-ready Flutter starter with Riverpod, go_router, theming, and localization built in.';

  @override
  String counterLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Button pushed $count times',
      one: 'Button pushed 1 time',
    );
    return '$_temp0';
  }

  @override
  String get increment => 'Increment';

  @override
  String get viewPosts => 'View sample posts';

  @override
  String get postsTitle => 'Posts';

  @override
  String get postsErrorMessage => 'Failed to load posts.';

  @override
  String get postsLoadingMore => 'Loading more…';

  @override
  String get postsLoadMoreError => 'Couldn\'t load more posts.';

  @override
  String get postsEndOfList => 'You\'ve reached the end.';

  @override
  String get genericErrorMessage => 'Something went wrong.';

  @override
  String get retry => 'Retry';

  @override
  String postDetailTitle(int id) {
    return 'Post #$id';
  }

  @override
  String get postNotFound => 'Post not found.';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String routeNotFoundMessage(String location) {
    return 'No screen matches $location.';
  }

  @override
  String get routeNotFoundAction => 'Go to home';

  @override
  String get profileTab => 'Profile';

  @override
  String get profileTitle => 'Profile';

  @override
  String profileSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get emailRequired => 'Enter your email.';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get passwordRequired => 'Enter your password.';

  @override
  String get loginFailedMessage => 'Sign-in failed. Check your credentials.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get colorSection => 'Theme color';

  @override
  String get presetIndigo => 'Indigo';

  @override
  String get presetEmerald => 'Emerald';

  @override
  String get presetCrimson => 'Crimson';

  @override
  String get presetAmber => 'Amber';

  @override
  String get presetViolet => 'Violet';

  @override
  String get presetTeal => 'Teal';

  @override
  String get languageSection => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageJapanese => '日本語';
}
