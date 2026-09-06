import React, { useState, useEffect, useRef } from 'react';
import { collection, addDoc, getDocs, doc, updateDoc, serverTimestamp, query, orderBy } from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../firebase';
import './Homepage.css';

const Categories = () => {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isAdding, setIsAdding] = useState(false);
  const [isFormVisible, setIsFormVisible] = useState(false);
  const [editingCategoryId, setEditingCategoryId] = useState(null);
  
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

  const fetchCategories = async (forceRefresh = false) => {
    try {
      // 1. Check local cache to avoid Firestore reads on tab switch
      if (!forceRefresh) {
        const cached = sessionStorage.getItem('admin_categories_cache');
        if (cached) {
          try {
            const parsed = JSON.parse(cached);
            setCategories(parsed);
            setLoading(false);
            return;
          } catch (e) {
            console.error('Cache parse error:', e);
          }
        }
      }

      setLoading(true);
      const q = query(collection(db, 'categories'), orderBy('createdAt', 'desc'));
      const querySnapshot = await getDocs(q);
      const fetched = [];
      querySnapshot.forEach((docSnap) => {
        const data = docSnap.data();
        // Convert serverTimestamp if present for serialization
        const createdAtVal = data.createdAt?.toDate ? data.createdAt.toDate().toISOString() : data.createdAt;
        fetched.push({ id: docSnap.id, ...data, createdAt: createdAtVal });
      });
      
      setCategories(fetched);
      sessionStorage.setItem('admin_categories_cache', JSON.stringify(fetched));
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
      setCategories(prev => {
        const updated = prev.map(c => c.id === categoryId ? { ...c, status: newStatus } : c);
        sessionStorage.setItem('admin_categories_cache', JSON.stringify(updated));
        return updated;
      });
    } catch (err) {
      console.error('Error updating status:', err);
      alert('Failed to update category status.');
    }
  };

  const convertToWebP = (file) => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = (event) => {
        const img = new Image();
        img.src = event.target.result;
        img.onload = () => {
          const canvas = document.createElement('canvas');
          canvas.width = img.width;
          canvas.height = img.height;
          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0);
          canvas.toBlob(
            (blob) => {
              if (blob) {
                const newFile = new File([blob], file.name.replace(/\.[^/.]+$/, "") + ".webp", {
                  type: 'image/webp',
                });
                resolve(newFile);
              } else {
                reject(new Error("Canvas to Blob failed"));
              }
            },
            'image/webp',
            0.85
          );
        };
        img.onerror = (error) => reject(error);
      };
      reader.onerror = (error) => reject(error);
    });
  };

  const resetForm = () => {
    setName('');
    setStatus('active');
    setImageFile(null);
    setImagePreview(null);
    setUploadProgress(0);
    setEditingCategoryId(null);
    setIsAdding(false);
    setIsFormVisible(false);
    setError('');
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const openEditModal = (category) => {
    setEditingCategoryId(category.id);
    setName(category.name);
    setStatus(category.status || 'active');
    setImagePreview(category.imageUrl);
    setImageFile(null);
    setError('');
    setIsFormVisible(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim() || (!imageFile && !editingCategoryId)) {
      setError('Please provide a category name and select an image.');
      return;
    }

    try {
      setIsAdding(true);
      setError('');
      
      let downloadURL = imagePreview; // Default to existing URL if editing and no new image

      if (imageFile) {
        // Convert to WebP
        let finalFile = imageFile;
        try {
          if (imageFile.type.startsWith('image/') && !imageFile.type.includes('webp')) {
            finalFile = await convertToWebP(imageFile);
          }
        } catch (conversionError) {
          console.error("WebP conversion failed, using original file:", conversionError);
        }

        // 1. Upload Image
        const storageRef = ref(storage, `categories/${Date.now()}_${finalFile.name}`);
        const uploadTask = uploadBytesResumable(storageRef, finalFile);

        downloadURL = await new Promise((resolve, reject) => {
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
              reject(error);
            },
            async () => {
              const url = await getDownloadURL(uploadTask.snapshot.ref);
              resolve(url);
            }
          );
        });
      }

      if (downloadURL) {
        if (editingCategoryId) {
          // Update existing
          await updateDoc(doc(db, 'categories', editingCategoryId), {
            name: name.trim(),
            imageUrl: downloadURL,
            status: status || 'active',
          });
        } else {
          // Save new
          await addDoc(collection(db, 'categories'), {
            name: name.trim(),
            imageUrl: downloadURL,
            status: status || 'active',
            createdAt: serverTimestamp()
          });
        }
        
        resetForm();
        fetchCategories(true);
      }
    } catch (err) {
      console.error('Error saving category:', err);
      setError('An error occurred while saving the category.');
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
            onClick={() => {
              resetForm();
              setIsFormVisible(true);
            }}
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
                <h3 style={{ fontSize: '18px', fontWeight: '700', color: '#0f172a', margin: 0 }}>
                  {editingCategoryId ? 'Edit Category' : 'Create New Category'}
                </h3>
                <button 
                  onClick={resetForm}
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
                    Category Name *
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
                    Category Image {editingCategoryId ? '(Optional to leave unchanged)' : '*'}
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
                    onClick={resetForm}
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
                    disabled={isAdding || !name || (!imageFile && !editingCategoryId)}
                    style={{
                      padding: '10px 20px',
                      background: (!name || (!imageFile && !editingCategoryId)) ? '#94a3b8' : '#0284c7',
                      color: '#ffffff',
                      border: 'none',
                      borderRadius: '8px',
                      cursor: (!name || (!imageFile && !editingCategoryId) || isAdding) ? 'not-allowed' : 'pointer',
                      fontWeight: '600',
                      fontSize: '14px',
                      opacity: isAdding ? 0.7 : 1
                    }}
                  >
                    {isAdding ? 'Saving...' : (editingCategoryId ? 'Save Changes' : 'Add Category')}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Categories Table View */}
        <div className="custom-table-wrapper" style={{ marginTop: '20px' }}>
          <table className="custom-table">
            <thead>
              <tr>
                <th>Category Image & Name</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="3" style={{ textAlign: 'center', padding: '30px', color: '#64748b' }}>
                    Loading categories...
                  </td>
                </tr>
              ) : categories.length > 0 ? (
                categories.map((category) => {
                  const isActive = (category.status || 'active') === 'active';
                  const currentStatus = isActive ? 'active' : 'suspended';

                  return (
                    <tr key={category.id}>
                      <td>
                        <div className="customer-cell" style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                          <div style={{ width: '48px', height: '48px', borderRadius: '10px', overflow: 'hidden', background: '#f8fafc', border: '1px solid #e2e8f0', flexShrink: 0 }}>
                            {category.imageUrl ? (
                              <img src={category.imageUrl} alt={category.name} loading="lazy" decoding="async" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            ) : (
                              <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: '11px' }}>No Image</div>
                            )}
                          </div>
                          <div style={{ fontWeight: '600', color: '#0f172a', fontSize: '14px' }}>
                            {category.name}
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className={`badge ${currentStatus}`}>
                          {isActive ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button
                            onClick={() => openEditModal(category)}
                            style={{
                              padding: '6px 12px',
                              borderRadius: '6px',
                              border: '1px solid #3b82f6',
                              background: 'transparent',
                              color: '#3b82f6',
                              fontSize: '12px',
                              fontWeight: '600',
                              cursor: 'pointer'
                            }}
                          >
                            Edit
                          </button>
                          <button
                            onClick={() => handleToggleStatus(category.id, category.status || 'active')}
                            style={{
                              padding: '6px 12px',
                              borderRadius: '6px',
                              border: isActive ? '1px solid #cbd5e1' : 'none',
                              background: isActive ? '#ffffff' : '#2ed573',
                              color: isActive ? '#dc2626' : '#ffffff',
                              fontSize: '12px',
                              fontWeight: '600',
                              cursor: 'pointer'
                            }}
                          >
                            {isActive ? 'Deactivate' : 'Activate'}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan="3" style={{ textAlign: 'center', padding: '30px', color: '#64748b' }}>
                    No categories found. Add your first category above.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default Categories;

