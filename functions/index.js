const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendMissedDoseAlert =
    functions.firestore
        .document("missed_doses/{docId}")
        .onCreate(async (snap, context) => {

            const data = snap.data();

            const caretakerId =
                data.caretakerId;

            const guardianId =
                data.guardianId;

            const medicine =
                data.medicine;

            const dose =
                data.dose;

            const patientName =
                data.patientName || "Patient";

            const body =
                `${patientName} missed ${dose} dose of ${medicine}`;

            const payload = {

                notification: {
                    title:
                        "Missed Medicine Alert",
                    body: body,
                },

                android: {
                    priority: "high",
                },
            };

            // CARETAKER
            if (caretakerId) {

                const caretakerDoc =
                    await admin.firestore()
                        .collection("users")
                        .doc(caretakerId)
                        .get();

                const caretakerToken =
                    caretakerDoc.data()
                        ?.fcmToken;

                if (caretakerToken) {

                    await admin.messaging()
                        .send({

                            token: caretakerToken,

                            notification: {
                                title:
                                    "Missed Medicine Alert",
                                body: body,
                            },
                        });
                }
            }

            // GUARDIAN
            if (guardianId) {

                const guardianDoc =
                    await admin.firestore()
                        .collection("users")
                        .doc(guardianId)
                        .get();

                const guardianToken =
                    guardianDoc.data()
                        ?.fcmToken;

                if (guardianToken) {

                    await admin.messaging()
                        .send({

                            token: guardianToken,

                            notification: {
                                title:
                                    "Missed Medicine Alert",
                                body: body,
                            },
                        });
                }
            }

            return null;
        });