import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 👉 Get current logged-in user
  static User? get currentUser => _auth.currentUser;

  // 👉 Handle Google Sign-In
  static Future<User?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // If the user cancels the login dialog, return null
      if (googleUser == null) return null;

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the Google credentials
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      return userCredential.user;
    } catch (e) {
      print("Error during Google Sign-In: $e");
      return null;
    }
  }

  // 👉 Handle Sign-Out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Error during Sign-Out: $e");
    }
  }
}
