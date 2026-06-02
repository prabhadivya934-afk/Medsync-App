import 'package:cloud_firestore/cloud_firestore.dart';

class PatientLinkService {
  static Future<void> linkAccounts({
    required String patientUid,
    required String caretakerEmail,
    required String guardianEmail,
  }) async {
    final users = FirebaseFirestore.instance.collection('users');

    // 🔍 Find caretaker
    final caretakerQuery = await users
        .where("email", isEqualTo: caretakerEmail)
        .where("role", isEqualTo: "caretaker")
        .get();

    // 🔍 Find guardian
    final guardianQuery = await users
        .where("email", isEqualTo: guardianEmail)
        .where("role", isEqualTo: "guardian")
        .get();

    String? caretakerUid;
    String? guardianUid;

    if (caretakerQuery.docs.isNotEmpty) {
      caretakerUid = caretakerQuery.docs.first.id;
    }

    if (guardianQuery.docs.isNotEmpty) {
      guardianUid = guardianQuery.docs.first.id;
    }

    // ✅ SAVE LINKED USERS
    await users.doc(patientUid).update({
      "caretakerUid": caretakerUid,
      "guardianUid": guardianUid,
    });

    // ✅ SAVE PATIENT INSIDE CARETAKER
    if (caretakerUid != null) {
      await users.doc(caretakerUid).collection("patients").doc(patientUid).set({
        "patientUid": patientUid,
      });
    }

    // ✅ SAVE PATIENT INSIDE GUARDIAN
    if (guardianUid != null) {
      await users.doc(guardianUid).collection("patients").doc(patientUid).set({
        "patientUid": patientUid,
      });
    }
  }
}
