import React, { useState, useEffect } from 'react';
import { collection, query, getDocs, doc, updateDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { createUserWithEmailAndPassword, signOut } from 'firebase/auth';
import { getFunctions, httpsCallable } from 'firebase/functions';
import { db, app, secondaryAuth } from '../firebase';
import { keralaPlaces } from '../constants/keralaPlaces';

const DeliveryBoys = () => {
  const [deliveryPartners, setDeliveryPartners] = useState([]);
  const [availableShops, setAvailableShops] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  const [actionLoading, setActionLoading] = useState(null);
  
  // Add / Edit Delivery Partner Modal
  const [showAddModal, setShowAddModal] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [addingUser, setAddingUser] = useState(false);
  const [formData, setFormData] = useState({
    name: '', mobileNumber: '', email: '', password: '',
    location: '', landmark: '', address: '', pincode: '',
    vehicleNumber: '', vehicleType: 'Motorcycle / Scooter'
  });

  // Assign Shops Modal
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedPartnerForShops, setSelectedPartnerForShops] = useState(null);
  const [selectedShopIds, setSelectedShopIds] = useState([]);
  const [assigningShops, setAssigningShops] = useState(false);

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
    fetchAvailableShops();
  }, []);

  const fetchAvailableShops = async () => {
    try {
      const q = query(collection(db, 'shop_owners'));
      const snapshot = await getDocs(q);
      const fetched = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        fetched.push({
          id: docSnap.id,
          name: data.shopName || data.name || 'Unnamed Shop',
          location: data.location || data.address || 'Kerala',
          address: data.shopAddress || data.address || '',
        });
      });
      setAvailableShops(fetched);
    } catch (err) {
      console.error('Error fetching shops for assignment:', err);
    }
  };

  const fetchDeliveryPartners = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'users'));
      const snapshot = await getDocs(q);
      const fetched = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        if (data.role === 'Delivery Boy' || data.role === 'delivery_partner' || data.vehicleNumber || data.deliveryStatus) {
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
          houseAddress: formData.address,
          location: formData.location,
          landmark: formData.landmark,
          pincode: formData.pincode,
          vehicleNumber: formData.vehicleNumber || 'KL-07-Temp',
          vehicleType: formData.vehicleType || 'Motorcycle / Scooter',
        };
        await updateDoc(doc(db, 'users', editingId), updateData);
        alert('Delivery Partner updated successfully!');
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
            role: 'Delivery Boy'
          });
          uid = result.data.uid;
        } catch (fnErr) {
          console.warn('Cloud function createAdminUser failed, using secondary auth if applicable:', fnErr);
          const errMsg = fnErr?.message || '';
          if (errMsg.includes('already exists') || errMsg.includes('already in use') || errMsg.includes('phone-number-already-exists')) {
            throw new Error(errMsg.replace('FirebaseError: ', ''));
          }
          const userCred = await createUserWithEmailAndPassword(secondaryAuth, formData.email, formData.password);
          uid = userCred.user.uid;
          await signOut(secondaryAuth);
        }
        
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
          vehicleNumber: formData.vehicleNumber || 'KL-07-Verified',
          vehicleType: formData.vehicleType || 'Motorcycle / Scooter',
          status: 'active',
          emailVerified: true,
          isPhoneVerified: true,
          assignedShopIds: [],
          assignedShopNames: [],
          createdAt: serverTimestamp()
        });
        
        alert('Delivery Partner created successfully! They can now log in immediately.');
      }
      
      handleCloseModal();
      fetchDeliveryPartners();
    } catch (err) {
      console.error(isEditing ? 'Error updating delivery partner:' : 'Error adding delivery partner:', err);
      alert((isEditing ? 'Failed to update delivery partner: ' : 'Failed to add delivery partner: ') + err.message);
    } finally {
      setAddingUser(false);
    }
  };

  const handleEditClick = (partner) => {
    setFormData({
      name: partner.name || '',
      mobileNumber: partner.mobileNumber || '',
      email: partner.email || '',
      password: '',
      location: partner.location || '',
      landmark: partner.landmark || '',
      address: partner.address || partner.houseAddress || '',
      pincode: partner.pincode || '',
      vehicleNumber: partner.vehicleNumber || '',
      vehicleType: partner.vehicleType || 'Motorcycle / Scooter'
    });
    setEditingId(partner.id);
    setIsEditing(true);
    setShowAddModal(true);
  };

  const handleOpenAssignModal = (partner) => {
    setSelectedPartnerForShops(partner);
    const currentAssigned = partner.assignedShopIds || [];
    const requested = partner.requestedShopIds || [];
    // Combine assigned + requested so admin can approve all easily
    setSelectedShopIds(Array.from(new Set([...currentAssigned, ...requested])));
    setShowAssignModal(true);
  };

  const handleSaveAssignedShops = async () => {
    if (!selectedPartnerForShops) return;
    setAssigningShops(true);

    try {
      const assignedNames = availableShops
        .filter(s => selectedShopIds.includes(s.id))
        .map(s => s.name);

      await updateDoc(doc(db, 'users', selectedPartnerForShops.id), {
        assignedShopIds: selectedShopIds,
        assignedShopNames: assignedNames,
        requestedShopIds: [],
        requestedShopNames: [],
        shopRequestStatus: 'approved',
        shopsAssignedAt: serverTimestamp()
      });

      alert(`Successfully assigned ${selectedShopIds.length} shop(s) to ${selectedPartnerForShops.name || 'partner'}!`);
      setShowAssignModal(false);
      setSelectedPartnerForShops(null);
      fetchDeliveryPartners();
    } catch (err) {
      console.error('Error assigning shops:', err);
      alert('Failed to assign shops: ' + err.message);
    } finally {
      setAssigningShops(false);
    }
  };

  const handleQuickApproveRequests = async (partner) => {
    const requestedIds = partner.requestedShopIds || [];
    if (requestedIds.length === 0) return;

    setActionLoading(partner.id);
    try {
      const currentAssigned = partner.assignedShopIds || [];
      const combinedIds = Array.from(new Set([...currentAssigned, ...requestedIds]));
      const assignedNames = availableShops
        .filter(s => combinedIds.includes(s.id))
        .map(s => s.name);

      await updateDoc(doc(db, 'users', partner.id), {
        assignedShopIds: combinedIds,
        assignedShopNames: assignedNames,
        requestedShopIds: [],
        requestedShopNames: [],
        shopRequestStatus: 'approved',
        shopsAssignedAt: serverTimestamp()
      });

      alert(`Approved shop requests for ${partner.name || 'partner'}!`);
      fetchDeliveryPartners();
    } catch (err) {
      console.error('Error approving requests:', err);
      alert('Failed to approve requests: ' + err.message);
    } finally {
      setActionLoading(null);
    }
  };

  const handleCloseModal = () => {
    setShowAddModal(false);
    setIsEditing(false);
    setEditingId(null);
    setFormData({
      name: '', mobileNumber: '', email: '', password: '',
      location: '', landmark: '', address: '', pincode: '',
      vehicleNumber: '', vehicleType: 'Motorcycle / Scooter'
    });
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
    const status = (p.status || 'active').toLowerCase();
    const matchesFilter = filterStatus === 'All' || 
      (filterStatus.toLowerCase() === 'active' ? status !== 'suspended' : status === 'suspended');
    return matchesSearch && matchesFilter;
  });

  return (
    <div className="table-card">
      <div className="table-header" style={{ flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <h2 style={{ margin: 0 }}>Delivery Boys & Partners</h2>
            <button 
              onClick={() => {
                handleCloseModal();
                setShowAddModal(true);
              }}
              style={{ padding: '8px 14px', background: '#0284c7', color: '#fff', border: 'none', borderRadius: '8px', fontWeight: '600', fontSize: '13px', cursor: 'pointer' }}>
              + Add Delivery Partner
            </button>
          </div>
          <p style={{ color: '#64748b', fontSize: '13px', margin: '4px 0 0' }}>
            Manage delivery personnel, assign shop coverage, and handle shop assignment requests.
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
            <option value="suspended">Suspended</option>
          </select>
        </div>
      </div>

      {/* Add / Edit Partner Modal */}
      {showAddModal && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(15, 23, 42, 0.65)', backdropFilter: 'blur(4px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ background: '#ffffff', padding: '28px', borderRadius: '16px', width: '90%', maxWidth: '620px', maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)', border: '1px solid #e2e8f0' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', borderBottom: '1px solid #f1f5f9', paddingBottom: '12px' }}>
              <h2 style={{ margin: 0, fontSize: '20px', color: '#0f172a', fontWeight: '700' }}>
                {isEditing ? 'Edit Delivery Partner' : 'Add New Delivery Partner'}
              </h2>
              <button onClick={handleCloseModal} style={{ background: 'transparent', border: 'none', fontSize: '24px', cursor: 'pointer', color: '#64748b' }}>&times;</button>
            </div>
            <form onSubmit={handleAddSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Full Name *</label>
                  <input required name="name" value={formData.name} onChange={handleInputChange} placeholder="e.g. Rahul Kumar" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Phone Number (10 Digits) *</label>
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
                    style={inputStyle}
                  />
                </div>
                {!isEditing && (
                  <>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Email Address *</label>
                      <input required type="email" name="email" value={formData.email} onChange={handleInputChange} placeholder="e.g. partner@example.com" style={inputStyle} />
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                      <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Password *</label>
                      <input required type="password" name="password" value={formData.password} onChange={handleInputChange} placeholder="••••••••" style={inputStyle} />
                    </div>
                  </>
                )}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Vehicle Number</label>
                  <input name="vehicleNumber" value={formData.vehicleNumber} onChange={handleInputChange} placeholder="e.g. KL-07-AB-1234" style={inputStyle} />
                </div>
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
                  <input required name="landmark" value={formData.landmark} onChange={handleInputChange} placeholder="e.g. Near Bus Stand" style={inputStyle} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Pincode (6 Digits) *</label>
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
                    style={inputStyle}
                  />
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '12px', fontWeight: '600', color: '#475569' }}>Full Address *</label>
                <textarea required name="address" value={formData.address} onChange={handleInputChange} placeholder="Enter complete home address..." style={{ ...inputStyle, minHeight: '70px', resize: 'vertical' }} />
              </div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '12px', borderTop: '1px solid #f1f5f9', paddingTop: '16px' }}>
                <button type="button" onClick={handleCloseModal} style={{ padding: '10px 20px', borderRadius: '8px', border: '1px solid #cbd5e1', background: '#ffffff', color: '#475569', cursor: 'pointer', fontWeight: '600', fontSize: '14px' }}>Cancel</button>
                <button type="submit" disabled={addingUser} style={{ padding: '10px 20px', borderRadius: '8px', border: 'none', background: addingUser ? '#94a3b8' : '#0284c7', color: '#ffffff', cursor: addingUser ? 'not-allowed' : 'pointer', fontWeight: '600', fontSize: '14px' }}>
                  {addingUser ? 'Saving...' : isEditing ? 'Save Changes' : 'Add Partner'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Assign / Manage Shops Modal */}
      {showAssignModal && selectedPartnerForShops && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(15, 23, 42, 0.65)', backdropFilter: 'blur(4px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ background: '#ffffff', padding: '28px', borderRadius: '16px', width: '90%', maxWidth: '580px', maxHeight: '85vh', display: 'flex', flexDirection: 'column', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)', border: '1px solid #e2e8f0' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', borderBottom: '1px solid #f1f5f9', paddingBottom: '12px' }}>
              <div>
                <h2 style={{ margin: 0, fontSize: '18px', color: '#0f172a', fontWeight: '700' }}>
                  Assign Shops to {selectedPartnerForShops.name || 'Partner'}
                </h2>
                <p style={{ margin: '4px 0 0', fontSize: '13px', color: '#64748b' }}>
                  Check the shops this delivery partner is authorized to deliver orders from.
                </p>
              </div>
              <button onClick={() => setShowAssignModal(false)} style={{ background: 'transparent', border: 'none', fontSize: '24px', cursor: 'pointer', color: '#64748b' }}>&times;</button>
            </div>

            {selectedPartnerForShops.requestedShopNames?.length > 0 && (
              <div style={{ padding: '10px 14px', background: '#fef3c7', borderRadius: '8px', border: '1px solid #fde68a', marginBottom: '16px', fontSize: '12.5px', color: '#92400e' }}>
                <strong>Requested by Partner:</strong> {selectedPartnerForShops.requestedShopNames.join(', ')}
              </div>
            )}

            <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '10px', paddingRight: '4px', marginBottom: '16px' }}>
              {availableShops.length === 0 ? (
                <div style={{ padding: '20px', textAlign: 'center', color: '#64748b' }}>
                  No registered shops found.
                </div>
              ) : (
                availableShops.map(shop => {
                  const isChecked = selectedShopIds.includes(shop.id);
                  const isRequested = (selectedPartnerForShops.requestedShopIds || []).includes(shop.id);

                  return (
                    <label 
                      key={shop.id}
                      style={{ 
                        display: 'flex', 
                        alignItems: 'center', 
                        gap: '12px', 
                        padding: '12px 14px', 
                        borderRadius: '10px', 
                        border: isChecked ? '1.5px solid #0284c7' : '1px solid #e2e8f0', 
                        background: isChecked ? '#f0f9ff' : '#ffffff',
                        cursor: 'pointer' 
                      }}>
                      <input
                        type="checkbox"
                        checked={isChecked}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedShopIds(prev => [...prev, shop.id]);
                          } else {
                            setSelectedShopIds(prev => prev.filter(id => id !== shop.id));
                          }
                        }}
                        style={{ width: '18px', height: '18px', cursor: 'pointer', accentColor: '#0284c7' }}
                      />
                      <div style={{ flex: 1 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <span style={{ fontWeight: '600', color: '#0f172a', fontSize: '14px' }}>{shop.name}</span>
                          {isRequested && (
                            <span style={{ fontSize: '11px', background: '#fef3c7', color: '#b45309', padding: '2px 6px', borderRadius: '4px', fontWeight: 'bold' }}>
                              Requested
                            </span>
                          )}
                        </div>
                        <div style={{ fontSize: '12px', color: '#64748b', marginTop: '2px' }}>
                          {shop.location}
                        </div>
                      </div>
                    </label>
                  );
                })
              )}
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid #f1f5f9', paddingTop: '16px' }}>
              <span style={{ fontSize: '13px', color: '#64748b', fontWeight: '500' }}>
                {selectedShopIds.length} shop(s) selected
              </span>
              <div style={{ display: 'flex', gap: '10px' }}>
                <button type="button" onClick={() => setShowAssignModal(false)} style={{ padding: '8px 16px', borderRadius: '8px', border: '1px solid #cbd5e1', background: '#ffffff', color: '#475569', cursor: 'pointer', fontWeight: '600', fontSize: '13px' }}>
                  Cancel
                </button>
                <button type="button" onClick={handleSaveAssignedShops} disabled={assigningShops} style={{ padding: '8px 18px', borderRadius: '8px', border: 'none', background: assigningShops ? '#94a3b8' : '#0284c7', color: '#ffffff', cursor: assigningShops ? 'not-allowed' : 'pointer', fontWeight: '600', fontSize: '13px' }}>
                  {assigningShops ? 'Saving...' : 'Save Assignments'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="custom-table-wrapper">
        <table className="custom-table">
          <thead>
            <tr>
              <th>Delivery Partner</th>
              <th>Contact Details</th>
              <th>Assigned Stores</th>
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
                const assignedCount = (partner.assignedShopNames || []).length;
                const requestedCount = (partner.requestedShopNames || []).length;

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
                          <div style={{ fontSize: '12px', color: '#64748b' }}>
                            {partner.vehicleNumber || 'Motorcycle'}
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
                      <div>
                        {assignedCount > 0 ? (
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px', maxWidth: '220px' }}>
                            {partner.assignedShopNames.map((shopName, idx) => (
                              <span key={idx} style={{ fontSize: '11px', background: '#dcfce7', color: '#15803d', padding: '2px 7px', borderRadius: '6px', fontWeight: '600' }}>
                                {shopName}
                              </span>
                            ))}
                          </div>
                        ) : (
                          <span style={{ fontSize: '12px', color: '#94a3b8', fontStyle: 'italic' }}>
                            No stores assigned
                          </span>
                        )}

                        {requestedCount > 0 && (
                          <div style={{ marginTop: '6px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <span style={{ fontSize: '11px', background: '#fef3c7', color: '#b45309', padding: '2px 6px', borderRadius: '4px', fontWeight: '600' }}>
                              Requested: {partner.requestedShopNames.join(', ')}
                            </span>
                            <button
                              onClick={() => handleQuickApproveRequests(partner)}
                              disabled={actionLoading === partner.id}
                              style={{
                                padding: '2px 6px',
                                fontSize: '10px',
                                background: '#22c55e',
                                color: '#fff',
                                border: 'none',
                                borderRadius: '4px',
                                cursor: 'pointer',
                                fontWeight: 'bold'
                              }}>
                              Approve
                            </button>
                          </div>
                        )}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${currentStatus === 'suspended' ? 'suspended' : 'active'}`}>
                        {currentStatus === 'suspended' ? 'Suspended' : 'Active'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                        <button
                          onClick={() => handleOpenAssignModal(partner)}
                          style={{
                            padding: '6px 10px',
                            borderRadius: '6px',
                            border: '1px solid #0284c7',
                            background: '#f0f9ff',
                            color: '#0284c7',
                            fontSize: '12px',
                            fontWeight: '600',
                            cursor: 'pointer'
                          }}
                        >
                          Assign Shops
                        </button>
                        <button
                          onClick={() => handleEditClick(partner)}
                          style={{
                            padding: '6px 10px',
                            borderRadius: '6px',
                            border: '1px solid #cbd5e1',
                            background: '#ffffff',
                            color: '#0f172a',
                            fontSize: '12px',
                            fontWeight: '600',
                            cursor: 'pointer'
                          }}
                        >
                          Edit
                        </button>
                        {currentStatus === 'suspended' ? (
                          <button
                            onClick={() => handleUpdateStatus(partner.id, 'active')}
                            disabled={actionLoading === partner.id}
                            style={{
                              padding: '6px 10px',
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
                            onClick={() => handleUpdateStatus(partner.id, 'suspended')}
                            disabled={actionLoading === partner.id}
                            style={{
                              padding: '6px 10px',
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
