
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Configuration constants
const MESSAGING_TIMEOUT_MS = 10000; // 10 seconds timeout for FCM messaging
const NOTIFICATION_CLEANUP_DAYS = 30; // Days after which notifications are cleaned up
const NOTIFICATION_CLEANUP_BATCH_SIZE = 500; // Max notifications to delete per cleanup run

/**
 * Triggered when a new notification is created in the 'notifications' collection.
 * Sends a push notification to the target user if they have an FCM token.
 */
exports.sendPushNotification = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snap, context) => {
        const notification = snap.data();
        const notificationId = context.params.notificationId;

        console.log(`New notification created: ${notificationId}`);
        console.log(`Target user: ${notification.targetUserId}`);

        // Get the target user's FCM token
        const targetUserId = notification.targetUserId;
        if (!targetUserId) {
            console.log("No target user ID, skipping push notification");
            return null;
        }

        try {
            const userDoc = await db.collection("users").doc(targetUserId).get();

            if (!userDoc.exists) {
                console.log(`User ${targetUserId} not found`);
                return null;
            }

            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;

            if (!fcmToken) {
                console.log(`User ${targetUserId} has no FCM token`);
                return null;
            }

            // Build the FCM message
            const message = {
                token: fcmToken,
                notification: {
                    title: notification.title || "New Notification",
                    body: notification.body || "",
                },
                data: {
                    notificationId: notificationId,
                    type: notification.type || "info",
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "cofiz_main_channel",
                        priority: "high",
                        defaultSound: true,
                        defaultVibrateTimings: true,
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
            };

            // Send the push notification with timeout
            let response;
            try {
                // Set a timeout for the messaging send operation
                response = await Promise.race([
                    messaging.send(message),
                    new Promise((_, reject) =>
                        setTimeout(() => reject(new Error("messaging-timeout")), MESSAGING_TIMEOUT_MS)
                    ),
                ]);
                console.log(`Push notification sent successfully: ${response}`);
            } catch (sendError) {
                console.error("Error sending message:", sendError);
                throw sendError; // Re-throw to be caught by outer catch block
            }

            // Use batch write to update both notification and potentially user
            const batch = db.batch();
            batch.update(snap.ref, {
                pushSent: true,
                pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            await batch.commit();

            return response;
        } catch (error) {
            console.error("Error sending push notification:", error);

            // If the token is invalid, remove it from the user using batch
            if (error.code === "messaging/invalid-registration-token" ||
                error.code === "messaging/registration-token-not-registered") {
                console.log(`Removing invalid FCM token for user ${targetUserId}`);
                
                const batch = db.batch();
                const userRef = db.collection("users").doc(targetUserId);
                batch.update(userRef, {
                    fcmToken: admin.firestore.FieldValue.delete(),
                });
                // Also mark the notification as failed
                batch.update(snap.ref, {
                    pushSent: false,
                    pushError: error.message,
                    pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                await batch.commit();
            }

            return null;
        }
    });

/**
 * Optional: Clean up old notifications (older than configurable days)
 * Run daily via Cloud Scheduler
 * 
 * NOTE: Requires composite index on 'notifications' collection:
 * createdAt (Ascending) + __name__ (Ascending)
 * Create via Firebase Console or use:
 * firebase deploy --only firestore:indexes
 */
exports.cleanupOldNotifications = functions.pubsub
    .schedule("every 24 hours")
    .onRun(async (context) => {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - NOTIFICATION_CLEANUP_DAYS);
        
        // Use Firestore Timestamp for proper comparison
        const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

        try {
            const oldNotifications = await db
                .collection("notifications")
                .where("createdAt", "<", cutoffTimestamp)
                .limit(NOTIFICATION_CLEANUP_BATCH_SIZE) // Process in batches to avoid memory issues
                .get();

            if (oldNotifications.empty) {
                console.log("No old notifications to delete");
                return null;
            }

            const batch = db.batch();
            oldNotifications.docs.forEach((doc) => {
                batch.delete(doc.ref);
            });

            await batch.commit();
            console.log(`Deleted ${oldNotifications.size} old notifications`);

            return null;
        } catch (error) {
            console.error("Error cleaning up old notifications:", error);
            return null;
        }
    });
