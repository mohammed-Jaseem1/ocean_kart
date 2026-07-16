import React, { useState, useEffect } from 'react';
import { collection, getDocs, doc, updateDoc, deleteDoc, addDoc, query, where, collectionGroup } from 'firebase/firestore';
import { db } from '../firebase';

const Inventory = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState({ stockAction: 'add', stockAmount: '', pricePerKg: '' });

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
      usersSnapshot.forEach(doc => {
        const shopName = doc.data().shopName || doc.data().name || 'Unknown Shop';
        shops[doc.id] = shopName;
      });

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
      stockAction: 'add',
      stockAmount: '',
      pricePerKg: product.pricePerKg?.toString() || '0'
    });
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditForm({ stockAction: 'add', stockAmount: '', pricePerKg: '' });
  };

  const handleSaveEdit = async (product) => {
    try {
      const productRef = doc(db, 'users', product.shopId, 'products', product.id);

      let newStock = product.stockQuantity || 0;
      const amount = parseInt(editForm.stockAmount, 10);

      if (!isNaN(amount) && amount > 0) {
        if (editForm.stockAction === 'add') {
          newStock += amount;
        } else if (editForm.stockAction === 'reduce') {
          newStock -= amount;
          if (newStock < 0) newStock = 0;
        }
      }

      const newPrice = parseFloat(editForm.pricePerKg);

      if (isNaN(newPrice)) {
        alert("Please enter a valid number for price");
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
                          onChange={(e) => setEditForm({ ...editForm, pricePerKg: e.target.value })}
                          style={{
                            width: '80px',
                            background: '#334155',
                            border: '1px solid #475569',
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
                      <span>{product.stockQuantity || 0}</span>
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
                        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                          <select
                            value={editForm.stockAction}
                            onChange={(e) => setEditForm({...editForm, stockAction: e.target.value})}
                            style={{
                              background: '#334155',
                              border: '1px solid #475569',
                              color: '#fff',
                              padding: '4px',
                              borderRadius: '4px',
                              fontSize: '12px'
                            }}
                          >
                            <option value="add" style={{ color: '#000' }}>Add</option>
                            <option value="reduce" style={{ color: '#000' }}>Reduce</option>
                          </select>
                          <input 
                            type="number"
                            placeholder="Qty"
                            value={editForm.stockAmount}
                            onChange={(e) => setEditForm({...editForm, stockAmount: e.target.value})}
                            style={{
                              width: '60px',
                              background: '#334155',
                              border: '1px solid #475569',
                              color: '#fff',
                              padding: '4px 8px',
                              borderRadius: '4px',
                              fontSize: '12px'
                            }}
                          />
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
                            Update
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
    </section>
  );
};

export default Inventory;
