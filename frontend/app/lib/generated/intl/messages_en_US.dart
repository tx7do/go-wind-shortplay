// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en_US locale. All the
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
  String get localeName => 'en_US';

  static String m0(count) => "Will be added to this series (${count} episodes)";

  static String m1(count) => "${count} comments";

  static String m2(n) => "In series · EP${n}";

  static String m3(n) => "EP${n}";

  static String m4(count) => "View ${count} replies";

  static String m5(count) => "${count} replies";

  static String m6(name) => "Reply to ${name}";

  static String m7(query) => "No videos found for \"${query}\"";

  static String m8(count) => "${count} EP";

  static String m9(published, total) =>
      "Updated to EP${published} · ${total} total";

  static String m10(count) => "${count} d ago";

  static String m11(count) => "${count} h ago";

  static String m12(count) => "${count} min ago";

  static String m13(percent) => "Uploading ${percent}%";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "addTags": MessageLookupByLibrary.simpleMessage("Add tags"),
    "advancedSettings": MessageLookupByLibrary.simpleMessage("Advanced"),
    "allLoaded": MessageLookupByLibrary.simpleMessage(
      "— You\'ve reached the end —",
    ),
    "appName": MessageLookupByLibrary.simpleMessage("Fengyin ShortPlay"),
    "appearance": MessageLookupByLibrary.simpleMessage("Appearance"),
    "asDraftOption": MessageLookupByLibrary.simpleMessage(
      "Save as draft (only visible to me)",
    ),
    "attachSeries": MessageLookupByLibrary.simpleMessage("Attach to Series"),
    "attachSeriesHint": m0,
    "attachSeriesNone": MessageLookupByLibrary.simpleMessage(
      "No series — publish as a standalone video",
    ),
    "attachSeriesRemove": MessageLookupByLibrary.simpleMessage("Remove"),
    "autoNextTip": MessageLookupByLibrary.simpleMessage("Playing next episode"),
    "avatarLabel": MessageLookupByLibrary.simpleMessage("Avatar"),
    "avatarTooLarge": MessageLookupByLibrary.simpleMessage(
      "Avatar image must be under 2MB",
    ),
    "backToHome": MessageLookupByLibrary.simpleMessage("Back to Home"),
    "bioHint": MessageLookupByLibrary.simpleMessage("Introduce yourself…"),
    "bioLabel": MessageLookupByLibrary.simpleMessage("Bio"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cannotFollowSelf": MessageLookupByLibrary.simpleMessage(
      "You cannot follow yourself",
    ),
    "changeSeries": MessageLookupByLibrary.simpleMessage("Change"),
    "chooseSeries": MessageLookupByLibrary.simpleMessage("Choose Series"),
    "chooseVideoToCreate": MessageLookupByLibrary.simpleMessage(
      "Select a video to start creating",
    ),
    "collects": MessageLookupByLibrary.simpleMessage("Collected"),
    "comment": MessageLookupByLibrary.simpleMessage("Comments"),
    "commentDeleted": MessageLookupByLibrary.simpleMessage("Comment deleted"),
    "commentIsEmpty": MessageLookupByLibrary.simpleMessage(
      "Comment cannot be empty",
    ),
    "commentSuccess": MessageLookupByLibrary.simpleMessage("Comment posted"),
    "commentsCount": m1,
    "confirm": MessageLookupByLibrary.simpleMessage("OK"),
    "confirmSend": MessageLookupByLibrary.simpleMessage("Send"),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
    "creatorCenter": MessageLookupByLibrary.simpleMessage("Creator center"),
    "creatorOverview": MessageLookupByLibrary.simpleMessage("Overview"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "darkMode": MessageLookupByLibrary.simpleMessage("Dark Mode"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteCommentConfirm": MessageLookupByLibrary.simpleMessage(
      "Delete this comment?",
    ),
    "deleteSeriesConfirm": MessageLookupByLibrary.simpleMessage(
      "Videos will be detached but kept. Delete this series?",
    ),
    "deleteSeriesTitle": MessageLookupByLibrary.simpleMessage("Delete Series"),
    "deleteVideo": MessageLookupByLibrary.simpleMessage("Delete video"),
    "deleteVideoConfirm": MessageLookupByLibrary.simpleMessage(
      "Delete this video? This cannot be undone",
    ),
    "descriptionHint": MessageLookupByLibrary.simpleMessage(
      "Tell viewers about your video…",
    ),
    "descriptionLabel": MessageLookupByLibrary.simpleMessage("Description"),
    "draftSaved": MessageLookupByLibrary.simpleMessage("Draft saved"),
    "draftSeriesAttached": MessageLookupByLibrary.simpleMessage(
      "In a series (episode auto-assigned on publish)",
    ),
    "draftSeriesBadge": m2,
    "drafts": MessageLookupByLibrary.simpleMessage("Drafts"),
    "editProfile": MessageLookupByLibrary.simpleMessage("Edit profile"),
    "editSeries": MessageLookupByLibrary.simpleMessage("Edit Series"),
    "episodeN": m3,
    "errorAccessTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "Access token not found",
    ),
    "errorBadGateway": MessageLookupByLibrary.simpleMessage("Bad gateway"),
    "errorBadRequest": MessageLookupByLibrary.simpleMessage("Bad request"),
    "errorConflict": MessageLookupByLibrary.simpleMessage(
      "Conflict, please refresh and retry",
    ),
    "errorDefault": MessageLookupByLibrary.simpleMessage(
      "Operation failed, please retry",
    ),
    "errorDeleteFailed": MessageLookupByLibrary.simpleMessage("Delete failed"),
    "errorDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "Download failed",
    ),
    "errorDuplicateReport": MessageLookupByLibrary.simpleMessage(
      "Duplicate report",
    ),
    "errorExpectationFailed": MessageLookupByLibrary.simpleMessage(
      "Expectation failed",
    ),
    "errorFailedDependency": MessageLookupByLibrary.simpleMessage(
      "Failed dependency",
    ),
    "errorFileNotFound": MessageLookupByLibrary.simpleMessage("File not found"),
    "errorFileTooLarge": MessageLookupByLibrary.simpleMessage("File too large"),
    "errorForbidden": MessageLookupByLibrary.simpleMessage("Permission denied"),
    "errorGatewayTimeout": MessageLookupByLibrary.simpleMessage(
      "Gateway timeout",
    ),
    "errorGone": MessageLookupByLibrary.simpleMessage("Resource deleted"),
    "errorHttpVersionNotSupported": MessageLookupByLibrary.simpleMessage(
      "HTTP version not supported",
    ),
    "errorImATeapot": MessageLookupByLibrary.simpleMessage(
      "Server refuses to process",
    ),
    "errorIncorrectAccessToken": MessageLookupByLibrary.simpleMessage(
      "Incorrect access token",
    ),
    "errorIncorrectAppSecret": MessageLookupByLibrary.simpleMessage(
      "Incorrect app secret",
    ),
    "errorIncorrectRefreshToken": MessageLookupByLibrary.simpleMessage(
      "Incorrect refresh token",
    ),
    "errorInsufficientStorage": MessageLookupByLibrary.simpleMessage(
      "Insufficient storage",
    ),
    "errorInternalServerError": MessageLookupByLibrary.simpleMessage(
      "Internal server error",
    ),
    "errorInvalidGrantType": MessageLookupByLibrary.simpleMessage(
      "Invalid grant type",
    ),
    "errorInvalidPassword": MessageLookupByLibrary.simpleMessage(
      "Incorrect username or password",
    ),
    "errorInvalidToken": MessageLookupByLibrary.simpleMessage("Invalid token"),
    "errorInvalidUserid": MessageLookupByLibrary.simpleMessage(
      "Invalid user ID",
    ),
    "errorLengthRequired": MessageLookupByLibrary.simpleMessage(
      "Content-Length required",
    ),
    "errorLocked": MessageLookupByLibrary.simpleMessage("Locked"),
    "errorLoopDetected": MessageLookupByLibrary.simpleMessage("Loop detected"),
    "errorMethodNotAllowed": MessageLookupByLibrary.simpleMessage(
      "Method not allowed",
    ),
    "errorMisdirectedRequest": MessageLookupByLibrary.simpleMessage(
      "Misdirected request",
    ),
    "errorNetworkAuthenticationRequired": MessageLookupByLibrary.simpleMessage(
      "Network authentication required",
    ),
    "errorNetworkConnectTimeoutError": MessageLookupByLibrary.simpleMessage(
      "Network connect timeout",
    ),
    "errorNetworkError": MessageLookupByLibrary.simpleMessage(
      "Network error, check your connection",
    ),
    "errorNetworkReadTimeoutError": MessageLookupByLibrary.simpleMessage(
      "Network read timeout",
    ),
    "errorNotAcceptable": MessageLookupByLibrary.simpleMessage(
      "Not acceptable",
    ),
    "errorNotExtended": MessageLookupByLibrary.simpleMessage("Not extended"),
    "errorNotFound": MessageLookupByLibrary.simpleMessage("Resource not found"),
    "errorNotImplemented": MessageLookupByLibrary.simpleMessage(
      "Not implemented",
    ),
    "errorNotOwner": MessageLookupByLibrary.simpleMessage(
      "You do not own this resource",
    ),
    "errorOccurred": MessageLookupByLibrary.simpleMessage(
      "Something went wrong!",
    ),
    "errorOrganizationNotFound": MessageLookupByLibrary.simpleMessage(
      "Organization not found",
    ),
    "errorPayloadTooLarge": MessageLookupByLibrary.simpleMessage(
      "Video too large, please compress it",
    ),
    "errorPaymentRequired": MessageLookupByLibrary.simpleMessage(
      "Payment required",
    ),
    "errorPositionNotFound": MessageLookupByLibrary.simpleMessage(
      "Position not found",
    ),
    "errorPreconditionFailed": MessageLookupByLibrary.simpleMessage(
      "Precondition failed",
    ),
    "errorPreconditionRequired": MessageLookupByLibrary.simpleMessage(
      "Precondition required",
    ),
    "errorProxyAuthenticationRequired": MessageLookupByLibrary.simpleMessage(
      "Proxy authentication required",
    ),
    "errorRangeNotSatisfiable": MessageLookupByLibrary.simpleMessage(
      "Range not satisfiable",
    ),
    "errorRefreshTokenNotFound": MessageLookupByLibrary.simpleMessage(
      "Refresh token not found",
    ),
    "errorRequestHeaderFieldsTooLarge": MessageLookupByLibrary.simpleMessage(
      "Request header fields too large",
    ),
    "errorRequestTimeout": MessageLookupByLibrary.simpleMessage(
      "Request timeout",
    ),
    "errorRoleNotFound": MessageLookupByLibrary.simpleMessage("Role not found"),
    "errorServiceUnavailable": MessageLookupByLibrary.simpleMessage(
      "Service unavailable",
    ),
    "errorTenantNotFound": MessageLookupByLibrary.simpleMessage(
      "Tenant not found",
    ),
    "errorTimeout": MessageLookupByLibrary.simpleMessage(
      "Request timed out, please retry",
    ),
    "errorTokenExpired": MessageLookupByLibrary.simpleMessage(
      "Session expired, please log in again",
    ),
    "errorTokenNotExist": MessageLookupByLibrary.simpleMessage(
      "Token not found",
    ),
    "errorTooEarly": MessageLookupByLibrary.simpleMessage("Too early"),
    "errorTooManyRequests": MessageLookupByLibrary.simpleMessage(
      "Too many requests, slow down",
    ),
    "errorUnauthorized": MessageLookupByLibrary.simpleMessage(
      "Not logged in or session expired",
    ),
    "errorUnavailableForLegalReasons": MessageLookupByLibrary.simpleMessage(
      "Unavailable for legal reasons",
    ),
    "errorUnprocessableEntity": MessageLookupByLibrary.simpleMessage(
      "Unprocessable entity",
    ),
    "errorUnsupportedMediaType": MessageLookupByLibrary.simpleMessage(
      "Unsupported video format",
    ),
    "errorUpgradeRequired": MessageLookupByLibrary.simpleMessage(
      "Upgrade required",
    ),
    "errorUploadFailed": MessageLookupByLibrary.simpleMessage("Upload failed"),
    "errorUriTooLong": MessageLookupByLibrary.simpleMessage("URI too long"),
    "errorUserFreeze": MessageLookupByLibrary.simpleMessage(
      "Account is frozen",
    ),
    "errorUserNotFound": MessageLookupByLibrary.simpleMessage("User not found"),
    "errorUsernameTaken": MessageLookupByLibrary.simpleMessage(
      "Username already taken",
    ),
    "errorVariantAlsoNegotiates": MessageLookupByLibrary.simpleMessage(
      "Variant also negotiates",
    ),
    "errorVideoNotFound": MessageLookupByLibrary.simpleMessage(
      "Video not found",
    ),
    "expandReplies": m4,
    "featureNotAvailable": MessageLookupByLibrary.simpleMessage(
      "This feature is coming soon",
    ),
    "follow": MessageLookupByLibrary.simpleMessage("Follow"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Follow System"),
    "followed": MessageLookupByLibrary.simpleMessage("Following"),
    "followers": MessageLookupByLibrary.simpleMessage("Followers"),
    "followingCountLabel": MessageLookupByLibrary.simpleMessage("Following"),
    "goLogin": MessageLookupByLibrary.simpleMessage("Log in"),
    "guestInteractionDesc": MessageLookupByLibrary.simpleMessage(
      "Log in to like, comment, collect and follow",
    ),
    "guestInteractionTitle": MessageLookupByLibrary.simpleMessage(
      "Log in to interact",
    ),
    "home": MessageLookupByLibrary.simpleMessage("Home"),
    "hotTags": MessageLookupByLibrary.simpleMessage("Hot tags"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "likeReceived": MessageLookupByLibrary.simpleMessage("Likes"),
    "loadFailed": MessageLookupByLibrary.simpleMessage("Failed to load"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading…"),
    "loadingMore": MessageLookupByLibrary.simpleMessage("Loading more…"),
    "login": MessageLookupByLibrary.simpleMessage("Log in"),
    "loginButton": MessageLookupByLibrary.simpleMessage("Log in"),
    "loginFailed": MessageLookupByLibrary.simpleMessage(
      "Login failed, check your username and password",
    ),
    "loginForMore": MessageLookupByLibrary.simpleMessage(
      "Log in to like, comment and publish",
    ),
    "loginSuccess": MessageLookupByLibrary.simpleMessage("Logged in"),
    "loginToViewMessages": MessageLookupByLibrary.simpleMessage(
      "Log in to view notifications",
    ),
    "loginToViewProfile": MessageLookupByLibrary.simpleMessage(
      "Log in to view your profile",
    ),
    "logout": MessageLookupByLibrary.simpleMessage("Log out"),
    "logoutConfirm": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to log out?",
    ),
    "markAllRead": MessageLookupByLibrary.simpleMessage("Mark all read"),
    "me": MessageLookupByLibrary.simpleMessage("Me"),
    "mergingVideo": MessageLookupByLibrary.simpleMessage("Processing video…"),
    "message": MessageLookupByLibrary.simpleMessage("Inbox"),
    "newSeries": MessageLookupByLibrary.simpleMessage("New Series"),
    "nicknameHint": MessageLookupByLibrary.simpleMessage("Enter a nickname"),
    "nicknameLabel": MessageLookupByLibrary.simpleMessage("Nickname"),
    "noCollectedVideos": MessageLookupByLibrary.simpleMessage(
      "No collected videos yet",
    ),
    "noCommentsYet": MessageLookupByLibrary.simpleMessage(
      "No comments yet. Be the first!",
    ),
    "noNewMessages": MessageLookupByLibrary.simpleMessage("No new messages"),
    "noTagFound": MessageLookupByLibrary.simpleMessage(
      "No matching tag, press enter to use it",
    ),
    "noWorksYet": MessageLookupByLibrary.simpleMessage(
      "No works yet. Publish your first video!",
    ),
    "notifyTypeComment": MessageLookupByLibrary.simpleMessage("Comment"),
    "notifyTypeFollow": MessageLookupByLibrary.simpleMessage("Follow"),
    "notifyTypeLike": MessageLookupByLibrary.simpleMessage("Like"),
    "notifyTypeSystem": MessageLookupByLibrary.simpleMessage("System"),
    "onlyOwnerCanDelete": MessageLookupByLibrary.simpleMessage(
      "You can only delete your own comments",
    ),
    "pageNotFound": MessageLookupByLibrary.simpleMessage("Page not found"),
    "pageNotFoundDesc": MessageLookupByLibrary.simpleMessage(
      "Sorry, the page you visited does not exist or has been moved.",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "passwordHint": MessageLookupByLibrary.simpleMessage("Enter password"),
    "pickVideo": MessageLookupByLibrary.simpleMessage("Choose from gallery"),
    "pickVideoFirst": MessageLookupByLibrary.simpleMessage(
      "Pick a video first",
    ),
    "playNow": MessageLookupByLibrary.simpleMessage("Now Playing"),
    "profileSaved": MessageLookupByLibrary.simpleMessage("Profile updated"),
    "publish": MessageLookupByLibrary.simpleMessage("Create"),
    "publishFailed": MessageLookupByLibrary.simpleMessage(
      "Publish failed, please retry",
    ),
    "publishGuideSubtitle": MessageLookupByLibrary.simpleMessage(
      "Short videos up to 5 minutes",
    ),
    "publishSuccess": MessageLookupByLibrary.simpleMessage(
      "Published, pending review",
    ),
    "readAllSuccess": MessageLookupByLibrary.simpleMessage(
      "All marked as read",
    ),
    "reasonFollow": MessageLookupByLibrary.simpleMessage("Following"),
    "reasonHot": MessageLookupByLibrary.simpleMessage("Hot"),
    "reasonLatest": MessageLookupByLibrary.simpleMessage("Latest"),
    "recordVideo": MessageLookupByLibrary.simpleMessage("Record video"),
    "register": MessageLookupByLibrary.simpleMessage("Sign up"),
    "registerFailed": MessageLookupByLibrary.simpleMessage(
      "Sign up failed, please retry",
    ),
    "registerSuccess": MessageLookupByLibrary.simpleMessage("Account created"),
    "registerTitle": MessageLookupByLibrary.simpleMessage("Create account"),
    "rejectReasonLabel": MessageLookupByLibrary.simpleMessage("Reject reason"),
    "removeVideo": MessageLookupByLibrary.simpleMessage("Remove video"),
    "repliesCount": m5,
    "reply": MessageLookupByLibrary.simpleMessage("Reply"),
    "replyTo": m6,
    "report": MessageLookupByLibrary.simpleMessage("Report"),
    "reportDescriptionHint": MessageLookupByLibrary.simpleMessage(
      "More details (optional)",
    ),
    "reportDuplicate": MessageLookupByLibrary.simpleMessage(
      "This content has already been reported",
    ),
    "reportReasonAbuse": MessageLookupByLibrary.simpleMessage("Abusive"),
    "reportReasonCopyright": MessageLookupByLibrary.simpleMessage(
      "Copyright infringement",
    ),
    "reportReasonFraud": MessageLookupByLibrary.simpleMessage("Fraud"),
    "reportReasonOther": MessageLookupByLibrary.simpleMessage("Other"),
    "reportReasonPorn": MessageLookupByLibrary.simpleMessage("Pornographic"),
    "reportReasonTitle": MessageLookupByLibrary.simpleMessage(
      "Select a reason",
    ),
    "reportReasonViolence": MessageLookupByLibrary.simpleMessage("Violence"),
    "reportSubmit": MessageLookupByLibrary.simpleMessage("Submit report"),
    "reportSubmitted": MessageLookupByLibrary.simpleMessage(
      "Report submitted, thank you",
    ),
    "reselectVideo": MessageLookupByLibrary.simpleMessage("Reselect"),
    "retry": MessageLookupByLibrary.simpleMessage("Retry"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveDraft": MessageLookupByLibrary.simpleMessage("Save draft"),
    "saveProfile": MessageLookupByLibrary.simpleMessage("Save"),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "searchEmpty": m7,
    "searchHint": MessageLookupByLibrary.simpleMessage("Search videos, tags"),
    "searchSomeKeyword": MessageLookupByLibrary.simpleMessage(
      "Search something to explore",
    ),
    "seriesCreated": MessageLookupByLibrary.simpleMessage("Series created"),
    "seriesDeleted": MessageLookupByLibrary.simpleMessage("Series deleted"),
    "seriesDescLabel": MessageLookupByLibrary.simpleMessage("Description"),
    "seriesEmpty": MessageLookupByLibrary.simpleMessage("No series yet"),
    "seriesEmptyMine": MessageLookupByLibrary.simpleMessage(
      "No series yet. Attach one when publishing to create it",
    ),
    "seriesEpisodeBadge": m8,
    "seriesNotFound": MessageLookupByLibrary.simpleMessage(
      "Series not found or not visible",
    ),
    "seriesSaved": MessageLookupByLibrary.simpleMessage("Series saved"),
    "seriesTab": MessageLookupByLibrary.simpleMessage("Series"),
    "seriesTitleLabel": MessageLookupByLibrary.simpleMessage("Series Title"),
    "seriesUpdatedTo": m9,
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "share": MessageLookupByLibrary.simpleMessage("Share"),
    "shareCopied": MessageLookupByLibrary.simpleMessage(
      "Link copied, go share it",
    ),
    "statusDraft": MessageLookupByLibrary.simpleMessage("Draft"),
    "statusOffline": MessageLookupByLibrary.simpleMessage("Offline"),
    "statusRejected": MessageLookupByLibrary.simpleMessage("Rejected"),
    "statusReviewing": MessageLookupByLibrary.simpleMessage("In review"),
    "submitPublish": MessageLookupByLibrary.simpleMessage("Publish"),
    "tagInlineHint": MessageLookupByLibrary.simpleMessage(
      "Type a tag, press enter or comma",
    ),
    "tagInputHint": MessageLookupByLibrary.simpleMessage(
      "Search or create tags",
    ),
    "tagPickerTitle": MessageLookupByLibrary.simpleMessage("Pick tags"),
    "timeDaysAgo": m10,
    "timeHoursAgo": m11,
    "timeJustNow": MessageLookupByLibrary.simpleMessage("just now"),
    "timeMinutesAgo": m12,
    "titleHint": MessageLookupByLibrary.simpleMessage(
      "Give your video a catchy title",
    ),
    "titleLabel": MessageLookupByLibrary.simpleMessage("Title"),
    "titleRequired": MessageLookupByLibrary.simpleMessage("Title is required"),
    "toLogin": MessageLookupByLibrary.simpleMessage(
      "Already have an account? Log in",
    ),
    "toRegister": MessageLookupByLibrary.simpleMessage("No account? Sign up"),
    "totalCollects": MessageLookupByLibrary.simpleMessage("Total collects"),
    "totalComments": MessageLookupByLibrary.simpleMessage("Total comments"),
    "totalLikes": MessageLookupByLibrary.simpleMessage("Total likes"),
    "totalViews": MessageLookupByLibrary.simpleMessage("Total views"),
    "unfollow": MessageLookupByLibrary.simpleMessage("Unfollow"),
    "unfollowConfirm": MessageLookupByLibrary.simpleMessage(
      "Stop following this user?",
    ),
    "unreadOnly": MessageLookupByLibrary.simpleMessage("Unread only"),
    "uploading": MessageLookupByLibrary.simpleMessage("Uploading"),
    "uploadingPercent": m13,
    "username": MessageLookupByLibrary.simpleMessage("Username"),
    "usernameHint": MessageLookupByLibrary.simpleMessage("Enter username"),
    "versionLabel": MessageLookupByLibrary.simpleMessage("Version"),
    "videoCountLabel": MessageLookupByLibrary.simpleMessage("Videos"),
    "videoDeleted": MessageLookupByLibrary.simpleMessage("Video deleted"),
    "videoDeletedSuccess": MessageLookupByLibrary.simpleMessage(
      "Video deleted",
    ),
    "videoNotFound": MessageLookupByLibrary.simpleMessage(
      "Video not found or offline",
    ),
    "videoPreview": MessageLookupByLibrary.simpleMessage("Preview"),
    "videosTab": MessageLookupByLibrary.simpleMessage("Videos"),
    "welcomeBack": MessageLookupByLibrary.simpleMessage("Welcome back"),
    "works": MessageLookupByLibrary.simpleMessage("Works"),
    "writeComment": MessageLookupByLibrary.simpleMessage("Add a comment…"),
  };
}
