import React, { useState } from 'react';
import './Loginpage.css';
import logoImg from '../assets/images/HomeScreen.png';
import { auth, db } from '../firebase';
import { signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';

const Loginpage = () => {
  const [showPassword, setShowPassword] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const uid = userCredential.user.uid;

      // Check exclusively if document exists in 'admin' collection
      const adminDocSnap = await getDoc(doc(db, 'admin', uid));

      if (!adminDocSnap.exists()) {
        await signOut(auth);
        setError('Access Denied. Only authorized administrators can log into this portal.');
        return;
      }

      console.log('Successfully signed in as Admin!');
    } catch (err) {
      console.error('Firebase Auth Error:', err);
      let message = 'Failed to sign in. Please try again.';
      if (err.code === 'auth/invalid-credential') {
        message = 'Invalid email or password.';
      } else if (err.code === 'auth/user-not-found') {
        message = 'No admin account found with this email.';
      } else if (err.code === 'auth/wrong-password') {
        message = 'Incorrect password.';
      }
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page-container">
      <div className="login-card-poyoka">
        {/* Logo */}
        <div className="login-card-logo">
          <img src={logoImg} alt="OceanKart Logo" />
        </div>

        <h2 className="login-card-title">Admin Portal</h2>
        <p className="login-card-subtitle">Sign in to manage your OceanKart platform</p>

        {error && <div className="login-error-banner">{error}</div>}

        {/* Login Form */}
        <form className="login-form-group" onSubmit={handleLogin}>
          {/* Email Field */}
          <div className="form-group">
            <label htmlFor="email" className="form-label">Email Address</label>
            <div className="login-field-wrapper">
              <svg className="login-field-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
                <polyline points="22,6 12,13 2,6"/>
              </svg>
              <input
                id="email"
                type="email"
                className="login-input-field"
                placeholder="admin@oceankart.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={loading}
                required
              />
            </div>
          </div>

          {/* Password Field */}
          <div className="form-group">
            <label htmlFor="password" className="form-label">Password</label>
            <div className="login-field-wrapper">
              <svg className="login-field-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
              </svg>
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                className="login-input-field"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={loading}
                required
              />
              <button
                type="button"
                className="login-toggle-pw"
                onClick={() => setShowPassword(!showPassword)}
                id="toggle-password-btn"
                aria-label="Toggle password visibility"
                disabled={loading}
              >
                {showPassword ? (
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/>
                    <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/>
                    <line x1="1" y1="1" x2="23" y2="23"/>
                  </svg>
                ) : (
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                    <circle cx="12" cy="12" r="3"/>
                  </svg>
                )}
              </button>
            </div>
          </div>

          {/* Login Button */}
          <button type="submit" className="btn btn-primary login-submit-btn" id="login-submit-btn" disabled={loading}>
            <span>{loading ? 'Signing In...' : 'Sign In to Dashboard'}</span>
          </button>
        </form>

        <p className="login-footer-text">
          Only authorized admin accounts can access this portal.
        </p>
      </div>
    </div>
  );
};

export default Loginpage;
