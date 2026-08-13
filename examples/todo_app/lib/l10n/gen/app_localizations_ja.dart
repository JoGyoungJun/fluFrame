// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Todo App アプリ';

  @override
  String get homeTab => 'ホーム';

  @override
  String get settingsTab => '設定';

  @override
  String get todosTab => 'やること';

  @override
  String get todosTitle => 'やること';

  @override
  String get addTodoHint => '何をしますか？';

  @override
  String get addTodoTooltip => 'やることを追加';

  @override
  String get deleteTodoTooltip => 'やることを削除';

  @override
  String get emptyTodos => 'まだありません — 上から最初のやることを追加してください。';

  @override
  String get homeGreeting => 'Todo App アプリへようこそ！';

  @override
  String get homeDescription =>
      'Riverpod、go_router、テーマ、多言語対応を備えたプロダクション品質のFlutterスターターです。';

  @override
  String counterLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ボタンを$count回押しました',
    );
    return '$_temp0';
  }

  @override
  String get increment => '増やす';

  @override
  String get viewPosts => 'サンプル投稿を見る';

  @override
  String get postsTitle => '投稿';

  @override
  String get postsErrorMessage => '投稿を読み込めませんでした。';

  @override
  String get postsLoadingMore => 'さらに読み込み中…';

  @override
  String get postsLoadMoreError => 'これ以上の投稿を読み込めませんでした。';

  @override
  String get postsEndOfList => '最後の投稿です。';

  @override
  String get genericErrorMessage => '問題が発生しました。';

  @override
  String get retry => '再試行';

  @override
  String postDetailTitle(int id) {
    return '投稿 #$id';
  }

  @override
  String get postNotFound => '投稿が見つかりません。';

  @override
  String get profileTab => 'プロフィール';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String profileSignedInAs(String email) {
    return '$email でログイン中';
  }

  @override
  String get loginTitle => 'おかえりなさい';

  @override
  String get emailLabel => 'メールアドレス';

  @override
  String get passwordLabel => 'パスワード';

  @override
  String get signInButton => 'ログイン';

  @override
  String get signOutButton => 'ログアウト';

  @override
  String get emailRequired => 'メールアドレスを入力してください。';

  @override
  String get emailInvalid => '有効なメールアドレスを入力してください。';

  @override
  String get passwordRequired => 'パスワードを入力してください。';

  @override
  String get loginFailedMessage => 'ログインに失敗しました。入力内容を確認してください。';

  @override
  String get settingsTitle => '設定';

  @override
  String get appearanceSection => '外観';

  @override
  String get themeModeSystem => 'システム';

  @override
  String get themeModeLight => 'ライト';

  @override
  String get themeModeDark => 'ダーク';

  @override
  String get colorSection => 'テーマカラー';

  @override
  String get presetIndigo => 'インディゴ';

  @override
  String get presetEmerald => 'エメラルド';

  @override
  String get presetCrimson => 'クリムゾン';

  @override
  String get presetAmber => 'アンバー';

  @override
  String get presetViolet => 'バイオレット';

  @override
  String get languageSection => '言語';

  @override
  String get languageSystem => 'システム';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get routeNotFoundTitle => 'ページが見つかりません';

  @override
  String routeNotFoundMessage(String location) {
    return '$location に一致する画面がありません。';
  }

  @override
  String get routeNotFoundAction => 'ホームへ移動';

  @override
  String get presetTeal => 'ティール';

  @override
  String get languageJapanese => '日本語';
}
