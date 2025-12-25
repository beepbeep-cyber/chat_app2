import 'package:flutter/widgets.dart';
import 'package:my_porject/models/user_model.dart';
import 'package:my_porject/resources/firebase_repository.dart';

class UserProvider with ChangeNotifier {
  Userr? _user;
  final FirebaseRepository _firebaseRepository = FirebaseRepository();

  Userr? get getUser => _user;

  void refreshUser() async {
    Userr user = await _firebaseRepository.getUserDetails();
    _user = user;
    notifyListeners();
  }
}
