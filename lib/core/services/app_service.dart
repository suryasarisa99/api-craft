import 'package:api_craft/core/services/storage_serivce.dart';
import 'package:api_craft/features/request/services/http_service.dart';

class AppService {
  static final http = HttpService();
  static final store = StorageSerivce();
}
