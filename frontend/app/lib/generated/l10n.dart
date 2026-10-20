// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `风印短剧`
  String get appName {
    return Intl.message('风印短剧', name: 'appName', desc: '', args: []);
  }

  /// `首页`
  String get home {
    return Intl.message('首页', name: 'home', desc: '', args: []);
  }

  /// `发布`
  String get publish {
    return Intl.message('发布', name: 'publish', desc: '', args: []);
  }

  /// `消息`
  String get message {
    return Intl.message('消息', name: 'message', desc: '', args: []);
  }

  /// `我的`
  String get me {
    return Intl.message('我的', name: 'me', desc: '', args: []);
  }

  /// `搜索`
  String get search {
    return Intl.message('搜索', name: 'search', desc: '', args: []);
  }

  /// `取消`
  String get cancel {
    return Intl.message('取消', name: 'cancel', desc: '', args: []);
  }

  /// `确定`
  String get confirm {
    return Intl.message('确定', name: 'confirm', desc: '', args: []);
  }

  /// `发送`
  String get confirmSend {
    return Intl.message('发送', name: 'confirmSend', desc: '', args: []);
  }

  /// `删除`
  String get delete {
    return Intl.message('删除', name: 'delete', desc: '', args: []);
  }

  /// `分享`
  String get share {
    return Intl.message('分享', name: 'share', desc: '', args: []);
  }

  /// `重试`
  String get retry {
    return Intl.message('重试', name: 'retry', desc: '', args: []);
  }

  /// `加载中…`
  String get loading {
    return Intl.message('加载中…', name: 'loading', desc: '', args: []);
  }

  /// `加载更多…`
  String get loadingMore {
    return Intl.message('加载更多…', name: 'loadingMore', desc: '', args: []);
  }

  /// `— 已经到底啦 —`
  String get allLoaded {
    return Intl.message('— 已经到底啦 —', name: 'allLoaded', desc: '', args: []);
  }

  /// `加载失败`
  String get loadFailed {
    return Intl.message('加载失败', name: 'loadFailed', desc: '', args: []);
  }

  /// `登录`
  String get login {
    return Intl.message('登录', name: 'login', desc: '', args: []);
  }

  /// `返回首页`
  String get backToHome {
    return Intl.message('返回首页', name: 'backToHome', desc: '', args: []);
  }

  /// `页面未找到`
  String get pageNotFound {
    return Intl.message('页面未找到', name: 'pageNotFound', desc: '', args: []);
  }

  /// `抱歉，您访问的页面不存在或已被移动。`
  String get pageNotFoundDesc {
    return Intl.message(
      '抱歉，您访问的页面不存在或已被移动。',
      name: 'pageNotFoundDesc',
      desc: '',
      args: [],
    );
  }

  /// `发生错误！`
  String get errorOccurred {
    return Intl.message('发生错误！', name: 'errorOccurred', desc: '', args: []);
  }

  /// `该功能即将上线，敬请期待`
  String get featureNotAvailable {
    return Intl.message(
      '该功能即将上线，敬请期待',
      name: 'featureNotAvailable',
      desc: '',
      args: [],
    );
  }

  /// `视频已删除`
  String get videoDeleted {
    return Intl.message('视频已删除', name: 'videoDeleted', desc: '', args: []);
  }

  /// `视频不存在或已下架`
  String get videoNotFound {
    return Intl.message('视频不存在或已下架', name: 'videoNotFound', desc: '', args: []);
  }

  /// `复制链接`
  String get copyLink {
    return Intl.message('复制链接', name: 'copyLink', desc: '', args: []);
  }

  /// `链接已复制，快去分享吧`
  String get shareCopied {
    return Intl.message('链接已复制，快去分享吧', name: 'shareCopied', desc: '', args: []);
  }

  /// `登录后才能互动`
  String get guestInteractionTitle {
    return Intl.message(
      '登录后才能互动',
      name: 'guestInteractionTitle',
      desc: '',
      args: [],
    );
  }

  /// `登录后即可点赞、评论、收藏和关注`
  String get guestInteractionDesc {
    return Intl.message(
      '登录后即可点赞、评论、收藏和关注',
      name: 'guestInteractionDesc',
      desc: '',
      args: [],
    );
  }

  /// `去登录`
  String get goLogin {
    return Intl.message('去登录', name: 'goLogin', desc: '', args: []);
  }

  /// `关注`
  String get reasonFollow {
    return Intl.message('关注', name: 'reasonFollow', desc: '', args: []);
  }

  /// `热`
  String get reasonHot {
    return Intl.message('热', name: 'reasonHot', desc: '', args: []);
  }

  /// `最新`
  String get reasonLatest {
    return Intl.message('最新', name: 'reasonLatest', desc: '', args: []);
  }

  /// `关注`
  String get follow {
    return Intl.message('关注', name: 'follow', desc: '', args: []);
  }

  /// `已关注`
  String get followed {
    return Intl.message('已关注', name: 'followed', desc: '', args: []);
  }

  /// `取消关注`
  String get unfollow {
    return Intl.message('取消关注', name: 'unfollow', desc: '', args: []);
  }

  /// `确定不再关注该用户吗？`
  String get unfollowConfirm {
    return Intl.message(
      '确定不再关注该用户吗？',
      name: 'unfollowConfirm',
      desc: '',
      args: [],
    );
  }

  /// `不能关注自己`
  String get cannotFollowSelf {
    return Intl.message('不能关注自己', name: 'cannotFollowSelf', desc: '', args: []);
  }

  /// `评论`
  String get comment {
    return Intl.message('评论', name: 'comment', desc: '', args: []);
  }

  /// `{count} 条评论`
  String commentsCount(int count) {
    return Intl.message(
      '$count 条评论',
      name: 'commentsCount',
      desc: '',
      args: [count],
    );
  }

  /// `写下你的评论…`
  String get writeComment {
    return Intl.message('写下你的评论…', name: 'writeComment', desc: '', args: []);
  }

  /// `回复`
  String get reply {
    return Intl.message('回复', name: 'reply', desc: '', args: []);
  }

  /// `回复 {name}`
  String replyTo(String name) {
    return Intl.message('回复 $name', name: 'replyTo', desc: '', args: [name]);
  }

  /// `{count} 条回复`
  String repliesCount(int count) {
    return Intl.message(
      '$count 条回复',
      name: 'repliesCount',
      desc: '',
      args: [count],
    );
  }

  /// `展开 {count} 条回复`
  String expandReplies(int count) {
    return Intl.message(
      '展开 $count 条回复',
      name: 'expandReplies',
      desc: '',
      args: [count],
    );
  }

  /// `确定删除这条评论吗？`
  String get deleteCommentConfirm {
    return Intl.message(
      '确定删除这条评论吗？',
      name: 'deleteCommentConfirm',
      desc: '',
      args: [],
    );
  }

  /// `评论成功`
  String get commentSuccess {
    return Intl.message('评论成功', name: 'commentSuccess', desc: '', args: []);
  }

  /// `评论已删除`
  String get commentDeleted {
    return Intl.message('评论已删除', name: 'commentDeleted', desc: '', args: []);
  }

  /// `暂无评论，快来抢沙发`
  String get noCommentsYet {
    return Intl.message(
      '暂无评论，快来抢沙发',
      name: 'noCommentsYet',
      desc: '',
      args: [],
    );
  }

  /// `评论内容不能为空`
  String get commentIsEmpty {
    return Intl.message('评论内容不能为空', name: 'commentIsEmpty', desc: '', args: []);
  }

  /// `只能删除自己的评论`
  String get onlyOwnerCanDelete {
    return Intl.message(
      '只能删除自己的评论',
      name: 'onlyOwnerCanDelete',
      desc: '',
      args: [],
    );
  }

  /// `从相册选择`
  String get pickVideo {
    return Intl.message('从相册选择', name: 'pickVideo', desc: '', args: []);
  }

  /// `拍摄视频`
  String get recordVideo {
    return Intl.message('拍摄视频', name: 'recordVideo', desc: '', args: []);
  }

  /// `视频预览`
  String get videoPreview {
    return Intl.message('视频预览', name: 'videoPreview', desc: '', args: []);
  }

  /// `重新选择`
  String get reselectVideo {
    return Intl.message('重新选择', name: 'reselectVideo', desc: '', args: []);
  }

  /// `标题`
  String get titleLabel {
    return Intl.message('标题', name: 'titleLabel', desc: '', args: []);
  }

  /// `给视频起个吸引人的标题`
  String get titleHint {
    return Intl.message('给视频起个吸引人的标题', name: 'titleHint', desc: '', args: []);
  }

  /// `简介`
  String get descriptionLabel {
    return Intl.message('简介', name: 'descriptionLabel', desc: '', args: []);
  }

  /// `介绍一下你的视频…`
  String get descriptionHint {
    return Intl.message(
      '介绍一下你的视频…',
      name: 'descriptionHint',
      desc: '',
      args: [],
    );
  }

  /// `添加标签`
  String get addTags {
    return Intl.message('添加标签', name: 'addTags', desc: '', args: []);
  }

  /// `选择标签`
  String get tagPickerTitle {
    return Intl.message('选择标签', name: 'tagPickerTitle', desc: '', args: []);
  }

  /// `搜索或创建标签`
  String get tagInputHint {
    return Intl.message('搜索或创建标签', name: 'tagInputHint', desc: '', args: []);
  }

  /// `没有匹配标签，回车直接使用`
  String get noTagFound {
    return Intl.message(
      '没有匹配标签，回车直接使用',
      name: 'noTagFound',
      desc: '',
      args: [],
    );
  }

  /// `存草稿`
  String get saveDraft {
    return Intl.message('存草稿', name: 'saveDraft', desc: '', args: []);
  }

  /// `发布`
  String get submitPublish {
    return Intl.message('发布', name: 'submitPublish', desc: '', args: []);
  }

  /// `上传中`
  String get uploading {
    return Intl.message('上传中', name: 'uploading', desc: '', args: []);
  }

  /// `上传中 {percent}%`
  String uploadingPercent(int percent) {
    return Intl.message(
      '上传中 $percent%',
      name: 'uploadingPercent',
      desc: '',
      args: [percent],
    );
  }

  /// `视频合并处理中…`
  String get mergingVideo {
    return Intl.message('视频合并处理中…', name: 'mergingVideo', desc: '', args: []);
  }

  /// `发布成功，等待审核`
  String get publishSuccess {
    return Intl.message(
      '发布成功，等待审核',
      name: 'publishSuccess',
      desc: '',
      args: [],
    );
  }

  /// `草稿已保存`
  String get draftSaved {
    return Intl.message('草稿已保存', name: 'draftSaved', desc: '', args: []);
  }

  /// `发布失败，请稍后重试`
  String get publishFailed {
    return Intl.message(
      '发布失败，请稍后重试',
      name: 'publishFailed',
      desc: '',
      args: [],
    );
  }

  /// `请先选择要发布的视频`
  String get pickVideoFirst {
    return Intl.message(
      '请先选择要发布的视频',
      name: 'pickVideoFirst',
      desc: '',
      args: [],
    );
  }

  /// `请填写视频标题`
  String get titleRequired {
    return Intl.message('请填写视频标题', name: 'titleRequired', desc: '', args: []);
  }

  /// `存为草稿（仅自己可见）`
  String get asDraftOption {
    return Intl.message(
      '存为草稿（仅自己可见）',
      name: 'asDraftOption',
      desc: '',
      args: [],
    );
  }

  /// `草稿箱`
  String get drafts {
    return Intl.message('草稿箱', name: 'drafts', desc: '', args: []);
  }

  /// `选择一段视频开始创作`
  String get chooseVideoToCreate {
    return Intl.message(
      '选择一段视频开始创作',
      name: 'chooseVideoToCreate',
      desc: '',
      args: [],
    );
  }

  /// `支持 5 分钟以内的短视频`
  String get publishGuideSubtitle {
    return Intl.message(
      '支持 5 分钟以内的短视频',
      name: 'publishGuideSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `高级设置`
  String get advancedSettings {
    return Intl.message('高级设置', name: 'advancedSettings', desc: '', args: []);
  }

  /// `输入标签，回车或逗号添加`
  String get tagInlineHint {
    return Intl.message(
      '输入标签，回车或逗号添加',
      name: 'tagInlineHint',
      desc: '',
      args: [],
    );
  }

  /// `移除视频`
  String get removeVideo {
    return Intl.message('移除视频', name: 'removeVideo', desc: '', args: []);
  }

  /// `全部已读`
  String get markAllRead {
    return Intl.message('全部已读', name: 'markAllRead', desc: '', args: []);
  }

  /// `只看未读`
  String get unreadOnly {
    return Intl.message('只看未读', name: 'unreadOnly', desc: '', args: []);
  }

  /// `暂无新消息`
  String get noNewMessages {
    return Intl.message('暂无新消息', name: 'noNewMessages', desc: '', args: []);
  }

  /// `已全部标记为已读`
  String get readAllSuccess {
    return Intl.message('已全部标记为已读', name: 'readAllSuccess', desc: '', args: []);
  }

  /// `登录后查看消息通知`
  String get loginToViewMessages {
    return Intl.message(
      '登录后查看消息通知',
      name: 'loginToViewMessages',
      desc: '',
      args: [],
    );
  }

  /// `赞`
  String get notifyTypeLike {
    return Intl.message('赞', name: 'notifyTypeLike', desc: '', args: []);
  }

  /// `评论`
  String get notifyTypeComment {
    return Intl.message('评论', name: 'notifyTypeComment', desc: '', args: []);
  }

  /// `关注`
  String get notifyTypeFollow {
    return Intl.message('关注', name: 'notifyTypeFollow', desc: '', args: []);
  }

  /// `系统`
  String get notifyTypeSystem {
    return Intl.message('系统', name: 'notifyTypeSystem', desc: '', args: []);
  }

  /// `作品`
  String get works {
    return Intl.message('作品', name: 'works', desc: '', args: []);
  }

  /// `收藏`
  String get collects {
    return Intl.message('收藏', name: 'collects', desc: '', args: []);
  }

  /// `创作者中心`
  String get creatorCenter {
    return Intl.message('创作者中心', name: 'creatorCenter', desc: '', args: []);
  }

  /// `数据总览`
  String get creatorOverview {
    return Intl.message('数据总览', name: 'creatorOverview', desc: '', args: []);
  }

  /// `粉丝`
  String get followers {
    return Intl.message('粉丝', name: 'followers', desc: '', args: []);
  }

  /// `关注`
  String get followingCountLabel {
    return Intl.message('关注', name: 'followingCountLabel', desc: '', args: []);
  }

  /// `获赞`
  String get likeReceived {
    return Intl.message('获赞', name: 'likeReceived', desc: '', args: []);
  }

  /// `总播放`
  String get totalViews {
    return Intl.message('总播放', name: 'totalViews', desc: '', args: []);
  }

  /// `总点赞`
  String get totalLikes {
    return Intl.message('总点赞', name: 'totalLikes', desc: '', args: []);
  }

  /// `总收藏`
  String get totalCollects {
    return Intl.message('总收藏', name: 'totalCollects', desc: '', args: []);
  }

  /// `总评论`
  String get totalComments {
    return Intl.message('总评论', name: 'totalComments', desc: '', args: []);
  }

  /// `作品数`
  String get videoCountLabel {
    return Intl.message('作品数', name: 'videoCountLabel', desc: '', args: []);
  }

  /// `编辑资料`
  String get editProfile {
    return Intl.message('编辑资料', name: 'editProfile', desc: '', args: []);
  }

  /// `昵称`
  String get nicknameLabel {
    return Intl.message('昵称', name: 'nicknameLabel', desc: '', args: []);
  }

  /// `给自己起个昵称`
  String get nicknameHint {
    return Intl.message('给自己起个昵称', name: 'nicknameHint', desc: '', args: []);
  }

  /// `简介`
  String get bioLabel {
    return Intl.message('简介', name: 'bioLabel', desc: '', args: []);
  }

  /// `介绍一下自己…`
  String get bioHint {
    return Intl.message('介绍一下自己…', name: 'bioHint', desc: '', args: []);
  }

  /// `头像`
  String get avatarLabel {
    return Intl.message('头像', name: 'avatarLabel', desc: '', args: []);
  }

  /// `头像图片不能超过 2MB`
  String get avatarTooLarge {
    return Intl.message(
      '头像图片不能超过 2MB',
      name: 'avatarTooLarge',
      desc: '',
      args: [],
    );
  }

  /// `保存`
  String get saveProfile {
    return Intl.message('保存', name: 'saveProfile', desc: '', args: []);
  }

  /// `资料已更新`
  String get profileSaved {
    return Intl.message('资料已更新', name: 'profileSaved', desc: '', args: []);
  }

  /// `退出登录`
  String get logout {
    return Intl.message('退出登录', name: 'logout', desc: '', args: []);
  }

  /// `确定要退出登录吗？`
  String get logoutConfirm {
    return Intl.message('确定要退出登录吗？', name: 'logoutConfirm', desc: '', args: []);
  }

  /// `登录后查看我的主页`
  String get loginToViewProfile {
    return Intl.message(
      '登录后查看我的主页',
      name: 'loginToViewProfile',
      desc: '',
      args: [],
    );
  }

  /// `还没有作品，去发布第一个视频吧`
  String get noWorksYet {
    return Intl.message(
      '还没有作品，去发布第一个视频吧',
      name: 'noWorksYet',
      desc: '',
      args: [],
    );
  }

  /// `还没有收藏的视频`
  String get noCollectedVideos {
    return Intl.message(
      '还没有收藏的视频',
      name: 'noCollectedVideos',
      desc: '',
      args: [],
    );
  }

  /// `草稿`
  String get statusDraft {
    return Intl.message('草稿', name: 'statusDraft', desc: '', args: []);
  }

  /// `审核中`
  String get statusReviewing {
    return Intl.message('审核中', name: 'statusReviewing', desc: '', args: []);
  }

  /// `未通过`
  String get statusRejected {
    return Intl.message('未通过', name: 'statusRejected', desc: '', args: []);
  }

  /// `已下架`
  String get statusOffline {
    return Intl.message('已下架', name: 'statusOffline', desc: '', args: []);
  }

  /// `驳回原因`
  String get rejectReasonLabel {
    return Intl.message('驳回原因', name: 'rejectReasonLabel', desc: '', args: []);
  }

  /// `删除视频`
  String get deleteVideo {
    return Intl.message('删除视频', name: 'deleteVideo', desc: '', args: []);
  }

  /// `确定删除该视频吗？删除后不可恢复`
  String get deleteVideoConfirm {
    return Intl.message(
      '确定删除该视频吗？删除后不可恢复',
      name: 'deleteVideoConfirm',
      desc: '',
      args: [],
    );
  }

  /// `视频已删除`
  String get videoDeletedSuccess {
    return Intl.message(
      '视频已删除',
      name: 'videoDeletedSuccess',
      desc: '',
      args: [],
    );
  }

  /// `设置`
  String get settings {
    return Intl.message('设置', name: 'settings', desc: '', args: []);
  }

  /// `外观`
  String get appearance {
    return Intl.message('外观', name: 'appearance', desc: '', args: []);
  }

  /// `深色模式`
  String get darkMode {
    return Intl.message('深色模式', name: 'darkMode', desc: '', args: []);
  }

  /// `浅色`
  String get light {
    return Intl.message('浅色', name: 'light', desc: '', args: []);
  }

  /// `跟随系统`
  String get followSystem {
    return Intl.message('跟随系统', name: 'followSystem', desc: '', args: []);
  }

  /// `深色`
  String get dark {
    return Intl.message('深色', name: 'dark', desc: '', args: []);
  }

  /// `语言`
  String get language {
    return Intl.message('语言', name: 'language', desc: '', args: []);
  }

  /// `关于`
  String get about {
    return Intl.message('关于', name: 'about', desc: '', args: []);
  }

  /// `版本`
  String get versionLabel {
    return Intl.message('版本', name: 'versionLabel', desc: '', args: []);
  }

  /// `搜索视频、标签`
  String get searchHint {
    return Intl.message('搜索视频、标签', name: 'searchHint', desc: '', args: []);
  }

  /// `没有找到「{query}」相关视频`
  String searchEmpty(String query) {
    return Intl.message(
      '没有找到「$query」相关视频',
      name: 'searchEmpty',
      desc: '',
      args: [query],
    );
  }

  /// `热门标签`
  String get hotTags {
    return Intl.message('热门标签', name: 'hotTags', desc: '', args: []);
  }

  /// `搜点什么看看吧`
  String get searchSomeKeyword {
    return Intl.message(
      '搜点什么看看吧',
      name: 'searchSomeKeyword',
      desc: '',
      args: [],
    );
  }

  /// `举报`
  String get report {
    return Intl.message('举报', name: 'report', desc: '', args: []);
  }

  /// `选择举报原因`
  String get reportReasonTitle {
    return Intl.message(
      '选择举报原因',
      name: 'reportReasonTitle',
      desc: '',
      args: [],
    );
  }

  /// `补充说明（选填）`
  String get reportDescriptionHint {
    return Intl.message(
      '补充说明（选填）',
      name: 'reportDescriptionHint',
      desc: '',
      args: [],
    );
  }

  /// `提交举报`
  String get reportSubmit {
    return Intl.message('提交举报', name: 'reportSubmit', desc: '', args: []);
  }

  /// `举报已提交，感谢你的反馈`
  String get reportSubmitted {
    return Intl.message(
      '举报已提交，感谢你的反馈',
      name: 'reportSubmitted',
      desc: '',
      args: [],
    );
  }

  /// `该内容已被举报过，请耐心等待处理`
  String get reportDuplicate {
    return Intl.message(
      '该内容已被举报过，请耐心等待处理',
      name: 'reportDuplicate',
      desc: '',
      args: [],
    );
  }

  /// `色情低俗`
  String get reportReasonPorn {
    return Intl.message('色情低俗', name: 'reportReasonPorn', desc: '', args: []);
  }

  /// `暴力血腥`
  String get reportReasonViolence {
    return Intl.message(
      '暴力血腥',
      name: 'reportReasonViolence',
      desc: '',
      args: [],
    );
  }

  /// `辱骂攻击`
  String get reportReasonAbuse {
    return Intl.message('辱骂攻击', name: 'reportReasonAbuse', desc: '', args: []);
  }

  /// `侵权`
  String get reportReasonCopyright {
    return Intl.message(
      '侵权',
      name: 'reportReasonCopyright',
      desc: '',
      args: [],
    );
  }

  /// `诈骗信息`
  String get reportReasonFraud {
    return Intl.message('诈骗信息', name: 'reportReasonFraud', desc: '', args: []);
  }

  /// `其他问题`
  String get reportReasonOther {
    return Intl.message('其他问题', name: 'reportReasonOther', desc: '', args: []);
  }

  /// `用户名`
  String get username {
    return Intl.message('用户名', name: 'username', desc: '', args: []);
  }

  /// `密码`
  String get password {
    return Intl.message('密码', name: 'password', desc: '', args: []);
  }

  /// `请输入用户名`
  String get usernameHint {
    return Intl.message('请输入用户名', name: 'usernameHint', desc: '', args: []);
  }

  /// `请输入密码`
  String get passwordHint {
    return Intl.message('请输入密码', name: 'passwordHint', desc: '', args: []);
  }

  /// `登录后点赞、评论、发布你的短视频`
  String get loginForMore {
    return Intl.message(
      '登录后点赞、评论、发布你的短视频',
      name: 'loginForMore',
      desc: '',
      args: [],
    );
  }

  /// `登录`
  String get loginButton {
    return Intl.message('登录', name: 'loginButton', desc: '', args: []);
  }

  /// `登录成功`
  String get loginSuccess {
    return Intl.message('登录成功', name: 'loginSuccess', desc: '', args: []);
  }

  /// `登录失败，请检查用户名和密码`
  String get loginFailed {
    return Intl.message(
      '登录失败，请检查用户名和密码',
      name: 'loginFailed',
      desc: '',
      args: [],
    );
  }

  /// `注册`
  String get register {
    return Intl.message('注册', name: 'register', desc: '', args: []);
  }

  /// `注册新账号`
  String get registerTitle {
    return Intl.message('注册新账号', name: 'registerTitle', desc: '', args: []);
  }

  /// `没有账号？去注册`
  String get toRegister {
    return Intl.message('没有账号？去注册', name: 'toRegister', desc: '', args: []);
  }

  /// `已有账号？去登录`
  String get toLogin {
    return Intl.message('已有账号？去登录', name: 'toLogin', desc: '', args: []);
  }

  /// `注册成功`
  String get registerSuccess {
    return Intl.message('注册成功', name: 'registerSuccess', desc: '', args: []);
  }

  /// `注册失败，请稍后重试`
  String get registerFailed {
    return Intl.message(
      '注册失败，请稍后重试',
      name: 'registerFailed',
      desc: '',
      args: [],
    );
  }

  /// `欢迎回来`
  String get welcomeBack {
    return Intl.message('欢迎回来', name: 'welcomeBack', desc: '', args: []);
  }

  /// `刚刚`
  String get timeJustNow {
    return Intl.message('刚刚', name: 'timeJustNow', desc: '', args: []);
  }

  /// `{count} 分钟前`
  String timeMinutesAgo(int count) {
    return Intl.message(
      '$count 分钟前',
      name: 'timeMinutesAgo',
      desc: '',
      args: [count],
    );
  }

  /// `{count} 小时前`
  String timeHoursAgo(int count) {
    return Intl.message(
      '$count 小时前',
      name: 'timeHoursAgo',
      desc: '',
      args: [count],
    );
  }

  /// `{count} 天前`
  String timeDaysAgo(int count) {
    return Intl.message(
      '$count 天前',
      name: 'timeDaysAgo',
      desc: '',
      args: [count],
    );
  }

  /// `操作失败，请稍后重试`
  String get errorDefault {
    return Intl.message('操作失败，请稍后重试', name: 'errorDefault', desc: '', args: []);
  }

  /// `网络异常，请检查网络连接`
  String get errorNetworkError {
    return Intl.message(
      '网络异常，请检查网络连接',
      name: 'errorNetworkError',
      desc: '',
      args: [],
    );
  }

  /// `请求超时，请稍后重试`
  String get errorTimeout {
    return Intl.message('请求超时，请稍后重试', name: 'errorTimeout', desc: '', args: []);
  }

  /// `请求参数错误`
  String get errorBadRequest {
    return Intl.message('请求参数错误', name: 'errorBadRequest', desc: '', args: []);
  }

  /// `用户名已被占用`
  String get errorUsernameTaken {
    return Intl.message(
      '用户名已被占用',
      name: 'errorUsernameTaken',
      desc: '',
      args: [],
    );
  }

  /// `授权类型无效`
  String get errorInvalidGrantType {
    return Intl.message(
      '授权类型无效',
      name: 'errorInvalidGrantType',
      desc: '',
      args: [],
    );
  }

  /// `用户 ID 无效`
  String get errorInvalidUserid {
    return Intl.message(
      '用户 ID 无效',
      name: 'errorInvalidUserid',
      desc: '',
      args: [],
    );
  }

  /// `令牌无效`
  String get errorInvalidToken {
    return Intl.message('令牌无效', name: 'errorInvalidToken', desc: '', args: []);
  }

  /// `用户名或密码错误`
  String get errorInvalidPassword {
    return Intl.message(
      '用户名或密码错误',
      name: 'errorInvalidPassword',
      desc: '',
      args: [],
    );
  }

  /// `未登录或登录已过期`
  String get errorUnauthorized {
    return Intl.message(
      '未登录或登录已过期',
      name: 'errorUnauthorized',
      desc: '',
      args: [],
    );
  }

  /// `账号已被冻结`
  String get errorUserFreeze {
    return Intl.message('账号已被冻结', name: 'errorUserFreeze', desc: '', args: []);
  }

  /// `应用密钥错误`
  String get errorIncorrectAppSecret {
    return Intl.message(
      '应用密钥错误',
      name: 'errorIncorrectAppSecret',
      desc: '',
      args: [],
    );
  }

  /// `访问令牌错误`
  String get errorIncorrectAccessToken {
    return Intl.message(
      '访问令牌错误',
      name: 'errorIncorrectAccessToken',
      desc: '',
      args: [],
    );
  }

  /// `刷新令牌错误`
  String get errorIncorrectRefreshToken {
    return Intl.message(
      '刷新令牌错误',
      name: 'errorIncorrectRefreshToken',
      desc: '',
      args: [],
    );
  }

  /// `登录已过期，请重新登录`
  String get errorTokenExpired {
    return Intl.message(
      '登录已过期，请重新登录',
      name: 'errorTokenExpired',
      desc: '',
      args: [],
    );
  }

  /// `令牌不存在`
  String get errorTokenNotExist {
    return Intl.message(
      '令牌不存在',
      name: 'errorTokenNotExist',
      desc: '',
      args: [],
    );
  }

  /// `需要支付`
  String get errorPaymentRequired {
    return Intl.message(
      '需要支付',
      name: 'errorPaymentRequired',
      desc: '',
      args: [],
    );
  }

  /// `没有权限执行此操作`
  String get errorForbidden {
    return Intl.message(
      '没有权限执行此操作',
      name: 'errorForbidden',
      desc: '',
      args: [],
    );
  }

  /// `资源不存在`
  String get errorNotFound {
    return Intl.message('资源不存在', name: 'errorNotFound', desc: '', args: []);
  }

  /// `用户不存在`
  String get errorUserNotFound {
    return Intl.message('用户不存在', name: 'errorUserNotFound', desc: '', args: []);
  }

  /// `视频不存在`
  String get errorVideoNotFound {
    return Intl.message(
      '视频不存在',
      name: 'errorVideoNotFound',
      desc: '',
      args: [],
    );
  }

  /// `请求方法不允许`
  String get errorMethodNotAllowed {
    return Intl.message(
      '请求方法不允许',
      name: 'errorMethodNotAllowed',
      desc: '',
      args: [],
    );
  }

  /// `不可接受的请求`
  String get errorNotAcceptable {
    return Intl.message(
      '不可接受的请求',
      name: 'errorNotAcceptable',
      desc: '',
      args: [],
    );
  }

  /// `需要代理身份验证`
  String get errorProxyAuthenticationRequired {
    return Intl.message(
      '需要代理身份验证',
      name: 'errorProxyAuthenticationRequired',
      desc: '',
      args: [],
    );
  }

  /// `请求超时`
  String get errorRequestTimeout {
    return Intl.message(
      '请求超时',
      name: 'errorRequestTimeout',
      desc: '',
      args: [],
    );
  }

  /// `数据冲突，请刷新后重试`
  String get errorConflict {
    return Intl.message(
      '数据冲突，请刷新后重试',
      name: 'errorConflict',
      desc: '',
      args: [],
    );
  }

  /// `资源已删除`
  String get errorGone {
    return Intl.message('资源已删除', name: 'errorGone', desc: '', args: []);
  }

  /// `缺少 Content-Length`
  String get errorLengthRequired {
    return Intl.message(
      '缺少 Content-Length',
      name: 'errorLengthRequired',
      desc: '',
      args: [],
    );
  }

  /// `前置条件不满足`
  String get errorPreconditionFailed {
    return Intl.message(
      '前置条件不满足',
      name: 'errorPreconditionFailed',
      desc: '',
      args: [],
    );
  }

  /// `视频过大，请压缩后重试`
  String get errorPayloadTooLarge {
    return Intl.message(
      '视频过大，请压缩后重试',
      name: 'errorPayloadTooLarge',
      desc: '',
      args: [],
    );
  }

  /// `请求地址过长`
  String get errorUriTooLong {
    return Intl.message('请求地址过长', name: 'errorUriTooLong', desc: '', args: []);
  }

  /// `不支持的视频格式`
  String get errorUnsupportedMediaType {
    return Intl.message(
      '不支持的视频格式',
      name: 'errorUnsupportedMediaType',
      desc: '',
      args: [],
    );
  }

  /// `请求范围无法满足`
  String get errorRangeNotSatisfiable {
    return Intl.message(
      '请求范围无法满足',
      name: 'errorRangeNotSatisfiable',
      desc: '',
      args: [],
    );
  }

  /// `请求期望无法满足`
  String get errorExpectationFailed {
    return Intl.message(
      '请求期望无法满足',
      name: 'errorExpectationFailed',
      desc: '',
      args: [],
    );
  }

  /// `服务器拒绝处理请求`
  String get errorImATeapot {
    return Intl.message(
      '服务器拒绝处理请求',
      name: 'errorImATeapot',
      desc: '',
      args: [],
    );
  }

  /// `请求被错误转发`
  String get errorMisdirectedRequest {
    return Intl.message(
      '请求被错误转发',
      name: 'errorMisdirectedRequest',
      desc: '',
      args: [],
    );
  }

  /// `无法处理请求数据`
  String get errorUnprocessableEntity {
    return Intl.message(
      '无法处理请求数据',
      name: 'errorUnprocessableEntity',
      desc: '',
      args: [],
    );
  }

  /// `资源已锁定`
  String get errorLocked {
    return Intl.message('资源已锁定', name: 'errorLocked', desc: '', args: []);
  }

  /// `依赖操作失败`
  String get errorFailedDependency {
    return Intl.message(
      '依赖操作失败',
      name: 'errorFailedDependency',
      desc: '',
      args: [],
    );
  }

  /// `请求过早`
  String get errorTooEarly {
    return Intl.message('请求过早', name: 'errorTooEarly', desc: '', args: []);
  }

  /// `需要升级后使用`
  String get errorUpgradeRequired {
    return Intl.message(
      '需要升级后使用',
      name: 'errorUpgradeRequired',
      desc: '',
      args: [],
    );
  }

  /// `需要前置条件`
  String get errorPreconditionRequired {
    return Intl.message(
      '需要前置条件',
      name: 'errorPreconditionRequired',
      desc: '',
      args: [],
    );
  }

  /// `请求过于频繁，请稍后重试`
  String get errorTooManyRequests {
    return Intl.message(
      '请求过于频繁，请稍后重试',
      name: 'errorTooManyRequests',
      desc: '',
      args: [],
    );
  }

  /// `请求头字段过大`
  String get errorRequestHeaderFieldsTooLarge {
    return Intl.message(
      '请求头字段过大',
      name: 'errorRequestHeaderFieldsTooLarge',
      desc: '',
      args: [],
    );
  }

  /// `因法律原因不可用`
  String get errorUnavailableForLegalReasons {
    return Intl.message(
      '因法律原因不可用',
      name: 'errorUnavailableForLegalReasons',
      desc: '',
      args: [],
    );
  }

  /// `服务器内部错误`
  String get errorInternalServerError {
    return Intl.message(
      '服务器内部错误',
      name: 'errorInternalServerError',
      desc: '',
      args: [],
    );
  }

  /// `功能暂未实现`
  String get errorNotImplemented {
    return Intl.message(
      '功能暂未实现',
      name: 'errorNotImplemented',
      desc: '',
      args: [],
    );
  }

  /// `网关错误`
  String get errorBadGateway {
    return Intl.message('网关错误', name: 'errorBadGateway', desc: '', args: []);
  }

  /// `服务暂时不可用`
  String get errorServiceUnavailable {
    return Intl.message(
      '服务暂时不可用',
      name: 'errorServiceUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `网关超时`
  String get errorGatewayTimeout {
    return Intl.message(
      '网关超时',
      name: 'errorGatewayTimeout',
      desc: '',
      args: [],
    );
  }

  /// `不支持的 HTTP 版本`
  String get errorHttpVersionNotSupported {
    return Intl.message(
      '不支持的 HTTP 版本',
      name: 'errorHttpVersionNotSupported',
      desc: '',
      args: [],
    );
  }

  /// `变体协商错误`
  String get errorVariantAlsoNegotiates {
    return Intl.message(
      '变体协商错误',
      name: 'errorVariantAlsoNegotiates',
      desc: '',
      args: [],
    );
  }

  /// `存储空间不足`
  String get errorInsufficientStorage {
    return Intl.message(
      '存储空间不足',
      name: 'errorInsufficientStorage',
      desc: '',
      args: [],
    );
  }

  /// `检测到循环请求`
  String get errorLoopDetected {
    return Intl.message(
      '检测到循环请求',
      name: 'errorLoopDetected',
      desc: '',
      args: [],
    );
  }

  /// `需要扩展`
  String get errorNotExtended {
    return Intl.message('需要扩展', name: 'errorNotExtended', desc: '', args: []);
  }

  /// `需要网络认证`
  String get errorNetworkAuthenticationRequired {
    return Intl.message(
      '需要网络认证',
      name: 'errorNetworkAuthenticationRequired',
      desc: '',
      args: [],
    );
  }

  /// `网络读取超时`
  String get errorNetworkReadTimeoutError {
    return Intl.message(
      '网络读取超时',
      name: 'errorNetworkReadTimeoutError',
      desc: '',
      args: [],
    );
  }

  /// `网络连接超时`
  String get errorNetworkConnectTimeoutError {
    return Intl.message(
      '网络连接超时',
      name: 'errorNetworkConnectTimeoutError',
      desc: '',
      args: [],
    );
  }

  /// `访问令牌不存在`
  String get errorAccessTokenNotFound {
    return Intl.message(
      '访问令牌不存在',
      name: 'errorAccessTokenNotFound',
      desc: '',
      args: [],
    );
  }

  /// `刷新令牌不存在`
  String get errorRefreshTokenNotFound {
    return Intl.message(
      '刷新令牌不存在',
      name: 'errorRefreshTokenNotFound',
      desc: '',
      args: [],
    );
  }

  /// `删除失败`
  String get errorDeleteFailed {
    return Intl.message('删除失败', name: 'errorDeleteFailed', desc: '', args: []);
  }

  /// `没有权限操作该资源`
  String get errorNotOwner {
    return Intl.message('没有权限操作该资源', name: 'errorNotOwner', desc: '', args: []);
  }

  /// `下载失败`
  String get errorDownloadFailed {
    return Intl.message(
      '下载失败',
      name: 'errorDownloadFailed',
      desc: '',
      args: [],
    );
  }

  /// `文件不存在`
  String get errorFileNotFound {
    return Intl.message('文件不存在', name: 'errorFileNotFound', desc: '', args: []);
  }

  /// `文件过大`
  String get errorFileTooLarge {
    return Intl.message('文件过大', name: 'errorFileTooLarge', desc: '', args: []);
  }

  /// `请勿重复举报`
  String get errorDuplicateReport {
    return Intl.message(
      '请勿重复举报',
      name: 'errorDuplicateReport',
      desc: '',
      args: [],
    );
  }

  /// `组织不存在`
  String get errorOrganizationNotFound {
    return Intl.message(
      '组织不存在',
      name: 'errorOrganizationNotFound',
      desc: '',
      args: [],
    );
  }

  /// `职位不存在`
  String get errorPositionNotFound {
    return Intl.message(
      '职位不存在',
      name: 'errorPositionNotFound',
      desc: '',
      args: [],
    );
  }

  /// `角色不存在`
  String get errorRoleNotFound {
    return Intl.message('角色不存在', name: 'errorRoleNotFound', desc: '', args: []);
  }

  /// `租户不存在`
  String get errorTenantNotFound {
    return Intl.message(
      '租户不存在',
      name: 'errorTenantNotFound',
      desc: '',
      args: [],
    );
  }

  /// `上传失败`
  String get errorUploadFailed {
    return Intl.message('上传失败', name: 'errorUploadFailed', desc: '', args: []);
  }

  /// `保存`
  String get save {
    return Intl.message('保存', name: 'save', desc: '', args: []);
  }

  /// `视频`
  String get videosTab {
    return Intl.message('视频', name: 'videosTab', desc: '', args: []);
  }

  /// `剧集`
  String get seriesTab {
    return Intl.message('剧集', name: 'seriesTab', desc: '', args: []);
  }

  /// `暂无剧集`
  String get seriesEmpty {
    return Intl.message('暂无剧集', name: 'seriesEmpty', desc: '', args: []);
  }

  /// `还没有剧集，发布时挂靠即可创建`
  String get seriesEmptyMine {
    return Intl.message(
      '还没有剧集，发布时挂靠即可创建',
      name: 'seriesEmptyMine',
      desc: '',
      args: [],
    );
  }

  /// `剧集不存在或暂无可见剧集`
  String get seriesNotFound {
    return Intl.message(
      '剧集不存在或暂无可见剧集',
      name: 'seriesNotFound',
      desc: '',
      args: [],
    );
  }

  /// `更新至{published}集 · 共{total}集`
  String seriesUpdatedTo(int published, int total) {
    return Intl.message(
      '更新至$published集 · 共$total集',
      name: 'seriesUpdatedTo',
      desc: '',
      args: [published, total],
    );
  }

  /// `{count}集`
  String seriesEpisodeBadge(int count) {
    return Intl.message(
      '$count集',
      name: 'seriesEpisodeBadge',
      desc: '',
      args: [count],
    );
  }

  /// `第{n}集`
  String episodeN(int n) {
    return Intl.message('第$n集', name: 'episodeN', desc: '', args: [n]);
  }

  /// `播放中`
  String get playNow {
    return Intl.message('播放中', name: 'playNow', desc: '', args: []);
  }

  /// `自动连播下一集`
  String get autoNextTip {
    return Intl.message('自动连播下一集', name: 'autoNextTip', desc: '', args: []);
  }

  /// `编辑剧集`
  String get editSeries {
    return Intl.message('编辑剧集', name: 'editSeries', desc: '', args: []);
  }

  /// `剧名`
  String get seriesTitleLabel {
    return Intl.message('剧名', name: 'seriesTitleLabel', desc: '', args: []);
  }

  /// `剧简介`
  String get seriesDescLabel {
    return Intl.message('剧简介', name: 'seriesDescLabel', desc: '', args: []);
  }

  /// `删除剧集`
  String get deleteSeriesTitle {
    return Intl.message('删除剧集', name: 'deleteSeriesTitle', desc: '', args: []);
  }

  /// `删除后剧集解绑，剧内视频保留。确定删除吗？`
  String get deleteSeriesConfirm {
    return Intl.message(
      '删除后剧集解绑，剧内视频保留。确定删除吗？',
      name: 'deleteSeriesConfirm',
      desc: '',
      args: [],
    );
  }

  /// `剧集已删除`
  String get seriesDeleted {
    return Intl.message('剧集已删除', name: 'seriesDeleted', desc: '', args: []);
  }

  /// `剧集已保存`
  String get seriesSaved {
    return Intl.message('剧集已保存', name: 'seriesSaved', desc: '', args: []);
  }

  /// `剧集已创建`
  String get seriesCreated {
    return Intl.message('剧集已创建', name: 'seriesCreated', desc: '', args: []);
  }

  /// `挂靠剧集`
  String get attachSeries {
    return Intl.message('挂靠剧集', name: 'attachSeries', desc: '', args: []);
  }

  /// `选择剧集`
  String get chooseSeries {
    return Intl.message('选择剧集', name: 'chooseSeries', desc: '', args: []);
  }

  /// `更换`
  String get changeSeries {
    return Intl.message('更换', name: 'changeSeries', desc: '', args: []);
  }

  /// `不挂靠剧集，作为独立视频发布`
  String get attachSeriesNone {
    return Intl.message(
      '不挂靠剧集，作为独立视频发布',
      name: 'attachSeriesNone',
      desc: '',
      args: [],
    );
  }

  /// `发布后自动排入该剧集（当前{count}集）`
  String attachSeriesHint(int count) {
    return Intl.message(
      '发布后自动排入该剧集（当前$count集）',
      name: 'attachSeriesHint',
      desc: '',
      args: [count],
    );
  }

  /// `移除挂靠`
  String get attachSeriesRemove {
    return Intl.message('移除挂靠', name: 'attachSeriesRemove', desc: '', args: []);
  }

  /// `新建剧集`
  String get newSeries {
    return Intl.message('新建剧集', name: 'newSeries', desc: '', args: []);
  }

  /// `已挂剧集 · 第{n}集`
  String draftSeriesBadge(int n) {
    return Intl.message(
      '已挂剧集 · 第$n集',
      name: 'draftSeriesBadge',
      desc: '',
      args: [n],
    );
  }

  /// `已挂剧集（发布时自动排集号）`
  String get draftSeriesAttached {
    return Intl.message(
      '已挂剧集（发布时自动排集号）',
      name: 'draftSeriesAttached',
      desc: '',
      args: [],
    );
  }

  /// `历史`
  String get historyTab {
    return Intl.message('历史', name: 'historyTab', desc: '', args: []);
  }

  /// `还没有观看记录，去刷刷视频吧`
  String get historyEmpty {
    return Intl.message(
      '还没有观看记录，去刷刷视频吧',
      name: 'historyEmpty',
      desc: '',
      args: [],
    );
  }

  /// `热榜`
  String get hotList {
    return Intl.message('热榜', name: 'hotList', desc: '', args: []);
  }

  /// `热榜暂时还没有内容`
  String get hotListEmpty {
    return Intl.message('热榜暂时还没有内容', name: 'hotListEmpty', desc: '', args: []);
  }

  /// `最热`
  String get sortHot {
    return Intl.message('最热', name: 'sortHot', desc: '', args: []);
  }

  /// `最新`
  String get sortLatest {
    return Intl.message('最新', name: 'sortLatest', desc: '', args: []);
  }

  /// `创作数据`
  String get creatorStatsTitle {
    return Intl.message('创作数据', name: 'creatorStatsTitle', desc: '', args: []);
  }

  /// `数据按日聚合（播放/点赞来自行为埋点，发布按过审时间）`
  String get creatorStatsHint {
    return Intl.message(
      '数据按日聚合（播放/点赞来自行为埋点，发布按过审时间）',
      name: 'creatorStatsHint',
      desc: '',
      args: [],
    );
  }

  /// `播放`
  String get creatorPlays {
    return Intl.message('播放', name: 'creatorPlays', desc: '', args: []);
  }

  /// `点赞`
  String get creatorLikes {
    return Intl.message('点赞', name: 'creatorLikes', desc: '', args: []);
  }

  /// `发布`
  String get creatorPublished {
    return Intl.message('发布', name: 'creatorPublished', desc: '', args: []);
  }

  /// `内容包含违规词汇，请修改后再试`
  String get errorSensitiveWordHit {
    return Intl.message(
      '内容包含违规词汇，请修改后再试',
      name: 'errorSensitiveWordHit',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      Locale.fromSubtags(languageCode: 'en', countryCode: 'US'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
