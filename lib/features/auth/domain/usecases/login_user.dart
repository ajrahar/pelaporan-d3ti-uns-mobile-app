import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUser implements UseCase<User, LoginUserParams> {
  final AuthRepository repository;

  LoginUser(this.repository);

  @override
  Future<Either<Failure, User>> call(LoginUserParams params) async {
    return await repository.loginMahasiswa(params.email, params.password);
  }
}

class LoginUserParams extends Equatable {
  final String email;
  final String password;

  const LoginUserParams({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}
