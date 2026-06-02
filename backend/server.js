require("dotenv").config();
const admin =
    require("firebase-admin");

const express = require("express");
const cors = require("cors");
const twilio = require("twilio");
const OpenAI = require("openai").default;
const serviceAccount =
    require("./serviceAccountKey.json");

admin.initializeApp({

    credential:
        admin.credential.cert(
            serviceAccount
        ),
});

const app = express();

app.use(cors());
app.use(express.json());

// ======================
// ROOT ROUTE
// ======================
app.get("/", (req, res) => {
    res.send("MedSync backend running successfully");
});

// ======================
// TWILIO
// ======================
const twilioClient = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
);

// ======================
// OPENAI
// ======================
const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
});

// ======================
// SEND SMS ROUTE
// ======================
app.post("/send-skip-alert", async (req, res) => {
    try {
        const { numbers, medicineName, time } = req.body;

        if (!numbers || numbers.length === 0) {
            return res.status(400).json({
                error: "No phone numbers provided",
            });
        }

        const body =
            "MedSync Alert: Patient skipped " +
            medicineName +
            " at " +
            time +
            ". Please check immediately.";

        const results = await Promise.all(
            numbers.map((number) =>
                twilioClient.messages.create({
                    body: body,
                    from: process.env.TWILIO_PHONE_NUMBER,
                    to: number,
                })
            )
        );

        res.json({
            success: true,
            results: results,
        });
    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ======================
// SEND PUSH ALERT ROUTE
// ======================

app.post(
    "/send-push-alert",

    async (req, res) => {

        try {

            const {
                token,
                patientName,
                medicineName,
                dose,
            } = req.body;

            await admin
                .messaging()
                .send({

                    token: token,

                    notification: {

                        title:
                            "Missed Medicine Alert",

                        body:
                            `${patientName} missed ${dose} dose of ${medicineName}`,
                    },

                    android: {
                        priority: "high",
                    },
                });

            res.json({
                success: true,
            });
        }
        catch (error) {

            console.error(error);

            res.status(500).json({

                success: false,

                error:
                    error.message,
            });
        }
    }
);

// ======================
// VOICE ASSISTANT ROUTE
// ======================
app.post("/voice-assistant", async (req, res) => {
    try {
        const { message } = req.body;

        const response = await openai.chat.completions.create({
            model: "gpt-4.1-mini",
            messages: [
                {
                    role: "system",
                    content: "You are MedSync AI assistant.",
                },
                {
                    role: "user",
                    content: message,
                },
            ],
        });

        res.json({
            reply: response.choices[0].message.content,
        });
    } catch (error) {
        console.error(error);

        res.status(500).json({
            error: error.message,
        });
    }
});

// ======================
// START SERVER
// ======================
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log("Server running on port " + PORT);
});