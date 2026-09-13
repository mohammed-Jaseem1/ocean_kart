import React, { useState, useEffect } from 'react';
import { collection, getDocs, query } from 'firebase/firestore';
import { db } from '../firebase';

const Revenue = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [metrics, setMetrics] = useState({
    totalRevenue: 0,
    monthlyRevenue: 0,
    completedOrders: 0,
    avgOrderValue: 0,
  });

  useEffect(() => {
    fetchRevenueData();
  }, []);

  const fetchRevenueData = async () => {
    setLoading(true);
    try {
      const snapshot = await getDocs(query(collection(db, 'orders')));
      let total = 0;
      let monthlyTotal = 0;
      let count = 0;
      const fetchedOrders = [];

      const currentMonth = new Date().getMonth();
      const currentYear = new Date().getFullYear();

      snapshot.forEach(docSnap => {
        const data = docSnap.data();
        const amt = parseFloat(data.amount || data.totalAmount || 0);
        total += amt;
        count++;

        const orderDate = data.createdAt?.toDate ? data.createdAt.toDate() : (data.createdAt ? new Date(data.createdAt) : null);
        if (orderDate && orderDate.getMonth() === currentMonth && orderDate.getFullYear() === currentYear) {
          monthlyTotal += amt;
        } else if (!orderDate) {
          // If date is not specified, include in current month total
          monthlyTotal += amt;
        }

        fetchedOrders.push({ id: docSnap.id, amount: amt, ...data });
      });

      const avg = count > 0 ? (total / count) : 0;

      setMetrics({
        totalRevenue: total,
        monthlyRevenue: monthlyTotal,
        completedOrders: count,
        avgOrderValue: avg,
      });

      setOrders(fetchedOrders);
    } catch (err) {
      console.error('Error fetching revenue data:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      {/* Revenue Stat Cards */}
      <div className="stat-grid">
        <div className="stat-card">
          <div className="stat-icon-wrapper">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="12" y1="1" x2="12" y2="23" /><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6" />
            </svg>
          </div>
          <div className="stat-info">
            <span className="stat-title">Gross Revenue</span>
            <span className="stat-value">₹{metrics.totalRevenue.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon-wrapper" style={{ background: '#dcfce7', color: '#16a34a' }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6" />
            </svg>
          </div>
          <div className="stat-info">
            <span className="stat-title">Monthly Net Revenue</span>
            <span className="stat-value">₹{metrics.monthlyRevenue.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon-wrapper" style={{ background: '#fef3c7', color: '#d97706' }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" /><path d="M16 8l-8 8M8 8h8v8" />
            </svg>
          </div>
          <div className="stat-info">
            <span className="stat-title">Average Order Value</span>
            <span className="stat-value">₹{metrics.avgOrderValue.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon-wrapper" style={{ background: '#e0f2fe', color: '#0284c7' }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" />
            </svg>
          </div>
          <div className="stat-info">
            <span className="stat-title">Paid Orders</span>
            <span className="stat-value">{metrics.completedOrders}</span>
          </div>
        </div>
      </div>

      {/* Revenue Breakdown Table */}
      <div className="card">
        <div className="page-header" style={{ marginBottom: '1.25rem' }}>
          <div>
            <h2 className="page-title" style={{ fontSize: '1.5rem' }}>Transaction & Revenue Details</h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
              Detailed financial audit log for all orders across OceanKart stores.
            </p>
          </div>
        </div>

        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                <th>Order Ref</th>
                <th>Customer / Payer</th>
                <th>Order Amount</th>
                <th>Commission Share</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
                    Loading financial records...
                  </td>
                </tr>
              ) : orders.length > 0 ? (
                orders.map((o) => (
                  <tr key={o.id}>
                    <td style={{ fontWeight: '600', color: 'var(--primary)' }}>
                      {o.orderId || o.id.substring(0, 8)}
                    </td>
                    <td>
                      <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                        {o.customerName || o.userName || 'Customer'}
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                        {o.customerEmail || o.userEmail || ''}
                      </div>
                    </td>
                    <td style={{ fontWeight: '700', color: 'var(--success)' }}>
                      ₹{parseFloat(o.amount || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                    </td>
                    <td style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                      ₹{(parseFloat(o.amount || 0) * 0.1).toLocaleString('en-IN', { minimumFractionDigits: 2 })} (10%)
                    </td>
                    <td>
                      <span className="badge badge-success">
                        {o.status || 'Paid'}
                      </span>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>
                    No transaction records available.
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

export default Revenue;
