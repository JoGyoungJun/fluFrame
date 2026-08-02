// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'FluFrame 앱';

  @override
  String get homeTab => '홈';

  @override
  String get settingsTab => '설정';

  @override
  String get homeGreeting => 'fluFrame에 오신 것을 환영합니다!';

  @override
  String get homeDescription =>
      'Riverpod, go_router, 테마, 다국어 지원이 내장된 프로덕션 수준의 Flutter 스타터입니다.';

  @override
  String counterLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '버튼을 $count번 눌렀습니다',
    );
    return '$_temp0';
  }

  @override
  String get increment => '증가';

  @override
  String get viewPosts => '샘플 게시글 보기';

  @override
  String get postsTitle => '게시글';

  @override
  String get postsErrorMessage => '게시글을 불러오지 못했습니다.';

  @override
  String get genericErrorMessage => '문제가 발생했습니다.';

  @override
  String get retry => '다시 시도';

  @override
  String postDetailTitle(int id) {
    return '게시글 #$id';
  }

  @override
  String get postNotFound => '게시글을 찾을 수 없습니다.';

  @override
  String get settingsTitle => '설정';

  @override
  String get appearanceSection => '화면 모드';

  @override
  String get themeModeSystem => '시스템';

  @override
  String get themeModeLight => '라이트';

  @override
  String get themeModeDark => '다크';

  @override
  String get languageSection => '언어';

  @override
  String get languageSystem => '시스템';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';
}
