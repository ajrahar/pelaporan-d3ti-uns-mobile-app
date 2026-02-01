import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.nim,
    required super.noTelp,
    required super.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // The structure based on login_mhs.dart seems to be:
    // jsonResponse['data']['user'] -> for user details
    // jsonResponse['data']['token'] -> for token
    // But this factory expects the flattened user object + token.
    // The Datasource will handle extracting these parts and passing them here or combining them.

    // Assuming the map passed here is a combination of user data and token.
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      nim: json['nim'],
      noTelp: json['no_telp'] ?? '', // Handle potential null
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'nim': nim,
      'no_telp': noTelp,
      'token': token,
    };
  }
}
