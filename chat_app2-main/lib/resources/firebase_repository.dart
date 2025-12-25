import '../models/user_model.dart';
import 'package:my_porject/resources/firebase_methods.dart';

class FirebaseRepository {
  final FirebaseMethods _firebaseMethods = FirebaseMethods();

  Future<Userr> getUserDetails() => _firebaseMethods.getUserDetails();
}
