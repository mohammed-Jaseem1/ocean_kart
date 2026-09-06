import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, doc, updateDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { createUserWithEmailAndPassword, signOut } from 'firebase/auth';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { db, app } from '../firebase';
import { keralaPlaces } from '../constants/keralaPlaces';

const ShopOwners = () => {
  const [shopOwners, setShopOwners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  const [actionLoading, setActionLoading] = useState(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
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
    fetchShopOwners();
  }, []);

  const fetchShopOwners = async () => {
    setLoading(true);
    try {
      // Query shop_owners collection directly
      const q = query(collection(db, 'shop_owners'));
      const snapshot = await getDocs(q);
      const fetched = [];
      snapshot.forEach((docSnap) => {
        fetched.push({ id: docSnap.id, ...docSnap.data() });
      });
      setShopOwners(fetched);
    } catch (err) {
      console.error('Error fetching shop owners:', err);
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
      if (isEditing) {
        const updateData = {
          name: formData.name,
          shopName: formData.name,
          mobileNumber: formData.mobileNumber,
          address: formData.address,
          shopAddress: formData.address,
          location: formData.location,
          landmark: formData.landmark,
          pincode: formData.pincode,
        };
        await updateDoc(doc(db, 'shop_owners', editingId), updateData);
        try {
          await updateDoc(doc(db, 'users', editingId), updateData);
        } catch (err) {
          console.log('User doc update optional note:', err);
        }
        alert('Shop Owner updated successfully!');
      } else {
        let uid = null;
        try {
          const functions = getFunctions(app);
          const createAdminUser = httpsCallable(functions, 'createAdminUser');
          const result = await createAdminUser({
            email: formData.email,
            password: formData.password,
            name: formData.name,
            mobileNumber: formData.mobileNumber,
            role: 'Shopkeeper'
          });
          uid = result.data.uid;
        } catch (fnErr) {
          console.warn('Cloud Function createAdminUser unavailable, using secondary auth:', fnErr);
          const userCred = await createUserWithEmailAndPassword(secondaryAuth, formData.email, formData.password);
          uid = userCred.user.uid;
          await signOut(secondaryAuth);
        }
        
        const ownerRecord = {
          uid,
          email: formData.email,
          name: formData.name,
          shopName: formData.name,
          role: 'Shopkeeper',
          mobileNumber: formData.mobileNumber,
          address: formData.address,
          shopAddress: formData.address,
          location: formData.location,
          landmark: formData.landmark,
          pincode: formData.pincode,
          status: 'active',
          emailVerified: true,
          isPhoneVerified: true,
          createdAt: serverTimestamp()
        };

        // Write to both shop_owners and users collections for seamless app login
        await setDoc(doc(db, 'shop_owners', uid), ownerRecord);
        await setDoc(doc(db, 'users', uid), ownerRecord);

        alert('Shop Owner created successfully! They can now log in immediately.');
      }
      
      handleCloseModal();
      fetchShopOwners();
    } catch (err) {
      console.error(isEditing ? 'Error updating shop owner:' : 'Error adding shop owner:', err);
      alert((isEditing ? 'Failed to update shop owner: ' : 'Failed to add shop owner: ') + err.message);
    } finally {
      setAddingUser(false);
    }
  };

  const handleEditClick = (owner) => {
    setFormData({
      name: owner.name || owner.shopName || '',
      mobileNumber: owner.mobileNumber || '',
      email: owner.email || '',
      password: '',
      location: owner.location || '',
      landmark: owner.landmark || '',
      address: owner.address || owner.shopAddress || '',
      pincode: owner.pincode || ''
    });
    setEditingId(owner.id);
    setIsEditing(true);
    setShowAddModal(true);
  };

  const handleCloseModal = () => {
    setShowAddModal(false);
    setIsEditing(false);
    setEditingId(null);
    setFormData({
      name: '', mobileNumber: '', email: '', password: '',
      location: '', landmark: '', address: '', pincode: ''
    });
  };

  const handleUpdateStatus = async (ownerId, newStatus) => {
    setActionLoading(ownerId);
    try {
      await updateDoc(doc(db, 'shop_owners', ownerId), { status: newStatus });
      try {
        await updateDoc(doc(db, 'users', ownerId), { status: newStatus });
      } catch (e) {}
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
    const status = (owner.status || 'active').toLowerCase();
    const matchesFilter = filterStatus === 'All' || 
      (filterStatus.toLowerCase() === 'active' ? status !== 'suspended' : status === 'suspended');
    return matchesSearch && matchesFilter;
  });

  return (
    <div className="table-card">
      <div className="table-header" style={{ flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <h2 style={{ margin: 0 }}>Shop Owners & Partners</h2>
            <button 
              onClick={() => {
                setFormData({
                  name: '', mobileNumber: '', email: '', password: '',
                  location: '', landmark: '', address: '', pincode: ''
                });
                setIsEditing(false);
                setShowAddModal(true);
              }}
              style={{ padding: '8px 14px', background: '#0284c7', color: '#fff', border: 'none', borderRadius: '8px', fontWeight: '600', fontSize: '13px', cursor: 'pointer' }}>
              + Add Shop Owner
            </button>
          </div>
          <p style={{ color: '#64748b', fontSize: '13px', margin: '4px 0 0' }}>
            Manage registered shop keepers, view store locations, and handle business status.
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
            <option value="suspended">Suspended</option>
          </select>
        </div>
      </div>

      {showAddModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(15, 23, 42, 0.65)', backdropFilter: 'blur(4px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ background: '#ffffff', padding: '28px', borderRadius: '16px', width: '90%', maxWidth: '620px', maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)', border: '1px solid #e2e8f0' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', borderBottom: '1px solid #f1f5f9', paddingBottom: '12px' }}>
              <h2 style={{ margin: 0, fontSize: '20px', color: '#0f172a', fontWeight: '700' }}>{isEditing ? 'Edit Shop Owner' : 'Add New Shop Owner'}</h2>
              <button onClick={handleCloseModal} style={{ background: 'transparent', border: 'none', fontSize: '24px', cursor: 'pointer', color: '#64748b' }}>&times;</button>
            </div>
            <form onSubmit={handleAddSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Shop / Owner Name *</label>
                  <input required name="name" value={formData.name} onChange={handleInputChange} placeholder="e.g. Ocean Supermarket" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Phone Number *</label>
                  <input required name="mobileNumber" value={formData.mobileNumber} onChange={handleInputChange} placeholder="e.g. 9876543210" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Email Address *</label>
                  <input required type="email" name="email" value={formData.email} onChange={handleInputChange} disabled={isEditing} placeholder="e.g. owner@example.com" style={{...inputStyle, background: isEditing ? '#e2e8f0' : '#f8fafc', cursor: isEditing ? 'not-allowed' : 'text'}} />
                </div>
                {!isEditing && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Password *</label>
                    <input required type="password" name="password" value={formData.password} onChange={handleInputChange} placeholder="••••••••" style={inputStyle} />
                  </div>
                )}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Location *</label>
                  <select required name="location" value={formData.location} onChange={handleInputChange} style={inputStyle}>
                    <option value="" disabled>Select Location</option>
                    {keralaPlaces.map((place) => (
                      <option key={place} value={place}>{place}</option>
                    ))}
                  </select>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Landmark *</label>
                  <input required name="landmark" value={formData.landmark} onChange={handleInputChange} placeholder="e.g. Near Metro Station" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', gridColumn: 'span 2' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Pincode *</label>
                  <input required name="pincode" value={formData.pincode} onChange={handleInputChange} placeholder="e.g. 682001" style={inputStyle} />
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Full Address *</label>
                <textarea required name="address" value={formData.address} onChange={handleInputChange} placeholder="Enter complete address..." style={{ ...inputStyle, minHeight: '80px', resize: 'vertical' }} />
              </div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '12px', borderTop: '1px solid #f1f5f9', paddingTop: '16px' }}>
                <button type="button" onClick={handleCloseModal} style={{ padding: '10px 20px', borderRadius: '8px', border: '1px solid #cbd5e1', background: '#ffffff', color: '#475569', cursor: 'pointer', fontWeight: '600', fontSize: '14px' }}>Cancel</button>
                <button type="submit" disabled={addingUser} style={{ padding: '10px 20px', borderRadius: '8px', border: 'none', background: addingUser ? '#94a3b8' : '#0284c7', color: '#ffffff', cursor: addingUser ? 'not-allowed' : 'pointer', fontWeight: '600', fontSize: '14px' }}>
                  {addingUser ? (isEditing ? 'Updating...' : 'Adding...') : (isEditing ? 'Update Owner' : 'Add Owner')}
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
                      <span className={`badge ${currentStatus === 'suspended' ? 'suspended' : 'active'}`}>
                        {currentStatus === 'suspended' ? 'Suspended' : 'Active'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button
                          onClick={() => handleEditClick(owner)}
                          disabled={actionLoading === owner.id}
                          style={{
                            padding: '6px 12px',
                            borderRadius: '6px',
                            border: '1px solid #0284c7',
                            background: 'transparent',
                            color: '#0284c7',
                            fontSize: '12px',
                            fontWeight: '600',
                            cursor: 'pointer'
                          }}
                        >
                          Edit
                        </button>
                        {currentStatus === 'suspended' ? (
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
                            Activate
                          </button>
                        ) : (
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
