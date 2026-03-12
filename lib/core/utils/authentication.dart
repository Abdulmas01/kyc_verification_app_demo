import 'dart:convert';

import 'package:my_atbu_app/core/features/auth/domain/models/auth_model.dart';
import 'package:my_atbu_app/core/features/auth/domain/models/auth_exception.dart';
import 'package:my_atbu_app/core/shared/models/user_model.dart';
import 'package:my_atbu_app/core/features/auth/domain/models/validation_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

class UserAuthentication {
  final String api;
  final User? user;
  UserAuthentication({required this.api, this.user});
  Future loginAuth(
      {required String username, required dynamic password}) async {
    try {
      http.Response response = await http.post(Uri.parse('${api}auth/login'),
          body: jsonEncode({"username": username, "password": password}),
          headers: {
            "Content-Type": "application/json",
          },
          encoding: Encoding.getByName("utf-8"));
      return sendResponse(response);
    } catch (e) {
      if (e is http.ClientException) {
        return Future.error(AuthException(
            statusCode: -400, errorType: "client error", message: e.message));
      }
      return Future.error(
          AuthException(statusCode: -1, errorType: null, message: ""));
    }
  }

  Future signUpAuth(
      {required String username,
      required dynamic password,
      required String email,
      required int schoolId}) async {
    try {
      http.Response response = await http.post(Uri.parse("${api}auth/register"),
          body: jsonEncode({
            "username": username,
            "email": email,
            "password": password,
            "school": schoolId
          }),
          headers: {
            "Content-Type": "application/json",
          },
          encoding: Encoding.getByName("utf-8"));
      return sendResponse(response, user);
    } catch (e) {
      if (e is http.ClientException) {
        return Future.error(AuthException(
            statusCode: -400, errorType: "client error", message: e.message));
      }
      return Future.error(
          AuthException(statusCode: -1, errorType: null, message: ""));
    }
  }

  void firebaseLoginAuth(params) {}
  void firbaseSignUpAuth(params) {}

  bool matchPassword(password, confirmPassword) {
    return password == confirmPassword ? true : false;
  }

  static ValidationModel validateLoginData(
      {required String username, required dynamic password}) {
    if (username.isEmpty) {
      return ValidationModel(
          validationError: true, message: "Username Cannot be Empty");
    }
    if (password.isEmpty) {
      return ValidationModel(
          validationError: true, message: "Password Cannot be Empty");
    }
    return ValidationModel(validationError: false);
  }

  Future<dynamic> sendResponse(Response response, [User? user]) async {
    switch (response.statusCode) {
      case 200:
        return AuthModel.fromDb(await jsonDecode(response.body));
      case 201:
        return AuthModel.fromSigUp(await jsonDecode(response.body), user!);
      case 400:
        dynamic res = await jsonDecode(response.body);
        return Future.error(AuthException(
            statusCode: 400,
            errorType: response.reasonPhrase,
            message: failedValidationMessage(res)));
      case 401 || 403:
        try {
          Map data = await jsonDecode(response.body);
          return Future.error(AuthException(
              statusCode: response.statusCode,
              errorType: response.reasonPhrase,
              message: data.values.firstOrNull));
        } catch (err) {
          AuthException(
              statusCode: 401,
              errorType: "decode error",
              message: "fail to decode response");
        }
      default:
        return Future.error(AuthException(
            statusCode: response.statusCode,
            errorType: response.reasonPhrase,
            message: response.reasonPhrase ?? ""));
    }
  }
}

String failedValidationMessage(dynamic result) {
  String message = "";
  if (result is Map) {
    for (String element in (result).keys) {
      if (result[element] is List) {
        if (result[element].isNotEmpty) {
          message += ("$element ${result[element]} ,");
        }
      } else {
        message += (result[element] + ",");
      }
    }
    return message;
  }
  if (result is List) {
    for (var element in result) {
      message += (element + ",");
    }
  }

  return message;
}
