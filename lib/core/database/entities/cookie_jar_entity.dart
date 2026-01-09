import 'package:objectbox/objectbox.dart';
import 'package:api_craft/core/models/models.dart';

@Entity()
class CookieJarEntity {
  @Id()
  int id = 0;

  @Index()
  @Unique()
  String uid;

  @Index()
  String collectionId;

  String name;

  // Flex: List<CookieDef> -> List<Map>
  List<Map<String, dynamic>>? cookies;

  CookieJarEntity({
    this.id = 0,
    required this.uid,
    required this.collectionId,
    required this.name,
    this.cookies,
  });

  factory CookieJarEntity.fromModel(CookieJarModel model) {
    return CookieJarEntity(
      uid: model.id,
      collectionId: model.collectionId,
      name: model.name,
      cookies: model.cookies.map((e) => e.toMap()).toList(),
    );
  }

  CookieJarModel toModel() {
    return CookieJarModel(
      id: uid,
      collectionId: collectionId,
      name: name,
      cookies: cookies?.map((e) => CookieDef.fromMap(e)).toList() ?? [],
    );
  }
}
