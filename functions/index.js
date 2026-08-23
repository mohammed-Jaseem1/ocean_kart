const { onCall, HttpsError } = require("firebase-functions/v2/https");
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
