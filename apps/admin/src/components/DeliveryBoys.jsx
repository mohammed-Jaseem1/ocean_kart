import React, { useState, useEffect } from 'react';
import { collection, query, getDocs, doc, updateDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { createUserWithEmailAndPassword, signOut } from 'firebase/auth';
import { db, secondaryAuth } from '../firebase';

const DeliveryBoys = () => {
  const [deliveryPartners, setDeliveryPartners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  const [actionLoading, setActionLoading] = useState(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [addingUser, setAddingUser] = useState(false);
  const [formData, setFormData] = useState({
    name: '', mobileNumber: '', email: '', password: '',
    location: '', landmark: '', address: '', pincode: ''
  });

  const inputStyle = { 
    padding: '10px 14px', 
    borderRadius: '8px', 
    border: '1px solid #cbd5e1', 
    fontSize: '14px', 
    outline: 'none', 
    boxSizing: 'border-box', 
    width: '100%',
    background: '#f8fafc',
    color: '#0f172a'
  };

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

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleAddSubmit = async (e) => {
    e.preventDefault();
    setAddingUser(true);
    try {
      const userCred = await createUserWithEmailAndPassword(secondaryAuth, formData.email, formData.password);
      const uid = userCred.user.uid;
      
      await setDoc(doc(db, 'users', uid), {
        uid,
        email: formData.email,
        role: 'Delivery Boy',
        name: formData.name,
        mobileNumber: formData.mobileNumber,
        address: formData.address,
        houseAddress: formData.address,
        location: formData.location,
        landmark: formData.landmark,
        pincode: formData.pincode,
        status: 'active',
        emailVerified: true,
        isPhoneVerified: true,
        createdAt: serverTimestamp()
      });
      
      await signOut(secondaryAuth);
      setShowAddModal(false);
      setFormData({
        name: '', mobileNumber: '', email: '', password: '',
        location: '', landmark: '', address: '', pincode: ''
      });
      fetchDeliveryPartners();
      alert('Delivery Partner added and verified successfully!');
    } catch (err) {
      console.error('Error adding delivery partner:', err);
      alert('Failed to add delivery partner: ' + err.message);
    } finally {
      setAddingUser(false);
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
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <h2 style={{ margin: 0 }}>Delivery Boys & Partners</h2>
            <button 
              onClick={() => setShowAddModal(true)}
              style={{ padding: '8px 14px', background: '#0284c7', color: '#fff', border: 'none', borderRadius: '8px', fontWeight: '600', fontSize: '13px', cursor: 'pointer' }}>
              + Add Delivery Partner
            </button>
          </div>
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

      {showAddModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(15, 23, 42, 0.65)', backdropFilter: 'blur(4px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ background: '#ffffff', padding: '28px', borderRadius: '16px', width: '90%', maxWidth: '620px', maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)', border: '1px solid #e2e8f0' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', borderBottom: '1px solid #f1f5f9', paddingBottom: '12px' }}>
              <h2 style={{ margin: 0, fontSize: '20px', color: '#0f172a', fontWeight: '700' }}>Add New Delivery Partner</h2>
              <button onClick={() => setShowAddModal(false)} style={{ background: 'transparent', border: 'none', fontSize: '24px', cursor: 'pointer', color: '#64748b' }}>&times;</button>
            </div>
            <form onSubmit={handleAddSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Full Name *</label>
                  <input required name="name" value={formData.name} onChange={handleInputChange} placeholder="e.g. Rahul Kumar" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Phone Number *</label>
                  <input required name="mobileNumber" value={formData.mobileNumber} onChange={handleInputChange} placeholder="e.g. 9876543210" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Email Address *</label>
                  <input required type="email" name="email" value={formData.email} onChange={handleInputChange} placeholder="e.g. partner@example.com" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Password *</label>
                  <input required type="password" name="password" value={formData.password} onChange={handleInputChange} placeholder="••••••••" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Location *</label>
                  <input required name="location" value={formData.location} onChange={handleInputChange} placeholder="e.g. Kochi" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Landmark *</label>
                  <input required name="landmark" value={formData.landmark} onChange={handleInputChange} placeholder="e.g. Near Bus Stand" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', gridColumn: 'span 2' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Pincode *</label>
                  <input required name="pincode" value={formData.pincode} onChange={handleInputChange} placeholder="e.g. 682001" style={inputStyle} />
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Full Address *</label>
                <textarea required name="address" value={formData.address} onChange={handleInputChange} placeholder="Enter complete home address..." style={{ ...inputStyle, minHeight: '80px', resize: 'vertical' }} />
              </div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '12px', borderTop: '1px solid #f1f5f9', paddingTop: '16px' }}>
                <button type="button" onClick={() => setShowAddModal(false)} style={{ padding: '10px 20px', borderRadius: '8px', border: '1px solid #cbd5e1', background: '#ffffff', color: '#475569', cursor: 'pointer', fontWeight: '600', fontSize: '14px' }}>Cancel</button>
                <button type="submit" disabled={addingUser} style={{ padding: '10px 20px', borderRadius: '8px', border: 'none', background: addingUser ? '#94a3b8' : '#0284c7', color: '#ffffff', cursor: addingUser ? 'not-allowed' : 'pointer', fontWeight: '600', fontSize: '14px' }}>
                  {addingUser ? 'Adding...' : 'Add Partner'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

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
