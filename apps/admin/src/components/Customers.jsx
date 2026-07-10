import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, doc, deleteDoc } from 'firebase/firestore';
import { db } from '../firebase';

const Customers = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const q = query(
        collection(db, 'users'),
        where('status', '==', 'active')
      );
      const querySnapshot = await getDocs(q);
      const fetchedUsers = [];
      querySnapshot.forEach((doc) => {
        fetchedUsers.push({ id: doc.id, ...doc.data() });
      });
      setUsers(fetchedUsers);
      setError(null);
    } catch (err) {
      console.error("Error fetching users: ", err);
      setError("Failed to fetch users.");
    } finally {
      setLoading(false);
    }
  };

  const handleRemove = async (userId) => {
    if (!window.confirm("Are you sure you want to remove this user?")) return;
    try {
      await deleteDoc(doc(db, 'users', userId));
      setUsers(users.filter(u => u.id !== userId));
    } catch (err) {
      console.error("Error removing user: ", err);
      alert("Failed to remove user.");
    }
  };

  if (loading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
        Loading users...
      </div>
    );
  }

  return (
    <section className="table-card" style={{ marginTop: '0' }}>
      <div className="table-header">
        <h2>Registered Users</h2>
        <div style={{ color: '#64748b', fontSize: '14px', fontWeight: '500' }}>
          Total Active Users: {users.length}
        </div>
      </div>

      {error && (
        <div style={{ padding: '16px', color: '#ff4757', background: 'rgba(255, 71, 87, 0.1)', borderRadius: '8px', marginBottom: '20px' }}>
          {error}
        </div>
      )}

      {users.length === 0 ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#64748b', fontSize: '15px' }}>
          No active users found.
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
                <th>Date Joined</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => {
                const date = user.createdAt?.toDate ? user.createdAt.toDate().toLocaleDateString() : 'Unknown';
                
                let roleColor = '#00b4d8';
                let roleBg = 'rgba(0, 180, 216, 0.1)';
                if (user.role === 'Delivery Boy') {
                    roleColor = '#ffa502';
                    roleBg = 'rgba(255, 165, 2, 0.1)';
                } else if (user.role === 'Customer') {
                    roleColor = '#2ed573';
                    roleBg = 'rgba(46, 213, 115, 0.1)';
                }

                return (
                  <tr key={user.id}>
                    <td>
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '12px',
                        fontSize: '12px',
                        fontWeight: '600',
                        background: roleBg,
                        color: roleColor,
                        whiteSpace: 'nowrap'
                      }}>
                        {user.role || 'Customer'}
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
                      <div style={{ fontSize: '12px', color: '#64748b' }}>{user.mobileNumber || user.phone || 'No phone'}</div>
                    </td>
                    <td>
                      <div>{user.city || 'N/A'}</div>
                      <div style={{ fontSize: '12px', color: '#64748b' }}>{user.district || ''}</div>
                    </td>
                    <td>{date}</td>
                    <td>
                      <button
                        onClick={() => handleRemove(user.id)}
                        style={{
                          background: 'rgba(255, 71, 87, 0.15)',
                          color: '#ff4757',
                          border: '1px solid rgba(255, 71, 87, 0.2)',
                          padding: '8px 16px',
                          borderRadius: '8px',
                          fontWeight: '600',
                          cursor: 'pointer',
                          transition: 'all 0.2s'
                        }}
                        onMouseOver={(e) => {
                          e.currentTarget.style.background = '#ff4757';
                          e.currentTarget.style.color = '#fff';
                        }}
                        onMouseOut={(e) => {
                          e.currentTarget.style.background = 'rgba(255, 71, 87, 0.15)';
                          e.currentTarget.style.color = '#ff4757';
                        }}
                      >
                        Remove
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

export default Customers;
