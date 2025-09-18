                    // providers/auth_provider.dart
                    import 'package:firebase_auth/firebase_auth.dart';
                    import 'package:flutter/foundation.dart';

                    import '../Auth/auth_service.dart';

                    class AuthProvider with ChangeNotifier {
                      final AuthService _authService = AuthService();

                      User? get currentUser => _authService.currentUser;
                      bool get isLoggedIn => currentUser != null;

                      Future<User?> signUp(String email, String password, String fullName) async {
                        try {
                          final user = await _authService.signUpWithEmailAndPassword(
                              email, password, fullName
                          );
                          notifyListeners();
                          return user;
                        } catch (e) {
                          rethrow;
                        }
                      }

                      Future<User?> signIn(String email, String password) async {
                        try {
                          final user = await _authService.signInWithEmailAndPassword(email, password);
                          notifyListeners();
                          return user;
                        } catch (e) {
                          rethrow;
                        }
                      }

                      Future<void> signOut() async {
                        await _authService.signOut();
                        notifyListeners();
                      }

                      Future<void> resetPassword(String email) async {
                        await _authService.resetPassword(email);
                      }
                    }