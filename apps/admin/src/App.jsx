import { useState, useEffect } from 'react'
import { onAuthStateChanged, signOut } from 'firebase/auth'
import { auth } from './firebase'
import Homepage from './components/Homepage'
import Loginpage from './components/Loginpage'
import UserApprovals from './components/UserApprovals';

import './App.css'

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  const handleSignOut = async () => {
    try {
      await signOut(auth);
    } catch (error) {
      console.error("Sign out error:", error);
    }
  };

  if (loading) {
    return (
      <div className="loading-screen" style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '100vh',
        background: '#0a1628',
        color: '#fff',
        fontFamily: 'Inter, sans-serif'
      }}>
        <div style={{ fontSize: '18px', fontWeight: '500', letterSpacing: '0.5px' }}>
          Loading OceanKart...
        </div>
      </div>
    );
  }

  return (
    <>
      {user ? (
        <Homepage user={user} onSignOut={handleSignOut} />
      ) : (
        <Loginpage />
      )}
    </>
  )
}

export default App


