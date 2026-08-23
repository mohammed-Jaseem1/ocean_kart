import React, { useState, useEffect, useRef } from 'react';
import { collection, addDoc, getDocs, doc, updateDoc, deleteDoc, serverTimestamp, query, orderBy } from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../firebase';
import './Homepage.css';

const Categories = () => {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isAdding, setIsAdding] = useState(false);
  const [isFormVisible, setIsFormVisible] = useState(false);
  
  // Form State
  const [name, setName] = useState('');
  const [malayalamName, setMalayalamName] = useState('');
  const [status, setStatus] = useState('active');
  const [imageFile, setImageFile] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [error, setError] = useState('');

  const fileInputRef = useRef(null);

  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    try {
      setLoading(true);
      const q = query(collection(db, 'categories'), orderBy('createdAt', 'desc'));
      const querySnapshot = await getDocs(q);
      const fetched = [];
      querySnapshot.forEach((docSnap) => {
        fetched.push({ id: docSnap.id, ...docSnap.data() });
      });
      setCategories(fetched);
    } catch (err) {
      console.error('Error fetching categories:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setImageFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setImagePreview(reader.result);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleToggleStatus = async (categoryId, currentStatus) => {
    const newStatus = currentStatus === 'inactive' ? 'active' : 'inactive';
    try {
      await updateDoc(doc(db, 'categories', categoryId), { status: newStatus });
      setCategories(prev =>
        prev.map(c => c.id === categoryId ? { ...c, status: newStatus } : c)
      );
    } catch (err) {
      console.error('Error updating status:', err);
      alert('Failed to update category status.');
    }
  };

  const handleDeleteCategory = async (categoryId) => {
    if (!window.confirm('Are you sure you want to delete this category?')) return;
    try {
      await deleteDoc(doc(db, 'categories', categoryId));
      setCategories(prev => prev.filter(c => c.id !== categoryId));
    } catch (err) {
      console.error('Error deleting category:', err);
      alert('Failed to delete category.');
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim() || !imageFile) {
      setError('Please provide a category name and select an image.');
      return;
    }

    try {
      setIsAdding(true);
      setError('');
      
      // 1. Upload Image
      const storageRef = ref(storage, `categories/${Date.now()}_${imageFile.name}`);
      const uploadTask = uploadBytesResumable(storageRef, imageFile);

      uploadTask.on(
        'state_changed',
        (snapshot) => {
          const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          setUploadProgress(progress);
        },
        (error) => {
          console.error("Upload error:", error);
          setError("Failed to upload image. Please try again.");
          setIsAdding(false);
        },
        async () => {
          // 2. Get Download URL
          const downloadURL = await getDownloadURL(uploadTask.snapshot.ref);
          
          // 3. Save to Firestore
          await addDoc(collection(db, 'categories'), {
            name: name.trim(),
            malayalamName: malayalamName.trim(),
            imageUrl: downloadURL,
            status: status || 'active',
            createdAt: serverTimestamp()
          });

          // Reset Form
          setName('');
          setMalayalamName('');
          setStatus('active');
          setImageFile(null);
          setImagePreview(null);
          setUploadProgress(0);
          if (fileInputRef.current) fileInputRef.current.value = '';
          
          setIsAdding(false);
          setIsFormVisible(false);
          fetchCategories();
        }
      );

    } catch (err) {
      console.error('Error adding category:', err);
      setError('An error occurred while adding the category.');
      setIsAdding(false);
    }
  };

  return (
    <div style={{ position: 'relative' }}>
      {/* Category List Card */}
      <div className="table-card">
        <div className="table-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h2>Product Categories</h2>
            <p style={{ color: '#64748b', fontSize: '13px', margin: '4px 0 0' }}>
              Total Categories: {categories.length}
            </p>
          </div>

          <button 
            onClick={() => setIsFormVisible(true)}
            style={{
              padding: '10px 18px',
              background: '#0284c7',
              color: '#ffffff',
              border: 'none',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: '600',
              fontSize: '13px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            Add New Category
          </button>
        </div>

        {/* Modal Window */}
        {isFormVisible && (
          <div style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(15, 23, 42, 0.6)',
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            zIndex: 9999,
            padding: '20px',
            boxSizing: 'border-box'
          }}>
            <div style={{
              width: '100%',
              maxWidth: '520px',
              backgroundColor: '#ffffff',
              borderRadius: '16px',
              boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.04)',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
              maxHeight: '90vh'
            }}>
              {/* Header */}
              <div style={{
                padding: '20px 24px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                borderBottom: '1px solid #e2e8f0'
              }}>
                <h3 style={{ fontSize: '18px', fontWeight: '700', color: '#0f172a', margin: 0 }}>Create New Category</h3>
                <button 
                  onClick={() => {
                    setIsFormVisible(false);
                    setError('');
                  }}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#94a3b8',
                    cursor: 'pointer',
                    padding: '4px',
                    borderRadius: '6px',
                    display: 'flex',
                    alignItems: 'center'
                  }}
                  title="Cancel"
                >
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                  </svg>
                </button>
              </div>

              {/* Form */}
              <form onSubmit={handleSubmit} style={{ padding: '24px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {error && (
                  <div style={{ padding: '10px 14px', color: '#dc2626', background: '#fef2f2', border: '1px solid #fecaca', borderRadius: '8px', fontSize: '13px' }}>
                    {error}
                  </div>
                )}

                <div>
                  <label style={{ display: 'block', marginBottom: '6px', color: '#334155', fontSize: '13px', fontWeight: '600' }}>
                    Category Name (English) *
                  </label>
                  <input 
                    type="text" 
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="e.g., Fresh Fish & Marine"
                    disabled={isAdding}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      background: '#ffffff',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      color: '#0f172a',
                      fontSize: '14px',
                      outline: 'none',
                      boxSizing: 'border-box'
                    }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', marginBottom: '6px', color: '#334155', fontSize: '13px', fontWeight: '600' }}>
                    Category Name (Malayalam) [Optional]
                  </label>
                  <input 
                    type="text" 
                    value={malayalamName}
                    onChange={(e) => setMalayalamName(e.target.value)}
                    placeholder="e.g., പുതിയ മത്സ്യം"
                    disabled={isAdding}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      background: '#ffffff',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      color: '#0f172a',
                      fontSize: '14px',
                      outline: 'none',
                      boxSizing: 'border-box'
                    }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', marginBottom: '6px', color: '#334155', fontSize: '13px', fontWeight: '600' }}>
                    Status *
                  </label>
                  <select
                    value={status}
                    onChange={(e) => setStatus(e.target.value)}
                    disabled={isAdding}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      background: '#ffffff',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      color: '#0f172a',
                      fontSize: '14px',
                      outline: 'none',
                      cursor: 'pointer',
                      boxSizing: 'border-box'
                    }}
                  >
                    <option value="active">Active (Visible in App)</option>
                    <option value="inactive">Inactive (Hidden in App)</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', marginBottom: '6px', color: '#334155', fontSize: '13px', fontWeight: '600' }}>
                    Category Image *
                  </label>
                  <input 
                    type="file" 
                    accept="image/*"
                    onChange={handleImageChange}
                    ref={fileInputRef}
                    style={{
                      width: '100%',
                      padding: '8px 14px',
                      background: '#ffffff',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      fontSize: '13px',
                      color: '#475569',
                      boxSizing: 'border-box',
                      cursor: 'pointer'
                    }}
                  />
                </div>

                {imagePreview && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: '#f8fafc', padding: '10px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                    <img 
                      src={imagePreview} 
                      alt="Preview" 
                      style={{ width: '60px', height: '60px', objectFit: 'cover', borderRadius: '6px' }} 
                    />
                    <span style={{ fontSize: '12px', color: '#64748b' }}>Selected Image Preview</span>
                  </div>
                )}

                {uploadProgress > 0 && uploadProgress < 100 && (
                  <div>
                    <div style={{ fontSize: '12px', color: '#0284c7', marginBottom: '4px', fontWeight: '600' }}>Uploading: {Math.round(uploadProgress)}%</div>
                    <div style={{ width: '100%', height: '6px', background: '#e2e8f0', borderRadius: '3px' }}>
                      <div style={{ width: `${uploadProgress}%`, height: '100%', background: '#0284c7', borderRadius: '3px', transition: 'width 0.2s' }}></div>
                    </div>
                  </div>
                )}

                <div style={{ display: 'flex', gap: '12px', marginTop: '12px', justifyContent: 'flex-end' }}>
                  <button
                    type="button"
                    onClick={() => setIsFormVisible(false)}
                    style={{
                      padding: '10px 18px',
                      background: '#ffffff',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      color: '#475569',
                      fontSize: '14px',
                      fontWeight: '600',
                      cursor: 'pointer'
                    }}
                  >
                    Cancel
                  </button>
                  <button 
                    type="submit" 
                    disabled={isAdding || !name || !imageFile}
                    style={{
                      padding: '10px 20px',
                      background: (!name || !imageFile) ? '#94a3b8' : '#0284c7',
                      color: '#ffffff',
                      border: 'none',
                      borderRadius: '8px',
                      cursor: (!name || !imageFile || isAdding) ? 'not-allowed' : 'pointer',
                      fontWeight: '600',
                      fontSize: '14px',
                      opacity: isAdding ? 0.7 : 1
                    }}
                  >
                    {isAdding ? 'Saving...' : 'Add Category'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Existing Categories Grid */}
        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>Loading categories...</div>
        ) : categories.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>No categories found. Add your first category above.</div>
        ) : (
          <div style={{ 
            display: 'grid', 
            gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', 
            gap: '20px',
            marginTop: '20px'
          }}>
            {categories.map(category => {
              const isActive = (category.status || 'active') === 'active';

              return (
                <div key={category.id} style={{
                  background: '#ffffff',
                  border: '1px solid #e2e8f0',
                  borderRadius: '16px',
                  overflow: 'hidden',
                  display: 'flex',
                  flexDirection: 'column',
                  transition: 'border-color 0.2s ease'
                }}>
                  <div style={{ height: '140px', background: '#f8fafc', width: '100%', position: 'relative' }}>
                    {category.imageUrl ? (
                      <img src={category.imageUrl} alt={category.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    ) : (
                      <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8' }}>No Image</div>
                    )}
                    <span style={{
                      position: 'absolute',
                      top: '10px',
                      right: '10px',
                      padding: '4px 10px',
                      borderRadius: '12px',
                      fontSize: '11px',
                      fontWeight: '600',
                      background: isActive ? '#ecfdf5' : '#f1f5f9',
                      color: isActive ? '#059669' : '#64748b',
                      border: isActive ? '1px solid #a7f3d0' : '1px solid #cbd5e1'
                    }}>
                      {isActive ? 'Active' : 'Inactive'}
                    </span>
                  </div>

                  <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', flex: 1, justifyContent: 'space-between', gap: '12px' }}>
                    <div>
                      <div style={{ fontWeight: '600', fontSize: '15px', color: '#0f172a', marginBottom: '2px' }}>{category.name}</div>
                      {category.malayalamName && (
                        <div style={{ fontSize: '13px', color: '#64748b' }}>{category.malayalamName}</div>
                      )}
                    </div>

                    <div style={{ display: 'flex', gap: '8px', paddingTop: '10px', borderTop: '1px solid #f1f5f9' }}>
                      <button
                        onClick={() => handleToggleStatus(category.id, category.status || 'active')}
                        style={{
                          flex: 1,
                          padding: '6px 10px',
                          borderRadius: '6px',
                          border: '1px solid #cbd5e1',
                          background: '#ffffff',
                          color: isActive ? '#dc2626' : '#059669',
                          fontSize: '12px',
                          fontWeight: '600',
                          cursor: 'pointer'
                        }}
                      >
                        {isActive ? 'Deactivate' : 'Activate'}
                      </button>
                      <button
                        onClick={() => handleDeleteCategory(category.id)}
                        style={{
                          padding: '6px 10px',
                          borderRadius: '6px',
                          border: '1px solid #fecaca',
                          background: '#fef2f2',
                          color: '#dc2626',
                          fontSize: '12px',
                          fontWeight: '600',
                          cursor: 'pointer'
                        }}
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default Categories;

