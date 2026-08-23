import React, { useState, useEffect } from 'react';
import ShopOwners from './ShopOwners';
import Users from './Users';
import Revenue from './Revenue';
import DeliveryBoys from './DeliveryBoys';
import { collection, query, where, getDocs } from 'firebase/firestore';
import { db } from '../firebase';
import './Homepage.css';

const Homepage = ({ user, onSignOut }) => {
  const [activeMenu, setActiveMenu] = useState('Dashboard');

  const [dashboardData, setDashboardData] = useState({
    totalRevenue: 0,
    totalOrders: 0,
    activeUsers: 0,
    conversionRate: 0,
    recentOrders: []
  });

  useEffect(() => {
    if (activeMenu === 'Dashboard') {
      fetchDashboardData();
    }
  }, [activeMenu]);

  const fetchDashboardData = async () => {
    let activeUsersCount = 0;
    let revenue = 0;
    let ordersCount = 0;
    let fetchedOrders = [];

    // 1. Fetch Active Users Count
    try {
      const usersQuery = query(collection(db, 'users'), where('status', '==', 'active'));
      const usersSnapshot = await getDocs(usersQuery);
      activeUsersCount = usersSnapshot.size;
    } catch (err) {
      console.warn("Active users fetch warning:", err.message);
      try {
        const allUsersSnap = await getDocs(collection(db, 'users'));
        activeUsersCount = allUsersSnap.size;
      } catch (fallbackErr) {
        console.warn("Users fallback fetch warning:", fallbackErr.message);
      }
    }

    // 2. Fetch Orders
    try {
      const ordersSnapshot = await getDocs(collection(db, 'orders'));
      ordersSnapshot.forEach(doc => {
        const data = doc.data();
        revenue += parseFloat(data.amount || data.totalAmount || 0);
        fetchedOrders.push({ id: doc.id, ...data });
      });

      ordersCount = fetchedOrders.length;

      fetchedOrders = fetchedOrders.sort((a, b) => {
        const dateA = a.createdAt?.toDate ? a.createdAt.toDate() : new Date(0);
        const dateB = b.createdAt?.toDate ? b.createdAt.toDate() : new Date(0);
        return dateB - dateA;
      }).slice(0, 5);
    } catch (err) {
      console.warn("Orders fetch warning:", err.message);
    }

    setDashboardData({
      totalRevenue: revenue,
      totalOrders: ordersCount,
      activeUsers: activeUsersCount,
      conversionRate: ordersCount > 0 && activeUsersCount > 0 ? (ordersCount / activeUsersCount * 100).toFixed(2) : 0,
      recentOrders: fetchedOrders
    });
  };

  const menuItems = [
    {
      name: 'Dashboard',
      icon: (
        <svg fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
          <path d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2v-4zM14 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2v-4z" />
        </svg>
      )
    },
    {
      name: 'Shop Owners',
      icon: (
        <svg fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
          <path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
        </svg>
      )
    },
    {
      name: 'Users',
      icon: (
        <svg fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
          <path d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
        </svg>
      )
    },
    {
      name: 'Revenue',
      icon: (
        <svg fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
          <line x1="12" y1="1" x2="12" y2="23" /><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6" />
        </svg>
      )
    },
    {
      name: 'Delivery Boys',
      icon: (
        <svg fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
          <rect x="1" y="3" width="15" height="13" rx="2" /><polygon points="16 8 20 8 23 11 23 16 16 16 16 8" /><circle cx="5.5" cy="18.5" r="2.5" /><circle cx="18.5" cy="18.5" r="2.5" />
        </svg>
      )
    },
  ];

  const userInitial = user?.email ? user.email.charAt(0).toUpperCase() : 'A';
  const userDisplayName = user?.email ? user.email.split('@')[0] : 'Administrator';

  return (
    <div className="dashboard-container">
      {/* Sidebar Section */}
      <aside className="sidebar">
        <div>
          <div className="sidebar-logo">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
            </svg>
            <span>OceanKart</span>
          </div>

          <nav className="sidebar-menu">
            {menuItems.map((item) => (
              <div
                key={item.name}
                className={`menu-item ${activeMenu === item.name ? 'active' : ''}`}
                onClick={() => setActiveMenu(item.name)}
              >
                {item.icon}
                <span>{item.name}</span>
              </div>
            ))}
          </nav>
        </div>

        <div className="sidebar-footer">
          <div className="user-profile">
            <div className="avatar">{userInitial}</div>
            <div className="user-info">
              <span className="user-name">{userDisplayName}</span>
              <span className="user-role">Super Admin</span>
            </div>
          </div>
          {onSignOut && (
            <button
              onClick={onSignOut}
              style={{
                width: '100%',
                background: 'rgba(255, 71, 87, 0.15)',
                border: '1px solid rgba(255, 71, 87, 0.25)',
                color: '#ff4757',
                padding: '10px',
                borderRadius: '10px',
                marginTop: '16px',
                fontWeight: '600',
                cursor: 'pointer',
                transition: 'all 0.25s',
                fontFamily: 'inherit'
              }}
              onMouseOver={(e) => {
                e.currentTarget.style.background = '#ff4757';
                e.currentTarget.style.color = '#fff';
              }}
              onMouseOut={(e) => {
                e.currentTarget.style.background = 'rgba(255, 71, 87, 0.15)';
                e.currentTarget.style.color = '#ff4757';
              }}
            >
              Sign Out
            </button>
          )}
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="main-content">
        <header className="dashboard-header">
          <div className="header-title">
            <h1>
              {activeMenu === 'Shop Owners'
                ? 'Shop Owners & Store Partners'
                : activeMenu === 'Users'
                ? 'Registered App Users'
                : activeMenu === 'Revenue'
                ? 'Financial & Revenue Analytics'
                : activeMenu === 'Delivery Boys'
                ? 'Delivery Personnel'
                : 'Dashboard Overview'}
            </h1>
            <p>
              {activeMenu === 'Shop Owners'
                ? 'Manage shop keeper partners, store approvals, and business status.'
                : activeMenu === 'Users'
                ? 'View and manage all registered customer user accounts.'
                : activeMenu === 'Revenue'
                ? 'Track sales revenue, profit commissions, and transaction logs.'
                : activeMenu === 'Delivery Boys'
                ? 'Monitor delivery partners, active orders, and vehicle verification.'
                : 'Welcome back, here is what is happening with OceanKart today.'}
            </p>
          </div>

          <div className="header-actions">
            <div className="search-bar">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <input type="text" placeholder="Search transactions, partners..." />
            </div>

            <button className="icon-btn" aria-label="Notifications">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 01-3.46 0" />
              </svg>
              <span className="badge-dot"></span>
            </button>
          </div>
        </header>

        {activeMenu === 'Shop Owners' ? (
          <ShopOwners />
        ) : activeMenu === 'Users' ? (
          <Users />
        ) : activeMenu === 'Revenue' ? (
          <Revenue />
        ) : activeMenu === 'Delivery Boys' ? (
          <DeliveryBoys />
        ) : (
          <>
            {/* KPI Metrics Widgets */}
            <section className="kpi-grid">
              <div className="kpi-card">
                <div className="kpi-icon-wrapper">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <line x1="12" y1="1" x2="12" y2="23" /><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6" />
                  </svg>
                </div>
                <span className="kpi-title">Total Revenue</span>
                <span className="kpi-value">${dashboardData.totalRevenue.toFixed(2)}</span>
                <div className="kpi-trend trend-up">
                  <span>+12.5% this week</span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-icon-wrapper">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" /><line x1="3" y1="6" x2="21" y2="6" /><path d="M16 10a4 4 0 01-8 0" />
                  </svg>
                </div>
                <span className="kpi-title">Total Orders</span>
                <span className="kpi-value">{dashboardData.totalOrders}</span>
                <div className="kpi-trend trend-up">
                  <span>+8.2% this week</span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-icon-wrapper">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" /><circle cx="9" cy="7" r="4" />
                  </svg>
                </div>
                <span className="kpi-title">Active Users</span>
                <span className="kpi-value">{dashboardData.activeUsers}</span>
                <div className="kpi-trend trend-up">
                  <span>+22.0% this week</span>
                </div>
              </div>

              <div className="kpi-card">
                <div className="kpi-icon-wrapper">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
                  </svg>
                </div>
                <span className="kpi-title">Conversion Rate</span>
                <span className="kpi-value">{dashboardData.conversionRate}%</span>
                <div className="kpi-trend trend-down">
                  <span>-1.2% this week</span>
                </div>
              </div>
            </section>

            {/* Charts & Interactive Section */}
            <section className="charts-grid">
              {/* Sales Chart */}
              <div className="chart-card">
                <div className="chart-card-header">
                  <h2>Weekly Sales Performance</h2>
                  <div className="chart-legend">
                    <div className="legend-item">
                      <span className="legend-color" style={{ background: '#00b4d8' }}></span>
                      <span>Direct Sales</span>
                    </div>
                  </div>
                </div>

                <div className="chart-container">
                  <svg className="svg-chart" viewBox="0 0 600 200">
                    <line x1="0" y1="40" x2="600" y2="40" stroke="rgba(255,255,255,0.04)" strokeWidth="1" />
                    <line x1="0" y1="90" x2="600" y2="90" stroke="rgba(255,255,255,0.04)" strokeWidth="1" />
                    <line x1="0" y1="140" x2="600" y2="140" stroke="rgba(255,255,255,0.04)" strokeWidth="1" />
                    <line x1="0" y1="190" x2="600" y2="190" stroke="rgba(255,255,255,0.08)" strokeWidth="1" />

                    <path
                      d="M 20 180 Q 110 120 200 130 T 380 70 T 580 40 L 580 190 L 20 190 Z"
                      fill="url(#chartGradient)"
                      opacity="0.15"
                    />

                    <path
                      d="M 20 180 Q 110 120 200 130 T 380 70 T 580 40"
                      fill="none"
                      stroke="#00b4d8"
                      strokeWidth="3.5"
                      strokeLinecap="round"
                    />

                    <circle cx="20" cy="180" r="5" fill="#00b4d8" stroke="#060b14" strokeWidth="2" />
                    <circle cx="200" cy="130" r="5" fill="#00b4d8" stroke="#060b14" strokeWidth="2" />
                    <circle cx="380" cy="70" r="5" fill="#00b4d8" stroke="#060b14" strokeWidth="2" />
                    <circle cx="580" cy="40" r="5" fill="#00b4d8" stroke="#060b14" strokeWidth="2" />

                    <defs>
                      <linearGradient id="chartGradient" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#00b4d8" />
                        <stop offset="100%" stopColor="#00b4d8" stopOpacity="0" />
                      </linearGradient>
                    </defs>
                  </svg>
                </div>
              </div>

              {/* Category Breakdown */}
              <div className="chart-card">
                <div className="chart-card-header">
                  <h2>Category Share</h2>
                </div>
                <div className="donut-wrapper">
                  <svg width="150" height="150" viewBox="0 0 36 36">
                    <circle cx="18" cy="18" r="15.915" fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="3.5" />
                    <circle cx="18" cy="18" r="15.915" fill="none" stroke="#00b4d8" strokeWidth="3.5"
                      strokeDasharray="45 55" strokeDashoffset="25" />
                    <circle cx="18" cy="18" r="15.915" fill="none" stroke="#2ed573" strokeWidth="3.5"
                      strokeDasharray="35 65" strokeDashoffset="80" />
                    <circle cx="18" cy="18" r="15.915" fill="none" stroke="#ffa502" strokeWidth="3.5"
                      strokeDasharray="20 80" strokeDashoffset="15" />
                  </svg>

                  <div style={{ marginTop: '20px', display: 'flex', flexDirection: 'column', gap: '8px', width: '100%' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                      <span style={{ color: '#00b4d8' }}>● Groceries & Supplies</span>
                      <span style={{ fontWeight: '600' }}>45%</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                      <span style={{ color: '#2ed573' }}>● Fresh Marine Foods</span>
                      <span style={{ fontWeight: '600' }}>35%</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px' }}>
                      <span style={{ color: '#ffa502' }}>● Electronics & Accessories</span>
                      <span style={{ fontWeight: '600' }}>20%</span>
                    </div>
                  </div>
                </div>
              </div>
            </section>

            {/* Recent Orders Section */}
            <section className="table-card">
              <div className="table-header">
                <h2>Recent Orders</h2>
              </div>

              <div className="custom-table-wrapper">
                <table className="custom-table">
                  <thead>
                    <tr>
                      <th>Order ID</th>
                      <th>Customer</th>
                      <th>Product</th>
                      <th>Amount</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {dashboardData.recentOrders.length > 0 ? dashboardData.recentOrders.map((order) => (
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
                        <td style={{ fontWeight: '600' }}>${parseFloat(order.amount || order.totalAmount || 0).toFixed(2)}</td>
                        <td>
                          <span className={`badge ${(order.status || 'pending').toLowerCase()}`}>
                            {order.status || 'Pending'}
                          </span>
                        </td>
                      </tr>
                    )) : (
                      <tr>
                        <td colSpan="5" style={{ textAlign: 'center', padding: '20px', color: '#64748b' }}>No recent orders found.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          </>
        )}
      </main>
    </div>
  );
};

export default Homepage;
