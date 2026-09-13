import React, { useState, useEffect } from 'react';
import { collection, query, getDocs } from 'firebase/firestore';
import { db } from '../firebase';

const Orders = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'orders'));
      const querySnapshot = await getDocs(q);
      let fetchedOrders = [];
      querySnapshot.forEach((doc) => {
        fetchedOrders.push({ id: doc.id, ...doc.data() });
      });
      
      fetchedOrders = fetchedOrders.sort((a, b) => {
        const dateA = a.createdAt?.toDate ? a.createdAt.toDate() : new Date(0);
        const dateB = b.createdAt?.toDate ? b.createdAt.toDate() : new Date(0);
        return dateB - dateA;
      });

      setOrders(fetchedOrders);
      setError(null);
    } catch (err) {
      console.error("Error fetching orders: ", err);
      setError("Failed to fetch orders.");
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div style={{ padding: '2.5rem', textAlign: 'center', color: 'var(--text-secondary)' }}>
        Loading orders...
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ padding: '2.5rem', textAlign: 'center', color: 'var(--danger)' }}>
        {error}
      </div>
    );
  }

  return (
    <div className="card">
      <div className="page-header" style={{ marginBottom: '1.25rem' }}>
        <h2 className="page-title" style={{ fontSize: '1.5rem' }}>All Orders</h2>
        <button className="btn btn-secondary btn-sm" onClick={fetchOrders}>Refresh Data</button>
      </div>

      <div className="table-container">
        <table className="table">
          <thead>
            <tr>
              <th>Order ID</th>
              <th>Customer</th>
              <th>Product</th>
              <th>Date</th>
              <th>Amount</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {orders.length > 0 ? orders.map((order) => {
              const statusLower = (order.status || 'pending').toLowerCase();
              const badgeClass = statusLower === 'completed' || statusLower === 'delivered' ? 'badge-success' : statusLower === 'cancelled' ? 'badge-danger' : 'badge-warning';

              return (
                <tr key={order.id}>
                  <td style={{ fontWeight: '600', color: 'var(--primary)' }}>{order.orderId || order.id.substring(0, 8)}</td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                      <div style={{
                        width: '32px', height: '32px', borderRadius: '50%',
                        backgroundColor: 'var(--primary-light)', color: 'var(--primary)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontWeight: '700', fontSize: '0.8rem'
                      }}>
                        {(order.customerName || order.userName || 'U').charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>{order.customerName || order.userName || 'Unknown'}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>{order.customerEmail || order.userEmail || ''}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    {Array.isArray(order.items) && order.items.length > 0
                      ? order.items.map(i => `${i.name || 'Item'} (${i.quantity || 1}kg)`).join(', ')
                      : order.productName || order.product || 'N/A'}
                  </td>
                  <td style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                    {order.createdAt?.toDate 
                      ? order.createdAt.toDate().toLocaleDateString() 
                      : 'Unknown'}
                  </td>
                  <td style={{ fontWeight: '700', color: 'var(--text-primary)' }}>₹{parseFloat(order.amount || order.totalAmount || 0).toFixed(2)}</td>
                  <td>
                    <span className={`badge ${badgeClass}`}>
                      {order.status || 'Pending'}
                    </span>
                  </td>
                </tr>
              );
            }) : (
              <tr>
                <td colSpan="6" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>No orders found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default Orders;
