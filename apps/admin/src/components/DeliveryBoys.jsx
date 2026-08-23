import React, { useState, useEffect } from 'react';
import { collection, query, getDocs, doc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase';

const DeliveryBoys = () => {
  const [deliveryPartners, setDeliveryPartners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  const [actionLoading, setActionLoading] = useState(null);

  useEffect(() => {
    fetchDeliveryPartners();
  }, []);

  const fetchDeliveryPartners = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'users'));
      const snapshot = await getDocs(q);
      const fetched = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        if (data.role === 'delivery_partner' || data.vehicleNumber || data.deliveryStatus) {
          fetched.push({ id: docSnap.id, ...data });
        }
      });
      setDeliveryPartners(fetched);
    } catch (err) {
      console.error('Error fetching delivery partners:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateStatus = async (partnerId, newStatus) => {
    setActionLoading(partnerId);
    try {
      await updateDoc(doc(db, 'users', partnerId), { status: newStatus });
      setDeliveryPartners(prev =>
        prev.map(item => item.id === partnerId ? { ...item, status: newStatus } : item)
      );
    } catch (err) {
      console.error('Error updating delivery partner status:', err);
      alert('Failed to update status: ' + err.message);
    } finally {
      setActionLoading(null);
    }
  };

  const filteredPartners = deliveryPartners.filter(p => {
    const name = p.name || p.email || '';
    const matchesSearch = name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (p.mobileNumber && p.mobileNumber.includes(searchTerm)) ||
      (p.vehicleNumber && p.vehicleNumber.toLowerCase().includes(searchTerm.toLowerCase()));
    const status = (p.status || 'pending').toLowerCase();
    const matchesFilter = filterStatus === 'All' || status === filterStatus.toLowerCase();
    return matchesSearch && matchesFilter;
  });

  return (
    <div className="table-card">
      <div className="table-header" style={{ flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h2>Delivery Boys & Partners</h2>
          <p style={{ color: '#64748b', fontSize: '13px', margin: '4px 0 0' }}>
            Manage delivery personnel, check vehicle verification, and handle active approvals.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          <div className="search-bar" style={{ maxWidth: '240px' }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search partner or vehicle..."
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
              <th>Delivery Partner</th>
              <th>Contact Details</th>
              <th>Vehicle Details</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan="5" style={{ textAlign: 'center', padding: '30px', color: '#64748b' }}>
                  Loading delivery partners...
                </td>
              </tr>
            ) : filteredPartners.length > 0 ? (
              filteredPartners.map((partner) => {
                const currentStatus = (partner.status || 'pending').toLowerCase();
                return (
                  <tr key={partner.id}>
                    <td>
                      <div className="customer-cell">
                        <div className="customer-avatar" style={{ background: '#ffa502', color: '#fff' }}>
                          {(partner.name || partner.email || 'D').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: '600', color: '#0f172a' }}>
                            {partner.name || 'Delivery Rider'}
                          </div>
                          <div style={{ fontSize: '11px', color: '#64748b' }}>
                            ID: {partner.id.substring(0, 8)}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div style={{ fontSize: '13px', color: '#334155', fontWeight: '500' }}>
                        {partner.email || 'No Email'}
                      </div>
                      <div style={{ fontSize: '12px', color: '#64748b' }}>
                        {partner.mobileNumber ? `+91 ${partner.mobileNumber}` : 'No Phone'}
                      </div>
                    </td>
                    <td>
                      <div style={{ fontSize: '13px', fontWeight: '600', color: '#0f172a' }}>
                        {partner.vehicleNumber || partner.vehicleType || 'Motorcycle / Scooter'}
                      </div>
                      <div style={{ fontSize: '11px', color: '#64748b' }}>
                        DL: Verified
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${currentStatus}`}>
                        {currentStatus === 'active' ? 'Active Duty' : currentStatus === 'pending' ? 'Pending Approval' : 'Suspended'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        {currentStatus !== 'active' && (
                          <button
                            onClick={() => handleUpdateStatus(partner.id, 'active')}
                            disabled={actionLoading === partner.id}
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
                            onClick={() => handleUpdateStatus(partner.id, 'suspended')}
                            disabled={actionLoading === partner.id}
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
                  No delivery partners found matching filter.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default DeliveryBoys;
