const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");
require("dotenv").config();

admin.initializeApp();

const MSG91_AUTH_KEY = process.env.MSG91_AUTH_KEY || "563466AVJB6j1dq9f6a8a80c1P1";
const MSG91_WIDGET_ID = process.env.MSG91_WIDGET_ID || "366877666949303632383336";
const MSG91_BASE = "https://control.msg91.com/api/v5";

/**
 * Send OTP callable Cloud Function — uses MSG91 Widget API
 * Data payload: { identifier: '919876543210' }
 */
exports.sendOtp = onCall(async (request) => {
  const { identifier } = request.data || {};
  if (!identifier) {
    throw new HttpsError("invalid-argument", "The 'identifier' field is required.");
  }

  // Ensure no leading + or spaces; 10-digit numbers get 91 prefix
  let cleanIdentifier = String(identifier).replace(/[+\s-]/g, "");
  if (!cleanIdentifier.includes("@") && cleanIdentifier.length === 10) {
    cleanIdentifier = `91${cleanIdentifier}`;
  }

  console.log(`sendOtp: sending to ${cleanIdentifier}`);

  try {
    // MSG91 Widget API — correct endpoint for widget-based OTP
    const response = await axios.post(
      `${MSG91_BASE}/widget/sendOTP`,
      { identifier: cleanIdentifier },
      {
        headers: {
          authkey: MSG91_AUTH_KEY,
          widgetId: MSG91_WIDGET_ID,
          "Content-Type": "application/json",
        },
      }
    );

    const resData = response.data || {};
    console.log("sendOtp MSG91 response:", JSON.stringify(resData));

    // MSG91 widget API returns { type: 'success', message: '<reqId>' }
    if (resData.type === "error") {
      throw new HttpsError("internal", resData.message || "MSG91 returned error.");
    }

    return {
      success: true,
      reqId: resData.message || resData.reqId || resData.request_id || "",
      data: resData,
    };
  } catch (error) {
    const errMsg = error.response?.data?.message || error.response?.data || error.message || "Failed to send OTP via MSG91.";
    console.error("sendOtp Error:", errMsg);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", String(errMsg));
  }
});

/**
 * Retry OTP callable Cloud Function — uses MSG91 Widget retryOTP API
 * Data payload: { reqId: '...', retryChannel: 11 }
 */
exports.retryOtp = onCall(async (request) => {
  const { reqId, retryChannel } = request.data || {};
  if (!reqId) {
    throw new HttpsError("invalid-argument", "The 'reqId' field is required.");
  }

  try {
    const response = await axios.post(
      `${MSG91_BASE}/widget/retryOTP`,
      { reqId, retryChannel: retryChannel || 11 },
      {
        headers: {
          authkey: MSG91_AUTH_KEY,
          widgetId: MSG91_WIDGET_ID,
          "Content-Type": "application/json",
        },
      }
    );

    const resData = response.data || {};
    console.log("retryOtp MSG91 response:", JSON.stringify(resData));
    return { success: true, data: resData };
  } catch (error) {
    const errMsg = error.response?.data?.message || error.message || "Failed to retry OTP via MSG91.";
    console.error("retryOtp Error:", errMsg);
    throw new HttpsError("internal", String(errMsg));
  }
});

/**
 * Verify OTP & Generate Firebase Custom Token — uses MSG91 Widget verifyOTP API
 * Data payload: { reqId: '...', otp: '1234', mobileNumber: '9876543210' }
 */
exports.verifyOtp = onCall(async (request) => {
  const { reqId, otp, mobileNumber } = request.data || {};
  if (!otp) {
    throw new HttpsError("invalid-argument", "The 'otp' field is required.");
  }
  if (!reqId) {
    throw new HttpsError("invalid-argument", "The 'reqId' field is required.");
  }

  try {
    // MSG91 Widget verifyOTP endpoint
    const response = await axios.post(
      `${MSG91_BASE}/widget/verifyOTP`,
      { reqId, otp },
      {
        headers: {
          authkey: MSG91_AUTH_KEY,
          widgetId: MSG91_WIDGET_ID,
          "Content-Type": "application/json",
        },
      }
    );

    const resData = response.data || {};
    console.log("verifyOtp MSG91 response:", JSON.stringify(resData));

    if (resData.type === "error") {
      throw new HttpsError("unauthenticated", resData.message || "Invalid OTP code.");
    }

    // OTP Verified — generate Firebase Custom Token
    const cleanPhone = mobileNumber
      ? mobileNumber.replace(/[+\s-]/g, "")
      : reqId;
    const uid = `phone_${cleanPhone}`;

    const customToken = await admin.auth().createCustomToken(uid, {
      phone: mobileNumber || "",
      verifiedVia: "MSG91_Widget",
    });

    return {
      success: true,
      customToken,
      uid,
      data: resData,
    };
  } catch (error) {
    const errMsg = error.response?.data?.message || error.message || "OTP verification failed.";
    console.error("verifyOtp Error:", errMsg);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", String(errMsg));
  }
});
