import React, { useState, useEffect } from 'react';
import { collection, query, getDocs, doc, updateDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { createUserWithEmailAndPassword, signOut } from 'firebase/auth';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { db, app, secondaryAuth } from '../firebase';

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
    location: '', landmark: '', address: '', pincode: '',
    deliveryRadiusKm: '10'
  });
  const [locationsList, setLocationsList] = useState([]);

  useEffect(() => {
    fetchShopOwners();
    fetchLocations();
  }, []);

  const fetchLocations = async () => {
    try {
      const q = query(collection(db, 'locations'));
      const snapshot = await getDocs(q);
      const fetched = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        if (data.status === 'active' || !data.status) {
          fetched.push({ id: docSnap.id, ...data });
        }
      });
      fetched.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
      setLocationsList(fetched);
    } catch (err) {
      console.error('Error fetching locations for shop owners dropdown:', err);
    }
  };

  const fetchShopOwners = async (forceRefresh = false) => {
    try {
      if (!forceRefresh) {
        const cached = sessionStorage.getItem('admin_shop_owners_cache');
        if (cached) {
          try {
            setShopOwners(JSON.parse(cached));
            setLoading(false);
            return;
          } catch (e) {
            console.error('Cache parse error:', e);
          }
        }
      }
      setLoading(true);
      const q = query(collection(db, 'shop_owners'));
      const snapshot = await getDocs(q);
      const fetched = [];
      snapshot.forEach((docSnap) => {
        fetched.push({ id: docSnap.id, ...docSnap.data() });
      });
      setShopOwners(fetched);
      sessionStorage.setItem('admin_shop_owners_cache', JSON.stringify(fetched));
    } catch (err) {
      console.error('Error fetching shop owners:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    if (name === 'mobileNumber' || name === 'phone') {
      const digitsOnly = value.replace(/\D/g, '').slice(0, 10);
      setFormData(prev => ({ ...prev, [name]: digitsOnly }));
      return;
    }
    if (name === 'pincode') {
      const digitsOnly = value.replace(/\D/g, '').slice(0, 6);
      setFormData(prev => ({ ...prev, [name]: digitsOnly }));
      return;
    }
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleAddSubmit = async (e) => {
    e.preventDefault();
    if (!formData.mobileNumber || formData.mobileNumber.length !== 10) {
      alert('Please enter a valid 10-digit phone number.');
      return;
    }
    setAddingUser(true);
    try {
      if (isEditing) {
        const updateData = {
          name: formData.name,
          mobileNumber: formData.mobileNumber,
          address: formData.address,
          location: formData.location,
          landmark: formData.landmark,
          pincode: formData.pincode,
          deliveryRadiusKm: parseFloat(formData.deliveryRadiusKm) || 10,
        };
        await updateDoc(doc(db, 'shop_owners', editingId), updateData);
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
          console.warn('Cloud Function createAdminUser error, trying fallback if applicable:', fnErr);
          const errMsg = fnErr?.message || '';
          if (errMsg.includes('already exists') || errMsg.includes('already in use') || errMsg.includes('phone-number-already-exists')) {
            throw new Error(errMsg.replace('FirebaseError: ', ''));
          }
          const userCred = await createUserWithEmailAndPassword(secondaryAuth, formData.email, formData.password);
          uid = userCred.user.uid;
          await signOut(secondaryAuth);
        }
        
        const ownerRecord = {
          uid,
          email: formData.email,
          name: formData.name,
          role: 'Shopkeeper',
          mobileNumber: formData.mobileNumber,
          address: formData.address,
          location: formData.location,
          landmark: formData.landmark,
          pincode: formData.pincode,
          deliveryRadiusKm: parseFloat(formData.deliveryRadiusKm) || 10,
          status: 'active',
          emailVerified: true,
          isPhoneVerified: true,
          createdAt: serverTimestamp()
        };

        await setDoc(doc(db, 'shop_owners', uid), ownerRecord);

        alert('Shop Owner created successfully! They can now log in immediately.');
      }
      
      handleCloseModal();
      fetchShopOwners(true);
    } catch (err) {
      console.error(isEditing ? 'Error updating shop owner:' : 'Error adding shop owner:', err);
      alert((isEditing ? 'Failed to update shop owner: ' : 'Failed to add shop owner: ') + err.message);
    } finally {
      setAddingUser(false);
    }
  };

  const handleEditClick = (owner) => {
    fetchLocations();
    setFormData({
      name: owner.name || owner.shopName || '',
      mobileNumber: owner.mobileNumber || '',
      email: owner.email || '',
      password: '',
      location: owner.location || '',
      landmark: owner.landmark || '',
      address: owner.address || owner.shopAddress || '',
      pincode: owner.pincode || '',
      deliveryRadiusKm: owner.deliveryRadiusKm?.toString() || '10',
      profileImage: owner.profileImage || owner.shopImage || owner.imageUrl || ''
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
      location: '', landmark: '', address: '', pincode: '',
      deliveryRadiusKm: '10'
    });
  };

  const handleUpdateStatus = async (ownerId, newStatus) => {
    setActionLoading(ownerId);
    try {
      await updateDoc(doc(db, 'shop_owners', ownerId), { status: newStatus });
      setShopOwners(prev => {
        const updated = prev.map(item => item.id === ownerId ? { ...item, status: newStatus } : item);
        sessionStorage.setItem('admin_shop_owners_cache', JSON.stringify(updated));
        return updated;
      });
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
    <div className="card">
      <div className="page-header" style={{ marginBottom: '1.5rem', flexDirection: 'column', alignItems: 'stretch', gap: '1.25rem' }}>
        <div>
          <h2 className="page-title" style={{ fontSize: '1.5rem' }}>Shop Owners &amp; Partners</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            Manage registered shop keepers, view store locations, and handle business status.
          </p>
        </div>

        <div className="toolbar" style={{ marginBottom: 0, justifyContent: 'space-between', width: '100%' }}>
          <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flexWrap: 'wrap' }}>
            <input
              type="text"
              className="form-input"
              placeholder="Search shop name or phone..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{ width: '320px', maxWidth: '100%' }}
            />

            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="form-select"
            >
              <option value="All">All Status</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended</option>
            </select>
          </div>

          <button 
            onClick={() => {
              fetchLocations();
              setFormData({
                name: '', mobileNumber: '', email: '', password: '',
                location: '', landmark: '', address: '', pincode: '',
                deliveryRadiusKm: '10'
              });
              setIsEditing(false);
              setShowAddModal(true);
            }}
            className="btn btn-primary">
            + Add Shop Owner
          </button>
        </div>
      </div>

      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '640px' }}>
            <div className="modal-header">
              <h3>{isEditing ? 'Edit Shop Owner' : 'Add New Shop Owner'}</h3>
              <button onClick={handleCloseModal} style={{ fontSize: '1.5rem', color: 'var(--text-secondary)' }}>&times;</button>
            </div>
            <form onSubmit={handleAddSubmit}>
              <div className="modal-body">
                {formData.profileImage && (
                  <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '1rem',
                    padding: '0.75rem 1rem',
                    marginBottom: '1rem',
                    backgroundColor: '#f8fafc',
                    border: '1px solid #e2e8f0',
                    borderRadius: '12px'
                  }}>
                    <img
                      src={formData.profileImage}
                      alt="Store Profile"
                      style={{
                        width: '56px',
                        height: '56px',
                        borderRadius: '50%',
                        objectFit: 'cover',
                        border: '2px solid var(--primary-light, #00b4d8)'
                      }}
                    />
                    <div>
                      <div style={{ fontWeight: '600', fontSize: '0.9rem', color: 'var(--text-primary)' }}>
                        Store Profile Image
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                        Configured via Store App Profile
                      </div>
                    </div>
                  </div>
                )}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Shop / Owner Name *</label>
                    <input required name="name" value={formData.name} onChange={handleInputChange} placeholder="e.g. Ocean Supermarket" className="form-input" />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Phone Number (10 Digits) *</label>
                    <input
                      required
                      type="tel"
                      inputMode="numeric"
                      maxLength={10}
                      pattern="[0-9]{10}"
                      title="Please enter a valid 10-digit phone number"
                      name="mobileNumber"
                      value={formData.mobileNumber}
                      onChange={handleInputChange}
                      placeholder="e.g. 9876543210"
                      className="form-input"
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Email Address *</label>
                    <input required type="email" name="email" value={formData.email} onChange={handleInputChange} disabled={isEditing} placeholder="e.g. owner@example.com" className="form-input" style={{ background: isEditing ? '#f1f5f9' : 'var(--bg-surface)' }} />
                  </div>
                  {!isEditing && (
                    <div className="form-group">
                      <label className="form-label">Password *</label>
                      <input required type="password" name="password" value={formData.password} onChange={handleInputChange} placeholder="••••••••" className="form-input" />
                    </div>
                  )}
                  <div className="form-group">
                    <label className="form-label">Location *</label>
                    <select
                      required
                      name="location"
                      value={formData.location}
                      onChange={handleInputChange}
                      className="form-select"
                    >
                      <option value="" disabled>
                        {locationsList.length === 0
                          ? 'No locations added yet (Add in Locations tab)'
                          : 'Select Location'}
                      </option>
                      {locationsList.map((loc) => (
                        <option key={loc.id} value={loc.name}>
                          {loc.name}
                        </option>
                      ))}
                      {formData.location &&
                        !locationsList.some((l) => l.name === formData.location) && (
                          <option value={formData.location}>
                            {formData.location} (Current)
                          </option>
                        )}
                    </select>
                    {locationsList.length === 0 && (
                      <p style={{ fontSize: '0.75rem', color: 'var(--danger)', marginTop: '0.25rem' }}>
                        No locations available. Please add a location in the <strong>Locations</strong> tab first.
                      </p>
                    )}
                  </div>
                  <div className="form-group">
                    <label className="form-label">Landmark *</label>
                    <input required name="landmark" value={formData.landmark} onChange={handleInputChange} placeholder="e.g. Near Metro Station" className="form-input" />
                  </div>
                  <div className="form-group" style={{ gridColumn: 'span 2' }}>
                    <label className="form-label">Pincode (6 Digits) *</label>
                    <input
                      required
                      type="tel"
                      inputMode="numeric"
                      maxLength={6}
                      pattern="[0-9]{6}"
                      name="pincode"
                      value={formData.pincode}
                      onChange={handleInputChange}
                      placeholder="e.g. 682001"
                      className="form-input"
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label className="form-label">Full Address *</label>
                  <textarea required name="address" value={formData.address} onChange={handleInputChange} placeholder="Enter complete address..." className="form-input" />
                </div>
                <div className="form-group">
                  <label className="form-label">Delivery Radius (km) *</label>
                  <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                    {[5, 10, 15, 20, 25, 30].map(km => (
                      <button
                        key={km}
                        type="button"
                        onClick={() => setFormData(prev => ({ ...prev, deliveryRadiusKm: km.toString() }))}
                        className={`filter-chip ${formData.deliveryRadiusKm === km.toString() ? 'active' : ''}`}
                      >
                        {km} km
                      </button>
                    ))}
                    <input
                      type="number"
                      min="1"
                      max="100"
                      name="deliveryRadiusKm"
                      value={formData.deliveryRadiusKm}
                      onChange={handleInputChange}
                      placeholder="Custom"
                      className="form-input"
                      style={{ width: '90px' }}
                    />
                  </div>
                  <p style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)' }}>Orders from addresses outside this radius will be blocked.</p>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" onClick={handleCloseModal} className="btn btn-secondary">Cancel</button>
                <button type="submit" disabled={addingUser} className="btn btn-primary">
                  {addingUser ? (isEditing ? 'Updating...' : 'Adding...') : (isEditing ? 'Update Owner' : 'Add Owner')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="table-container">
        <table className="table">
          <thead>
            <tr>
              <th>Shop &amp; Owner</th>
              <th>Contact Details</th>
              <th>Location</th>
              <th>Delivery Radius</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan="6" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
                  Loading shop owners...
                </td>
              </tr>
            ) : filteredOwners.length > 0 ? (
              filteredOwners.map((owner) => {
                const currentStatus = (owner.status || 'pending').toLowerCase();
                return (
                  <tr key={owner.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        {owner.profileImage || owner.shopImage || owner.imageUrl ? (
                          <img
                            src={owner.profileImage || owner.shopImage || owner.imageUrl}
                            alt={owner.shopName || owner.name || 'Shop'}
                            loading="lazy"
                            style={{
                              width: '38px',
                              height: '38px',
                              borderRadius: '50%',
                              objectFit: 'cover',
                              border: '1.5px solid #e2e8f0',
                              backgroundColor: '#f8fafc',
                              flexShrink: 0
                            }}
                            onError={(e) => {
                              e.target.style.display = 'none';
                              if (e.target.nextSibling) {
                                e.target.nextSibling.style.display = 'flex';
                              }
                            }}
                          />
                        ) : null}
                        <div style={{
                          width: '38px', height: '38px', borderRadius: '50%',
                          backgroundColor: 'var(--primary-light)', color: 'var(--primary)',
                          display: (owner.profileImage || owner.shopImage || owner.imageUrl) ? 'none' : 'flex',
                          alignItems: 'center', justifyContent: 'center',
                          fontWeight: '700', fontSize: '0.875rem',
                          flexShrink: 0
                        }}>
                          {(owner.shopName || owner.name || 'S').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                            {owner.shopName || owner.name || 'OceanKart Shop'}
                          </div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                            Owner: {owner.name || 'N/A'}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div style={{ fontSize: '0.85rem', color: 'var(--text-primary)', fontWeight: '500' }}>
                        {owner.email || 'No Email'}
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                        {owner.mobileNumber ? `+91 ${owner.mobileNumber}` : 'No Phone'}
                      </div>
                    </td>
                    <td style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                      {owner.address || owner.shopAddress || 'Kerala, India'}
                    </td>
                    <td>
                      <span className="badge badge-info">
                        📍 {owner.deliveryRadiusKm || 10} km
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${currentStatus === 'suspended' ? 'badge-danger' : 'badge-success'}`}>
                        {currentStatus === 'suspended' ? 'Suspended' : 'Active'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        <button
                          onClick={() => handleEditClick(owner)}
                          disabled={actionLoading === owner.id}
                          className="btn btn-secondary btn-sm"
                        >
                          Edit
                        </button>
                        {currentStatus === 'suspended' ? (
                          <button
                            onClick={() => handleUpdateStatus(owner.id, 'active')}
                            disabled={actionLoading === owner.id}
                            className="btn btn-success btn-sm"
                          >
                            Activate
                          </button>
                        ) : (
                          <button
                            onClick={() => handleUpdateStatus(owner.id, 'suspended')}
                            disabled={actionLoading === owner.id}
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
                <td colSpan="6" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
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
