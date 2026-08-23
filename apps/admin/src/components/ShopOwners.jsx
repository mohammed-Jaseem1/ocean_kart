import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';

const ShopOwners = () => {
  const [shopOwners, setShopOwners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  const [actionLoading, setActionLoading] = useState(null);

  useEffect(() => {
    fetchShopOwners();
  }, []);

  const fetchShopOwners = async () => {
    setLoading(true);
    try {
      // Query users collection for partners / shop_keepers or users with shop details
      const q = query(collection(db, 'users'));
      const snapshot = await getDocs(q);
      const fetched = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        // Include shop keepers or partners
        if (data.role === 'shop_keeper' || data.role === 'partner' || data.shopName) {
          fetched.push({ id: docSnap.id, ...data });
        }
      });
      setShopOwners(fetched);
    } catch (err) {
      console.error('Error fetching shop owners:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateStatus = async (ownerId, newStatus) => {
    setActionLoading(ownerId);
    try {
      await updateDoc(doc(db, 'users', ownerId), { status: newStatus });
      setShopOwners(prev =>
        prev.map(item => item.id === ownerId ? { ...item, status: newStatus } : item)
      );
    } catch (err) {
      console.error('Error updating shop owner status:', err);
      alert('Failed to update status: ' + err.message);
    } finally {
      setActionLoading(null);
    }
  };

  const filteredOwners = shopOwners.filter(owner => {
    const name = owner.name || owner.shopName || owner.email || '';
    const matchesSearch = name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (owner.mobileNumber && owner.mobileNumber.includes(searchTerm));
    const matchesFilter = filterStatus === 'All' || (owner.status || 'pending').toLowerCase() === filterStatus.toLowerCase();
    return matchesSearch && matchesFilter;
  });

  return (
    <div className="table-card">
      <div className="table-header" style={{ flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h2>Shop Owners & Partners</h2>
          <p style={{ color: '#64748b', fontSize: '13px', margin: '4px 0 0' }}>
            Manage registered shop keepers, view store locations, and handle approvals.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          <div className="search-bar" style={{ maxWidth: '240px' }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search shop name..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            style={{
              padding: '10px 14px',
              borderRadius: '10px',
              border: '1px solid #cbd5e1',
              background: '#ffffff',
              color: '#0f172a',
              fontSize: '13px',
              fontWeight: '500',
              outline: 'none',
              cursor: 'pointer'
            }}
          >
            <option value="All">All Status</option>
            <option value="active">Active</option>
            <option value="pending">Pending Approval</option>
            <option value="suspended">Suspended</option>
          </select>
        </div>
      </div>

      <div className="custom-table-wrapper">
        <table className="custom-table">
          <thead>
            <tr>
              <th>Shop & Owner</th>
              <th>Contact Details</th>
              <th>Location</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan="5" style={{ textAlign: 'center', padding: '30px', color: '#64748b' }}>
                  Loading shop owners...
                </td>
              </tr>
            ) : filteredOwners.length > 0 ? (
              filteredOwners.map((owner) => {
                const currentStatus = (owner.status || 'pending').toLowerCase();
                return (
                  <tr key={owner.id}>
                    <td>
                      <div className="customer-cell">
                        <div className="customer-avatar" style={{ background: '#00b4d8', color: '#fff' }}>
                          {(owner.shopName || owner.name || 'S').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: '600', color: '#0f172a' }}>
                            {owner.shopName || owner.name || 'OceanKart Shop'}
                          </div>
                          <div style={{ fontSize: '12px', color: '#64748b' }}>
                            Owner: {owner.name || 'N/A'}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div style={{ fontSize: '13px', color: '#334155', fontWeight: '500' }}>
                        {owner.email || 'No Email'}
                      </div>
                      <div style={{ fontSize: '12px', color: '#64748b' }}>
                        {owner.mobileNumber ? `+91 ${owner.mobileNumber}` : 'No Phone'}
                      </div>
                    </td>
                    <td style={{ fontSize: '13px', color: '#475569' }}>
                      {owner.address || owner.shopAddress || 'Kerala, India'}
                    </td>
                    <td>
                      <span className={`badge ${currentStatus}`}>
                        {currentStatus === 'active' ? 'Active' : currentStatus === 'pending' ? 'Pending Approval' : 'Suspended'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        {currentStatus !== 'active' && (
                          <button
                            onClick={() => handleUpdateStatus(owner.id, 'active')}
                            disabled={actionLoading === owner.id}
                            style={{
                              padding: '6px 12px',
                              borderRadius: '6px',
                              border: 'none',
                              background: '#2ed573',
                              color: '#fff',
                              fontSize: '12px',
                              fontWeight: '600',
                              cursor: 'pointer'
                            }}
                          >
                            Approve
                          </button>
                        )}
                        {currentStatus !== 'suspended' && (
                          <button
                            onClick={() => handleUpdateStatus(owner.id, 'suspended')}
                            disabled={actionLoading === owner.id}
                            style={{
                              padding: '6px 12px',
                              borderRadius: '6px',
                              border: '1px solid #ff4757',
                              background: 'transparent',
                              color: '#ff4757',
                              fontSize: '12px',
                              fontWeight: '600',
                              cursor: 'pointer'
                            }}
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
                <td colSpan="5" style={{ textAlign: 'center', padding: '30px', color: '#64748b' }}>
                  No shop owners found matching filter.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default ShopOwners;
