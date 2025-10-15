"use strict";

/**
 * Cloud Functions for notifying household members when a new
 * public task is created.
 */

const {setGlobalOptions} = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

setGlobalOptions({maxInstances: 10});

initializeApp();

/**
 * Trigger: on create of `tasks/{taskId}`.
 * Sends push notifications to all household members (except creator)
 * when the task's `status` is "public".
 *
 * Task fields expected:
 *  - householdId: string
 *  - createdBy: string (uid)
 *  - title: string
 *  - status: "public" | "private"
 */
exports.notifyOnNewPublicTask = onDocumentCreated(
    "tasks/{taskId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("No data in event");
        return null;
      }

      const task = snap.data() || {};

      if (task.status !== "public") {
        const id = event.params.taskId || "(no id)";
        console.log("Skipping: task not public:", id);
        return null;
      }

      const householdId = task.householdId;
      const createdBy = task.createdBy || null;
      const title = task.title || "New household task";

      if (!householdId) {
        console.log("Skipping: missing householdId");
        return null;
      }

      // 1) Load household members
      const db = getFirestore();
      const householdRef = db.collection("households").doc(householdId);

      const householdSnap = await householdRef.get();

      if (!householdSnap.exists) {
        console.log("No household for ID:", householdId);
        return null;
      }

      const hhData = householdSnap.data() || {};
      let memberIds = [];

      // Support several shapes
      if (Array.isArray(hhData.memberIds)) {
        memberIds = hhData.memberIds.filter(Boolean);
      } else if (Array.isArray(hhData.members)) {
        memberIds = hhData.members.filter(Boolean);
      } else if (
        hhData &&
      typeof hhData.members === "object" &&
      hhData.members !== null
      ) {
        memberIds = Object.keys(hhData.members);
      }

      const recipients = memberIds.filter((uid) => {
        return uid && uid !== createdBy;
      });

      if (!recipients.length) {
        console.log("No recipients after excluding creator.");
        return null;
      }

      // 2) Collect tokens for recipients
      const tokenSnapPromises = recipients.map((uid) => {
        return db.collection("users")
            .doc(uid)
            .collection("fcmTokens")
            .get();
      });

      const tokenSnaps = await Promise.all(tokenSnapPromises);

      // Avoid flatMap for older parsers
      const tokens = [];
      for (let i = 0; i < tokenSnaps.length; i++) {
        const snapI = tokenSnaps[i];
        for (let j = 0; j < snapI.docs.length; j++) {
          const d = snapI.docs[j];
          const t = d.get("token");
          if (t) {
            tokens.push(t);
          }
        }
      }

      if (!tokens.length) {
        console.log("No tokens found for recipients.");
        return null;
      }

      // 3) Build message
      const taskId = event.params.taskId ?
      String(event.params.taskId) : "";

      const message = {
        tokens: tokens,
        notification: {
          title: "New Public Task",
          body: `"${title}" was added to your household.`,
        },
        data: {
          type: "public_task_created",
          taskId: taskId,
          householdId: String(householdId),
          createdBy: createdBy ? String(createdBy) : "",
        },
        android: {priority: "high"},
        apns: {payload: {aps: {sound: "default"}}},
      };

      // 4) Send
      const messaging = getMessaging();
      const response = await messaging.sendEachForMulticast(message);
      console.log(
          `Sent to ${response.successCount}/${tokens.length} devices.`,
      );

      // 5) Remove invalid tokens
      const invalidTokens = [];
      for (let k = 0; k < response.responses.length; k++) {
        const r = response.responses[k];
        if (!r.success) {
          const code = (r.error && r.error.code) ? r.error.code : "";
          if (
            code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
          ) {
            invalidTokens.push(tokens[k]);
          }
        }
      }

      if (invalidTokens.length) {
        console.log("Cleaning invalid tokens:", invalidTokens.length);
        const deletions = [];
        for (let m = 0; m < invalidTokens.length; m++) {
          const tok = invalidTokens[m];
          const q = await db.collectionGroup("fcmTokens")
              .where("token", "==", tok)
              .get();
          q.forEach((doc) => {
            deletions.push(doc.ref.delete());
          });
        }
        await Promise.all(deletions);
      }

      return null;
    },
);

/**
 * Trigger: on update of `tasks/{taskId}`.
 * Sends a push notification to the task creator when someone claims the task.
 *
 * Task fields expected:
 *  - createdBy: string (uid)
 *  - claimedBy: string (uid) - the person who claimed the task
 *  - title: string
 */
exports.notifyCreatorOnTaskClaim = onDocumentUpdated(
    "tasks/{taskId}",
    async (event) => {
      const beforeSnap = event.data.before;
      const afterSnap = event.data.after;

      if (!beforeSnap || !afterSnap) {
        console.log("No data in event");
        return null;
      }

      const beforeData = beforeSnap.data() || {};
      const afterData = afterSnap.data() || {};

      // Check if task was just claimed (claimedBy changed from empty to a uid)
      const wasUnclaimed = !beforeData.claimedBy;
      const nowClaimed = !!afterData.claimedBy;

      if (wasUnclaimed && nowClaimed) {
        const createdBy = afterData.createdBy;
        const claimedBy = afterData.claimedBy;
        const title = afterData.title || "A task";
        const taskId = event.params.taskId || "";

        if (!createdBy || !claimedBy) {
          console.log("Skipping: missing createdBy or claimedBy");
          return null;
        }

        // Don't notify if creator claimed their own task
        if (createdBy === claimedBy) {
          console.log("Skipping: creator claimed their own task");
          return null;
        }

        const db = getFirestore();

        // Get the claimer's name
        const claimerDoc = await db.collection("users").doc(claimedBy).get();
        let claimerName = "Someone";

        if (claimerDoc.exists) {
          const claimerData = claimerDoc.data() || {};
          claimerName = claimerData.name ||
          claimerData.displayName ||
          claimerData.username ||
          "Someone";
        }

        // Get the creator's FCM tokens
        const tokenSnap = await db.collection("users")
            .doc(createdBy)
            .collection("fcmTokens")
            .get();

        const tokens = [];
        tokenSnap.forEach((doc) => {
          const t = doc.get("token");
          if (t) {
            tokens.push(t);
          }
        });

        if (!tokens.length) {
          console.log("No tokens found for creator");
          return null;
        }

        // Build and send message
        const message = {
          tokens: tokens,
          notification: {
            title: "Task Claimed",
            body: `${claimerName} claimed "${title}"`,
          },
          data: {
            type: "task_claimed",
            taskId: String(taskId),
            claimedBy: String(claimedBy),
          },
          android: {priority: "high"},
          apns: {payload: {aps: {sound: "default"}}},
        };

        const messaging = getMessaging();
        const response = await messaging.sendEachForMulticast(message);
        console.log(
            `Notified creator of claim:
            ${response.successCount}/${tokens.length} devices.`,
        );

        // Clean up invalid tokens
        const invalidTokens = [];
        for (let i = 0; i < response.responses.length; i++) {
          const r = response.responses[i];
          if (!r.success) {
            const code = (r.error && r.error.code) ? r.error.code : "";
            if (
              code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
            ) {
              invalidTokens.push(tokens[i]);
            }
          }
        }

        if (invalidTokens.length) {
          console.log("Cleaning invalid tokens:", invalidTokens.length);
          const deletions = [];
          for (let m = 0; m < invalidTokens.length; m++) {
            const tok = invalidTokens[m];
            const q = await db.collectionGroup("fcmTokens")
                .where("token", "==", tok)
                .get();
            q.forEach((doc) => {
              deletions.push(doc.ref.delete());
            });
          }
          await Promise.all(deletions);
        }
      }

      return null;
    },
);

/**
 * Trigger: on update of `tasks/{taskId}`.
 * Sends a push notification to the task creator when the task is completed.
 *
 * Task fields expected:
 *  - createdBy: string (uid)
 *  - title: string
 *  - status: string (checking for change to "completed")
 */
exports.notifyCreatorOnTaskComplete = onDocumentUpdated(
    "tasks/{taskId}",
    async (event) => {
      const beforeSnap = event.data.before;
      const afterSnap = event.data.after;

      if (!beforeSnap || !afterSnap) {
        console.log("No data in event");
        return null;
      }

      const beforeData = beforeSnap.data() || {};
      const afterData = afterSnap.data() || {};

      // Check if status changed to "completed"
      if (
        beforeData.status !== "completed" &&
      afterData.status === "completed"
      ) {
        const createdBy = afterData.createdBy;
        const title = afterData.title || "A task";
        const taskId = event.params.taskId || "";

        if (!createdBy) {
          console.log("Skipping: no creator to notify");
          return null;
        }

        // Get the creator's FCM tokens
        const db = getFirestore();
        const tokenSnap = await db.collection("users")
            .doc(createdBy)
            .collection("fcmTokens")
            .get();

        const tokens = [];
        tokenSnap.forEach((doc) => {
          const t = doc.get("token");
          if (t) {
            tokens.push(t);
          }
        });

        if (!tokens.length) {
          console.log("No tokens found for creator");
          return null;
        }

        // Build and send message
        const message = {
          tokens: tokens,
          notification: {
            title: "Task Completed! 🎉",
            body: `"${title}" has been completed.`,
          },
          data: {
            type: "task_completed",
            taskId: String(taskId),
          },
          android: {priority: "high"},
          apns: {payload: {aps: {sound: "default"}}},
        };

        const messaging = getMessaging();
        const response = await messaging.sendEachForMulticast(message);
        console.log(
            `Notified creator:
            ${response.successCount}/${tokens.length} devices.`,
        );

        // Clean up invalid tokens
        const invalidTokens = [];
        for (let i = 0; i < response.responses.length; i++) {
          const r = response.responses[i];
          if (!r.success) {
            const code = (r.error && r.error.code) ? r.error.code : "";
            if (
              code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
            ) {
              invalidTokens.push(tokens[i]);
            }
          }
        }

        if (invalidTokens.length) {
          console.log("Cleaning invalid tokens:", invalidTokens.length);
          const deletions = [];
          for (let m = 0; m < invalidTokens.length; m++) {
            const tok = invalidTokens[m];
            const q = await db.collectionGroup("fcmTokens")
                .where("token", "==", tok)
                .get();
            q.forEach((doc) => {
              deletions.push(doc.ref.delete());
            });
          }
          await Promise.all(deletions);
        }
      }

      return null;
    },
);
