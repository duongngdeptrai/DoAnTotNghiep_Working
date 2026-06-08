import { NavLink } from "react-router-dom";

export default function TopNav({ isLoggedIn, currentUser, onLogout }) {
  return (
    <header className="top-nav">
      <div className="brand">
        <div className="brand-title">Child Tracking</div>
        <div className="brand-sub">Real-time safety dashboard</div>
      </div>
      <nav className="nav-links">
        <NavLink to="/" end className="nav-link">
          Theo dõi
        </NavLink>
        <NavLink to="/stats" className="nav-link">
          Thống kê
        </NavLink>
        <NavLink to="/profile" className="nav-link">
          Hồ sơ
        </NavLink>
        {!isLoggedIn && (
          <NavLink to="/auth" className="nav-link">
            Đăng nhập
          </NavLink>
        )}
      </nav>
      <div className="nav-meta">
        {isLoggedIn ? (
          <>
            <span className="nav-user">{currentUser?.email || "Đã đăng nhập"}</span>
            <button className="secondary-button" onClick={onLogout} type="button">
              Đăng xuất
            </button>
          </>
        ) : (
          <span className="nav-user muted">Chưa đăng nhập</span>
        )}
      </div>
    </header>
  );
}
