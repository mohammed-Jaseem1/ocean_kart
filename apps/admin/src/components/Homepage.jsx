import React, { useState, useEffect } from 'react';
import ShopOwners from './ShopOwners';
import Users from './Users';
import Revenue from './Revenue';
import DeliveryBoys from './DeliveryBoys';
import Categories from './Categories';
import Locations from './Locations';
import { collection, getDocs } from 'firebase/firestore';
import { db } from '../firebase';
import logoImg from '../assets/images/HomeScreen.png';
import './Homepage.css';

const Homepage = ({ user, onSignOut }) => {
  const [activeMenu, setActiveMenu] = useState('Dashboard');

  const [dashboardData, setDashboardData] = useState({
    totalRevenue: 0,
    totalOrders: 0,
    activeUsers: 0,
    conversionRate: 0,
    recentSignUps: [],
    categoryBreakdown: [],
    weeklySales: []
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
    let fetchedUsers = [];
    let fetchedOrders = [];

    // 1. Fetch Users, Shop Owners, Delivery Partners & Recent Sign-ups
    try {
      const usersSnapshot = await getDocs(collection(db, 'users'));
      usersSnapshot.forEach(docSnap => {
        const data = docSnap.data();
        if (data.status === 'active' || !data.status) {
          activeUsersCount++;
        }
        fetchedUsers.push({ id: docSnap.id, ...data });
      });

      try {
        const shopsSnapshot = await getDocs(collection(db, 'shop_owners'));
        shopsSnapshot.forEach(docSnap => {
          const data = docSnap.data();
          if (data.status === 'active' || !data.status) {
            activeUsersCount++;
          }
          fetchedUsers.push({ id: docSnap.id, ...data });
        });
      } catch (e) {}

      try {
        const deliverySnapshot = await getDocs(collection(db, 'delivery_partners'));
        deliverySnapshot.forEach(docSnap => {
          const data = docSnap.data();
          if (data.status === 'active' || !data.status) {
            activeUsersCount++;
          }
          fetchedUsers.push({ id: docSnap.id, ...data });
        });
      } catch (e) {}

      fetchedUsers = fetchedUsers.sort((a, b) => {
        const dateA = a.createdAt?.toDate ? a.createdAt.toDate() : (a.createdAt ? new Date(a.createdAt) : new Date(0));
        const dateB = b.createdAt?.toDate ? b.createdAt.toDate() : (b.createdAt ? new Date(b.createdAt) : new Date(0));
        return dateB - dateA;
      }).slice(0, 5);
    } catch (err) {
      console.warn("Users fetch warning:", err.message);
    }

    // 2. Fetch Orders for KPIs & Weekly Sales
    try {
      const ordersSnapshot = await getDocs(collection(db, 'orders'));
      ordersSnapshot.forEach(docSnap => {
        const data = docSnap.data();
        const amt = parseFloat(data.amount || data.totalAmount || 0);
        revenue += amt;
        ordersCount++;
        fetchedOrders.push({ id: docSnap.id, amount: amt, ...data });
      });
    } catch (err) {
      console.warn("Orders fetch warning:", err.message);
    }

    // 3. Compute Dynamic Weekly Sales (Last 7 Days)
    const last7Days = [];
    const now = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const dayLabel = d.toLocaleDateString('en-US', { weekday: 'short' });
      const dateStr = d.toISOString().split('T')[0];
      last7Days.push({
        dateStr,
        dayLabel,
        amount: 0
      });
    }

    fetchedOrders.forEach(order => {
      const orderDate = order.createdAt?.toDate ? order.createdAt.toDate() : (order.createdAt ? new Date(order.createdAt) : null);
      if (orderDate) {
        const dateStr = orderDate.toISOString().split('T')[0];
        const dayObj = last7Days.find(d => d.dateStr === dateStr);
        if (dayObj) {
          dayObj.amount += order.amount;
        }
      }
    });

    // Calculate SVG coordinates for Weekly Sales Path
    const maxSales = Math.max(...last7Days.map(d => d.amount), 100);
    const chartWidth = 560;
    const chartHeight = 130;
    const paddingX = 30;
    const stepX = chartWidth / (last7Days.length - 1 || 1);

    const weeklyPoints = last7Days.map((d, index) => {
      const x = paddingX + index * stepX;
      // y=150 is bottom, y=20 is top
      const y = 150 - (d.amount / maxSales) * chartHeight;
      return { ...d, x, y };
    });

    let pathD = '';
    let areaD = '';
    if (weeklyPoints.length > 0) {
      pathD = `M ${weeklyPoints[0].x} ${weeklyPoints[0].y}`;
      for (let i = 1; i < weeklyPoints.length; i++) {
        const prev = weeklyPoints[i - 1];
        const curr = weeklyPoints[i];
        const cpX = (prev.x + curr.x) / 2;
        pathD += ` C ${cpX} ${prev.y}, ${cpX} ${curr.y}, ${curr.x} ${curr.y}`;
      }
      areaD = `${pathD} L ${weeklyPoints[weeklyPoints.length - 1].x} 170 L ${weeklyPoints[0].x} 170 Z`;
    }

    // 4. Compute Dynamic Category Breakdown from Firestore 'categories' and 'orders'
    let categoryData = [];
    try {
      const catSnapshot = await getDocs(collection(db, 'categories'));
      const catCounts = {};

      catSnapshot.forEach(docSnap => {
        const cat = docSnap.data();
        if (cat.name) {
          catCounts[cat.name] = 0;
        }
      });

      let totalItems = 0;
      fetchedOrders.forEach(order => {
        if (Array.isArray(order.items)) {
          order.items.forEach(item => {
            const catName = item.category || item.categoryName;
            if (catName && catCounts[catName] !== undefined) {
              catCounts[catName] += (item.quantity || 1);
              totalItems += (item.quantity || 1);
            } else if (catName) {
              catCounts[catName] = (catCounts[catName] || 0) + (item.quantity || 1);
              totalItems += (item.quantity || 1);
            }
          });
        }
      });

      const colors = ['var(--primary)', '#10b981', '#f59e0b', '#8b5cf6', '#ec4899', '#3b82f6'];
      const entries = Object.entries(catCounts);

      if (entries.length > 0) {
        categoryData = entries.map(([name, count], index) => {
          const percentage = totalItems > 0 ? Math.round((count / totalItems) * 100) : Math.round(100 / entries.length);
          return {
            name,
            count,
            percentage,
            color: colors[index % colors.length]
          };
        }).slice(0, 5);
      }
    } catch (err) {
      console.warn("Categories breakdown warning:", err.message);
    }

    setDashboardData({
      totalRevenue: revenue,
      totalOrders: ordersCount,
      activeUsers: activeUsersCount,
      conversionRate: ordersCount > 0 && activeUsersCount > 0 ? (ordersCount / activeUsersCount * 100).toFixed(1) : 0,
      recentSignUps: fetchedUsers,
      categoryBreakdown: categoryData,
      weeklySales: weeklyPoints,
      pathD,
      areaD
    });
  };

  const navSections = [
    {
      label: 'OVERVIEW',
      items: [
        {
          name: 'Dashboard',
          icon: (
            <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2v-4zM14 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2v-4z" />
            </svg>
          )
        }
      ]
    },
    {
      label: 'OPERATIONS',
      items: [
        {
          name: 'Shop Owners',
          icon: (
            <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
          )
        },
        {
          name: 'Locations',
          icon: (
            <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z" />
              <circle cx="12" cy="9" r="2.5" />
            </svg>
          )
        },
        {
          name: 'Users',
          icon: (
            <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
          )
        },
        {
          name: 'Delivery Boys',
          icon: (
            <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <rect x="1" y="3" width="15" height="13" rx="2" /><polygon points="16 8 20 8 23 11 23 16 16 16 16 8" /><circle cx="5.5" cy="18.5" r="2.5" /><circle cx="18.5" cy="18.5" r="2.5" />
            </svg>
          )
        }
      ]
    },
    {
      label: 'CATALOGUE',
      items: [
        {
          name: 'Categories',
          icon: (
            <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
            </svg>
          )
        }
      ]
    },
    {
      label: 'FINANCIAL',
      items: [
        {
          name: 'Revenue',
          icon: (
            <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <line x1="12" y1="1" x2="12" y2="23" /><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6" />
            </svg>
          )
        }
      ]
    }
  ];

  // Calculate dynamic cumulative offset for SVG Donut Ring
  let cumulativeOffset = 25;

  return (
    <div className="layout">
      {/* Poyoka-style Sidebar */}
      <aside className="sidebar">
        <div className="sidebar-header">
          <img src={logoImg} alt="OceanKart Logo" />
          <h2>OceanKart</h2>
        </div>

        <nav className="sidebar-nav">
          {navSections.map((section, idx) => (
            <div key={idx}>
              <div className="nav-section-label">{section.label}</div>
              {section.items.map((item) => (
                <button
                  key={item.name}
                  className={`nav-item ${activeMenu === item.name ? 'active' : ''}`}
                  onClick={() => setActiveMenu(item.name)}
                >
                  {item.icon}
                  <span>{item.name}</span>
                </button>
              ))}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          {onSignOut && (
            <button
              onClick={onSignOut}
              className="btn btn-secondary btn-sm"
              style={{ width: '100%', justifyContent: 'center' }}
            >
              <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
                <polyline points="16 17 21 12 16 7" />
                <line x1="21" y1="12" x2="9" y2="12" />
              </svg>
              Sign Out
            </button>
          )}
        </div>
      </aside>

      {/* Poyoka-style Main Content Area */}
      <div className="main-content">
        <header className="top-header">
          <h1 className="header-title">
            {activeMenu === 'Shop Owners'
              ? 'Shop Owners & Store Partners'
              : activeMenu === 'Locations'
              ? 'Service & Store Locations'
              : activeMenu === 'Users'
              ? 'Registered App Users'
              : activeMenu === 'Revenue'
              ? 'Financial & Revenue Analytics'
              : activeMenu === 'Delivery Boys'
              ? 'Delivery Personnel'
              : activeMenu === 'Categories'
              ? 'Product Categories'
              : 'Dashboard Overview'}
          </h1>

          <div className="header-profile">
            <span style={{ fontSize: '0.875rem', fontWeight: '500', color: 'var(--text-secondary)' }}>
              {user?.email || 'Admin'}
            </span>
            {onSignOut && (
              <button onClick={onSignOut} className="btn btn-secondary btn-sm">
                Sign Out
              </button>
            )}
          </div>
        </header>

        <main className="page-content">
          {activeMenu === 'Shop Owners' ? (
            <ShopOwners />
          ) : activeMenu === 'Locations' ? (
            <Locations />
          ) : activeMenu === 'Users' ? (
            <Users />
          ) : activeMenu === 'Revenue' ? (
            <Revenue />
          ) : activeMenu === 'Delivery Boys' ? (
            <DeliveryBoys />
          ) : activeMenu === 'Categories' ? (
            <Categories />
          ) : (
            <>
              {/* Stat Cards Grid */}
              <div className="stat-grid">
                <div className="stat-card">
                  <div className="stat-icon-wrapper">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <line x1="12" y1="1" x2="12" y2="23" /><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6" />
                    </svg>
                  </div>
                  <div className="stat-info">
                    <span className="stat-title">Total Revenue</span>
                    <span className="stat-value">₹{dashboardData.totalRevenue.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
                  </div>
                </div>

                <div className="stat-card">
                  <div className="stat-icon-wrapper" style={{ background: '#dcfce7', color: '#16a34a' }}>
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" /><line x1="3" y1="6" x2="21" y2="6" /><path d="M16 10a4 4 0 01-8 0" />
                    </svg>
                  </div>
                  <div className="stat-info">
                    <span className="stat-title">Total Orders</span>
                    <span className="stat-value">{dashboardData.totalOrders}</span>
                  </div>
                </div>

                <div className="stat-card">
                  <div className="stat-icon-wrapper" style={{ background: '#e0f2fe', color: '#0284c7' }}>
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" /><circle cx="9" cy="7" r="4" />
                    </svg>
                  </div>
                  <div className="stat-info">
                    <span className="stat-title">Active Users</span>
                    <span className="stat-value">{dashboardData.activeUsers}</span>
                  </div>
                </div>

                <div className="stat-card">
                  <div className="stat-icon-wrapper" style={{ background: '#fef3c7', color: '#d97706' }}>
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
                    </svg>
                  </div>
                  <div className="stat-info">
                    <span className="stat-title">Conversion Rate</span>
                    <span className="stat-value">{dashboardData.conversionRate}%</span>
                  </div>
                </div>
              </div>

              {/* Dynamic Charts Grid */}
              <div className="charts-grid">
                {/* 100% Dynamic Weekly Sales Performance Chart */}
                <div className="card">
                  <div className="chart-card-header">
                    <h2 style={{ fontSize: '1rem', fontWeight: '700' }}>Weekly Sales Performance</h2>
                    <div className="chart-legend">
                      <div className="legend-item">
                        <span className="legend-color" style={{ background: 'var(--primary)' }}></span>
                        <span>Direct Sales (₹)</span>
                      </div>
                    </div>
                  </div>

                  <div className="chart-container">
                    <svg className="svg-chart" viewBox="0 0 620 200">
                      <line x1="20" y1="30" x2="600" y2="30" stroke="#f1f5f9" strokeWidth="1" />
                      <line x1="20" y1="75" x2="600" y2="75" stroke="#f1f5f9" strokeWidth="1" />
                      <line x1="20" y1="120" x2="600" y2="120" stroke="#f1f5f9" strokeWidth="1" />
                      <line x1="20" y1="170" x2="600" y2="170" stroke="#e2e8f0" strokeWidth="1" />

                      {/* Area Fill */}
                      {dashboardData.areaD && (
                        <path
                          d={dashboardData.areaD}
                          fill="url(#chartGradient)"
                          opacity="0.15"
                        />
                      )}

                      {/* Dynamic Curved Line */}
                      {dashboardData.pathD && (
                        <path
                          d={dashboardData.pathD}
                          fill="none"
                          stroke="var(--primary)"
                          strokeWidth="3"
                          strokeLinecap="round"
                        />
                      )}

                      {/* Dynamic Data Points & X-Axis Day Labels */}
                      {dashboardData.weeklySales?.map((pt, idx) => (
                        <g key={idx}>
                          <circle cx={pt.x} cy={pt.y} r="5" fill="var(--primary)" stroke="#ffffff" strokeWidth="2" />
                          <text x={pt.x} y="190" textAnchor="middle" fill="var(--text-secondary)" fontSize="11" fontWeight="500">
                            {pt.dayLabel}
                          </text>
                        </g>
                      ))}

                      <defs>
                        <linearGradient id="chartGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="var(--primary)" />
                          <stop offset="100%" stopColor="var(--primary)" stopOpacity="0" />
                        </linearGradient>
                      </defs>
                    </svg>
                  </div>
                </div>

                {/* 100% Dynamic Category Breakdown Donut Chart */}
                <div className="card">
                  <div className="chart-card-header">
                    <h2 style={{ fontSize: '1rem', fontWeight: '700' }}>Category Breakdown</h2>
                  </div>
                  <div className="donut-wrapper">
                    {dashboardData.categoryBreakdown?.length > 0 ? (
                      <>
                        <svg width="140" height="140" viewBox="0 0 36 36">
                          <circle cx="18" cy="18" r="15.915" fill="none" stroke="#f1f5f9" strokeWidth="3.5" />
                          {dashboardData.categoryBreakdown.map((cat, idx) => {
                            const strokeDasharray = `${cat.percentage} ${100 - cat.percentage}`;
                            const offset = cumulativeOffset;
                            cumulativeOffset -= cat.percentage;
                            return (
                              <circle
                                key={idx}
                                cx="18"
                                cy="18"
                                r="15.915"
                                fill="none"
                                stroke={cat.color}
                                strokeWidth="3.5"
                                strokeDasharray={strokeDasharray}
                                strokeDashoffset={offset}
                              />
                            );
                          })}
                        </svg>

                        <div style={{ marginTop: '16px', display: 'flex', flexDirection: 'column', gap: '8px', width: '100%' }}>
                          {dashboardData.categoryBreakdown.map((cat, idx) => (
                            <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                              <span style={{ color: cat.color, fontWeight: '600' }}>● {cat.name}</span>
                              <span style={{ fontWeight: '700', color: 'var(--text-primary)' }}>{cat.percentage}%</span>
                            </div>
                          ))}
                        </div>
                      </>
                    ) : (
                      <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                        No categories found in Firestore. Add categories to view distribution.
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Recent Sign-ups Card */}
              <div className="card" style={{ marginTop: '2rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
                  <h2 style={{ fontSize: '1.1rem', fontWeight: '700' }}>Recent Sign-ups</h2>
                  <button onClick={() => setActiveMenu('Users')} className="btn btn-secondary btn-sm">
                    View All Users
                  </button>
                </div>

                <div className="table-container">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>User</th>
                        <th>Role / Plan</th>
                        <th>Joined Date</th>
                        <th>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {dashboardData.recentSignUps.length > 0 ? dashboardData.recentSignUps.map((u) => {
                        const joinedDate = u.createdAt?.toDate
                          ? u.createdAt.toDate().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                          : u.createdAt
                          ? new Date(u.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                          : 'Recent';

                        const userRole = u.plan || u.role || 'Customer';
                        const userStatus = (u.status || 'active').toLowerCase();

                        return (
                          <tr key={u.id}>
                            <td>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                                <div style={{
                                  width: '36px',
                                  height: '36px',
                                  borderRadius: '50%',
                                  backgroundColor: 'var(--primary-light)',
                                  color: 'var(--primary)',
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  fontWeight: '700',
                                  fontSize: '0.875rem'
                                }}>
                                  {(u.name || u.shopName || u.email || 'U').charAt(0).toUpperCase()}
                                </div>
                                <div>
                                  <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>
                                    {u.name || u.shopName || 'New User'}
                                  </div>
                                  <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                                    {u.email || (u.mobileNumber ? `+91 ${u.mobileNumber}` : '')}
                                  </div>
                                </div>
                              </div>
                            </td>
                            <td>
                              <span style={{
                                padding: '0.2rem 0.6rem',
                                borderRadius: 'var(--radius-sm)',
                                background: '#f1f5f9',
                                color: 'var(--text-secondary)',
                                fontSize: '0.75rem',
                                fontWeight: '600',
                                textTransform: 'uppercase'
                              }}>
                                {userRole.replace('_', ' ')}
                              </span>
                            </td>
                            <td style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                              {joinedDate}
                            </td>
                            <td>
                              <span className={`badge ${userStatus === 'active' ? 'badge-success' : userStatus === 'pending' ? 'badge-warning' : 'badge-danger'}`}>
                                {userStatus === 'active' ? 'Active' : userStatus === 'pending' ? 'Pending' : 'Suspended'}
                              </span>
                            </td>
                          </tr>
                        );
                      }) : (
                        <tr>
                          <td colSpan="4" style={{ textAlign: 'center', padding: '2rem', color: 'var(--text-secondary)' }}>No recent sign-ups found.</td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </>
          )}
        </main>
      </div>
    </div>
  );
};

export default Homepage;
