import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';

const UserApprovals = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchPendingUsers();
  }, []);

  const fetchPendingUsers = async () => {
    setLoading(true);
    try {
      const q = query(
        collection(db, 'users'),
        where('status', '==', 'pending')
      );
      const querySnapshot = await getDocs(q);
      const fetchedUsers = [];
      querySnapshot.forEach((doc) => {
        fetchedUsers.push({ id: doc.id, ...doc.data() });
      });
      setUsers(fetchedUsers);
      setError(null);
    } catch (err) {
      console.error("Error fetching pending users: ", err);
      setError("Failed to fetch pending requests.");
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (userId) => {
    try {
      const userRef = doc(db, 'users', userId);
      await updateDoc(userRef, {
        status: 'active'
      });
      // Remove from the local state list immediately
      setUsers(users.filter(u => u.id !== userId));
    } catch (err) {
      console.error("Error approving user: ", err);
      alert("Failed to approve user. Please try again.");
    }
  };

  if (loading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
        Loading pending requests...
      </div>
    );
  }

  return (
    <section className="table-card" style={{ marginTop: '0' }}>
      <div className="table-header">
        <h2>Pending Approvals</h2>
      </div>

      {error && (
        <div style={{ padding: '16px', color: '#ff4757', background: 'rgba(255, 71, 87, 0.1)', borderRadius: '8px', marginBottom: '20px' }}>
          {error}
        </div>
      )}

      {users.length === 0 ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#64748b', fontSize: '15px' }}>
          No pending requests at the moment.
        </div>
      ) : (
        <div className="custom-table-wrapper">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Role</th>
                <th>Name</th>
                <th>Contact</th>
                <th>Location</th>
                <th>Date Applied</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => {
                const date = user.createdAt?.toDate ? user.createdAt.toDate().toLocaleDateString() : 'Unknown';
                
                return (
                  <tr key={user.id}>
                    <td>
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '12px',
                        fontSize: '12px',
                        fontWeight: '600',
                        background: user.role === 'Shopkeeper' ? 'rgba(0, 180, 216, 0.1)' : 'rgba(255, 165, 2, 0.1)',
                        color: user.role === 'Shopkeeper' ? '#00b4d8' : '#ffa502',
                        whiteSpace: 'nowrap'
                      }}>
                        {user.role}
                      </span>
                    </td>
                    <td>
                      <div className="customer-cell">
                        <div className="customer-avatar">
                          {user.name ? user.name.charAt(0).toUpperCase() : 'U'}
                        </div>
                        <div>
                          <div style={{ fontWeight: '600' }}>{user.name || 'N/A'}</div>
                          {user.role === 'Shopkeeper' && <div style={{ fontSize: '11px', color: '#00b4d8' }}>{user.shopName}</div>}
                        </div>
                      </div>
                    </td>
                    <td>
                      <div>{user.email || 'N/A'}</div>
                      <div style={{ fontSize: '12px', color: '#64748b' }}>{user.mobileNumber || user.phone}</div>
                    </td>
                    <td>
                      <div>{user.city || 'N/A'}</div>
                      <div style={{ fontSize: '12px', color: '#64748b' }}>{user.district}</div>
                    </td>
                    <td>{date}</td>
                    <td>
                      <button
                        onClick={() => handleApprove(user.id)}
                        style={{
                          background: 'rgba(46, 213, 115, 0.15)',
                          color: '#2ed573',
                          border: '1px solid rgba(46, 213, 115, 0.2)',
                          padding: '8px 16px',
                          borderRadius: '8px',
                          fontWeight: '600',
                          cursor: 'pointer',
                          transition: 'all 0.2s'
                        }}
                        onMouseOver={(e) => {
                          e.currentTarget.style.background = '#2ed573';
                          e.currentTarget.style.color = '#fff';
                        }}
                        onMouseOut={(e) => {
                          e.currentTarget.style.background = 'rgba(46, 213, 115, 0.15)';
                          e.currentTarget.style.color = '#2ed573';
                        }}
                      >
                        Approve
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
};

export default UserApprovals;
