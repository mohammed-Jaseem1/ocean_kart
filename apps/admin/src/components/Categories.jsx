import React, { useState, useEffect, useRef } from 'react';
import { collection, addDoc, getDocs, doc, updateDoc, serverTimestamp, query, orderBy } from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../firebase';

const Categories = () => {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isAdding, setIsAdding] = useState(false);
  const [isFormVisible, setIsFormVisible] = useState(false);
  const [editingCategoryId, setEditingCategoryId] = useState(null);
  
  // Form State
  const [name, setName] = useState('');
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
      
      let downloadURL = imagePreview;

      if (imageFile) {
        let finalFile = imageFile;
        try {
          if (imageFile.type.startsWith('image/') && !imageFile.type.includes('webp')) {
            finalFile = await convertToWebP(imageFile);
          }
        } catch (conversionError) {
          console.error("WebP conversion failed, using original file:", conversionError);
        }

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
          await updateDoc(doc(db, 'categories', editingCategoryId), {
            name: name.trim(),
            imageUrl: downloadURL,
            status: status || 'active',
          });
        } else {
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
    <div className="card">
      <div className="page-header" style={{ marginBottom: '1.5rem' }}>
        <div>
          <h2 className="page-title" style={{ fontSize: '1.5rem' }}>Product Categories</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            Total Categories: {categories.length}
          </p>
        </div>

        <button 
          onClick={() => {
            resetForm();
            setIsFormVisible(true);
          }}
          className="btn btn-primary"
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
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '520px' }}>
            <div className="modal-header">
              <h3>{editingCategoryId ? 'Edit Category' : 'Create New Category'}</h3>
              <button onClick={resetForm} style={{ fontSize: '1.5rem', color: 'var(--text-secondary)' }}>&times;</button>
            </div>

            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                {error && (
                  <div style={{ padding: '0.75rem 1rem', color: '#991b1b', background: '#fee2e2', border: '1px solid #fca5a5', borderRadius: 'var(--radius-md)', fontSize: '0.85rem' }}>
                    {error}
                  </div>
                )}

                <div className="form-group">
                  <label className="form-label">Category Name *</label>
                  <input 
                    type="text" 
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="e.g., Fresh Fish & Marine"
                    disabled={isAdding}
                    className="form-input"
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Status *</label>
                  <select
                    value={status}
                    onChange={(e) => setStatus(e.target.value)}
                    disabled={isAdding}
                    className="form-select"
                  >
                    <option value="active">Active (Visible in App)</option>
                    <option value="inactive">Inactive (Hidden in App)</option>
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">
                    Category Image {editingCategoryId ? '(Optional to leave unchanged)' : '*'}
                  </label>
                  <input 
                    type="file" 
                    accept="image/*"
                    onChange={handleImageChange}
                    ref={fileInputRef}
                    className="form-input"
                  />
                </div>

                {imagePreview && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', background: 'var(--bg-base)', padding: '0.75rem', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-light)' }}>
                    <img 
                      src={imagePreview} 
                      alt="Preview" 
                      style={{ width: '56px', height: '56px', objectFit: 'cover', borderRadius: 'var(--radius-md)' }} 
                    />
                    <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Selected Image Preview</span>
                  </div>
                )}

                {uploadProgress > 0 && uploadProgress < 100 && (
                  <div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--primary)', marginBottom: '4px', fontWeight: '600' }}>
                      Uploading: {Math.round(uploadProgress)}%
                    </div>
                    <div style={{ width: '100%', height: '6px', background: 'var(--border-light)', borderRadius: '3px' }}>
                      <div style={{ width: `${uploadProgress}%`, height: '100%', background: 'var(--primary)', borderRadius: '3px', transition: 'width 0.2s' }}></div>
                    </div>
                  </div>
                )}
              </div>

              <div className="modal-footer">
                <button type="button" onClick={resetForm} className="btn btn-secondary">
                  Cancel
                </button>
                <button 
                  type="submit" 
                  disabled={isAdding || !name || (!imageFile && !editingCategoryId)}
                  className="btn btn-primary"
                >
                  {isAdding ? 'Saving...' : (editingCategoryId ? 'Save Changes' : 'Add Category')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Categories Table View */}
      <div className="table-container">
        <table className="table">
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
                <td colSpan="3" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
                  Loading categories...
                </td>
              </tr>
            ) : categories.length > 0 ? (
              categories.map((category) => {
                const isActive = (category.status || 'active') === 'active';

                return (
                  <tr key={category.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                        <div style={{ width: '48px', height: '48px', borderRadius: 'var(--radius-md)', overflow: 'hidden', background: 'var(--bg-base)', border: '1px solid var(--border-light)', flexShrink: 0 }}>
                          {category.imageUrl ? (
                            <img src={category.imageUrl} alt={category.name} loading="lazy" decoding="async" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                          ) : (
                            <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-tertiary)', fontSize: '0.75rem' }}>No Image</div>
                          )}
                        </div>
                        <div style={{ fontWeight: '600', color: 'var(--text-primary)', fontSize: '0.925rem' }}>
                          {category.name}
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${isActive ? 'badge-success' : 'badge-danger'}`}>
                        {isActive ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        <button
                          onClick={() => openEditModal(category)}
                          className="btn btn-secondary btn-sm"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => handleToggleStatus(category.id, category.status || 'active')}
                          className={`btn ${isActive ? 'btn-danger' : 'btn-success'} btn-sm`}
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
                <td colSpan="3" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
                  No categories found. Add your first category above.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Categories;
