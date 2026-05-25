import { useState } from 'react'
import Homepage from './components/Homepage'
import Loginpage from './components/Loginpage'
import './App.css'

function App() {
  const [page, setPage] = useState('home'); // 'home' | 'login'

  return (
    <>
      {page === 'home' && (
        <div style={{ position: 'relative' }}>
          <Homepage />
          {/* Floating Login Button over home screen */}
          <button
            id="go-to-login-btn"
            onClick={() => setPage('login')}
            style={{
              position: 'fixed',
              top: '24px',
              right: '28px',
              padding: '12px 28px',
              background: 'linear-gradient(135deg, #0288d1, #00b4d8)',
              color: '#fff',
              border: 'none',
              borderRadius: '30px',
              fontSize: '15px',
              fontWeight: '700',
              fontFamily: 'Inter, sans-serif',
              cursor: 'pointer',
              boxShadow: '0 4px 18px rgba(0,180,216,0.5)',
              zIndex: 100,
              transition: 'all 0.3s ease',
              letterSpacing: '0.3px',
            }}
          >
            Sign In →
          </button>
        </div>
      )}
      {page === 'login' && <Loginpage />}
    </>
  )
}

export default App

