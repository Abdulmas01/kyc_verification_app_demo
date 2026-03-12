import 'package:logger/logger.dart';

Logger logger = Logger(
  printer: PrettyPrinter(),
);

void logPrint(Object object) {
  logger.i(object);
}
