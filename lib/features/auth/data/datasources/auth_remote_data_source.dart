import 'dart:developer';

import 'package:tasky/core/failure/failure.dart';
import 'package:tasky/core/server_service/end_points.dart';
import 'package:tasky/core/server_service/http_service.dart';
import 'package:tasky/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:tasky/features/auth/data/models/tokens_models.dart';
import 'package:tasky/features/auth/data/models/user_data_model.dart';
import 'package:tasky/tasky_enjection.dart';

abstract class AuthRemoteDataSource {
  Future<void> register(UserDataModel user);
  Future<void> login(String phone, String password);
  Future<void> logout();
  Future<void> refreshToken();
  Future<UserDataModel> getProfile();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final HttpService httpService;

  AuthRemoteDataSourceImpl({required this.httpService});
  @override
  Future<UserDataModel> getProfile() async {
    final token = await ls<AuthLocalDataSource>().getToken();
    if (token != null) {
      final result = await httpService.get(
        url: EndPoints.profile,
        header: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      return UserDataModel.fromJson(result);
    }
    throw CachFailure(message: 'Error while get token');
  }

  @override
  Future<void> login(String phone, String password) async {
    final result = await httpService.post(
        url: EndPoints.login, data: {"phone": phone, "password": password});
    final token = TokensModels.formJson(result);
    await ls<AuthLocalDataSource>().saveRefreshToken(token.refreshToken!);
    await ls<AuthLocalDataSource>().saveToken(token.accessToken);
    log('refreshToken: ${token.refreshToken}, token: ${token.accessToken}');
  }

  @override
  Future<void> logout() async {
    final token = await ls<AuthLocalDataSource>().getToken();
    if (token != null) {
      await httpService.post(
        url: EndPoints.logout,
        data: {'token': token},
        header: {
          "Authorization": "Bearer $token",
        },
      );
      await ls<AuthLocalDataSource>().logoutUser();
    } else {
      throw CachFailure(message: 'Error while get token');
    }
  }

  @override
  Future<void> refreshToken() async {
    final refreshToken = await ls<AuthLocalDataSource>().getRefreshToken();
    final token = await ls<AuthLocalDataSource>().getToken();
    log('refreshToken: $refreshToken, token: $token');
    if (refreshToken == null || token == null) {
      throw CachFailure(message: 'Token or Refresh Token is null');
    } else {
      final result = await httpService.get(
        url: EndPoints.refreshToken(refreshToken),
        header: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      await ls<AuthLocalDataSource>().saveToken(result['access_token']);
    }
  }

  @override
  Future<void> register(UserDataModel user) async {
    final result = await await httpService.post(
      url: EndPoints.register,
      data: user.toJosn(),
    );
    final token = TokensModels.formJson(result);
    await ls<AuthLocalDataSource>().saveRefreshToken(token.refreshToken!);
    await ls<AuthLocalDataSource>().saveToken(token.accessToken);
  }
}
