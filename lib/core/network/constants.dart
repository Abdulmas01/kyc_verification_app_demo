import 'package:dio/dio.dart';

const String kAnErrorOccurred = "An error occurred.";
const String kSomethingWentWrong = "Something went wrong.";
const String kUnableToConnect = "Unable to connect, please try again.";
const String kNotAvailable = "N/A";

Options pulicEndpointOptions = Options(
  headers: {
    'public': true, // This will skip token attachment
  },
);
