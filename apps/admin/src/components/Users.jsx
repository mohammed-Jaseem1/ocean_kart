import React, { useState, useEffect } from 'react';
import { collection, query, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';

const Users = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterRole, setFilterRole] = useState('All');
  const [actionLoading, setActionLoading] = useState(null);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'users'));
      const snapshot = await getDocs(q);
      const fetched = [];
      snapshot.forEach((docSnap) => {
        fetched.push({ id: docSnap.id, ...docSnap.data() });
      });
      setUsers(fetched);
    } catch (err) {
      console.error('Error fetching users:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateStatus = async (userId, newStatus) => {
    setActionLoading(userId);
    try {
      await updateDoc(doc(db, 'users', userId), { status: newStatus });
      setUsers(prev =>
        prev.map(item => item.id === userId ? { ...item, status: newStatus } : item)
      );
    } catch (err) {
      console.error('Error updating user status:', err);
      alert('Failed to update user status: ' + err.message);
    } finally {
      setActionLoading(null);
    }
  };

  const filteredUsers = users.filter(user => {
    const name = user.name || user.email || '';
    const matchesSearch = name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (user.mobileNumber && user.mobileNumber.includes(searchTerm));
    const role = (user.role || 'customer').toLowerCase();
    const matchesFilter = filterRole === 'All' || role === filterRole.toLowerCase();
    return matchesSearch && matchesFilter;
  });

  return (
    <div className="card">
      <div className="page-header" style={{ marginBottom: '1.5rem' }}>
        <div>
          <h2 className="page-title" style={{ fontSize: '1.5rem' }}>Registered App Users</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            View and manage all registered customer user accounts.
          </p>
        </div>

        <div className="toolbar" style={{ marginBottom: 0 }}>
          <input
            type="text"
            className="form-input"
            placeholder="Search user name or phone..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{ width: '320px', maxWidth: '100%' }}
          />

          <select
            value={filterRole}
            onChange={(e) => setFilterRole(e.target.value)}
            className="form-select"
          >
            <option value="All">All Roles</option>
            <option value="customer">Customers</option>
            <option value="shopkeeper">Shop Keepers</option>
            <option value="delivery_partner">Delivery Partners</option>
          </select>
        </div>
      </div>

      <div className="table-container">
        <table className="table">
          <thead>
            <tr>
              <th>User Name</th>
              <th>Contact Info</th>
              <th>Role</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan="5" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
                  Loading users...
                </td>
              </tr>
            ) : filteredUsers.length > 0 ? (
              filteredUsers.map((u) => {
                const userRole = u.role || 'customer';
                const userStatus = (u.status || 'active').toLowerCase();
                return (
                  <tr key={u.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div style={{
                          width: '36px', height: '36px', borderRadius: '50%',
                          backgroundColor: 'var(--primary-light)', color: 'var(--primary)',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          fontWeight: '700', fontSize: '0.875rem'
                        }}>
                          {(u.name || u.email || 'U').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                            {u.name || 'OceanKart User'}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div style={{ fontSize: '0.85rem', color: 'var(--text-primary)', fontWeight: '500' }}>
                        {u.email || 'No Email'}
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                        {u.mobileNumber ? `+91 ${u.mobileNumber}` : 'No Phone'}
                      </div>
                    </td>
                    <td style={{ fontSize: '0.85rem', textTransform: 'capitalize', fontWeight: '500', color: 'var(--text-primary)' }}>
                      {userRole.replace('_', ' ')}
                    </td>
                    <td>
                      <span className={`badge ${userStatus === 'suspended' ? 'badge-danger' : userStatus === 'pending' ? 'badge-warning' : 'badge-success'}`}>
                        {userStatus === 'active' ? 'Active' : userStatus === 'suspended' ? 'Suspended' : 'Pending'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        {userStatus !== 'active' ? (
                          <button
                            onClick={() => handleUpdateStatus(u.id, 'active')}
                            disabled={actionLoading === u.id}
                            className="btn btn-success btn-sm"
                          >
                            Activate
                          </button>
                        ) : (
                          <button
                            onClick={() => handleUpdateStatus(u.id, 'suspended')}
                            disabled={actionLoading === u.id}
                            className="btn btn-danger btn-sm"
                          >
                            Suspend
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })
            ) : (
              <tr>
                <td colSpan="5" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
                  No users found matching search criteria.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Users;
