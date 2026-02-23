import 'package:path/path.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class App {
  final GoogleSignIn googleSignIn = GoogleSignIn();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = join('a', 'b');
    print('$prefs $dir');
  }
}
