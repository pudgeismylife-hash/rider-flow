import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<UserModel?>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

class AuthController extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _repository.authStateChanges.listen(
      (user) {
        state = AsyncValue.data(user);
      },
      onError: (err, stack) {
        state = AsyncValue.error(err, stack);
      },
    );
  }

  Future<void> requestOTP(String mobileNumber) async {
    state = const AsyncValue.loading();
    try {
      await _repository.requestOTP(mobileNumber);
      state = AsyncValue.data(_repository.currentUser);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> verifyOTP(String mobileNumber, String otpCode) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.verifyOTP(mobileNumber, otpCode);
      state = AsyncValue.data(user);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<void> completeOnboarding({
    required String name,
    required UserRole role,
    String? companyId,
    String? branchId,
    String? newCompanyName,
    String? newBranchName,
    String? newBranchCity,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.completeOnboarding(
        name: name,
        role: role,
        companyId: companyId,
        branchId: branchId,
        newCompanyName: newCompanyName,
        newBranchName: newBranchName,
        newBranchCity: newBranchCity,
      );
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> testSwitchUser(UserModel user) async {
    state = const AsyncValue.loading();
    await _repository.testSwitchUser(user);
    state = AsyncValue.data(user);
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _repository.logout();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
