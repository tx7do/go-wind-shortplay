import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:shortplay_app/src/core/utilities/logger.dart' show fatal;
import 'api_state.dart';

export 'api_state.dart';

class GetApiCubit<T> extends Cubit<ApiResponse<T>> {
  GetApiCubit() : super(Initial());

  Future<bool> listItems(Future<T> Function() loader) async {
    emit(Loading());

    try {
      final item = await loader();
      emit(Success<T>(item));
      return true;
    } on Exception catch (e) {
      // 面向用户展示友好提示；原始异常仅进日志（502/超时等 Dio 原文对用户无意义）
      fatal("get item from api exception: $e");
      emit(Error<T>('内容加载失败，请检查网络后重试'));
      return false;
    }
  }
}
