const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");
require("dotenv").config();

admin.initializeApp();

const MSG91_AUTH_KEY = process.env.MSG91_AUTH_KEY || "563466AVJB6j1dq9f6a8a80c1P1";
const MSG91_WIDGET_ID = process.env.MSG91_WIDGET_ID || "366877666949303632383336";
const MSG91_WIDGET_AUTH_TOKEN = process.env.MSG91_WIDGET_AUTH_TOKEN || "563466TfHiw5YA6a8aa465P1";
const MSG91_BASE = "https://control.msg91.com/api/v5";  // Standard OTP API
const MSG91_API_BASE = "https://api.msg91.com/api/v5";  // Widget/token API

/**
 * Send OTP — uses MSG91 Standard OTP API (server-side fallback)
 * The widget SDK sends OTP client-side; this Cloud Function is the server-side fallback.
 *
 * MSG91 Standard OTP API: POST /api/v5/otp
 * Data payload: { identifier: '919876543210' }
 */
exports.sendOtp = onCall(async (request) => {
  const { identifier } = request.data || {};
  if (!identifier) {
    throw new HttpsError("invalid-argument", "The 'identifier' field is required.");
  }

  // Normalize: strip formatting, add country code 91 for 10-digit mobile numbers
  let mobile = String(identifier).replace(/[+\s-]/g, "");
  if (!mobile.includes("@") && mobile.length === 10) {
    mobile = `91${mobile}`;
  }

  console.log(`sendOtp: sending OTP to ${mobile}`);

  try {
    // Standard MSG91 OTP API — works server-side
    const response = await axios.post(
      `${MSG91_BASE}/otp`,
      { mobile },
      {
        headers: {
          authkey: MSG91_AUTH_KEY,
          "Content-Type": "application/json",
        },
      }
    );

    const resData = response.data || {};
    console.log("sendOtp MSG91 response:", JSON.stringify(resData));

    // MSG91 returns { type: 'success', message: '<reqId>' }
    if (resData.type === "error") {
      throw new HttpsError("internal", resData.message || "MSG91 returned error.");
    }

    return {
      success: true,
      reqId: resData.message || resData.reqId || resData.request_id || "",
      mobile,
      data: resData,
    };
  } catch (error) {
    const errData = error.response?.data;
    const errMsg =
      (typeof errData === "object" ? errData?.message : String(errData)) ||
      error.message ||
      "Failed to send OTP via MSG91.";
    console.error("sendOtp Error:", errMsg, "| Status:", error.response?.status);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", String(errMsg));
  }
});

/**
 * Retry OTP — uses MSG91 Standard OTP retry API
 * Data payload: { mobile: '919876543210', retryChannel: 11 }
 * retryChannel: 11=SMS, 4=Voice, 3=Email, 12=WhatsApp
 */
exports.retryOtp = onCall(async (request) => {
  const { mobile, retryChannel } = request.data || {};
  if (!mobile) {
    throw new HttpsError("invalid-argument", "The 'mobile' field is required.");
  }

  const cleanMobile = String(mobile).replace(/[+\s-]/g, "");

  try {
    const response = await axios.get(`${MSG91_BASE}/otp/retry`, {
      params: {
        authkey: MSG91_AUTH_KEY,
        retryChannel: retryChannel || 11,
        mobile: cleanMobile,
      },
    });

    const resData = response.data || {};
    console.log("retryOtp MSG91 response:", JSON.stringify(resData));

    if (resData.type === "error") {
      throw new HttpsError("internal", resData.message || "Retry failed.");
    }

    return { success: true, data: resData };
  } catch (error) {
    const errMsg =
      error.response?.data?.message || error.message || "Failed to retry OTP via MSG91.";
    console.error("retryOtp Error:", errMsg);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", String(errMsg));
  }
});

/**
 * Verify OTP & Generate Firebase Custom Token — uses MSG91 Standard OTP verify API
 * Data payload: { otp: '1234', mobile: '919876543210', reqId: '...' }
 */
exports.verifyOtp = onCall(async (request) => {
  const { otp, mobile, reqId } = request.data || {};
  if (!otp) {
    throw new HttpsError("invalid-argument", "The 'otp' field is required.");
  }
  if (!mobile) {
    throw new HttpsError("invalid-argument", "The 'mobile' field is required.");
  }

  const cleanMobile = String(mobile).replace(/[+\s-]/g, "");

  try {
    const response = await axios.get(`${MSG91_BASE}/otp/verify`, {
      params: {
        authkey: MSG91_AUTH_KEY,
        otp,
        mobile: cleanMobile,
        ...(reqId ? { reqId } : {}),
      },
    });

    const resData = response.data || {};
    console.log("verifyOtp MSG91 response:", JSON.stringify(resData));

    if (resData.type === "error") {
      throw new HttpsError("unauthenticated", resData.message || "Invalid OTP code.");
    }

    // OTP Verified — generate Firebase Custom Token
    const uid = `phone_${cleanMobile}`;
    const customToken = await admin.auth().createCustomToken(uid, {
      phone: cleanMobile,
      verifiedVia: "MSG91_OTP",
    });

    return {
      success: true,
      customToken,
      uid,
      data: resData,
    };
  } catch (error) {
    const errMsg =
      error.response?.data?.message || error.message || "OTP verification failed.";
    console.error("verifyOtp Error:", errMsg);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", String(errMsg));
  }
});

/**
 * Verify MSG91 Widget Access Token (auto-verification / SIM-based flow)
 * Called when the widget returns an 'access-token' (JWT) — no OTP entry needed.
 *
 * MSG91 Widget API: POST /api/v5/widget/verifyAccessToken  ← this one DOES exist
 * Data payload: { accessToken: '<jwt>', mobileNumber: '9876543210' }
 */
exports.verifyAccessToken = onCall(async (request) => {
  const { accessToken, mobileNumber } = request.data || {};

  if (!accessToken) {
    throw new HttpsError("invalid-argument", "The 'accessToken' field is required.");
  }

  console.log("verifyAccessToken: verifying JWT with MSG91...");

  try {
    // ✅ Correct domain: api.msg91.com (not control.msg91.com) — per MSG91 docs
    const response = await axios.post(
      `${MSG91_API_BASE}/widget/verifyAccessToken`,
      {
        authkey: MSG91_AUTH_KEY,
        "access-token": accessToken,
      },
      {
        headers: {
          "Content-Type": "application/json",
        },
      }
    );

    const resData = response.data || {};
    console.log("verifyAccessToken MSG91 response:", JSON.stringify(resData));

    if (resData.type === "error") {
      throw new HttpsError("unauthenticated", resData.message || "Access token verification failed.");
    }

    const resolvedPhone = mobileNumber
      ? String(mobileNumber).replace(/[+\s-]/g, "")
      : (resData.mobile || resData.phone || "unknown");

    const uid = `phone_${resolvedPhone}`;

    const customToken = await admin.auth().createCustomToken(uid, {
      phone: resolvedPhone,
      verifiedVia: "MSG91_AccessToken",
    });

    return {
      success: true,
      customToken,
      uid,
      mobile: resolvedPhone,
      data: resData,
    };
  } catch (error) {
    const errMsg =
      error.response?.data?.message ||
      error.response?.data ||
      error.message ||
      "Access token verification failed.";
    console.error("verifyAccessToken Error:", errMsg);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", String(errMsg));
  }
});
/**
 * Link Phone Number to Firebase Auth user — uses Admin SDK to update phoneNumber.
 * Called after OTP is successfully verified to attach the phone number as a provider.
 *
 * Data payload: { uid: '<firebase-uid>', mobileNumber: '9876543210' }
 * Requires the caller to be authenticated (request.auth.uid must match uid).
 */
exports.linkPhoneNumber = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  let { uid, mobileNumber } = request.data || {};

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "You must be signed in to link a phone number.");
  }
  uid = uid || callerUid;
  if (callerUid !== uid) {
    throw new HttpsError("permission-denied", "You can only link your own phone number.");
  }

  // If mobileNumber was not provided directly in payload, lookup from Firestore doc
  if (!mobileNumber) {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      mobileNumber = data.mobileNumber || data.phone;
    }
  }

  if (!mobileNumber) {
    throw new HttpsError("invalid-argument", "'mobileNumber' is required.");
  }

  // Normalize: strip formatting, add country code +91 for 10-digit Indian numbers
  let clean = String(mobileNumber).replace(/[+\s-]/g, "");
  if (clean.length === 10) {
    clean = `91${clean}`;
  }
  const e164Phone = `+${clean}`;

  try {
    await admin.auth().updateUser(uid, { phoneNumber: e164Phone });
    console.log(`linkPhoneNumber: linked ${e164Phone} to uid ${uid}`);
    return { success: true, phoneNumber: e164Phone };
  } catch (error) {
    const errMsg = error.message || "Failed to link phone number.";
    console.error("linkPhoneNumber Error:", errMsg);
    // If phone is already linked to another account, give a clear message
    if (error.code === "auth/phone-number-already-exists") {
      throw new HttpsError("already-exists", "This phone number is already linked to another account.");
    }
    throw new HttpsError("internal", errMsg);
  }
});


/**
 * HTTP endpoint to sync all users' phone numbers from Firestore to Firebase Auth in one pass.
 * Can be called via GET request to https://us-central1-oceankart-83bbd.cloudfunctions.net/syncAllUsersAuthPhone
 */
exports.syncAllUsersAuthPhone = onRequest(async (req, res) => {
  try {
    const usersSnap = await admin.firestore().collection("users").get();
    const results = [];

    for (const doc of usersSnap.docs) {
      const userId = doc.id;
      const data = doc.data();
      const rawPhone = data.mobileNumber || data.phone;

      if (!rawPhone) {
        results.push({ uid: userId, email: data.email, status: "skipped (no phone in firestore)" });
        continue;
      }

      let clean = String(rawPhone).replace(/[+\s-]/g, "");
      if (clean.length === 10) {
        clean = `91${clean}`;
      }
      const e164Phone = `+${clean}`;

      try {
        const userRecord = await admin.auth().getUser(userId);
        if (userRecord.phoneNumber !== e164Phone) {
          await admin.auth().updateUser(userId, { phoneNumber: e164Phone });
          results.push({ uid: userId, email: data.email, phone: e164Phone, status: "updated" });
        } else {
          results.push({ uid: userId, email: data.email, phone: e164Phone, status: "already matching" });
        }
      } catch (err) {
        results.push({ uid: userId, email: data.email, phone: e164Phone, status: `error: ${err.message}` });
      }
    }

    res.status(200).json({ success: true, count: results.length, results });
  } catch (error) {
    console.error("syncAllUsersAuthPhone Error:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Create a new user (Shop Owner or Admin) from the admin panel.
 * Only authenticated users with admin role can call this.
 * Allows setting the phone number directly.
 */
exports.createAdminUser = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  // Check if caller is admin
  const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
  const adminDoc = await admin.firestore().collection('admin').doc(callerUid).get();
  
  if (!(adminDoc.exists || (callerDoc.exists && callerDoc.data().role === 'admin'))) {
    throw new HttpsError("permission-denied", "Only admins can create users.");
  }

  const { email, password, name, mobileNumber, role } = request.data || {};
  if (!email || !password) {
    throw new HttpsError("invalid-argument", "Email and password are required.");
  }

  // Format mobile number to E.164
  let e164Phone = undefined;
  if (mobileNumber) {
    let clean = String(mobileNumber).replace(/[+\s-]/g, "");
    if (clean.length === 10) {
      clean = `91${clean}`;
    }
    e164Phone = `+${clean}`;
  }

  try {
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: name,
      ...(e164Phone && { phoneNumber: e164Phone }),
      emailVerified: true
    });

    return { success: true, uid: userRecord.uid };
  } catch (error) {
    console.error("createAdminUser Error:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Reset User Password with Mobile & OTP Verification
 * Data payload: { mobileNumber: '9876543210', otp: '1234', reqId: '...', newPassword: '...' }
 */
exports.resetPasswordWithMobile = onCall(async (request) => {
  const { mobileNumber, otp, reqId, newPassword } = request.data || {};

  if (!mobileNumber) {
    throw new HttpsError("invalid-argument", "Mobile number is required.");
  }
  if (!newPassword || newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }

  // 1. Clean mobile number
  let cleanMobile = String(mobileNumber).replace(/[+\s-]/g, "").trim();
  let raw10 = cleanMobile;
  if (cleanMobile.startsWith("91") && cleanMobile.length === 12) {
    raw10 = cleanMobile.substring(2);
  } else if (cleanMobile.length === 10) {
    cleanMobile = `91${cleanMobile}`;
  }

  // 2. Verify OTP with MSG91 if otp is provided
  if (otp) {
    try {
      const verifyRes = await axios.get(`${MSG91_BASE}/otp/verify`, {
        params: {
          authkey: MSG91_AUTH_KEY,
          otp: String(otp).trim(),
          mobile: cleanMobile,
          ...(reqId ? { reqId } : {}),
        },
      });

      const resData = verifyRes.data || {};
      console.log("resetPasswordWithMobile MSG91 response:", JSON.stringify(resData));
      if (resData.type === "error") {
        throw new HttpsError("unauthenticated", resData.message || "Invalid OTP code.");
      }
    } catch (error) {
      console.error("resetPasswordWithMobile OTP error:", error);
      if (error instanceof HttpsError) throw error;
      const errMsg = error.response?.data?.message || error.message || "OTP verification failed.";
      throw new HttpsError("unauthenticated", String(errMsg));
    }
  }

  // 3. Find user in Firestore users collection
  let targetUid = null;
  let targetEmail = null;

  const usersSnap = await admin.firestore().collection("users")
    .where("mobileNumber", "in", [raw10, cleanMobile, `+${cleanMobile}`])
    .limit(1)
    .get();

  if (!usersSnap.empty) {
    const doc = usersSnap.docs[0];
    targetUid = doc.id;
    targetEmail = doc.data().email;
  } else {
    // Try finding in Auth directly by phoneNumber
    try {
      const authUser = await admin.auth().getUserByPhoneNumber(`+${cleanMobile}`);
      targetUid = authUser.uid;
      targetEmail = authUser.email;
    } catch (_) {}
  }

  if (!targetUid) {
    throw new HttpsError("not-found", "No account found matching this mobile number.");
  }

  // 4. Update the password via Admin Auth
  try {
    await admin.auth().updateUser(targetUid, { password: newPassword });
    console.log(`resetPasswordWithMobile: successfully updated password for uid ${targetUid}`);
    return {
      success: true,
      email: targetEmail,
      message: "Password reset successfully. You can now log in with your new password.",
    };
  } catch (err) {
    console.error("resetPasswordWithMobile updateUser error:", err);
    throw new HttpsError("internal", err.message || "Failed to update password.");
  }
});

/**
 * Check if a customer account exists with the given mobile number.
 * Can be called anonymously by users resetting their password.
 */
exports.checkMobileRegistered = onCall(async (request) => {
  const { mobileNumber } = request.data || {};
  if (!mobileNumber) {
    throw new HttpsError("invalid-argument", "Mobile number is required.");
  }

  let cleanMobile = String(mobileNumber).replace(/[+\s-]/g, "").trim();
  let raw10 = cleanMobile;
  if (cleanMobile.startsWith("91") && cleanMobile.length === 12) {
    raw10 = cleanMobile.substring(2);
  } else if (cleanMobile.length === 10) {
    cleanMobile = `91${cleanMobile}`;
  }

  const variations = [raw10, cleanMobile, `+${cleanMobile}`, `+91 ${raw10}`];
  
  try {
    const query = await admin.firestore().collection("users")
      .where("mobileNumber", "in", variations)
      .limit(1)
      .get();

    if (!query.empty) {
      const doc = query.docs[0];
      return {
        exists: true,
        email: doc.data().email || "",
      };
    }

    // Also check Firebase Auth by phone number
    try {
      const authUser = await admin.auth().getUserByPhoneNumber(`+${cleanMobile}`);
      return { exists: true, email: authUser.email || "" };
    } catch (_) {
      return { exists: false };
    }
  } catch (error) {
    console.error("checkMobileRegistered error:", error);
    throw new HttpsError("internal", error.message || "Error checking mobile number.");
  }
});


