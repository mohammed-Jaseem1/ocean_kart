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
      const q = query(collection(db, 'delivery_partners'));
      const snapshot = await getDocs(q);
      const fetched = [];
      const seenIds = new Set();

      snapshot.forEach((docSnap) => {
        seenIds.add(docSnap.id);
        fetched.push({ id: docSnap.id, ...docSnap.data() });
      });

      // Fallback query to legacy 'users' collection for delivery boys not yet migrated
      try {
        const usersQ = query(collection(db, 'users'));
        const usersSnapshot = await getDocs(usersQ);
        usersSnapshot.forEach((docSnap) => {
          if (!seenIds.has(docSnap.id)) {
            const data = docSnap.data();
            if (data.role === 'Delivery Boy' || data.role === 'delivery_partner' || data.vehicleNumber || data.deliveryStatus) {
              fetched.push({ id: docSnap.id, ...data });
            }
          }
        });
      } catch (legacyErr) {
        console.warn('Legacy users fetch notice:', legacyErr);
      }

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
        await updateDoc(doc(db, 'delivery_partners', editingId), updateData);
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
        
        await setDoc(doc(db, 'delivery_partners', uid), {
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

      const updateData = {
        assignedShopIds: selectedShopIds,
        assignedShopNames: assignedNames,
        requestedShopIds: [],
        requestedShopNames: [],
        shopRequestStatus: 'approved',
        shopsAssignedAt: serverTimestamp()
      };

      await updateDoc(doc(db, 'delivery_partners', selectedPartnerForShops.id), updateData);
      try {
        await updateDoc(doc(db, 'users', selectedPartnerForShops.id), updateData);
      } catch (e) {}

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

      const updateData = {
        assignedShopIds: combinedIds,
        assignedShopNames: assignedNames,
        requestedShopIds: [],
        requestedShopNames: [],
        shopRequestStatus: 'approved',
        shopsAssignedAt: serverTimestamp()
      };

      await updateDoc(doc(db, 'delivery_partners', partner.id), updateData);
      try {
        await updateDoc(doc(db, 'users', partner.id), updateData);
      } catch (e) {}

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
      await updateDoc(doc(db, 'delivery_partners', partnerId), { status: newStatus });
      try {
        await updateDoc(doc(db, 'users', partnerId), { status: newStatus });
      } catch (e) {}
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
    <div className="card">
      <div className="page-header" style={{ marginBottom: '1.5rem', flexDirection: 'column', alignItems: 'stretch', gap: '1.25rem' }}>
        <div>
          <h2 className="page-title" style={{ fontSize: '1.5rem' }}>Delivery Personnel</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            Manage delivery personnel, assign shop coverage, and handle shop assignment requests.
          </p>
        </div>

        <div className="toolbar" style={{ marginBottom: 0, justifyContent: 'space-between', width: '100%' }}>
          <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', flexWrap: 'wrap' }}>
            <input
              type="text"
              className="form-input"
              placeholder="Search partner or vehicle..."
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
              handleCloseModal();
              setShowAddModal(true);
            }}
            className="btn btn-primary">
            + Add Delivery Partner
          </button>
        </div>
      </div>

      {/* Add / Edit Partner Modal */}
      {showAddModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '640px' }}>
            <div className="modal-header">
              <h3>{isEditing ? 'Edit Delivery Partner' : 'Add New Delivery Partner'}</h3>
              <button onClick={handleCloseModal} style={{ fontSize: '1.5rem', color: 'var(--text-secondary)' }}>&times;</button>
            </div>
            <form onSubmit={handleAddSubmit}>
              <div className="modal-body">
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label">Full Name *</label>
                    <input required name="name" value={formData.name} onChange={handleInputChange} placeholder="e.g. Rahul Kumar" className="form-input" />
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
                  {!isEditing && (
                    <>
                      <div className="form-group">
                        <label className="form-label">Email Address *</label>
                        <input required type="email" name="email" value={formData.email} onChange={handleInputChange} placeholder="e.g. partner@example.com" className="form-input" />
                      </div>
                      <div className="form-group">
                        <label className="form-label">Password *</label>
                        <input required type="password" name="password" value={formData.password} onChange={handleInputChange} placeholder="••••••••" className="form-input" />
                      </div>
                    </>
                  )}
                  <div className="form-group">
                    <label className="form-label">Vehicle Number</label>
                    <input name="vehicleNumber" value={formData.vehicleNumber} onChange={handleInputChange} placeholder="e.g. KL-07-AB-1234" className="form-input" />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Location *</label>
                    <select required name="location" value={formData.location} onChange={handleInputChange} className="form-select">
                      <option value="" disabled>Select Location</option>
                      {keralaPlaces.map((place) => (
                        <option key={place} value={place}>{place}</option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label className="form-label">Landmark *</label>
                    <input required name="landmark" value={formData.landmark} onChange={handleInputChange} placeholder="e.g. Near Bus Stand" className="form-input" />
                  </div>
                  <div className="form-group">
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
                  <textarea required name="address" value={formData.address} onChange={handleInputChange} placeholder="Enter complete home address..." className="form-input" />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" onClick={handleCloseModal} className="btn btn-secondary">Cancel</button>
                <button type="submit" disabled={addingUser} className="btn btn-primary">
                  {addingUser ? 'Saving...' : isEditing ? 'Save Changes' : 'Add Partner'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Assign / Manage Shops Modal */}
      {showAssignModal && selectedPartnerForShops && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '580px' }}>
            <div className="modal-header">
              <div>
                <h3>Assign Shops to {selectedPartnerForShops.name || 'Partner'}</h3>
                <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                  Check the shops this delivery partner is authorized to deliver orders from.
                </p>
              </div>
              <button onClick={() => setShowAssignModal(false)} style={{ fontSize: '1.5rem', color: 'var(--text-secondary)' }}>&times;</button>
            </div>

            <div className="modal-body">
              {selectedPartnerForShops.requestedShopNames?.length > 0 && (
                <div style={{ padding: '0.75rem 1rem', background: 'var(--warning-bg)', color: 'var(--warning-text)', borderRadius: 'var(--radius-md)', fontSize: '0.85rem', fontWeight: '500' }}>
                  <strong>Requested by Partner:</strong> {selectedPartnerForShops.requestedShopNames.join(', ')}
                </div>
              )}

              <div style={{ maxHeight: '320px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {availableShops.length === 0 ? (
                  <div style={{ padding: '1rem', textAlign: 'center', color: 'var(--text-secondary)' }}>
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
                          gap: '0.75rem', 
                          padding: '0.75rem 1rem', 
                          borderRadius: 'var(--radius-md)', 
                          border: isChecked ? '1.5px solid var(--primary)' : '1px solid var(--border-light)', 
                          background: isChecked ? 'var(--primary-light)' : 'var(--bg-surface)',
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
                          style={{ width: '18px', height: '18px', cursor: 'pointer', accentColor: 'var(--primary)' }}
                        />
                        <div style={{ flex: 1 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                            <span style={{ fontWeight: '600', color: 'var(--text-primary)', fontSize: '0.9rem' }}>{shop.name}</span>
                            {isRequested && (
                              <span className="badge badge-warning" style={{ fontSize: '0.7rem' }}>
                                Requested
                              </span>
                            )}
                          </div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: '2px' }}>
                            {shop.location}
                          </div>
                        </div>
                      </label>
                    );
                  })
                )}
              </div>
            </div>

            <div className="modal-footer">
              <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginRight: 'auto' }}>
                {selectedShopIds.length} shop(s) selected
              </span>
              <button type="button" onClick={() => setShowAssignModal(false)} className="btn btn-secondary">
                Cancel
              </button>
              <button type="button" onClick={handleSaveAssignedShops} disabled={assigningShops} className="btn btn-primary">
                {assigningShops ? 'Saving...' : 'Save Assignments'}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="table-container">
        <table className="table">
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
                <td colSpan="5" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
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
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div style={{
                          width: '36px', height: '36px', borderRadius: '50%',
                          backgroundColor: '#fef3c7', color: '#d97706',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          fontWeight: '700', fontSize: '0.875rem'
                        }}>
                          {(partner.name || partner.email || 'D').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                            {partner.name || 'Delivery Rider'}
                          </div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                            {partner.vehicleNumber || 'Motorcycle'}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div style={{ fontSize: '0.85rem', color: 'var(--text-primary)', fontWeight: '500' }}>
                        {partner.email || 'No Email'}
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                        {partner.mobileNumber ? `+91 ${partner.mobileNumber}` : 'No Phone'}
                      </div>
                    </td>
                    <td>
                      <div>
                        {assignedCount > 0 ? (
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.25rem', maxWidth: '220px' }}>
                            {partner.assignedShopNames.map((shopName, idx) => (
                              <span key={idx} className="badge badge-success" style={{ fontSize: '0.7rem' }}>
                                {shopName}
                              </span>
                            ))}
                          </div>
                        ) : (
                          <span style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)', fontStyle: 'italic' }}>
                            No stores assigned
                          </span>
                        )}

                        {requestedCount > 0 && (
                          <div style={{ marginTop: '0.35rem', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                            <span className="badge badge-warning" style={{ fontSize: '0.7rem' }}>
                              Requested: {partner.requestedShopNames.join(', ')}
                            </span>
                            <button
                              onClick={() => handleQuickApproveRequests(partner)}
                              disabled={actionLoading === partner.id}
                              className="btn btn-success btn-sm"
                              style={{ padding: '0.15rem 0.4rem', fontSize: '0.7rem' }}
                            >
                              Approve
                            </button>
                          </div>
                        )}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${currentStatus === 'suspended' ? 'badge-danger' : 'badge-success'}`}>
                        {currentStatus === 'suspended' ? 'Suspended' : 'Active'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.35rem', flexWrap: 'wrap' }}>
                        <button
                          onClick={() => handleOpenAssignModal(partner)}
                          className="btn btn-secondary btn-sm"
                        >
                          Assign Shops
                        </button>
                        <button
                          onClick={() => handleEditClick(partner)}
                          className="btn btn-secondary btn-sm"
                        >
                          Edit
                        </button>
                        {currentStatus === 'suspended' ? (
                          <button
                            onClick={() => handleUpdateStatus(partner.id, 'active')}
                            disabled={actionLoading === partner.id}
                            className="btn btn-success btn-sm"
                          >
                            Activate
                          </button>
                        ) : (
                          <button
                            onClick={() => handleUpdateStatus(partner.id, 'suspended')}
                            disabled={actionLoading === partner.id}
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
