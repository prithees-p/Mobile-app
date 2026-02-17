import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final ApiService _singleton = ApiService._internal();
  factory ApiService() => _singleton;
  ApiService._internal();

  late Dio dio;
  late PersistCookieJar cookieJar;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    dio = Dio(
      BaseOptions(
        baseUrl: "${dotenv.env['url']}",
        headers: {"Content-Type": "application/json"},
        validateStatus: (status) => status! < 500,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    cookieJar = PersistCookieJar(
      storage: FileStorage("${directory.path}/.cookies/"),
    );

    // Prevent duplicate interceptors
    dio.interceptors.removeWhere((i) => i is CookieManager);
    dio.interceptors.add(CookieManager(cookieJar));

    _isInitialized = true;
  }

  /// Call on logout
  Future<void> clearSession() async {
    print("Clearing session and cookies...");
    print(cookieJar);
    await cookieJar.deleteAll();
  }
}
