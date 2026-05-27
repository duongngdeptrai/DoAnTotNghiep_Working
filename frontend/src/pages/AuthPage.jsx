import { useState } from "react";

export default function AuthPage({ onAuth, loading, error }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  return (
    <section className="card auth-panel">
      <div className="auth-grid">
        <div>
          <h3>Đăng nhập / Đăng ký</h3>
          <p className="muted">Nhập email và mật khẩu để tiếp tục.</p>
        </div>
        <div className="auth-form">
          <label className="field">
            Email
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="you@example.com"
            />
          </label>
          <label className="field">
            Mật khẩu
            <input
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="******"
            />
          </label>
          <div className="button-row">
            <button
              className="primary-button"
              onClick={() => onAuth("login", { email, password })}
              disabled={loading}
              type="button"
            >
              Đăng nhập
            </button>
            <button
              className="secondary-button"
              onClick={() => onAuth("register", { email, password })}
              disabled={loading}
              type="button"
            >
              Đăng ký
            </button>
          </div>
          {error && <p className="error-text">{error}</p>}
        </div>
      </div>
    </section>
  );
}
