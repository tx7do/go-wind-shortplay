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

  static String m0(count) => "${count} comments";

  static String m1(count) => "View ${count} replies";

  static String m2(count) => "${count} replies";

  static String m3(name) => "Reply to ${name}";

  static String m4(query) => "No videos found for \"${query}\"";

  static String m5(count) => "${count} d ago";

  static String m6(count) => "${count} h ago";

  static String m7(count) => "${count} min ago";

  static String m8(percent) => "Uploading ${percent}%";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "addTags": MessageLookupByLibrary.simpleMessage("Add tags"),
    "allLoaded": MessageLookupByLibrary.simpleMessage(
      "— You\'ve reached the end —",
    ),
    "appName": MessageLookupByLibrary.simpleMessage("GoWind ShortPlay"),
    "asDraftOption": MessageLookupByLibrary.simpleMessage(
      "Save as draft (only visible to me)",
    ),
    "avatarLabel": MessageLookupByLibrary.simpleMessage("Avatar"),
    "backToHome": MessageLookupByLibrary.simpleMessage("Back to Home"),
    "bioHint": MessageLookupByLibrary.simpleMessage("Introduce yourself…"),
    "bioLabel": MessageLookupByLibrary.simpleMessage("Bio"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cannotFollowSelf": MessageLookupByLibrary.simpleMessage(
      "You cannot follow yourself",
    ),
    "collects": MessageLookupByLibrary.simpleMessage("Collected"),
    "comment": MessageLookupByLibrary.simpleMessage("Comments"),
    "commentDeleted": MessageLookupByLibrary.simpleMessage("Comment deleted"),
    "commentIsEmpty": MessageLookupByLibrary.simpleMessage(
      "Comment cannot be empty",
    ),
    "commentSuccess": MessageLookupByLibrary.simpleMessage("Comment posted"),
    "commentsCount": m0,
    "confirm": MessageLookupByLibrary.simpleMessage("OK"),
    "confirmSend": MessageLookupByLibrary.simpleMessage("Send"),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
    "creatorCenter": MessageLookupByLibrary.simpleMessage("Creator center"),
    "creatorOverview": MessageLookupByLibrary.simpleMessage("Overview"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteCommentConfirm": MessageLookupByLibrary.simpleMessage(
      "Delete this comment?",
    ),
    "deleteVideo": MessageLookupByLibrary.simpleMessage("Delete video"),
    "deleteVideoConfirm": MessageLookupByLibrary.simpleMessage(
      "Delete this video? This cannot be undone",
    ),
    "descriptionHint": MessageLookupByLibrary.simpleMessage(
      "Tell viewers about your video…",
    ),
    "descriptionLabel": MessageLookupByLibrary.simpleMessage("Description"),
    "draftSaved": MessageLookupByLibrary.simpleMessage("Draft saved"),
    "drafts": MessageLookupByLibrary.simpleMessage("Drafts"),
    "editProfile": MessageLookupByLibrary.simpleMessage("Edit profile"),
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
    "expandReplies": m1,
    "featureNotAvailable": MessageLookupByLibrary.simpleMessage(
      "This feature is coming soon",
    ),
    "follow": MessageLookupByLibrary.simpleMessage("Follow"),
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
    "profileSaved": MessageLookupByLibrary.simpleMessage("Profile updated"),
    "publish": MessageLookupByLibrary.simpleMessage("Create"),
    "publishFailed": MessageLookupByLibrary.simpleMessage(
      "Publish failed, please retry",
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
    "repliesCount": m2,
    "reply": MessageLookupByLibrary.simpleMessage("Reply"),
    "replyTo": m3,
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
    "saveDraft": MessageLookupByLibrary.simpleMessage("Save draft"),
    "saveProfile": MessageLookupByLibrary.simpleMessage("Save"),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "searchEmpty": m4,
    "searchHint": MessageLookupByLibrary.simpleMessage("Search videos, tags"),
    "searchSomeKeyword": MessageLookupByLibrary.simpleMessage(
      "Search something to explore",
    ),
    "share": MessageLookupByLibrary.simpleMessage("Share"),
    "shareCopied": MessageLookupByLibrary.simpleMessage(
      "Link copied, go share it",
    ),
    "statusDraft": MessageLookupByLibrary.simpleMessage("Draft"),
    "statusOffline": MessageLookupByLibrary.simpleMessage("Offline"),
    "statusRejected": MessageLookupByLibrary.simpleMessage("Rejected"),
    "statusReviewing": MessageLookupByLibrary.simpleMessage("In review"),
    "submitPublish": MessageLookupByLibrary.simpleMessage("Publish"),
    "tagInputHint": MessageLookupByLibrary.simpleMessage(
      "Search or create tags",
    ),
    "tagPickerTitle": MessageLookupByLibrary.simpleMessage("Pick tags"),
    "timeDaysAgo": m5,
    "timeHoursAgo": m6,
    "timeJustNow": MessageLookupByLibrary.simpleMessage("just now"),
    "timeMinutesAgo": m7,
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
    "uploadingPercent": m8,
    "username": MessageLookupByLibrary.simpleMessage("Username"),
    "usernameHint": MessageLookupByLibrary.simpleMessage("Enter username"),
    "videoCountLabel": MessageLookupByLibrary.simpleMessage("Videos"),
    "videoDeleted": MessageLookupByLibrary.simpleMessage("Video deleted"),
    "videoDeletedSuccess": MessageLookupByLibrary.simpleMessage(
      "Video deleted",
    ),
    "videoNotFound": MessageLookupByLibrary.simpleMessage(
      "Video not found or offline",
    ),
    "videoPreview": MessageLookupByLibrary.simpleMessage("Preview"),
    "welcomeBack": MessageLookupByLibrary.simpleMessage("Welcome back"),
    "works": MessageLookupByLibrary.simpleMessage("Works"),
    "writeComment": MessageLookupByLibrary.simpleMessage("Add a comment…"),
  };
}
