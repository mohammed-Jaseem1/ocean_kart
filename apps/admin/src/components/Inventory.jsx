import React, { useState, useEffect } from 'react';
import { collection, getDocs, doc, updateDoc, deleteDoc, addDoc, query, where, collectionGroup } from 'firebase/firestore';
import { db } from '../firebase';

const Inventory = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState({ stockQuantity: '', pricePerKg: '' });
  
  const [shopsList, setShopsList] = useState([]);
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [newProduct, setNewProduct] = useState({ shopId: '', name: '', category: 'General', pricePerKg: '', stockQuantity: '' });

  useEffect(() => {
    fetchAllInventory();
  }, []);

  const fetchAllInventory = async () => {
    setLoading(true);
    try {
      // First, get all shopkeepers to map shopId to shopName
      const usersQuery = query(collection(db, 'users'), where('role', '==', 'Shopkeeper'));
      const usersSnapshot = await getDocs(usersQuery);
      const shops = {};
      const fetchedShops = [];
      usersSnapshot.forEach(doc => {
        const shopName = doc.data().shopName || doc.data().name || 'Unknown Shop';
        shops[doc.id] = shopName;
        fetchedShops.push({ id: doc.id, name: shopName });
      });
      setShopsList(fetchedShops);

      // Now fetch all products using collectionGroup
      const productsSnapshot = await getDocs(collectionGroup(db, 'products'));
      const fetchedProducts = [];
      
      productsSnapshot.forEach(doc => {
        const data = doc.data();
        const ref = doc.ref;
        // The parent of the products collection is the user document
        const shopId = ref.parent.parent?.id;
        
        fetchedProducts.push({
          id: doc.id,
          shopId: shopId,
          shopName: shopId ? shops[shopId] || 'Unknown Shop' : 'Unknown Shop',
          ...data
        });
      });
      
      setProducts(fetchedProducts);
      setError(null);
    } catch (err) {
      console.error("Error fetching inventory: ", err);
      setError("Failed to fetch inventory.");
    } finally {
      setLoading(false);
    }
  };

  const handleEditClick = (product) => {
    setEditingId(product.id);
    setEditForm({
      stockQuantity: product.stockQuantity?.toString() || '0',
      pricePerKg: product.pricePerKg?.toString() || '0'
    });
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditForm({ stockQuantity: '', pricePerKg: '' });
  };

  const handleSaveEdit = async (product) => {
    try {
      const productRef = doc(db, 'users', product.shopId, 'products', product.id);
      
      const newStock = parseInt(editForm.stockQuantity, 10);
      const newPrice = parseFloat(editForm.pricePerKg);
      
      if (isNaN(newStock) || isNaN(newPrice)) {
        alert("Please enter valid numbers for stock and price");
        return;
      }
      
      await updateDoc(productRef, {
        stockQuantity: newStock,
        pricePerKg: newPrice
      });
      
      // Update local state
      setProducts(products.map(p => {
        if (p.id === product.id) {
          return { ...p, stockQuantity: newStock, pricePerKg: newPrice };
        }
        return p;
      }));
      
      setEditingId(null);
    } catch (err) {
      console.error("Error updating product: ", err);
      alert("Failed to update product.");
    }
  };

  const handleDelete = async (product) => {
    if (!window.confirm("Are you sure you want to delete this product?")) return;
    try {
      const productRef = doc(db, 'users', product.shopId, 'products', product.id);
      await deleteDoc(productRef);
      setProducts(products.filter(p => p.id !== product.id));
    } catch (err) {
      console.error("Error deleting product: ", err);
      alert("Failed to delete product.");
    }
  };

  const handleAddProduct = async () => {
    if (!newProduct.shopId || !newProduct.name || !newProduct.pricePerKg || !newProduct.stockQuantity) {
      alert("Please fill in all required fields.");
      return;
    }
    
    try {
      const productsRef = collection(db, 'users', newProduct.shopId, 'products');
      const docRef = await addDoc(productsRef, {
        shopId: newProduct.shopId,
        name: newProduct.name,
        category: newProduct.category,
        pricePerKg: parseFloat(newProduct.pricePerKg),
        stockQuantity: parseInt(newProduct.stockQuantity, 10),
        status: 'active',
        createdAt: new Date(),
      });
      
      const shopName = shopsList.find(s => s.id === newProduct.shopId)?.name || 'Unknown Shop';
      setProducts([{
        id: docRef.id,
        shopId: newProduct.shopId,
        shopName: shopName,
        name: newProduct.name,
        category: newProduct.category,
        pricePerKg: parseFloat(newProduct.pricePerKg),
        stockQuantity: parseInt(newProduct.stockQuantity, 10),
      }, ...products]);
      
      setIsAddOpen(false);
      setNewProduct({ shopId: '', name: '', category: 'General', pricePerKg: '', stockQuantity: '' });
    } catch (err) {
      console.error("Error adding product: ", err);
      alert("Failed to add product.");
    }
  };

  if (loading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
        Loading inventory...
      </div>
    );
  }

  return (
    <section className="table-card" style={{ marginTop: '0' }}>
      <div className="table-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2>Global Inventory</h2>
          <div style={{ color: '#64748b', fontSize: '14px', fontWeight: '500' }}>
            Total Products: {products.length}
          </div>
        </div>
        <button 
          onClick={() => setIsAddOpen(true)}
          style={{
            background: '#00b4d8',
            color: '#fff',
            border: 'none',
            padding: '8px 16px',
            borderRadius: '8px',
            cursor: 'pointer',
            fontWeight: '600'
          }}
        >
          + Add Product
        </button>
      </div>

      {error && (
        <div style={{ padding: '16px', color: '#ff4757', background: 'rgba(255, 71, 87, 0.1)', borderRadius: '8px', marginBottom: '20px' }}>
          {error}
        </div>
      )}

      {products.length === 0 ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#64748b', fontSize: '15px' }}>
          No products found in any shop.
        </div>
      ) : (
        <div className="custom-table-wrapper">
          <table className="custom-table">
            <thead>
              <tr>
                <th>Product</th>
                <th>Shop</th>
                <th>Category</th>
                <th>Price (₹)</th>
                <th>Stock</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {products.map((product) => {
                const isEditing = editingId === product.id;
                
                let stockStatus = 'In Stock';
                let statusColor = 'rgba(46, 213, 115, 0.1)';
                let statusTextColor = '#2ed573';
                
                if (product.stockQuantity == null || product.stockQuantity <= 0) {
                    stockStatus = 'Out of Stock';
                    statusColor = 'rgba(255, 71, 87, 0.1)';
                    statusTextColor = '#ff4757';
                } else if (product.stockQuantity < 10) {
                    stockStatus = 'Low Stock';
                    statusColor = 'rgba(255, 165, 2, 0.1)';
                    statusTextColor = '#ffa502';
                }

                return (
                  <tr key={product.id}>
                    <td>
                      <div className="customer-cell">
                        <div className="customer-avatar" style={{ background: 'rgba(0, 180, 216, 0.1)', color: '#00b4d8' }}>
                          {product.name ? product.name.charAt(0).toUpperCase() : 'P'}
                        </div>
                        <div>
                          <div style={{ fontWeight: '600' }}>{product.name || 'Unnamed'}</div>
                          <div style={{ fontSize: '11px', color: 'rgba(255,255,255,0.4)' }}>{product.unit || ''}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <span style={{ fontWeight: '500', color: '#00b4d8' }}>{product.shopName}</span>
                    </td>
                    <td>{product.category || 'General'}</td>
                    
                    {/* Price Column */}
                    <td>
                      {isEditing ? (
                        <input 
                          type="number"
                          value={editForm.pricePerKg}
                          onChange={(e) => setEditForm({...editForm, pricePerKg: e.target.value})}
                          style={{
                            width: '80px',
                            background: 'rgba(255,255,255,0.05)',
                            border: '1px solid rgba(255,255,255,0.1)',
                            color: '#fff',
                            padding: '4px 8px',
                            borderRadius: '4px'
                          }}
                        />
                      ) : (
                        <span style={{ fontWeight: '600' }}>{product.pricePerKg}</span>
                      )}
                    </td>
                    
                    {/* Stock Column */}
                    <td>
                      {isEditing ? (
                        <input 
                          type="number"
                          value={editForm.stockQuantity}
                          onChange={(e) => setEditForm({...editForm, stockQuantity: e.target.value})}
                          style={{
                            width: '80px',
                            background: 'rgba(255,255,255,0.05)',
                            border: '1px solid rgba(255,255,255,0.1)',
                            color: '#fff',
                            padding: '4px 8px',
                            borderRadius: '4px'
                          }}
                        />
                      ) : (
                        <span>{product.stockQuantity || 0}</span>
                      )}
                    </td>
                    
                    <td>
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '12px',
                        fontSize: '12px',
                        fontWeight: '600',
                        background: statusColor,
                        color: statusTextColor,
                        whiteSpace: 'nowrap'
                      }}>
                        {stockStatus}
                      </span>
                    </td>
                    
                    <td>
                      {isEditing ? (
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button
                            onClick={() => handleSaveEdit(product)}
                            style={{
                              background: 'rgba(46, 213, 115, 0.15)',
                              color: '#2ed573',
                              border: 'none',
                              padding: '6px 12px',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontWeight: '600'
                            }}
                          >
                            Save
                          </button>
                          <button
                            onClick={handleCancelEdit}
                            style={{
                              background: 'rgba(255, 255, 255, 0.1)',
                              color: '#fff',
                              border: 'none',
                              padding: '6px 12px',
                              borderRadius: '6px',
                              cursor: 'pointer'
                            }}
                          >
                            Cancel
                          </button>
                        </div>
                      ) : (
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button
                            onClick={() => handleEditClick(product)}
                            style={{
                              background: 'rgba(0, 180, 216, 0.15)',
                              color: '#00b4d8',
                              border: '1px solid rgba(0, 180, 216, 0.2)',
                              padding: '6px 16px',
                              borderRadius: '8px',
                              fontWeight: '600',
                              cursor: 'pointer',
                              transition: 'all 0.2s'
                            }}
                          >
                            Edit
                          </button>
                          <button
                            onClick={() => handleDelete(product)}
                            style={{
                              background: 'rgba(255, 71, 87, 0.15)',
                              color: '#ff4757',
                              border: '1px solid rgba(255, 71, 87, 0.2)',
                              padding: '6px 16px',
                              borderRadius: '8px',
                              fontWeight: '600',
                              cursor: 'pointer',
                              transition: 'all 0.2s'
                            }}
                          >
                            Delete
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Add Product Modal */}
      {isAddOpen && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000
        }}>
          <div style={{ background: '#0a1628', padding: '24px', borderRadius: '16px', width: '400px', border: '1px solid rgba(255,255,255,0.1)' }}>
            <h3 style={{ marginTop: 0, color: '#fff' }}>Add New Product</h3>
            
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '12px', color: 'rgba(255,255,255,0.7)' }}>SELECT SHOP</label>
              <select 
                value={newProduct.shopId} 
                onChange={(e) => setNewProduct({...newProduct, shopId: e.target.value})}
                style={{ width: '100%', padding: '10px', borderRadius: '8px', background: 'rgba(255,255,255,0.05)', color: '#fff', border: '1px solid rgba(255,255,255,0.1)' }}
              >
                <option value="" style={{ color: '#000' }}>Select a shop</option>
                {shopsList.map(shop => (
                  <option key={shop.id} value={shop.id} style={{ color: '#000' }}>{shop.name}</option>
                ))}
              </select>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '12px', color: 'rgba(255,255,255,0.7)' }}>PRODUCT NAME</label>
              <input 
                type="text" 
                value={newProduct.name}
                onChange={(e) => setNewProduct({...newProduct, name: e.target.value})}
                style={{ width: '100%', padding: '10px', borderRadius: '8px', background: 'rgba(255,255,255,0.05)', color: '#fff', border: '1px solid rgba(255,255,255,0.1)' }}
              />
            </div>

            <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '12px', color: 'rgba(255,255,255,0.7)' }}>PRICE (₹)</label>
                <input 
                  type="number" 
                  value={newProduct.pricePerKg}
                  onChange={(e) => setNewProduct({...newProduct, pricePerKg: e.target.value})}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', background: 'rgba(255,255,255,0.05)', color: '#fff', border: '1px solid rgba(255,255,255,0.1)' }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '12px', color: 'rgba(255,255,255,0.7)' }}>STOCK (KG)</label>
                <input 
                  type="number" 
                  value={newProduct.stockQuantity}
                  onChange={(e) => setNewProduct({...newProduct, stockQuantity: e.target.value})}
                  style={{ width: '100%', padding: '10px', borderRadius: '8px', background: 'rgba(255,255,255,0.05)', color: '#fff', border: '1px solid rgba(255,255,255,0.1)' }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button 
                onClick={() => setIsAddOpen(false)}
                style={{ padding: '10px 16px', borderRadius: '8px', background: 'transparent', color: '#fff', border: 'none', cursor: 'pointer' }}
              >
                Cancel
              </button>
              <button 
                onClick={handleAddProduct}
                style={{ padding: '10px 16px', borderRadius: '8px', background: '#00b4d8', color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 'bold' }}
              >
                Add Product
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
};

export default Inventory;
