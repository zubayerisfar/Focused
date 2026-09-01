
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountLifecycleService {
  AccountLifecycleService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> deactivate({
    required List<String> reasons,
    String? feedback,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed in user');

    final now = DateTime.now().toUtc();
    await _firestore.collection('deactivated_users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'reasons': reasons,
      'feedback': feedback ?? '',
      'deactivatedAt': now,
      'reactivationTime': now.add(const Duration(hours: 24)),
      'status': 'deactivated',
    });

    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed in user');

    await _firestore.collection('users').doc(user.uid).delete();
    await _firestore.collection('deactivated_users').doc(user.uid).delete();
    await user.delete();
  }
}
