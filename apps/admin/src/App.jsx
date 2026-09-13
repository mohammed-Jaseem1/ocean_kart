import { useState, useEffect } from 'react'
import { onAuthStateChanged, signOut } from 'firebase/auth'
import { doc, getDoc } from 'firebase/firestore'
import { auth, db } from './firebase'
import Homepage from './components/Homepage'
import Loginpage from './components/Loginpage'
import './App.css'

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser) {
        try {
          const uid = currentUser.uid;
          const adminDocSnap = await getDoc(doc(db, 'admin', uid));

          if (adminDocSnap.exists()) {
            setUser(currentUser);
          } else {
            await signOut(auth);
            setUser(null);
          }
        } catch (err) {
          console.error('Admin verification error:', err);
          await signOut(auth);
          setUser(null);
        }
      } else {
        setUser(null);
      }
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
        background: 'var(--bg-base)',
        color: 'var(--text-primary)',
        fontFamily: 'Inter, sans-serif'
      }}>
        <div style={{ fontSize: '1rem', fontWeight: '500', letterSpacing: '0.5px' }}>
          Loading OceanKart Admin...
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
