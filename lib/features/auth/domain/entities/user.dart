import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int id;
  final String name;
  final String email;
  final String nim;
  final String noTelp;
  final String token;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.nim,
    required this.noTelp,
    required this.token,
  });

  @override
  List<Object?> get props => [id, name, email, nim, noTelp, token];
}
