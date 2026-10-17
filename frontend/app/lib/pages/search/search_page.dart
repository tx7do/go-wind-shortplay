import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/search_cubit.dart';
import '../../core/config.dart';
import '../../models/video.dart';
import '../../widgets/common.dart';
import '../video_detail/video_detail_page.dart';

/// 搜索页：关键词搜视频（标题模糊 + 标签精确），结果进单视频详情。
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SearchCubit>(
      create: (_) => SearchCubit(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _inputCtrl = TextEditingController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: _SearchField(
          controller: _inputCtrl,
          onSubmit: (kw) => context.read<SearchCubit>().search(kw),
        ),
      ),
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          if (state.searching && state.results.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          if (!state.searched) {
            return const EmptyView(
              icon: Icons.search_rounded,
              text: '输入关键词，搜索感兴趣的视频',
            );
          }
          if (state.error != null && state.results.isEmpty) {
            return ErrorRetryView(
              message: state.error ?? '加载失败',
              onRetry: () => context.read<SearchCubit>().search(state.keyword),
            );
          }
          if (state.results.isEmpty) {
            return const EmptyView(
              icon: Icons.search_off_rounded,
              text: '没有找到相关视频，换个关键词试试',
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                context.read<SearchCubit>().loadMore();
              }
              return false;
            },
            child: ListView.separated(
              itemCount: state.results.length + 1,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 14, color: Colors.white10),
              itemBuilder: (context, i) {
                if (i == state.results.length) {
                  return LoadMoreFooter(
                    loading: state.searching,
                    hasMore: state.hasMore,
                  );
                }
                final v = state.results[i];
                return _SearchResultCard(
                  video: v,
                  onTap: () => VideoDetailPage.push(context, v.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 顶部搜索框（回车触发搜索）。
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: '搜索视频标题 / 标签',
        prefixIcon: Icon(Icons.search, color: Colors.white38),
      ),
      onSubmitted: onSubmit,
    );
  }
}

/// 搜索结果卡片：封面 + 标题 + 标签 + 播放/点赞数。
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.video, required this.onTap});

  final Video video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面。
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 116,
                height: 74,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.06),
                  child: video.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: AppConfig.absolutize(video.coverUrl),
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: Colors.white24,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.movie_outlined,
                            color: Colors.white24,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 文本信息。
            Expanded(
              child: SizedBox(
                height: 74,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title.isEmpty ? '无标题' : video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (video.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          video.tags.take(3).map((t) => '#$t').join('  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFF7A9C),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            size: 14, color: Colors.white38),
                        const SizedBox(width: 2),
                        Text(
                          formatCount(video.viewCount),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.favorite_rounded,
                            size: 13, color: Colors.white38),
                        const SizedBox(width: 2),
                        Text(
                          formatCount(video.likeCount),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
