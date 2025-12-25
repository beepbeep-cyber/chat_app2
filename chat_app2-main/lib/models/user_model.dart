class Userr {
  String? uid;
  String? name;
  String? email;
  String? status;
  String? avatar;

  Userr({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
    required this.avatar,
  });

  Map toMap(Userr user) {
    var data = <String, dynamic>{};
    data['uid'] = user.uid;
    data['name'] = user.name;
    data['email'] = user.email;
    data["status"] = user.status;
    data["profile_photo"] = user.avatar;
    return data;
  }

  // Named constructor
  Userr.fromMap(Map<String, dynamic> mapData) {
    uid = mapData['uid'];
    name = mapData['name'];
    email = mapData['email'];
    status = mapData['status'];
    avatar = mapData['avatar'];
  }
}
