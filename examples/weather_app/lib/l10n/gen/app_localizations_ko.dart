// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Weather App 앱';

  @override
  String get homeTab => '홈';

  @override
  String get settingsTab => '설정';

  @override
  String get weatherTab => '날씨';

  @override
  String get weatherTitle => '날씨';

  @override
  String get citySeoul => '서울';

  @override
  String get cityTokyo => '도쿄';

  @override
  String get cityNewYork => '뉴욕';

  @override
  String get cityParis => '파리';

  @override
  String get citySydney => '시드니';

  @override
  String temperatureValue(double value) {
    return '$value°C';
  }

  @override
  String windValue(double value) {
    return '바람 $value km/h';
  }

  @override
  String get weatherErrorMessage => '날씨를 불러오지 못했습니다.';

  @override
  String get homeGreeting => 'Weather App 앱에 오신 것을 환영합니다!';

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
  String get postsLoadingMore => '더 불러오는 중…';

  @override
  String get postsLoadMoreError => '게시글을 더 불러오지 못했습니다.';

  @override
  String get postsEndOfList => '마지막 게시글입니다.';

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
  String get profileTab => '프로필';

  @override
  String get profileTitle => '프로필';

  @override
  String profileSignedInAs(String email) {
    return '$email 계정으로 로그인됨';
  }

  @override
  String get loginTitle => '다시 오신 것을 환영합니다';

  @override
  String get emailLabel => '이메일';

  @override
  String get passwordLabel => '비밀번호';

  @override
  String get signInButton => '로그인';

  @override
  String get signOutButton => '로그아웃';

  @override
  String get emailRequired => '이메일을 입력하세요.';

  @override
  String get emailInvalid => '올바른 이메일 주소를 입력하세요.';

  @override
  String get passwordRequired => '비밀번호를 입력하세요.';

  @override
  String get loginFailedMessage => '로그인에 실패했습니다. 입력 정보를 확인하세요.';

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
  String get colorSection => '테마 색상';

  @override
  String get presetIndigo => '인디고';

  @override
  String get presetEmerald => '에메랄드';

  @override
  String get presetCrimson => '크림슨';

  @override
  String get presetAmber => '앰버';

  @override
  String get presetViolet => '바이올렛';

  @override
  String get languageSection => '언어';

  @override
  String get languageSystem => '시스템';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get routeNotFoundTitle => '페이지를 찾을 수 없습니다';

  @override
  String routeNotFoundMessage(String location) {
    return '$location 에 해당하는 화면이 없습니다.';
  }

  @override
  String get routeNotFoundAction => '홈으로 이동';

  @override
  String get presetTeal => '틸';

  @override
  String get languageJapanese => '日本語';
}
