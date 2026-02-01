import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> loginMahasiswa(String email, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient dioClient;

  AuthRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<UserModel> loginMahasiswa(String email, String password) async {
    try {
      final response = await dioClient.dio.post(
        ApiConstants.loginMahasiswaEndpoint,
        data: {
          'email': email,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data['status'] == true) {
          final userData = data['data']['user'];
          final token = data['data']['token'];

          final Map<String, dynamic> userMap = Map<String, dynamic>.from(userData);
          userMap['token'] = token;

          return UserModel.fromJson(userMap);
        } else {
          throw ServerException(message: data['message'] ?? 'Login failed');
        }
      } else {
        throw ServerException(message: 'Login failed with status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Unknown Dio Error');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
