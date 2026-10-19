import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:shortplay_app/src/core/utilities/logger.dart' show fatal;
import 'api_state.dart';

export 'api_state.dart';

class ListApiCubit<T> extends Cubit<ApiResponse<List<T>>> {
  ListApiCubit() : super(Initial());

  Future<bool> listItems(Future<List<T>> Function() loader) async {
    emit(Loading());

    try {
      final items = await loader();
      emit(Success<List<T>>(items));
      return true;
    } on Exception catch (e) {
      // 面向用户展示友好提示；原始异常仅进日志
      fatal("list items from api exception: $e");
      emit(Error<List<T>>('内容加载失败，请检查网络后重试'));
      return false;
    }
  }
}
