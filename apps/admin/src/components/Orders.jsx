import React, { useState, useEffect } from 'react';
import { collection, query, getDocs, orderBy } from 'firebase/firestore';
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
      const q = query(
        collection(db, 'orders')
        // orderBy('createdAt', 'desc') // Ensure createdAt exists, otherwise it might fail without an index
      );
      const querySnapshot = await getDocs(q);
      let fetchedOrders = [];
      querySnapshot.forEach((doc) => {
        fetchedOrders.push({ id: doc.id, ...doc.data() });
      });
      
      // Sort manually to avoid index issues if they haven't been created in firestore yet
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
      <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
        Loading orders...
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#ff4757' }}>
        {error}
      </div>
    );
  }

  return (
    <section className="table-card">
      <div className="table-header">
        <h2>All Orders</h2>
        <button className="btn-view-all" onClick={fetchOrders}>Refresh Data</button>
      </div>

      <div className="custom-table-wrapper">
        <table className="custom-table">
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
            {orders.length > 0 ? orders.map((order) => (
              <tr key={order.id}>
                <td style={{ fontWeight: '600', color: '#00b4d8' }}>{order.orderId || order.id.substring(0, 8)}</td>
                <td>
                  <div className="customer-cell">
                    <div className="customer-avatar">
                      {(order.customerName || order.userName || 'U').charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <div style={{ fontWeight: '600' }}>{order.customerName || order.userName || 'Unknown'}</div>
                      <div style={{ fontSize: '11px', color: 'rgba(255,255,255,0.4)' }}>{order.customerEmail || order.userEmail || ''}</div>
                    </div>
                  </div>
                </td>
                <td>{order.productName || order.product || 'Various'}</td>
                <td>
                    {order.createdAt?.toDate 
                        ? order.createdAt.toDate().toLocaleDateString() 
                        : 'Unknown'}
                </td>
                <td style={{ fontWeight: '600' }}>${parseFloat(order.amount || order.totalAmount || 0).toFixed(2)}</td>
                <td>
                  <span className={`badge ${(order.status || 'pending').toLowerCase()}`}>
                    {order.status || 'Pending'}
                  </span>
                </td>
              </tr>
            )) : (
              <tr>
                <td colSpan="6" style={{ textAlign: 'center', padding: '20px', color: '#64748b' }}>No orders found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
};

export default Orders;
