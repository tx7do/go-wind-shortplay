// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_CN locale. All the
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
  String get localeName => 'zh_CN';

  static String m0(count) => "${count} 条评论";

  static String m1(count) => "展开 ${count} 条回复";

  static String m2(count) => "${count} 条回复";

  static String m3(name) => "回复 ${name}";

  static String m4(query) => "没有找到「${query}」相关视频";

  static String m5(count) => "${count} 天前";

  static String m6(count) => "${count} 小时前";

  static String m7(count) => "${count} 分钟前";

  static String m8(percent) => "上传中 ${percent}%";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "addTags": MessageLookupByLibrary.simpleMessage("添加标签"),
    "allLoaded": MessageLookupByLibrary.simpleMessage("— 已经到底啦 —"),
    "appName": MessageLookupByLibrary.simpleMessage("GoWind 短视频社区"),
    "asDraftOption": MessageLookupByLibrary.simpleMessage("存为草稿（仅自己可见）"),
    "avatarLabel": MessageLookupByLibrary.simpleMessage("头像"),
    "avatarTooLarge": MessageLookupByLibrary.simpleMessage("头像图片不能超过 2MB"),
    "backToHome": MessageLookupByLibrary.simpleMessage("返回首页"),
    "bioHint": MessageLookupByLibrary.simpleMessage("介绍一下自己…"),
    "bioLabel": MessageLookupByLibrary.simpleMessage("简介"),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "cannotFollowSelf": MessageLookupByLibrary.simpleMessage("不能关注自己"),
    "collects": MessageLookupByLibrary.simpleMessage("收藏"),
    "comment": MessageLookupByLibrary.simpleMessage("评论"),
    "commentDeleted": MessageLookupByLibrary.simpleMessage("评论已删除"),
    "commentIsEmpty": MessageLookupByLibrary.simpleMessage("评论内容不能为空"),
    "commentSuccess": MessageLookupByLibrary.simpleMessage("评论成功"),
    "commentsCount": m0,
    "confirm": MessageLookupByLibrary.simpleMessage("确定"),
    "confirmSend": MessageLookupByLibrary.simpleMessage("发送"),
    "copyLink": MessageLookupByLibrary.simpleMessage("复制链接"),
    "creatorCenter": MessageLookupByLibrary.simpleMessage("创作者中心"),
    "creatorOverview": MessageLookupByLibrary.simpleMessage("数据总览"),
    "delete": MessageLookupByLibrary.simpleMessage("删除"),
    "deleteCommentConfirm": MessageLookupByLibrary.simpleMessage("确定删除这条评论吗？"),
    "deleteVideo": MessageLookupByLibrary.simpleMessage("删除视频"),
    "deleteVideoConfirm": MessageLookupByLibrary.simpleMessage(
      "确定删除该视频吗？删除后不可恢复",
    ),
    "descriptionHint": MessageLookupByLibrary.simpleMessage("介绍一下你的视频…"),
    "descriptionLabel": MessageLookupByLibrary.simpleMessage("简介"),
    "draftSaved": MessageLookupByLibrary.simpleMessage("草稿已保存"),
    "drafts": MessageLookupByLibrary.simpleMessage("草稿箱"),
    "editProfile": MessageLookupByLibrary.simpleMessage("编辑资料"),
    "errorAccessTokenNotFound": MessageLookupByLibrary.simpleMessage("访问令牌不存在"),
    "errorBadGateway": MessageLookupByLibrary.simpleMessage("网关错误"),
    "errorBadRequest": MessageLookupByLibrary.simpleMessage("请求参数错误"),
    "errorConflict": MessageLookupByLibrary.simpleMessage("数据冲突，请刷新后重试"),
    "errorDefault": MessageLookupByLibrary.simpleMessage("操作失败，请稍后重试"),
    "errorDeleteFailed": MessageLookupByLibrary.simpleMessage("删除失败"),
    "errorDownloadFailed": MessageLookupByLibrary.simpleMessage("下载失败"),
    "errorDuplicateReport": MessageLookupByLibrary.simpleMessage("请勿重复举报"),
    "errorExpectationFailed": MessageLookupByLibrary.simpleMessage("请求期望无法满足"),
    "errorFailedDependency": MessageLookupByLibrary.simpleMessage("依赖操作失败"),
    "errorFileNotFound": MessageLookupByLibrary.simpleMessage("文件不存在"),
    "errorFileTooLarge": MessageLookupByLibrary.simpleMessage("文件过大"),
    "errorForbidden": MessageLookupByLibrary.simpleMessage("没有权限执行此操作"),
    "errorGatewayTimeout": MessageLookupByLibrary.simpleMessage("网关超时"),
    "errorGone": MessageLookupByLibrary.simpleMessage("资源已删除"),
    "errorHttpVersionNotSupported": MessageLookupByLibrary.simpleMessage(
      "不支持的 HTTP 版本",
    ),
    "errorImATeapot": MessageLookupByLibrary.simpleMessage("服务器拒绝处理请求"),
    "errorIncorrectAccessToken": MessageLookupByLibrary.simpleMessage("访问令牌错误"),
    "errorIncorrectAppSecret": MessageLookupByLibrary.simpleMessage("应用密钥错误"),
    "errorIncorrectRefreshToken": MessageLookupByLibrary.simpleMessage(
      "刷新令牌错误",
    ),
    "errorInsufficientStorage": MessageLookupByLibrary.simpleMessage("存储空间不足"),
    "errorInternalServerError": MessageLookupByLibrary.simpleMessage("服务器内部错误"),
    "errorInvalidGrantType": MessageLookupByLibrary.simpleMessage("授权类型无效"),
    "errorInvalidPassword": MessageLookupByLibrary.simpleMessage("用户名或密码错误"),
    "errorInvalidToken": MessageLookupByLibrary.simpleMessage("令牌无效"),
    "errorInvalidUserid": MessageLookupByLibrary.simpleMessage("用户 ID 无效"),
    "errorLengthRequired": MessageLookupByLibrary.simpleMessage(
      "缺少 Content-Length",
    ),
    "errorLocked": MessageLookupByLibrary.simpleMessage("资源已锁定"),
    "errorLoopDetected": MessageLookupByLibrary.simpleMessage("检测到循环请求"),
    "errorMethodNotAllowed": MessageLookupByLibrary.simpleMessage("请求方法不允许"),
    "errorMisdirectedRequest": MessageLookupByLibrary.simpleMessage("请求被错误转发"),
    "errorNetworkAuthenticationRequired": MessageLookupByLibrary.simpleMessage(
      "需要网络认证",
    ),
    "errorNetworkConnectTimeoutError": MessageLookupByLibrary.simpleMessage(
      "网络连接超时",
    ),
    "errorNetworkError": MessageLookupByLibrary.simpleMessage("网络异常，请检查网络连接"),
    "errorNetworkReadTimeoutError": MessageLookupByLibrary.simpleMessage(
      "网络读取超时",
    ),
    "errorNotAcceptable": MessageLookupByLibrary.simpleMessage("不可接受的请求"),
    "errorNotExtended": MessageLookupByLibrary.simpleMessage("需要扩展"),
    "errorNotFound": MessageLookupByLibrary.simpleMessage("资源不存在"),
    "errorNotImplemented": MessageLookupByLibrary.simpleMessage("功能暂未实现"),
    "errorNotOwner": MessageLookupByLibrary.simpleMessage("没有权限操作该资源"),
    "errorOccurred": MessageLookupByLibrary.simpleMessage("发生错误！"),
    "errorOrganizationNotFound": MessageLookupByLibrary.simpleMessage("组织不存在"),
    "errorPayloadTooLarge": MessageLookupByLibrary.simpleMessage("视频过大，请压缩后重试"),
    "errorPaymentRequired": MessageLookupByLibrary.simpleMessage("需要支付"),
    "errorPositionNotFound": MessageLookupByLibrary.simpleMessage("职位不存在"),
    "errorPreconditionFailed": MessageLookupByLibrary.simpleMessage("前置条件不满足"),
    "errorPreconditionRequired": MessageLookupByLibrary.simpleMessage("需要前置条件"),
    "errorProxyAuthenticationRequired": MessageLookupByLibrary.simpleMessage(
      "需要代理身份验证",
    ),
    "errorRangeNotSatisfiable": MessageLookupByLibrary.simpleMessage(
      "请求范围无法满足",
    ),
    "errorRefreshTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "刷新令牌不存在",
    ),
    "errorRequestHeaderFieldsTooLarge": MessageLookupByLibrary.simpleMessage(
      "请求头字段过大",
    ),
    "errorRequestTimeout": MessageLookupByLibrary.simpleMessage("请求超时"),
    "errorRoleNotFound": MessageLookupByLibrary.simpleMessage("角色不存在"),
    "errorServiceUnavailable": MessageLookupByLibrary.simpleMessage("服务暂时不可用"),
    "errorTenantNotFound": MessageLookupByLibrary.simpleMessage("租户不存在"),
    "errorTimeout": MessageLookupByLibrary.simpleMessage("请求超时，请稍后重试"),
    "errorTokenExpired": MessageLookupByLibrary.simpleMessage("登录已过期，请重新登录"),
    "errorTokenNotExist": MessageLookupByLibrary.simpleMessage("令牌不存在"),
    "errorTooEarly": MessageLookupByLibrary.simpleMessage("请求过早"),
    "errorTooManyRequests": MessageLookupByLibrary.simpleMessage(
      "请求过于频繁，请稍后重试",
    ),
    "errorUnauthorized": MessageLookupByLibrary.simpleMessage("未登录或登录已过期"),
    "errorUnavailableForLegalReasons": MessageLookupByLibrary.simpleMessage(
      "因法律原因不可用",
    ),
    "errorUnprocessableEntity": MessageLookupByLibrary.simpleMessage(
      "无法处理请求数据",
    ),
    "errorUnsupportedMediaType": MessageLookupByLibrary.simpleMessage(
      "不支持的视频格式",
    ),
    "errorUpgradeRequired": MessageLookupByLibrary.simpleMessage("需要升级后使用"),
    "errorUploadFailed": MessageLookupByLibrary.simpleMessage("上传失败"),
    "errorUriTooLong": MessageLookupByLibrary.simpleMessage("请求地址过长"),
    "errorUserFreeze": MessageLookupByLibrary.simpleMessage("账号已被冻结"),
    "errorUserNotFound": MessageLookupByLibrary.simpleMessage("用户不存在"),
    "errorUsernameTaken": MessageLookupByLibrary.simpleMessage("用户名已被占用"),
    "errorVariantAlsoNegotiates": MessageLookupByLibrary.simpleMessage(
      "变体协商错误",
    ),
    "errorVideoNotFound": MessageLookupByLibrary.simpleMessage("视频不存在"),
    "expandReplies": m1,
    "featureNotAvailable": MessageLookupByLibrary.simpleMessage("该功能即将上线，敬请期待"),
    "follow": MessageLookupByLibrary.simpleMessage("关注"),
    "followed": MessageLookupByLibrary.simpleMessage("已关注"),
    "followers": MessageLookupByLibrary.simpleMessage("粉丝"),
    "followingCountLabel": MessageLookupByLibrary.simpleMessage("关注"),
    "goLogin": MessageLookupByLibrary.simpleMessage("去登录"),
    "guestInteractionDesc": MessageLookupByLibrary.simpleMessage(
      "登录后即可点赞、评论、收藏和关注",
    ),
    "guestInteractionTitle": MessageLookupByLibrary.simpleMessage("登录后才能互动"),
    "home": MessageLookupByLibrary.simpleMessage("首页"),
    "hotTags": MessageLookupByLibrary.simpleMessage("热门标签"),
    "likeReceived": MessageLookupByLibrary.simpleMessage("获赞"),
    "loadFailed": MessageLookupByLibrary.simpleMessage("加载失败"),
    "loading": MessageLookupByLibrary.simpleMessage("加载中…"),
    "loadingMore": MessageLookupByLibrary.simpleMessage("加载更多…"),
    "login": MessageLookupByLibrary.simpleMessage("登录"),
    "loginButton": MessageLookupByLibrary.simpleMessage("登录"),
    "loginFailed": MessageLookupByLibrary.simpleMessage("登录失败，请检查用户名和密码"),
    "loginForMore": MessageLookupByLibrary.simpleMessage("登录后点赞、评论、发布你的短视频"),
    "loginSuccess": MessageLookupByLibrary.simpleMessage("登录成功"),
    "loginToViewMessages": MessageLookupByLibrary.simpleMessage("登录后查看消息通知"),
    "loginToViewProfile": MessageLookupByLibrary.simpleMessage("登录后查看我的主页"),
    "logout": MessageLookupByLibrary.simpleMessage("退出登录"),
    "logoutConfirm": MessageLookupByLibrary.simpleMessage("确定要退出登录吗？"),
    "markAllRead": MessageLookupByLibrary.simpleMessage("全部已读"),
    "me": MessageLookupByLibrary.simpleMessage("我的"),
    "mergingVideo": MessageLookupByLibrary.simpleMessage("视频合并处理中…"),
    "message": MessageLookupByLibrary.simpleMessage("消息"),
    "nicknameHint": MessageLookupByLibrary.simpleMessage("给自己起个昵称"),
    "nicknameLabel": MessageLookupByLibrary.simpleMessage("昵称"),
    "noCollectedVideos": MessageLookupByLibrary.simpleMessage("还没有收藏的视频"),
    "noCommentsYet": MessageLookupByLibrary.simpleMessage("暂无评论，快来抢沙发"),
    "noNewMessages": MessageLookupByLibrary.simpleMessage("暂无新消息"),
    "noTagFound": MessageLookupByLibrary.simpleMessage("没有匹配标签，回车直接使用"),
    "noWorksYet": MessageLookupByLibrary.simpleMessage("还没有作品，去发布第一个视频吧"),
    "notifyTypeComment": MessageLookupByLibrary.simpleMessage("评论"),
    "notifyTypeFollow": MessageLookupByLibrary.simpleMessage("关注"),
    "notifyTypeLike": MessageLookupByLibrary.simpleMessage("赞"),
    "notifyTypeSystem": MessageLookupByLibrary.simpleMessage("系统"),
    "onlyOwnerCanDelete": MessageLookupByLibrary.simpleMessage("只能删除自己的评论"),
    "pageNotFound": MessageLookupByLibrary.simpleMessage("页面未找到"),
    "pageNotFoundDesc": MessageLookupByLibrary.simpleMessage(
      "抱歉，您访问的页面不存在或已被移动。",
    ),
    "password": MessageLookupByLibrary.simpleMessage("密码"),
    "passwordHint": MessageLookupByLibrary.simpleMessage("请输入密码"),
    "pickVideo": MessageLookupByLibrary.simpleMessage("从相册选择"),
    "pickVideoFirst": MessageLookupByLibrary.simpleMessage("请先选择要发布的视频"),
    "profileSaved": MessageLookupByLibrary.simpleMessage("资料已更新"),
    "publish": MessageLookupByLibrary.simpleMessage("发布"),
    "publishFailed": MessageLookupByLibrary.simpleMessage("发布失败，请稍后重试"),
    "publishSuccess": MessageLookupByLibrary.simpleMessage("发布成功，等待审核"),
    "readAllSuccess": MessageLookupByLibrary.simpleMessage("已全部标记为已读"),
    "reasonFollow": MessageLookupByLibrary.simpleMessage("关注"),
    "reasonHot": MessageLookupByLibrary.simpleMessage("热"),
    "reasonLatest": MessageLookupByLibrary.simpleMessage("最新"),
    "recordVideo": MessageLookupByLibrary.simpleMessage("拍摄视频"),
    "register": MessageLookupByLibrary.simpleMessage("注册"),
    "registerFailed": MessageLookupByLibrary.simpleMessage("注册失败，请稍后重试"),
    "registerSuccess": MessageLookupByLibrary.simpleMessage("注册成功"),
    "registerTitle": MessageLookupByLibrary.simpleMessage("注册新账号"),
    "rejectReasonLabel": MessageLookupByLibrary.simpleMessage("驳回原因"),
    "repliesCount": m2,
    "reply": MessageLookupByLibrary.simpleMessage("回复"),
    "replyTo": m3,
    "report": MessageLookupByLibrary.simpleMessage("举报"),
    "reportDescriptionHint": MessageLookupByLibrary.simpleMessage("补充说明（选填）"),
    "reportDuplicate": MessageLookupByLibrary.simpleMessage("该内容已被举报过，请耐心等待处理"),
    "reportReasonAbuse": MessageLookupByLibrary.simpleMessage("辱骂攻击"),
    "reportReasonCopyright": MessageLookupByLibrary.simpleMessage("侵权"),
    "reportReasonFraud": MessageLookupByLibrary.simpleMessage("诈骗信息"),
    "reportReasonOther": MessageLookupByLibrary.simpleMessage("其他问题"),
    "reportReasonPorn": MessageLookupByLibrary.simpleMessage("色情低俗"),
    "reportReasonTitle": MessageLookupByLibrary.simpleMessage("选择举报原因"),
    "reportReasonViolence": MessageLookupByLibrary.simpleMessage("暴力血腥"),
    "reportSubmit": MessageLookupByLibrary.simpleMessage("提交举报"),
    "reportSubmitted": MessageLookupByLibrary.simpleMessage("举报已提交，感谢你的反馈"),
    "reselectVideo": MessageLookupByLibrary.simpleMessage("重新选择"),
    "retry": MessageLookupByLibrary.simpleMessage("重试"),
    "saveDraft": MessageLookupByLibrary.simpleMessage("存草稿"),
    "saveProfile": MessageLookupByLibrary.simpleMessage("保存"),
    "search": MessageLookupByLibrary.simpleMessage("搜索"),
    "searchEmpty": m4,
    "searchHint": MessageLookupByLibrary.simpleMessage("搜索视频、标签"),
    "searchSomeKeyword": MessageLookupByLibrary.simpleMessage("搜点什么看看吧"),
    "share": MessageLookupByLibrary.simpleMessage("分享"),
    "shareCopied": MessageLookupByLibrary.simpleMessage("链接已复制，快去分享吧"),
    "statusDraft": MessageLookupByLibrary.simpleMessage("草稿"),
    "statusOffline": MessageLookupByLibrary.simpleMessage("已下架"),
    "statusRejected": MessageLookupByLibrary.simpleMessage("未通过"),
    "statusReviewing": MessageLookupByLibrary.simpleMessage("审核中"),
    "submitPublish": MessageLookupByLibrary.simpleMessage("发布"),
    "tagInputHint": MessageLookupByLibrary.simpleMessage("搜索或创建标签"),
    "tagPickerTitle": MessageLookupByLibrary.simpleMessage("选择标签"),
    "timeDaysAgo": m5,
    "timeHoursAgo": m6,
    "timeJustNow": MessageLookupByLibrary.simpleMessage("刚刚"),
    "timeMinutesAgo": m7,
    "titleHint": MessageLookupByLibrary.simpleMessage("给视频起个吸引人的标题"),
    "titleLabel": MessageLookupByLibrary.simpleMessage("标题"),
    "titleRequired": MessageLookupByLibrary.simpleMessage("请填写视频标题"),
    "toLogin": MessageLookupByLibrary.simpleMessage("已有账号？去登录"),
    "toRegister": MessageLookupByLibrary.simpleMessage("没有账号？去注册"),
    "totalCollects": MessageLookupByLibrary.simpleMessage("总收藏"),
    "totalComments": MessageLookupByLibrary.simpleMessage("总评论"),
    "totalLikes": MessageLookupByLibrary.simpleMessage("总点赞"),
    "totalViews": MessageLookupByLibrary.simpleMessage("总播放"),
    "unfollow": MessageLookupByLibrary.simpleMessage("取消关注"),
    "unfollowConfirm": MessageLookupByLibrary.simpleMessage("确定不再关注该用户吗？"),
    "unreadOnly": MessageLookupByLibrary.simpleMessage("只看未读"),
    "uploading": MessageLookupByLibrary.simpleMessage("上传中"),
    "uploadingPercent": m8,
    "username": MessageLookupByLibrary.simpleMessage("用户名"),
    "usernameHint": MessageLookupByLibrary.simpleMessage("请输入用户名"),
    "videoCountLabel": MessageLookupByLibrary.simpleMessage("作品数"),
    "videoDeleted": MessageLookupByLibrary.simpleMessage("视频已删除"),
    "videoDeletedSuccess": MessageLookupByLibrary.simpleMessage("视频已删除"),
    "videoNotFound": MessageLookupByLibrary.simpleMessage("视频不存在或已下架"),
    "videoPreview": MessageLookupByLibrary.simpleMessage("视频预览"),
    "welcomeBack": MessageLookupByLibrary.simpleMessage("欢迎回来"),
    "works": MessageLookupByLibrary.simpleMessage("作品"),
    "writeComment": MessageLookupByLibrary.simpleMessage("写下你的评论…"),
  };
}
