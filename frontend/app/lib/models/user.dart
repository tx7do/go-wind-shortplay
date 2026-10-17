import 'common.dart';

/// 用户资料。
class User {
  const User({
    required this.id,
    this.username = '',
    this.nickname = '',
    this.avatarUrl = '',
    this.bio = '',
  });

  final int id;
  final String username;
  final String nickname;
  final String avatarUrl;
  final String bio;

  /// 展示用名称：昵称 > 用户名 > “用户{id}”。
  String get displayName {
    if (nickname.isNotEmpty) return nickname;
    if (username.isNotEmpty) return username;
    return '用户$id';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: asInt(json['id'] ?? json['userId'] ?? json['user_id']),
      username: asStr(json['username']),
      nickname: asStr(json['nickname']),
      avatarUrl: asStr(json['avatarUrl'] ?? json['avatar_url']),
      bio: asStr(json['bio']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'nickname': nickname,
        'avatarUrl': avatarUrl,
        'bio': bio,
      };

  User copyWith({String? nickname, String? bio, String? avatarUrl}) => User(
        id: id,
        username: username,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
      );
}

/// 用户统计（GET /users/{id}/stats）。
class UserStats {
  const UserStats({
    this.videoCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.likeReceivedCount = 0,
  });

  final int videoCount;
  final int followerCount;
  final int followingCount;
  final int likeReceivedCount;

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        videoCount: asInt(json['videoCount'] ?? json['video_count']),
        followerCount: asInt(json['followerCount'] ?? json['follower_count']),
        followingCount: asInt(json['followingCount'] ?? json['following_count']),
        likeReceivedCount:
            asInt(json['likeReceivedCount'] ?? json['like_received_count']),
      );
}

/// 创作者中心概览（GET /creator/overview）。
class CreatorOverview {
  const CreatorOverview({
    this.videoCount = 0,
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalCollects = 0,
    this.totalComments = 0,
    this.followerCount = 0,
  });

  final int videoCount;
  final int totalViews;
  final int totalLikes;
  final int totalCollects;
  final int totalComments;
  final int followerCount;

  factory CreatorOverview.fromJson(Map<String, dynamic> json) =>
      CreatorOverview(
        videoCount: asInt(json['videoCount'] ?? json['video_count']),
        totalViews: asInt(json['totalViews'] ?? json['total_views']),
        totalLikes: asInt(json['totalLikes'] ?? json['total_likes']),
        totalCollects: asInt(json['totalCollects'] ?? json['total_collects']),
        totalComments: asInt(json['totalComments'] ?? json['total_comments']),
        followerCount: asInt(json['followerCount'] ?? json['follower_count']),
      );
}

/// 登录 / 注册结果。
class LoginResult {
  const LoginResult({
    required this.token,
    this.refreshToken,
    this.user,
  });

  final String token;
  final String? refreshToken;
  final User? user;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final auth = json['authenticator'];
    final authMap = auth is Map<String, dynamic> ? auth : json;
    final rawUser = json['user'];
    return LoginResult(
      token: asStr(
        authMap['accessToken'] ?? authMap['access_token'],
      ),
      refreshToken:
          asStr(authMap['refreshToken'] ?? authMap['refresh_token']),
      user: rawUser is Map<String, dynamic> ? User.fromJson(rawUser) : null,
    );
  }
}
