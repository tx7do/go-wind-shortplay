// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja_JP locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ja_JP';

  static String m0(count) => "投稿後に自動でこのシリーズに追加されます（現在${count}話）";

  static String m1(count) => "${count} 件のコメント";

  static String m2(n) => "紐付け済 ・ 第${n}話";

  static String m3(n) => "第${n}話";

  static String m4(count) => "${count} 件の返信を表示";

  static String m5(count) => "${count} 件の返信";

  static String m6(name) => "${name} に返信";

  static String m7(query) => "「${query}」に関連する動画が見つかりません";

  static String m8(count) => "${count}話";

  static String m9(count) => "${count}人がフォロー中";

  static String m10(published, total) => "第${published}話まで更新 ・ 全${total}話";

  static String m11(count) => "${count} 日前";

  static String m12(count) => "${count} 時間前";

  static String m13(count) => "${count} 分前";

  static String m14(percent) => "アップロード中 ${percent}%";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("アプリについて"),
    "addTags": MessageLookupByLibrary.simpleMessage("タグを追加"),
    "advancedSettings": MessageLookupByLibrary.simpleMessage("詳細設定"),
    "allLoaded": MessageLookupByLibrary.simpleMessage("― すべて見ました ―"),
    "appName": MessageLookupByLibrary.simpleMessage("風印ショートドラマ"),
    "appearance": MessageLookupByLibrary.simpleMessage("外観"),
    "asDraftOption": MessageLookupByLibrary.simpleMessage("下書きとして保存（自分のみ表示）"),
    "attachSeries": MessageLookupByLibrary.simpleMessage("シリーズに紐付け"),
    "attachSeriesHint": m0,
    "attachSeriesNone": MessageLookupByLibrary.simpleMessage(
      "紐付けなし（独立動画として投稿）",
    ),
    "attachSeriesRemove": MessageLookupByLibrary.simpleMessage("紐付けを解除"),
    "autoNextTip": MessageLookupByLibrary.simpleMessage("次のエピソードを自動再生"),
    "avatarLabel": MessageLookupByLibrary.simpleMessage("アバター"),
    "avatarTooLarge": MessageLookupByLibrary.simpleMessage("アイコン画像は 2MB までです"),
    "backToHome": MessageLookupByLibrary.simpleMessage("ホームに戻る"),
    "bioHint": MessageLookupByLibrary.simpleMessage("自分を紹介しよう…"),
    "bioLabel": MessageLookupByLibrary.simpleMessage("自己紹介"),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cannotFollowSelf": MessageLookupByLibrary.simpleMessage("自分はフォローできません"),
    "changeSeries": MessageLookupByLibrary.simpleMessage("変更"),
    "chooseSeries": MessageLookupByLibrary.simpleMessage("シリーズを選択"),
    "chooseVideoToCreate": MessageLookupByLibrary.simpleMessage(
      "動画を選んで创作を始めよう",
    ),
    "collects": MessageLookupByLibrary.simpleMessage("お気に入り"),
    "comment": MessageLookupByLibrary.simpleMessage("コメント"),
    "commentDeleted": MessageLookupByLibrary.simpleMessage("コメントを削除しました"),
    "commentIsEmpty": MessageLookupByLibrary.simpleMessage("コメント内容を入力してください"),
    "commentSuccess": MessageLookupByLibrary.simpleMessage("コメントしました"),
    "commentsCount": m1,
    "confirm": MessageLookupByLibrary.simpleMessage("OK"),
    "confirmSend": MessageLookupByLibrary.simpleMessage("送信"),
    "copyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "creatorCenter": MessageLookupByLibrary.simpleMessage("クリエイターセンター"),
    "creatorLikes": MessageLookupByLibrary.simpleMessage("いいね"),
    "creatorOverview": MessageLookupByLibrary.simpleMessage("データ概要"),
    "creatorPlays": MessageLookupByLibrary.simpleMessage("再生"),
    "creatorPublished": MessageLookupByLibrary.simpleMessage("投稿"),
    "creatorStatsHint": MessageLookupByLibrary.simpleMessage(
      "日別集計（再生/いいねは行動ログ、投稿は審査通過時刻）",
    ),
    "creatorStatsTitle": MessageLookupByLibrary.simpleMessage("创作データ"),
    "creatorVideoStatsTitle": MessageLookupByLibrary.simpleMessage("動画別データ"),
    "danmaku": MessageLookupByLibrary.simpleMessage("コメント（弾幕）"),
    "danmakuArea": MessageLookupByLibrary.simpleMessage("コメント表示領域"),
    "danmakuSendAction": MessageLookupByLibrary.simpleMessage("送信"),
    "danmakuSendHint": MessageLookupByLibrary.simpleMessage("何か書いてみよう…"),
    "danmakuSendTitle": MessageLookupByLibrary.simpleMessage("コメントを送信"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "darkMode": MessageLookupByLibrary.simpleMessage("ダークモード"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteCommentConfirm": MessageLookupByLibrary.simpleMessage(
      "このコメントを削除しますか？",
    ),
    "deleteSeriesConfirm": MessageLookupByLibrary.simpleMessage(
      "削除するとシリーズの紐付けが解除され、動画自体は残ります。削除しますか？",
    ),
    "deleteSeriesTitle": MessageLookupByLibrary.simpleMessage("シリーズを削除"),
    "deleteVideo": MessageLookupByLibrary.simpleMessage("動画を削除"),
    "deleteVideoConfirm": MessageLookupByLibrary.simpleMessage(
      "この動画を削除しますか？元に戻せません",
    ),
    "descriptionHint": MessageLookupByLibrary.simpleMessage("動画を紹介しよう…"),
    "descriptionLabel": MessageLookupByLibrary.simpleMessage("概要"),
    "dislikeNotInterested": MessageLookupByLibrary.simpleMessage("興味なし"),
    "dislikeRecorded": MessageLookupByLibrary.simpleMessage("この種のコンテンツを減らします"),
    "draftSaved": MessageLookupByLibrary.simpleMessage("下書きを保存しました"),
    "draftSeriesAttached": MessageLookupByLibrary.simpleMessage(
      "シリーズ紐付け済（投稿時に自動で話数割り）",
    ),
    "draftSeriesBadge": m2,
    "drafts": MessageLookupByLibrary.simpleMessage("下書き"),
    "editProfile": MessageLookupByLibrary.simpleMessage("プロフィール編集"),
    "editSeries": MessageLookupByLibrary.simpleMessage("シリーズを編集"),
    "episodeN": m3,
    "errorAccessTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "アクセストークンが存在しません",
    ),
    "errorBadGateway": MessageLookupByLibrary.simpleMessage("ゲートウェイエラー"),
    "errorBadRequest": MessageLookupByLibrary.simpleMessage("リクエストパラメータが不正です"),
    "errorConflict": MessageLookupByLibrary.simpleMessage(
      "データが競合しています。更新してからお試しください",
    ),
    "errorDefault": MessageLookupByLibrary.simpleMessage("操作に失敗しました。後でお試しください"),
    "errorDeleteFailed": MessageLookupByLibrary.simpleMessage("削除に失敗しました"),
    "errorDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "ダウンロードに失敗しました",
    ),
    "errorDuplicateReport": MessageLookupByLibrary.simpleMessage(
      "重複して通報しないでください",
    ),
    "errorExpectationFailed": MessageLookupByLibrary.simpleMessage(
      "リクエストの期待条件を満たせません",
    ),
    "errorFailedDependency": MessageLookupByLibrary.simpleMessage(
      "依存操作に失敗しました",
    ),
    "errorFileNotFound": MessageLookupByLibrary.simpleMessage("ファイルが存在しません"),
    "errorFileTooLarge": MessageLookupByLibrary.simpleMessage("ファイルが大きすぎます"),
    "errorForbidden": MessageLookupByLibrary.simpleMessage("この操作を行う権限がありません"),
    "errorGatewayTimeout": MessageLookupByLibrary.simpleMessage(
      "ゲートウェイがタイムアウトしました",
    ),
    "errorGone": MessageLookupByLibrary.simpleMessage("リソースは削除されました"),
    "errorHttpVersionNotSupported": MessageLookupByLibrary.simpleMessage(
      "対応していない HTTP バージョンです",
    ),
    "errorImATeapot": MessageLookupByLibrary.simpleMessage("サーバーがリクエストを拒否しました"),
    "errorIncorrectAccessToken": MessageLookupByLibrary.simpleMessage(
      "アクセストークンが正しくありません",
    ),
    "errorIncorrectAppSecret": MessageLookupByLibrary.simpleMessage(
      "アプリシークレットが正しくありません",
    ),
    "errorIncorrectRefreshToken": MessageLookupByLibrary.simpleMessage(
      "リフレッシュトークンが正しくありません",
    ),
    "errorInsufficientStorage": MessageLookupByLibrary.simpleMessage(
      "ストレージが不足しています",
    ),
    "errorInternalServerError": MessageLookupByLibrary.simpleMessage(
      "サーバー内部エラー",
    ),
    "errorInvalidGrantType": MessageLookupByLibrary.simpleMessage("認可タイプが無効です"),
    "errorInvalidPassword": MessageLookupByLibrary.simpleMessage(
      "ユーザー名またはパスワードが違います",
    ),
    "errorInvalidToken": MessageLookupByLibrary.simpleMessage("トークンが無効です"),
    "errorInvalidUserid": MessageLookupByLibrary.simpleMessage("ユーザー ID が無効です"),
    "errorLengthRequired": MessageLookupByLibrary.simpleMessage(
      "Content-Length が不足しています",
    ),
    "errorLocked": MessageLookupByLibrary.simpleMessage("リソースはロックされています"),
    "errorLoopDetected": MessageLookupByLibrary.simpleMessage(
      "ループリクエストを検出しました",
    ),
    "errorMethodNotAllowed": MessageLookupByLibrary.simpleMessage(
      "許可されていないリクエストメソッドです",
    ),
    "errorMisdirectedRequest": MessageLookupByLibrary.simpleMessage(
      "リクエストが誤って転送されました",
    ),
    "errorNetworkAuthenticationRequired": MessageLookupByLibrary.simpleMessage(
      "ネットワーク認証が必要です",
    ),
    "errorNetworkConnectTimeoutError": MessageLookupByLibrary.simpleMessage(
      "ネットワーク接続がタイムアウトしました",
    ),
    "errorNetworkError": MessageLookupByLibrary.simpleMessage(
      "ネットワーク異常。接続をご確認ください",
    ),
    "errorNetworkReadTimeoutError": MessageLookupByLibrary.simpleMessage(
      "ネットワークの読み取りがタイムアウトしました",
    ),
    "errorNotAcceptable": MessageLookupByLibrary.simpleMessage(
      "受け付けられないリクエストです",
    ),
    "errorNotExtended": MessageLookupByLibrary.simpleMessage("拡張が必要です"),
    "errorNotFound": MessageLookupByLibrary.simpleMessage("リソースが存在しません"),
    "errorNotImplemented": MessageLookupByLibrary.simpleMessage("機能は未実装です"),
    "errorNotOwner": MessageLookupByLibrary.simpleMessage(
      "このリソースを操作する権限がありません",
    ),
    "errorOccurred": MessageLookupByLibrary.simpleMessage("エラーが発生しました"),
    "errorOrganizationNotFound": MessageLookupByLibrary.simpleMessage(
      "組織が存在しません",
    ),
    "errorPayloadTooLarge": MessageLookupByLibrary.simpleMessage(
      "動画が大きすぎます。圧縮してからお試しください",
    ),
    "errorPaymentRequired": MessageLookupByLibrary.simpleMessage("支払いが必要です"),
    "errorPositionNotFound": MessageLookupByLibrary.simpleMessage("職位が存在しません"),
    "errorPreconditionFailed": MessageLookupByLibrary.simpleMessage(
      "前提条件を満たしていません",
    ),
    "errorPreconditionRequired": MessageLookupByLibrary.simpleMessage(
      "前提条件が必要です",
    ),
    "errorProxyAuthenticationRequired": MessageLookupByLibrary.simpleMessage(
      "プロキシ認証が必要です",
    ),
    "errorRangeNotSatisfiable": MessageLookupByLibrary.simpleMessage(
      "リクエスト範囲を満たせません",
    ),
    "errorRefreshTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "リフレッシュトークンが存在しません",
    ),
    "errorRequestHeaderFieldsTooLarge": MessageLookupByLibrary.simpleMessage(
      "リクエストヘッダーが大きすぎます",
    ),
    "errorRequestTimeout": MessageLookupByLibrary.simpleMessage(
      "リクエストがタイムアウトしました",
    ),
    "errorRoleNotFound": MessageLookupByLibrary.simpleMessage("ロールが存在しません"),
    "errorSensitiveWordHit": MessageLookupByLibrary.simpleMessage(
      "コンテンツに不適切な語が含まれています。修正してください",
    ),
    "errorServiceUnavailable": MessageLookupByLibrary.simpleMessage(
      "サービスは一時的に利用できません",
    ),
    "errorTenantNotFound": MessageLookupByLibrary.simpleMessage("テナントが存在しません"),
    "errorTimeout": MessageLookupByLibrary.simpleMessage(
      "リクエストがタイムアウトしました。後でお試しください",
    ),
    "errorTokenExpired": MessageLookupByLibrary.simpleMessage(
      "ログインが期限切れです。再ログインしてください",
    ),
    "errorTokenNotExist": MessageLookupByLibrary.simpleMessage("トークンが存在しません"),
    "errorTooEarly": MessageLookupByLibrary.simpleMessage("リクエストが早すぎます"),
    "errorTooManyRequests": MessageLookupByLibrary.simpleMessage(
      "リクエストが多すぎます。後でお試しください",
    ),
    "errorUnauthorized": MessageLookupByLibrary.simpleMessage(
      "未ログインか、ログインが期限切れです",
    ),
    "errorUnavailableForLegalReasons": MessageLookupByLibrary.simpleMessage(
      "法的な理由により利用できません",
    ),
    "errorUnprocessableEntity": MessageLookupByLibrary.simpleMessage(
      "リクエストデータを処理できません",
    ),
    "errorUnsupportedMediaType": MessageLookupByLibrary.simpleMessage(
      "対応していない動画形式です",
    ),
    "errorUpgradeRequired": MessageLookupByLibrary.simpleMessage(
      "アップグレードが必要です",
    ),
    "errorUploadFailed": MessageLookupByLibrary.simpleMessage("アップロードに失敗しました"),
    "errorUriTooLong": MessageLookupByLibrary.simpleMessage("リクエスト URL が長すぎます"),
    "errorUserFreeze": MessageLookupByLibrary.simpleMessage("アカウントが凍結されています"),
    "errorUserNotFound": MessageLookupByLibrary.simpleMessage("ユーザーが存在しません"),
    "errorUsernameTaken": MessageLookupByLibrary.simpleMessage(
      "このユーザー名は既に使用されています",
    ),
    "errorVariantAlsoNegotiates": MessageLookupByLibrary.simpleMessage(
      "バリアントネゴシエーションエラー",
    ),
    "errorVideoNotFound": MessageLookupByLibrary.simpleMessage("動画が存在しません"),
    "expandReplies": m4,
    "featureNotAvailable": MessageLookupByLibrary.simpleMessage(
      "この機能は近日公開予定です",
    ),
    "follow": MessageLookupByLibrary.simpleMessage("フォロー"),
    "followSystem": MessageLookupByLibrary.simpleMessage("システムに従う"),
    "followed": MessageLookupByLibrary.simpleMessage("フォロー中"),
    "followers": MessageLookupByLibrary.simpleMessage("フォロワー"),
    "followingCountLabel": MessageLookupByLibrary.simpleMessage("フォロー中"),
    "followingSeriesEmpty": MessageLookupByLibrary.simpleMessage(
      "フォローしたシリーズはまだません。見つけてみよう",
    ),
    "followingSeriesTab": MessageLookupByLibrary.simpleMessage("フォロー"),
    "goLogin": MessageLookupByLibrary.simpleMessage("ログインする"),
    "guestInteractionDesc": MessageLookupByLibrary.simpleMessage(
      "ログインといいね・コメント・お気に入り・フォローができます",
    ),
    "guestInteractionTitle": MessageLookupByLibrary.simpleMessage(
      "ログインで操作できます",
    ),
    "historyEmpty": MessageLookupByLibrary.simpleMessage("視聴履歴はまだありません"),
    "historyTab": MessageLookupByLibrary.simpleMessage("履歴"),
    "home": MessageLookupByLibrary.simpleMessage("ホーム"),
    "hotKeywords": MessageLookupByLibrary.simpleMessage("急上昇ワード"),
    "hotList": MessageLookupByLibrary.simpleMessage("ランキング"),
    "hotListEmpty": MessageLookupByLibrary.simpleMessage("ランキングはまだありません"),
    "hotTags": MessageLookupByLibrary.simpleMessage("人気タグ"),
    "imChat": MessageLookupByLibrary.simpleMessage("メッセージを送る"),
    "imConversationEmpty": MessageLookupByLibrary.simpleMessage(
      "メッセージはまだありません",
    ),
    "imConversations": MessageLookupByLibrary.simpleMessage("メッセージ"),
    "imEmpty": MessageLookupByLibrary.simpleMessage("まだ会話がありません。プロフィールから始めよう"),
    "imInputHint": MessageLookupByLibrary.simpleMessage("メッセージを入力…"),
    "imUserFallback": MessageLookupByLibrary.simpleMessage("ユーザー"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "likeReceived": MessageLookupByLibrary.simpleMessage("獲得いいね"),
    "loadFailed": MessageLookupByLibrary.simpleMessage("読み込みに失敗しました"),
    "loading": MessageLookupByLibrary.simpleMessage("読み込み中…"),
    "loadingMore": MessageLookupByLibrary.simpleMessage("もっと読み込む…"),
    "login": MessageLookupByLibrary.simpleMessage("ログイン"),
    "loginButton": MessageLookupByLibrary.simpleMessage("ログイン"),
    "loginFailed": MessageLookupByLibrary.simpleMessage(
      "ログインに失敗しました。ユーザー名とパスワードをご確認ください",
    ),
    "loginForMore": MessageLookupByLibrary.simpleMessage(
      "ログインでいいね・コメント・投稿ができます",
    ),
    "loginSuccess": MessageLookupByLibrary.simpleMessage("ログインしました"),
    "loginToViewMessages": MessageLookupByLibrary.simpleMessage(
      "ログインで通知を確認できます",
    ),
    "loginToViewProfile": MessageLookupByLibrary.simpleMessage("ログインでマイページを表示"),
    "logout": MessageLookupByLibrary.simpleMessage("ログアウト"),
    "logoutConfirm": MessageLookupByLibrary.simpleMessage("ログアウトしますか？"),
    "markAllRead": MessageLookupByLibrary.simpleMessage("すべて既読"),
    "me": MessageLookupByLibrary.simpleMessage("マイページ"),
    "mergingVideo": MessageLookupByLibrary.simpleMessage("動画を処理中です…"),
    "message": MessageLookupByLibrary.simpleMessage("メッセージ"),
    "newSeries": MessageLookupByLibrary.simpleMessage("シリーズを新規作成"),
    "nicknameHint": MessageLookupByLibrary.simpleMessage("ニックネームを設定しよう"),
    "nicknameLabel": MessageLookupByLibrary.simpleMessage("ニックネーム"),
    "noCollectedVideos": MessageLookupByLibrary.simpleMessage(
      "お気に入りの動画はまだありません",
    ),
    "noCommentsYet": MessageLookupByLibrary.simpleMessage(
      "コメントはまだありません。最初のコメントを書こう",
    ),
    "noNewMessages": MessageLookupByLibrary.simpleMessage("新着メッセージはありません"),
    "noTagFound": MessageLookupByLibrary.simpleMessage(
      "一致するタグがありません。Enter でそのまま使用",
    ),
    "noWorksYet": MessageLookupByLibrary.simpleMessage(
      "作品はまだありません。最初の動画を投稿しよう",
    ),
    "notifyTypeComment": MessageLookupByLibrary.simpleMessage("コメント"),
    "notifyTypeFollow": MessageLookupByLibrary.simpleMessage("フォロー"),
    "notifyTypeLike": MessageLookupByLibrary.simpleMessage("いいね"),
    "notifyTypeSystem": MessageLookupByLibrary.simpleMessage("システム"),
    "onlyOwnerCanDelete": MessageLookupByLibrary.simpleMessage(
      "自分のコメントのみ削除できます",
    ),
    "pageNotFound": MessageLookupByLibrary.simpleMessage("ページが見つかりません"),
    "pageNotFoundDesc": MessageLookupByLibrary.simpleMessage(
      "申し訳ありません。お探しのページは存在しないか、移動されました。",
    ),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "passwordHint": MessageLookupByLibrary.simpleMessage("パスワードを入力"),
    "pickVideo": MessageLookupByLibrary.simpleMessage("アルバムから選択"),
    "pickVideoFirst": MessageLookupByLibrary.simpleMessage("投稿する動画を選択してください"),
    "pin": MessageLookupByLibrary.simpleMessage("ピン留め"),
    "pinnedBadge": MessageLookupByLibrary.simpleMessage("ピン留め"),
    "playNow": MessageLookupByLibrary.simpleMessage("再生中"),
    "playback": MessageLookupByLibrary.simpleMessage("再生"),
    "profileSaved": MessageLookupByLibrary.simpleMessage("プロフィールを更新しました"),
    "publish": MessageLookupByLibrary.simpleMessage("投稿"),
    "publishFailed": MessageLookupByLibrary.simpleMessage(
      "投稿に失敗しました。後でお試しください",
    ),
    "publishGuideSubtitle": MessageLookupByLibrary.simpleMessage(
      "5 分以内のショート動画に対応",
    ),
    "publishSuccess": MessageLookupByLibrary.simpleMessage("投稿しました。審査をお待ちください"),
    "readAllSuccess": MessageLookupByLibrary.simpleMessage("すべて既読にしました"),
    "reasonFollow": MessageLookupByLibrary.simpleMessage("フォロー"),
    "reasonHot": MessageLookupByLibrary.simpleMessage("人気"),
    "reasonLatest": MessageLookupByLibrary.simpleMessage("新着"),
    "recordVideo": MessageLookupByLibrary.simpleMessage("撮影"),
    "register": MessageLookupByLibrary.simpleMessage("登録"),
    "registerFailed": MessageLookupByLibrary.simpleMessage(
      "登録に失敗しました。後でお試しください",
    ),
    "registerSuccess": MessageLookupByLibrary.simpleMessage("登録しました"),
    "registerTitle": MessageLookupByLibrary.simpleMessage("新規アカウント登録"),
    "rejectReasonLabel": MessageLookupByLibrary.simpleMessage("却下理由"),
    "removeVideo": MessageLookupByLibrary.simpleMessage("動画を削除"),
    "repliesCount": m5,
    "reply": MessageLookupByLibrary.simpleMessage("返信"),
    "replyTo": m6,
    "report": MessageLookupByLibrary.simpleMessage("通報"),
    "reportDescriptionHint": MessageLookupByLibrary.simpleMessage("補足説明（任意）"),
    "reportDuplicate": MessageLookupByLibrary.simpleMessage(
      "このコンテンツはすでに通報されています",
    ),
    "reportReasonAbuse": MessageLookupByLibrary.simpleMessage("辱罵・攻撃"),
    "reportReasonCopyright": MessageLookupByLibrary.simpleMessage("権利侵害"),
    "reportReasonFraud": MessageLookupByLibrary.simpleMessage("詐欺情報"),
    "reportReasonOther": MessageLookupByLibrary.simpleMessage("その他の問題"),
    "reportReasonPorn": MessageLookupByLibrary.simpleMessage("性的・低俗"),
    "reportReasonTitle": MessageLookupByLibrary.simpleMessage("通報理由を選択"),
    "reportReasonViolence": MessageLookupByLibrary.simpleMessage("暴力・流血"),
    "reportSubmit": MessageLookupByLibrary.simpleMessage("通報を送信"),
    "reportSubmitted": MessageLookupByLibrary.simpleMessage(
      "通報を受け付けました。ありがとうございます",
    ),
    "reselectVideo": MessageLookupByLibrary.simpleMessage("選び直す"),
    "retry": MessageLookupByLibrary.simpleMessage("再試行"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveDraft": MessageLookupByLibrary.simpleMessage("下書き保存"),
    "saveProfile": MessageLookupByLibrary.simpleMessage("保存"),
    "scheduledPublishOption": MessageLookupByLibrary.simpleMessage(
      "予約投稿（指定時刻に自動公開）",
    ),
    "scheduledPublished": MessageLookupByLibrary.simpleMessage("予約投稿に設定しました"),
    "scheduledTimePast": MessageLookupByLibrary.simpleMessage(
      "予約時刻は現在より後にしてください",
    ),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "searchEmpty": m7,
    "searchHint": MessageLookupByLibrary.simpleMessage("動画・タグを検索"),
    "searchHistory": MessageLookupByLibrary.simpleMessage("検索履歴"),
    "searchHistoryClear": MessageLookupByLibrary.simpleMessage("クリア"),
    "searchSomeKeyword": MessageLookupByLibrary.simpleMessage("何か検索してみよう"),
    "seriesCreated": MessageLookupByLibrary.simpleMessage("シリーズを作成しました"),
    "seriesDeleted": MessageLookupByLibrary.simpleMessage("シリーズを削除しました"),
    "seriesDescLabel": MessageLookupByLibrary.simpleMessage("シリーズ概要"),
    "seriesEmpty": MessageLookupByLibrary.simpleMessage("シリーズはまだありません"),
    "seriesEmptyMine": MessageLookupByLibrary.simpleMessage(
      "シリーズはまだありません。投稿時に紐付けると作成できます",
    ),
    "seriesEpisodeBadge": m8,
    "seriesFollowShort": MessageLookupByLibrary.simpleMessage("フォロー"),
    "seriesFollowersCount": m9,
    "seriesFollowing": MessageLookupByLibrary.simpleMessage("フォロー中"),
    "seriesNotFound": MessageLookupByLibrary.simpleMessage(
      "シリーズが存在しないか、表示できるエピソードがありません",
    ),
    "seriesSaved": MessageLookupByLibrary.simpleMessage("シリーズを保存しました"),
    "seriesTab": MessageLookupByLibrary.simpleMessage("シリーズ"),
    "seriesTitleLabel": MessageLookupByLibrary.simpleMessage("シリーズ名"),
    "seriesUpdatedTo": m10,
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "share": MessageLookupByLibrary.simpleMessage("シェア"),
    "shareCopied": MessageLookupByLibrary.simpleMessage("リンクをコピーしました。シェアしましょう"),
    "sharePoster": MessageLookupByLibrary.simpleMessage("ポスターをシェア"),
    "sortHot": MessageLookupByLibrary.simpleMessage("人気"),
    "sortLatest": MessageLookupByLibrary.simpleMessage("新着"),
    "statusDraft": MessageLookupByLibrary.simpleMessage("下書き"),
    "statusOffline": MessageLookupByLibrary.simpleMessage("公開停止"),
    "statusRejected": MessageLookupByLibrary.simpleMessage("却下"),
    "statusReviewing": MessageLookupByLibrary.simpleMessage("審査中"),
    "submitPublish": MessageLookupByLibrary.simpleMessage("投稿"),
    "tagInlineHint": MessageLookupByLibrary.simpleMessage(
      "タグを入力し、Enter かカンマで追加",
    ),
    "tagInputHint": MessageLookupByLibrary.simpleMessage("タグを検索または作成"),
    "tagPickerTitle": MessageLookupByLibrary.simpleMessage("タグを選択"),
    "teenMode": MessageLookupByLibrary.simpleMessage("ティーンモード"),
    "teenModeConfirm": MessageLookupByLibrary.simpleMessage(
      "オンにすると、1 日の視聴が 40 分を超えたら休憩を促します。有効にしますか？",
    ),
    "teenRestMessage": MessageLookupByLibrary.simpleMessage(
      "今日 40 分視聴しました。少し休みましょう",
    ),
    "teenRestTitle": MessageLookupByLibrary.simpleMessage("休憩しましょう"),
    "timeDaysAgo": m11,
    "timeHoursAgo": m12,
    "timeJustNow": MessageLookupByLibrary.simpleMessage("たった今"),
    "timeMinutesAgo": m13,
    "titleHint": MessageLookupByLibrary.simpleMessage("目を引くタイトルを付けよう"),
    "titleLabel": MessageLookupByLibrary.simpleMessage("タイトル"),
    "titleRequired": MessageLookupByLibrary.simpleMessage("タイトルを入力してください"),
    "toLogin": MessageLookupByLibrary.simpleMessage("アカウントをお持ちの方 → ログイン"),
    "toRegister": MessageLookupByLibrary.simpleMessage("アカウントをお持ちでない方 → 登録"),
    "totalCollects": MessageLookupByLibrary.simpleMessage("総お気に入り数"),
    "totalComments": MessageLookupByLibrary.simpleMessage("総コメント数"),
    "totalLikes": MessageLookupByLibrary.simpleMessage("総いいね数"),
    "totalViews": MessageLookupByLibrary.simpleMessage("総再生数"),
    "unfollow": MessageLookupByLibrary.simpleMessage("フォロー解除"),
    "unfollowConfirm": MessageLookupByLibrary.simpleMessage(
      "このユーザーのフォローを解除しますか？",
    ),
    "unpin": MessageLookupByLibrary.simpleMessage("ピン留め解除"),
    "unreadOnly": MessageLookupByLibrary.simpleMessage("未読のみ"),
    "uploading": MessageLookupByLibrary.simpleMessage("アップロード中"),
    "uploadingPercent": m14,
    "username": MessageLookupByLibrary.simpleMessage("ユーザー名"),
    "usernameHint": MessageLookupByLibrary.simpleMessage("ユーザー名を入力"),
    "versionLabel": MessageLookupByLibrary.simpleMessage("バージョン"),
    "videoCountLabel": MessageLookupByLibrary.simpleMessage("作品数"),
    "videoDeleted": MessageLookupByLibrary.simpleMessage("動画を削除しました"),
    "videoDeletedSuccess": MessageLookupByLibrary.simpleMessage("動画を削除しました"),
    "videoNotFound": MessageLookupByLibrary.simpleMessage("動画が存在しないか、公開停止中です"),
    "videoPreview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "videosTab": MessageLookupByLibrary.simpleMessage("動画"),
    "welcomeBack": MessageLookupByLibrary.simpleMessage("おかえりなさい"),
    "works": MessageLookupByLibrary.simpleMessage("作品"),
    "writeComment": MessageLookupByLibrary.simpleMessage("コメントを書く…"),
  };
}
