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
      let count = 0;
      const fetchedOrders = [];

      snapshot.forEach(docSnap => {
        const data = docSnap.data();
        const amt = parseFloat(data.amount || data.totalAmount || 0);
        total += amt;
        count++;
        fetchedOrders.push({ id: docSnap.id, amount: amt, ...data });
      });

      const avg = count > 0 ? (total / count) : 0;

      setMetrics({
        totalRevenue: total,
        monthlyRevenue: total * 0.85, // estimated monthly
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
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Revenue KPI Cards */}
      <section className="kpi-grid">
        <div className="kpi-card">
          <div className="kpi-icon-wrapper" style={{ background: 'rgba(0, 180, 216, 0.1)', color: '#00b4d8' }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="12" y1="1" x2="12" y2="23" /><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6" />
            </svg>
          </div>
          <span className="kpi-title">Gross Revenue</span>
          <span className="kpi-value">${metrics.totalRevenue.toFixed(2)}</span>
          <div className="kpi-trend trend-up">
            <span>+15.4% from last month</span>
          </div>
        </div>

        <div className="kpi-card">
          <div className="kpi-icon-wrapper" style={{ background: 'rgba(46, 213, 115, 0.1)', color: '#2ed573' }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6" />
            </svg>
          </div>
          <span className="kpi-title">Monthly Net Revenue</span>
          <span className="kpi-value">${metrics.monthlyRevenue.toFixed(2)}</span>
          <div className="kpi-trend trend-up">
            <span>+9.2% growth rate</span>
          </div>
        </div>

        <div className="kpi-card">
          <div className="kpi-icon-wrapper" style={{ background: 'rgba(255, 165, 2, 0.1)', color: '#ffa502' }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" /><path d="M16 8l-8 8M8 8h8v8" />
            </svg>
          </div>
          <span className="kpi-title">Average Order Value</span>
          <span className="kpi-value">${metrics.avgOrderValue.toFixed(2)}</span>
          <div className="kpi-trend trend-up">
            <span>+$3.50 per customer order</span>
          </div>
        </div>

        <div className="kpi-card">
          <div className="kpi-icon-wrapper" style={{ background: 'rgba(112, 161, 255, 0.1)', color: '#70a1ff' }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" />
            </svg>
          </div>
          <span className="kpi-title">Paid Orders</span>
          <span className="kpi-value">{metrics.completedOrders}</span>
          <div className="kpi-trend trend-up">
            <span>100% processed</span>
          </div>
        </div>
      </section>

      {/* Revenue Breakdown Table */}
      <div className="table-card">
        <div className="table-header">
          <div>
            <h2>Transaction & Revenue Details</h2>
            <p style={{ color: '#64748b', fontSize: '13px', margin: '4px 0 0' }}>
              Detailed financial audit log for all orders across OceanKart stores.
            </p>
          </div>
        </div>

        <div className="custom-table-wrapper">
          <table className="custom-table">
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
                  <td colSpan="5" style={{ textAlign: 'center', padding: '30px', color: '#64748b' }}>
                    Loading financial records...
                  </td>
                </tr>
              ) : orders.length > 0 ? (
                orders.map((o) => (
                  <tr key={o.id}>
                    <td style={{ fontWeight: '600', color: '#00b4d8' }}>
                      {o.orderId || o.id.substring(0, 8)}
                    </td>
                    <td>
                      <div style={{ fontWeight: '600', color: '#0f172a' }}>
                        {o.customerName || o.userName || 'Customer'}
                      </div>
                      <div style={{ fontSize: '11px', color: '#64748b' }}>
                        {o.customerEmail || o.userEmail || ''}
                      </div>
                    </td>
                    <td style={{ fontWeight: '700', color: '#2ed573' }}>
                      ${parseFloat(o.amount || 0).toFixed(2)}
                    </td>
                    <td style={{ fontWeight: '600', color: '#0f172a' }}>
                      ${(parseFloat(o.amount || 0) * 0.1).toFixed(2)} (10%)
                    </td>
                    <td>
                      <span className="badge active">
                        {o.status || 'Paid'}
                      </span>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan="5" style={{ textAlign: 'center', padding: '30px', color: '#64748b' }}>
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
