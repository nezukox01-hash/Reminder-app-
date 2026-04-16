import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Standard constructor for stable versions
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;

  static Future<User?> signInWithGoogle() async {
    try {
      // 1. Start the flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // 2. Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase Sign-in
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
      
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Sign-Out Error: $e");
    }
  }
}
