/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {setGlobalOptions} = require("firebase-functions/v2");
// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Trigger: fires when a new task is added to `tasks/{taskId}`.
 * Sends push notifications to all members of that task's household
 * (except the creator) if the task is public.
 *
 * Task document fields expected:
 *  - householdId: string
 *  - createdBy: string (uid of user who created it)
 *  - title: string
 *  - status: "public" or "private"
 */
exports.notifyOnNewPublicTask = functions.firestore
  .document("tasks/{taskId}")
  .onCreate(async (snap, context) => {
    const task = snap.data() || {};

    // ✅ Only send for public tasks
    if (task.status !== "public") return null;

    const householdId = task.householdId;
    const title = task.title || "New household task";
    const createdBy = task.createdBy || null;

    if (!householdId) return null;

    // 1️⃣ Get household members
    const householdSnap = await admin
      .firestore()
      .collection("households")
      .doc(householdId)
      .get();

    if (!householdSnap.exists) {
      console.log(`No household found for ID: ${householdId}`);
      return null;
    }

    const hhData = householdSnap.data() || {};
    let memberIds = [];

    // Handle different possible member structures
    if (Array.isArray(hhData.memberIds)) {
      memberIds = hhData.memberIds.filter(Boolean);
    } else if (Array.isArray(hhData.members)) {
      memberIds = hhData.members.filter(Boolean);
    } else if (typeof hhData.members === "object") {
      memberIds = Object.keys(hhData.members);
    }

    const recipients = memberIds.filter((uid) => uid !== createdBy);
    if (!recipients.length) {
      console.log("No recipients to notify");
      return null;
    }

    // 2️⃣ Collect FCM tokens from each recipient
    const tokenSnaps = await Promise.all(
      recipients.map((uid) =>
        admin
          .firestore()
          .collection("users")
          .doc(uid)
          .collection("fcmTokens")
          .get()
      )
    );

    const tokens = tokenSnaps
      .flatMap((snap) => snap.docs.map((d) => d.get("token")))
      .filter(Boolean);

    if (!tokens.length) {
      console.log("No tokens found for recipients");
      return null;
    }

    // 3️⃣ Prepare the push notification
    const message = {
      tokens,
      notification: {
        title: "New Public Task",
        body: `“${title}” was added to your household.`,
      },
      data: {
        type: "public_task_created",
        taskId: context.params.taskId,
        householdId: householdId,
        createdBy: createdBy || "",
      },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    };

    // 4️⃣ Send notifications
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ Sent to ${response.successCount}/${tokens.length} devices.`);

    // 5️⃣ Clean up invalid tokens
    const invalidTokens = [];
    response.responses.forEach((res, i) => {
      if (!res.success) {
        const code = res.error?.code || "";
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          invalidTokens.push(tokens[i]);
        }
      }
    });

    await Promise.all(
      invalidTokens.map(async (tok) => {
        const q = await admin
          .firestore()
          .collectionGroup("fcmTokens")
          .where("token", "==", tok)
          .get();
        await Promise.all(q.docs.map((d) => d.ref.delete()));
      })
    );

    return null;
  });

