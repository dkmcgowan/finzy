import 'home_user.dart';

class Home {
  final int id;
  final String name;
  final int? guestUserID;
  final String guestUserUUID;
  final bool guestEnabled;
  final bool subscription;
  final List<HomeUser> users;

  Home({
    required this.id,
    required this.name,
    required this.guestUserID,
    required this.guestUserUUID,
    required this.guestEnabled,
    required this.subscription,
    required this.users,
  });

  factory Home.fromJson(Map<String, dynamic> json) {
    final List<dynamic> usersJson = json['users'] as List<dynamic>;
    final users = usersJson.map((userJson) => HomeUser.fromJson(userJson as Map<String, dynamic>)).toList();

    return Home(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String,
      guestUserID: (json['guestUserID'] as num?)?.toInt(),
      guestUserUUID: json['guestUserUUID'] as String,
      guestEnabled: json['guestEnabled'] as bool,
      subscription: json['subscription'] as bool,
      users: users,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'guestUserID': guestUserID,
      'guestUserUUID': guestUserUUID,
      'guestEnabled': guestEnabled,
      'subscription': subscription,
      'users': users.map((user) => user.toJson()).toList(),
    };
  }

  HomeUser? get adminUser => users.where((user) => user.admin).firstOrNull;

  List<HomeUser> get managedUsers => users.where((user) => !user.admin).toList();

  List<HomeUser> get restrictedUsers => users.where((user) => user.restricted).toList();

  HomeUser? getUserByUUID(String uuid) {
    try {
      return users.firstWhere((user) => user.uuid == uuid);
    } catch (e) {
      return null;
    }
  }

  bool get hasMultipleUsers => users.length > 1;
}
