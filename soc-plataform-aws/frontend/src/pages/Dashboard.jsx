import { useEffect, useState } from 'react';
import { Shield, AlertTriangle, Activity, Server } from 'lucide-react';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import api from '../services/api';

const SEVERITY_COLORS = {
  critical: '#dc2626',
  high:     '#ea580c',
  medium:   '#facc15',
  low:      '#22c55e',
};

function StatCard({ icon: Icon, label, value, trend, accent }) {
  return (
    <div className="bg-slate-900 border border-slate-800 rounded-xl p-5">
      <div className="flex items-center justify-between mb-3">
        <span className="text-slate-400 text-sm">{label}</span>
        <Icon className={`w-5 h-5 ${accent || 'text-cyan-400'}`} />
      </div>
      <div className="text-3xl font-bold text-white">{value}</div>
      {trend && <div className={`text-xs mt-1 ${trend.startsWith('+') ? 'text-rose-400' : 'text-emerald-400'}`}>{trend}</div>}
    </div>
  );
}

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [timeline, setTimeline] = useState([]);

  useEffect(() => {
    Promise.all([
      api.get('/events/stats'),
      api.get('/events?limit=100'),
    ]).then(([s, e]) => {
      setStats(s.data);
      setTimeline(buildTimeline(e.data.items));
    });
  }, []);

  function buildTimeline(items) {
    const map = {};
    items.forEach((it) => {
      const hour = it.occurred_at.slice(11, 13) + ':00';
      map[hour] = (map[hour] || 0) + 1;
    });
    return Object.entries(map).map(([time, count]) => ({ time, count }));
  }

  const totals = stats?.stats?.reduce((acc, s) => {
    acc.total += parseInt(s.total);
    acc.last24h += parseInt(s.last_24h);
    if (s.severity === 'critical') acc.critical += parseInt(s.last_24h);
    return acc;
  }, { total: 0, last24h: 0, critical: 0 }) || { total: 0, last24h: 0, critical: 0 };

  return (
    <div className="p-6 space-y-6">
      <header className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white">Security Operations Center</h1>
        <span className="text-sm text-slate-400">Live · {new Date().toLocaleString('pt-BR')}</span>
      </header>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard icon={Shield} label="Eventos totais" value={totals.total.toLocaleString()} accent="text-cyan-400" />
        <StatCard icon={Activity} label="Últimas 24h" value={totals.last24h.toLocaleString()} accent="text-blue-400" />
        <StatCard icon={AlertTriangle} label="Críticos 24h" value={totals.critical} accent="text-rose-400" />
        <StatCard icon={Server} label="Tenants" value="2" accent="text-emerald-400" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5">
          <h2 className="text-white font-semibold mb-4">Eventos por hora</h2>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={timeline}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
              <XAxis dataKey="time" stroke="#94a3b8" />
              <YAxis stroke="#94a3b8" />
              <Tooltip contentStyle={{ background: '#0f172a', border: '1px solid #334155' }} />
              <Line type="monotone" dataKey="count" stroke="#06b6d4" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-5">
          <h2 className="text-white font-semibold mb-4">Distribuição por severidade</h2>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={stats?.stats || []}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
              <XAxis dataKey="severity" stroke="#94a3b8" />
              <YAxis stroke="#94a3b8" />
              <Tooltip contentStyle={{ background: '#0f172a', border: '1px solid #334155' }} />
              <Bar dataKey="total" fill="#06b6d4" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}
