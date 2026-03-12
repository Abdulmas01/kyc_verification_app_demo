import 'package:connectivity_plus/connectivity_plus.dart';

class ConecctivityService {
  ConecctivityService._();

  static ConecctivityService instance = ConecctivityService._();
  static final Connectivity _connectivity = Connectivity();
  static List<ConnectivityResult> allconectivity = [
    ConnectivityResult.mobile,
    ConnectivityResult.wifi
  ];

  Future<bool> hasNetworkConection() async {
    List<ConnectivityResult> result = await (_connectivity.checkConnectivity());
    return result.any(
      (element) => allconectivity.contains(element),
    );
  }

  Future<bool> hasMobileConnection() async {
    List<ConnectivityResult> result = await (_connectivity.checkConnectivity());
    return result.any(
      (element) => element == ConnectivityResult.mobile,
    );
  }
}
