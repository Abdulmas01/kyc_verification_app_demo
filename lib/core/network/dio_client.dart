import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyc_verification_app_demo/helpers/navigation_helpers.dart';
import 'package:kyc_verification_app_demo/core/exception/network_exception.dart';
import 'package:kyc_verification_app_demo/core/utils/logger.dart';
import 'package:kyc_verification_app_demo/core/utils/toast_utils.dart';
import 'package:kyc_verification_app_demo/core/features/auth/presentation/pages/login.dart';

import 'constants.dart';
import 'endpoints.dart';

T? cast<T>(x) => x is T ? x : null;

final dioProvider = Provider<DioClient>((ref) {
  return DioClient(ref: ref);
});

Future<Response> makeRequest(
  Future<Response> Function() f,
) async {
  try {
    final response = await f();

    logger.i(response.data);

    return response;
  } on DioException catch (e) {
    logger.f(e.error.toString());

    logPrint(e.response?.realUri.toString() ?? "");

    throw _mapDioError(e);
  } catch (e) {
    throw NetworkException(statusCode: "-1", message: e.toString());
  }
}

class DioClient {
  late final Dio dio;
  final Ref ref;

  DioClient({required this.ref}) {
    dio = Dio()
      ..options.baseUrl = Endpoints.baseUrl
      ..options.contentType = "application/json"
      ..options.headers.addEntries(
            {'Accept': "application/json", 'X-Client-Version': '1.3'}.entries,
          )
      ..options.connectTimeout = const Duration(milliseconds: 30000);

    // dio.interceptors.add(
    //   InterceptorsWrapper(
    //     onRequest: (options, handler) {
    //       final bool isPublic = options.headers['public'] == true;
    //       if (!isPublic) {
    //         final String token =
    //             AuthLocalDataSource(HiveBox()).getSession()?.token ?? "";
    //         if (token.isNotEmpty) {
    //           options.headers[HttpHeaders.authorizationHeader] =
    //               "Bearer $token";
    //         }
    //       }
    //       logger.i(
    //           "Request: ${options.method} ${options.uri} \nHeaders: ${options.headers} \nData: ${options.data}");
    //       handler.next(options);
    //     },
    //   ),
    // );
  }

  Future<Response> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParams,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    return makeRequest(() {
      logger.i(data);

      return dio.post(
        url,
        data: data,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    });
  }

  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParams,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return makeRequest(() {
      logger.i(url);

      logger.i(queryParams);

      return dio.get(
        url,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<Response> patch(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParams,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return makeRequest(() {
      logger.i(data);

      return dio.patch(
        url,
        data: data,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<Response> delete(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParams,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return makeRequest(() {
      return dio.delete(
        url,
        data: data,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );
    });
  }

  Future<Response> put(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParams,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return makeRequest(() {
      logger.i(data);

      return dio.put(
        url,
        data: data,
        queryParameters: queryParams,
        options: options,
        cancelToken: cancelToken,
      );
    });
  }
}

NetworkException _mapDioError(DioException e) {
  final int statusCode = e.response?.statusCode ?? -1;
  final dynamic rData = e.response?.data;
  String? message = _extractErrorMessage(rData);

  logPrint(rData);

  if (statusCode == 401 &&
      (message?.toLowerCase() == "session expired" ||
          message?.toLowerCase() == "invalid/expired token" ||
          message?.toLowerCase() == "invalid token" ||
          message?.toLowerCase() == "invalid signature")) {
    if (NavigationHelpers.navigationKey.currentState != null) {
      NavigationHelpers.pushAndClearStackFromNavigator(
        route: const Login(),
      );
      ToastUtil.showErrorToast("Session expired, please login again.");
    }
    return NetworkException(
        statusCode: statusCode.toString(), message: "Session expired");
  }

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.error is SocketException) {
    return NetworkException(
        statusCode: statusCode.toString(), message: kUnableToConnect);
  }

  if (message != null) {
    return NetworkException(
        statusCode: statusCode.toString(), message: message);
  }

  if (statusCode >= 500) {
    return NetworkException(
        statusCode: statusCode.toString(), message: kUnableToConnect);
  }

  return NetworkException(
      statusCode: statusCode.toString(), message: kSomethingWentWrong);
}

String? _extractErrorMessage(dynamic data) {
  if (data is! Map) return null;

  final dynamic msg = data["message"] ?? data["detail"];
  if (msg is String && msg.isNotEmpty) return msg;
  if (msg is List && msg.isNotEmpty) return msg.first.toString();

  for (final entry in data.entries) {
    final key = entry.key.toString();
    final value = entry.value;
    if (value is List && value.isNotEmpty) {
      return "$key: ${value.first}";
    }
    if (value is String && value.isNotEmpty) {
      return "$key: $value";
    }
    if (value is Map) {
      for (final nested in value.entries) {
        final nestedKey = nested.key.toString();
        final nestedValue = nested.value;
        if (nestedValue is List && nestedValue.isNotEmpty) {
          return "$key.$nestedKey: ${nestedValue.first}";
        }
        if (nestedValue is String && nestedValue.isNotEmpty) {
          return "$key.$nestedKey: $nestedValue";
        }
      }
    }
  }

  return null;
}
