const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendCallNotification = onDocumentCreated("calls/{callId}", async (event) => {
  const snap = event.data;
  if (!snap) return null;
  
  const callData = snap.data();

  // We only send a push notification when a call is initiated
  if (callData.status !== "ringing") return null;

  const calleeIds = callData.calleeIds || [];
  const callerName = callData.callerName || "Someone";
  const isVideo = callData.isVideo;

  if (calleeIds.length === 0) return null;

  try {
    // Fetch user documents for all callees
    const promises = calleeIds.map(uid => admin.firestore().collection("users").doc(uid).get());
    const userDocs = await Promise.all(promises);

    const tokens = [];
    userDocs.forEach(doc => {
      if (doc.exists && doc.data().fcmToken) {
        tokens.push(doc.data().fcmToken);
      }
    });

    if (tokens.length === 0) {
      console.log("No FCM tokens found for callees:", calleeIds);
      return null;
    }

    const message = {
      notification: {
        title: "Incoming Call",
        body: `${callerName} is calling you via ${isVideo ? "Video" : "Audio"}...`,
      },
      data: {
        callId: event.params.callId,
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      },
      tokens: tokens
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Notification sent successfully. Success: ${response.successCount}, Failure: ${response.failureCount}`);
  } catch (error) {
    console.error("Error sending notification:", error);
  }
  
  return null;
});
