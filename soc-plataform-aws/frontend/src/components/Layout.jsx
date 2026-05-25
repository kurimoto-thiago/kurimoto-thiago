import { Outlet, NavLink } from 'react-router-dom';
import { Shield, AlertTriangle, ListChecks, Settings, LogOut, BarChart3 } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

const NAV = [
  { to: '/',            label: 'Dashboard',  icon: BarChart3 },
  { to: '/events',      label: 'Eventos',    icon: Shield },
  { to: '/alerts',      label: 'Alertas',    icon: AlertTriangle },
  { to: '/compliance',  label: 'Compliance', icon: ListChecks },
  { to: '/settings',    label: 'Settings',   icon: Settings },
];

export default function Layout() {
  const logout = useAuth((s) => s.logout);

  return (
    <div className="flex min-h-screen bg-slate-950">
      <aside className="w-60 bg-slate-900 border-r border-slate-800 flex flex-col">
        <div className="px-5 py-6 border-b border-slate-800">
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <Shield className="text-cyan-400" /> SOC Platform
          </h1>
          <p className="text-xs text-slate-500 mt-1">AWS Cloud Security</p>
        </div>
        <nav className="flex-1 px-3 py-4 space-y-1">
          {NAV.map(({ to, label, icon: Icon }) => (
            <NavLink key={to} to={to} end={to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors ${
                  isActive ? 'bg-cyan-500/10 text-cyan-400' : 'text-slate-400 hover:bg-slate-800 hover:text-white'
                }`
              }>
              <Icon className="w-4 h-4" />
              {label}
            </NavLink>
          ))}
        </nav>
        <button onClick={logout}
          className="m-3 flex items-center gap-2 px-3 py-2 text-sm text-slate-400 hover:text-rose-400">
          <LogOut className="w-4 h-4" /> Sair
        </button>
      </aside>
      <main className="flex-1"><Outlet /></main>
    </div>
  );
}
