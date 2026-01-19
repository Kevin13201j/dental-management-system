import { useState } from 'react'
import './App.css'

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  return (
    <div className="app-container">
      {/* Barra de Navegación Superior */}
      <nav className="navbar">
        <div className="logo-section">
          <span className="logo-icon">🦷</span>
          <h1>Dental Management System</h1>
        </div>
        <div className="nav-links">
          <a href="#dashboard" className="active">Dashboard</a>
          <a href="#patients">Pacientes</a>
          <a href="#appointments">Citas</a>
          <button className="btn-login" onClick={() => setIsLoggedIn(!isLoggedIn)}>
            {isLoggedIn ? 'Cerrar Sesión' : 'Ingresar'}
          </button>
        </div>
      </nav>

      {/* Contenido Principal */}
      <main className="main-content">
        <header className="hero-section">
          <h2>Bienvenido al Portal Clínico</h2>
          <p>Gestiona pacientes, citas e historiales médicos de forma eficiente y segura.</p>
        </header>

        {/* Tarjetas de Módulos (Simulando los Microservicios) */}
        <div className="grid-container">
          <div className="card">
            <div className="icon">👥</div>
            <h3>Pacientes</h3>
            <p>Registro y gestión de historias clínicas.</p>
            <button className="btn-card">Ver Pacientes</button>
          </div>

          <div className="card">
            <div className="icon">📅</div>
            <h3>Citas</h3>
            <p>Agenda y control de turnos en tiempo real.</p>
            <button className="btn-card">Agendar Cita</button>
          </div>

          <div className="card">
            <div className="icon">💰</div>
            <h3>Facturación</h3>
            <p>Control de pagos y aseguradoras.</p>
            <button className="btn-card">Ver Finanzas</button>
          </div>

          <div className="card">
            <div className="icon">📊</div>
            <h3>Reportes</h3>
            <p>Analítica avanzada del consultorio.</p>
            <button className="btn-card">Ver Dashboard</button>
          </div>
        </div>
      </main>

      <footer className="footer">
        <p>© 2026 Dental Management System | Infraestructura AWS QA</p>
      </footer>
    </div>
  )
}

export default App