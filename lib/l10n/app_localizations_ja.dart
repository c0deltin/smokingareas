// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get accepts => '分別';

  @override
  String get access => '利用条件';

  @override
  String get accessHint => '例：駅構内（改札内）、博物館内';

  @override
  String get accessNotPublic => '利用制限あり（切符・入場料・購入が必要）';

  @override
  String get accessOptional => '利用条件（任意）';

  @override
  String get accessPublic => '誰でも利用可能';

  @override
  String get account => 'アカウント';

  @override
  String get accountActions => 'アカウント・サインアウト・アカウント削除';

  @override
  String get accountDeleteFailed => 'アカウントを削除できませんでした。もう一度お試しください。';

  @override
  String get accountDeleted => 'アカウントを削除しました。';

  @override
  String get activeProfile => '使用中のプロフィール';

  @override
  String get addPhoto => '写真を追加';

  @override
  String get address => '住所';

  @override
  String get alertRadius => '通知する距離';

  @override
  String get alertRadiusHelp =>
      '小さくすると喫煙所のすぐ近くでのみ通知します。大きくすると早めに通知しますが、密集した地域では通知が増えます。現在地の周りの青い円が距離を示します。';

  @override
  String get alertsOff => '通知オフ。';

  @override
  String alertsOnWithin(int meters) {
    return '通知オン：$meters m 以内に近づくとお知らせします。';
  }

  @override
  String get alreadyOnMap => 'すでに地図にありますか？';

  @override
  String get appTitle => 'Ippuku';

  @override
  String asUser(String name) {
    return '$name として';
  }

  @override
  String get babyChanging => 'おむつ交換台';

  @override
  String get binHereQuestion => 'ここにゴミ箱はありますか？';

  @override
  String binNo(int count) {
    return 'なし（$count）';
  }

  @override
  String get binNone => 'ここにゴミ箱はありません。';

  @override
  String get binShown => '地図にゴミ箱ありとして表示されます。';

  @override
  String binYes(int count) {
    return 'ゴミ箱あり（$count）';
  }

  @override
  String get block => 'ブロック';

  @override
  String get blockExplain => 'このユーザーの場所・評価・写真が表示されなくなります。設定 → アカウントで元に戻せます。';

  @override
  String blockName(String name) {
    return '$name をブロック';
  }

  @override
  String blockNameQuestion(String name) {
    return '$name をブロックしますか？';
  }

  @override
  String get blockedUsers => 'ブロック中のユーザー';

  @override
  String get cancel => 'キャンセル';

  @override
  String get catBin => 'ゴミ箱';

  @override
  String get catBinPlural => 'ゴミ箱';

  @override
  String get catSmoking => '喫煙所';

  @override
  String get catSmokingPlural => '喫煙所';

  @override
  String get catToilet => '公衆トイレ';

  @override
  String get catToiletPlural => 'トイレ';

  @override
  String get changePhoto => '写真を変更';

  @override
  String get changeRating => '変更';

  @override
  String get chooseFromGallery => 'ギャラリーから選ぶ';

  @override
  String get cities => '都市';

  @override
  String get city => '自治体';

  @override
  String get close => '閉じる';

  @override
  String get closedNow => '利用時間外';

  @override
  String get closedOfficially => '公式リストでは閉鎖中です。';

  @override
  String closesAt(String time) {
    return '$timeまで';
  }

  @override
  String get closureHint => '通行止め、工事中、使用不可？報告してください。報告は 14 日後、または指定した日に終了します。';

  @override
  String closureInfo(int closed, int reopened) {
    String _temp0 = intl.Intl.pluralLogic(
      reopened,
      locale: localeName,
      other: '、「再開」の報告 $reopened 件',
      zero: '',
    );
    return '「閉鎖中」の報告 $closed 件$_temp0';
  }

  @override
  String get closureReasonHint => '例：工事中、使用不可、通行止め';

  @override
  String get commentHint => 'コメント（任意）：きれい、混雑、見つけやすい…';

  @override
  String get community => 'コミュニティ';

  @override
  String get continueLabel => '続ける';

  @override
  String get continueWithoutAccount => 'アカウントなしで続ける';

  @override
  String get couldNotLoadData => 'データを読み込めませんでした。';

  @override
  String get covered => '屋根あり';

  @override
  String get createProfile => 'プロフィールを作成';

  @override
  String get dataSources => 'データソース：';

  @override
  String get date => '日付';

  @override
  String get delete => '削除';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get deleteAccountQuestion => 'アカウントを削除しますか？';

  @override
  String get deleteAccountText =>
      'アカウント・評価・写真・投票・閉鎖の報告は完全に削除されます。投稿した場所は名前なしで地図に残ります。';

  @override
  String deleteSpotQuestion(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get deleteSpotText => 'この場所はすべての利用者の地図から削除されます。';

  @override
  String get detailsOptional => '詳細（任意）';

  @override
  String get discard => '破棄';

  @override
  String get distance => '距離';

  @override
  String distanceAway(String distance) {
    return 'あと $distance';
  }

  @override
  String get edit => '編集';

  @override
  String get editTitleBin => 'ゴミ箱を編集';

  @override
  String get editTitleSmoking => '喫煙所を編集';

  @override
  String get editTitleToilet => '公衆トイレを編集';

  @override
  String get endUnknown => '終了日不明（14 日後に終了）';

  @override
  String get errConnection => '保存できませんでした。接続を確認してください。';

  @override
  String errCouldNotSave(String reason) {
    return '保存できませんでした（$reason）。';
  }

  @override
  String get errRateLimit => '短時間の投稿が多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String get errSignInFirst => '先にサインインしてください。';

  @override
  String expectedUntil(String date) {
    return '$date まで（予定）';
  }

  @override
  String get fee => '料金';

  @override
  String fgAlertsOnText(int meters) {
    return '$meters m 以内に喫煙所があるとお知らせします。';
  }

  @override
  String get fgAlertsOnTitle => '喫煙所の通知オン';

  @override
  String get fgChannel => '位置情報の確認';

  @override
  String get goneText => '十分な人数がなくなったと報告すると、地図から削除されます。';

  @override
  String get goneTitle => 'なくなりましたか？';

  @override
  String get hasTrashCan => 'ゴミ箱あり';

  @override
  String get hoursAlways => '24時間利用可';

  @override
  String hoursClosedOn(String days) {
    return '休み：$days';
  }

  @override
  String get hoursHolidays => '祝日';

  @override
  String get hoursNewYear => '年末年始';

  @override
  String hoursNextDay(String time) {
    return '翌$time';
  }

  @override
  String get imprint => '運営者情報';

  @override
  String inThisCity(int count) {
    return 'この都市に $count か所';
  }

  @override
  String get info => '情報';

  @override
  String get infoAbout =>
      '日本全国の公共の喫煙所（緑）と公衆トイレ（青）、利用者が投稿したゴミ箱（オレンジ）を表示します。多くの都市では路上喫煙が禁止され、指定された場所でのみ喫煙できます。\n\n通知をオンにすると、喫煙所に近づいたときにお知らせします（距離は設定で変更可能）。アプリがバックグラウンドでも動作します（トイレは対象外）。\n';

  @override
  String get infoLegendMerge =>
      '凡例（メニュー ⋮）ですべての記号を説明しています。公式データ（金色の枠）は市区町村が公開しているリストに基づきます。同じ場所に OSM のデータがある場合は 1 つのマーカーにまとめます。座標のない住所は国土地理院の住所検索で位置を求め、「おおよその位置」と表示しています。';

  @override
  String get infoMapCredits =>
      '地図：Google マップ。場所のデータ：© OpenStreetMap contributors (ODbL)。\n正確性は保証されません。不足や誤りは openstreetmap.org で直接修正できます（amenity=smoking_area、amenity=toilets）。';

  @override
  String get initialSignInReason => 'アカウントなしでも閲覧できます。評価・投稿・写真の追加にはサインインしてください。';

  @override
  String get legAlertRadius => '近くの喫煙所を通知する距離。';

  @override
  String get legBin => 'ゴミ箱（利用者の投稿）。';

  @override
  String get legBinBadge => 'オレンジのマーク：ゴミ箱あり。';

  @override
  String get legCategory => '種類（塗りの色）';

  @override
  String get legClosed => '灰色と一時停止マーク：一時閉鎖中。';

  @override
  String get legClusterBin => '複数のゴミ箱 – タップで拡大。';

  @override
  String get legClusterSmoking => '複数の喫煙所 – タップで拡大。';

  @override
  String get legClusterToilet => '複数のトイレ – タップで拡大。';

  @override
  String get legGold => '金：市区町村の公式リスト。';

  @override
  String get legIndoorSmoking => '屋内の喫煙室。';

  @override
  String get legMap => '地図';

  @override
  String get legOrigin => 'データ元（枠）';

  @override
  String get legOutdoorSmoking => '屋外の喫煙所。';

  @override
  String get legPink => 'ピンク：利用者の投稿。';

  @override
  String get legStatus => '状態';

  @override
  String get legToilet => '公衆トイレ。';

  @override
  String get legWhite => '白：OpenStreetMap のデータ。';

  @override
  String get legYourLocation => '現在地 – 扇形は向いている方向を示します。';

  @override
  String get legend => '凡例';

  @override
  String get loadingSmokingAreas => '喫煙所を読み込み中…';

  @override
  String get localDataRemoved => 'この端末から投稿を削除しました。';

  @override
  String localDataText(int count) {
    return '$count 件の投稿（場所・評価・写真・報告）がこの端末にのみ保存されています。みんなが見られるようにアカウントにアップロードしますか？';
  }

  @override
  String get localDataTitle => 'この端末の投稿';

  @override
  String get localProfilesNote =>
      '評価・写真・報告は現在この端末にのみ保存され、使用中のプロフィールに紐づきます。複数のプロフィールで、例えば「なくなった」報告が 3 件で場所が消えることを試せます。';

  @override
  String get locationServicesOff => '位置情報サービスがオフになっています。';

  @override
  String get locationUseText =>
      'Ippuku は、近くの喫煙所や公衆トイレを地図に表示するために位置情報を使います。\n\n通知をオンにすると、アプリを閉じているときや使っていないときもバックグラウンドで位置情報を使い、指定喫煙所に近づいたときにお知らせします。\n\n位置情報は端末内でのみ処理され、私たちに送信されたり第三者と共有されたりすることはありません。通知はいつでもオフにできます。';

  @override
  String get locationUseTitle => '位置情報の利用について';

  @override
  String mapDataUpdated(String version) {
    return '地図データを更新しました（$version）。';
  }

  @override
  String get menu => 'メニュー';

  @override
  String meters(int meters) {
    return '$meters m';
  }

  @override
  String get more => 'その他';

  @override
  String moveCrossHint(String category) {
    return '$category：十字が場所の真上に来るよう地図を動かしてください。';
  }

  @override
  String get myLocation => '現在地';

  @override
  String get mySpots => '自分の投稿';

  @override
  String get mySpotsEmpty => 'まだ場所を投稿していません。地図の「場所を投稿」ボタンを使ってください。';

  @override
  String get mySpotsSignIn => '投稿した場所を確認・管理するにはサインインしてください。';

  @override
  String get name => '名前';

  @override
  String get nameHintBin => '例：「自販機横のゴミ箱」';

  @override
  String get nameHintSmoking => '例：「ファミリーマート横の喫煙コーナー」';

  @override
  String get nameHintToilet => '例：「公園入口のトイレ」';

  @override
  String get namePlace => '名前・場所';

  @override
  String nearestName(String name) {
    return '最寄り：$name';
  }

  @override
  String get no => 'いいえ';

  @override
  String get noAccountText =>
      'アカウントなしで利用しています。評価・投稿・写真の追加には Apple または Google でサインインしてください。';

  @override
  String get noLocationNoAlerts => '位置情報へのアクセスがないと、近くの通知は届きません。';

  @override
  String get noRatingsYet => 'まだ評価はありません';

  @override
  String get noReportNew => 'いいえ、新規投稿';

  @override
  String get noSeparate => 'いいえ、別の場所';

  @override
  String get notNow => '今はしない';

  @override
  String get notSignedIn => 'サインインしていません';

  @override
  String get notSure => '不明';

  @override
  String get note => 'メモ';

  @override
  String get noteBabyChairTable => 'ベビーチェア・ベビーシート';

  @override
  String get noteChangingTable => 'ベビーシート';

  @override
  String get noteConstruction => '工事中のため休止中';

  @override
  String get noteHeatedOnly => '加熱式たばこ専用';

  @override
  String get noteHintBin => '正確な場所や見つけ方など…';

  @override
  String get noteHintDefault => '利用時間、灰皿、利用条件など…';

  @override
  String get noteMenOnly => '男性専用';

  @override
  String get noteOptional => 'メモ（任意）';

  @override
  String get noteUnisex => '男女共用';

  @override
  String get noteWomenAccessible => '女子トイレ 誰でもトイレ兼用';

  @override
  String get noteWomenOnly => '女性専用';

  @override
  String get notifChannelNearby => '近くの喫煙所';

  @override
  String get notifChannelNearbyDesc => '喫煙所に近づいたときにお知らせします。';

  @override
  String notifNearbyBody(String name, int meters) {
    return '$name – 約 $meters m 先。タップして地図を開きます。';
  }

  @override
  String get notifNearbyTitle => '近くに喫煙所があります';

  @override
  String officialDataVersion(String version) {
    return '公式データのバージョン：$version – 自動で更新されます（再読み込みでも更新）。';
  }

  @override
  String offlineSavedData(String date) {
    return 'オフライン – $date に保存したデータを表示しています。';
  }

  @override
  String get ok => 'OK';

  @override
  String get openAgain => '再開している';

  @override
  String get openNow => '利用可能';

  @override
  String get openingHours => '利用時間';

  @override
  String opensAt(String time) {
    return '$timeから';
  }

  @override
  String get operator => '管理者';

  @override
  String get osm => 'OSM';

  @override
  String get osmCopyright => 'データ © OpenStreetMap contributors';

  @override
  String get outdoors => '屋外';

  @override
  String partOfHostText(String name, String category) {
    return '「$name」（$category）がすぐそばにあります。ゴミ箱はその一部ですか（例：ゴミ箱付きの灰皿）？その場合、新しいマーカーではなくそこに追加されます。';
  }

  @override
  String get partOfHostTitle => 'この場所の一部ですか？';

  @override
  String get photo => '写真';

  @override
  String photoCount(int count) {
    return '写真 $count 枚';
  }

  @override
  String get photoUploadFailed => '写真をアップロードできませんでした。';

  @override
  String get popularDistricts => '人気のエリア';

  @override
  String get position => '位置';

  @override
  String get positionApprox => 'おおよその位置（住所から算出、約 ±50 m）';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get profile => 'プロフィール';

  @override
  String get profilesOnDevice => 'この端末のプロフィール';

  @override
  String get publiclyAccessible => '誰でも利用可能';

  @override
  String get publiclyAccessibleSub => '切符・入場料・購入は不要';

  @override
  String get rate => '評価する';

  @override
  String ratingSummary(String average, int count) {
    return '$average（$count 件の評価）';
  }

  @override
  String get reasonOffensive => '攻撃的・不適切';

  @override
  String get reasonOptional => '理由（任意）';

  @override
  String get reasonOther => 'その他';

  @override
  String get reasonPersonalData => '他人の個人情報';

  @override
  String get reasonSpam => 'スパム・広告';

  @override
  String get reasonWrong => '誤り・誤解を招く';

  @override
  String get reload => '再読み込み';

  @override
  String get remove => '削除';

  @override
  String get removedAfterReports => 'ありがとうございます！報告により、この場所は削除されました。';

  @override
  String get removedByCommunity => '利用者の報告により削除';

  @override
  String get rename => '名前を変更';

  @override
  String get report => '報告';

  @override
  String get reportASpot => '場所を投稿';

  @override
  String get reportHere => 'ここで投稿';

  @override
  String get reportTitleBin => 'ゴミ箱を投稿';

  @override
  String get reportTitleSmoking => '喫煙所を投稿';

  @override
  String get reportTitleToilet => '公衆トイレを投稿';

  @override
  String get reportedBy => '投稿者';

  @override
  String reportedGone(int count) {
    return '$count 人がこの場所はもうないと報告しています。';
  }

  @override
  String reportedOn(String date) {
    return '$date に投稿';
  }

  @override
  String get reportedVisibleNote =>
      '投稿した場所はすぐに表示されます。存在しないという報告が十分に集まると削除されます。';

  @override
  String resetToMeters(int meters) {
    return '$meters m に戻す';
  }

  @override
  String get retry => '再試行';

  @override
  String roomsInBuilding(int count) {
    return '同じ建物内に $count か所';
  }

  @override
  String get route => 'ルート';

  @override
  String sameplaceQuestion(String name, int meters) {
    return '「$name」が $meters m 先にあります。同じ場所ですか？';
  }

  @override
  String get save => '保存';

  @override
  String get savedOffline => '接続がありません。この端末に保存し、後で自動的に送信します。';

  @override
  String get saving => '保存中…';

  @override
  String get searchPlaceHint => '市区町村・地区・都道府県を検索';

  @override
  String get send => '送信';

  @override
  String get sending => '送信中…';

  @override
  String get settings => '設定';

  @override
  String get showOnMap => '地図で表示';

  @override
  String get shownWithContributions => '投稿に表示されます';

  @override
  String get signIn => 'サインイン';

  @override
  String get signInDefaultReason => '評価・投稿・写真の追加にはサインインしてください。';

  @override
  String get signInFailed => 'サインインに失敗しました。もう一度お試しください。';

  @override
  String get signInPrivacyNote =>
      '投稿には名（ファーストネーム）のみが表示されます。位置情報が端末の外に送られることはありません。サインインすると利用規約に同意したことになります。';

  @override
  String get signInToAddDetails => '詳細を追加するにはサインインしてください。';

  @override
  String get signInToAddPhotos => '写真を追加するにはサインインしてください。';

  @override
  String get signInToBlock => 'ユーザーをブロックするにはサインインしてください。';

  @override
  String get signInToConfirm => '場所を確認するにはサインインしてください。';

  @override
  String get signInToContribute => '投稿するにはサインインしてください。';

  @override
  String get signInToRate => '評価するにはサインインしてください。';

  @override
  String get signInToReport => '新しい場所を投稿するにはサインインしてください。';

  @override
  String get signInToReportClosures => '閉鎖を報告するにはサインインしてください。';

  @override
  String get signInToReportContent => 'コンテンツを報告するにはサインインしてください。';

  @override
  String get signInToReportGone => 'なくなった場所を報告するにはサインインしてください。';

  @override
  String get signInWithGoogle => 'Google でサインイン';

  @override
  String get signOut => 'サインアウト';

  @override
  String signedInAs(String name) {
    return '$name としてサインイン中';
  }

  @override
  String get smokingAreaAlerts => '喫煙所の通知';

  @override
  String get smokingAreaAlertsSub => '喫煙所に近づいたら通知する。';

  @override
  String smokingAreasInCity(int count) {
    return 'この都市の喫煙所：$count か所';
  }

  @override
  String get smokingRoom => '喫煙室';

  @override
  String get smokingRoomIndoors => '喫煙室（屋内）';

  @override
  String get smokingRooms => '喫煙室';

  @override
  String get someSourcesUnreachable => '一部のデータソースに接続できません。';

  @override
  String get source => 'データ元';

  @override
  String sourceOfficial(String source) {
    return '$source（公式）';
  }

  @override
  String get stillThereQuestion => 'この場所はまだありますか？';

  @override
  String get switchProfile => '切り替え';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String get temporarilyClosed => '一時閉鎖中';

  @override
  String get temporarilyClosedLower => '一時閉鎖中';

  @override
  String get termsOfUse => '利用規約';

  @override
  String thanksHostHasBin(String name) {
    return 'ありがとうございます！「$name」にゴミ箱を追加しました。';
  }

  @override
  String get thanksReportReviewed => 'ありがとうございます。報告を確認します。';

  @override
  String get thanksSpotOnMap => 'ありがとうございます！地図に追加しました。';

  @override
  String get thanksSpotPhotoUploading => 'ありがとうございます！地図に追加しました。写真をアップロード中です。';

  @override
  String get thisUser => 'このユーザー';

  @override
  String get tipAllowAlways => 'ヒント：バックグラウンドで通知するには「常に許可」を選択してください。';

  @override
  String toiletNearest(String name, String distance) {
    return 'トイレ：$name · $distance';
  }

  @override
  String get translate => '翻訳';

  @override
  String get tryAgain => 'もう一度試す';

  @override
  String get turnAlertsOff => '通知をオフにする';

  @override
  String get turnAlertsOn => '通知をオンにする';

  @override
  String get type => '種類';

  @override
  String get unblock => 'ブロック解除';

  @override
  String get unknown => '不明';

  @override
  String get upload => 'アップロード';

  @override
  String get uploadFailedTap => '失敗 – タップ';

  @override
  String uploadedPartly(int done, int left) {
    return '$done 件をアップロードしました。残り $left 件は次回アップロードします。';
  }

  @override
  String uploadedThanks(int count) {
    return '$count 件の投稿をアップロードしました。ありがとうございます！';
  }

  @override
  String get uploading => 'アップロード中…';

  @override
  String voteNo(int count) {
    return 'いいえ（$count）';
  }

  @override
  String voteYes(int count) {
    return 'はい（$count）';
  }

  @override
  String wardName(String ward) {
    return '$ward';
  }

  @override
  String get wasteBottles => 'ペットボトル';

  @override
  String get wasteCans => '缶';

  @override
  String get wasteTrash => '燃えるゴミ・一般ゴミ';

  @override
  String get whatToReport => '何を投稿しますか？';

  @override
  String get wheelchairAccessible => '車いす対応';

  @override
  String get yes => 'はい';

  @override
  String get yesAddToIt => 'はい、追加する';

  @override
  String get yesShowIt => 'はい、表示する';
}
