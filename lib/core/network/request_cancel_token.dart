import 'package:dio/dio.dart';

class RequestCancelToken {
  final CancelToken _token = CancelToken();

  bool get isCancelled => _token.isCancelled;

  void cancel([String? reason]) {
    if (_token.isCancelled) return;
    _token.cancel(reason);
  }

  CancelToken get dioToken => _token;
}
