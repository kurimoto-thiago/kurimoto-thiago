import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Shield } from 'lucide-react';
import api from '../services/api';
import { useAuth } from '../hooks/useAuth';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState('');
  const nav = useNavigate();
  const login = useAuth((s) => s.login);

  async function submit(e) {
    e.preventDefault();
    setErr('');
    try {
      const { data } = await api.post('/auth/login', { email, password });
      login(data.token, data.user);
      nav('/');
    } catch (e) {
      setErr('Credenciais inválidas');
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950">
      <form onSubmit={submit} className="w-96 bg-slate-900 border border-slate-800 rounded-xl p-8">
        <div className="flex items-center gap-3 mb-6">
          <Shield className="w-8 h-8 text-cyan-400" />
          <h1 className="text-2xl font-bold text-white">SOC Platform</h1>
        </div>
        <label className="block text-sm text-slate-400 mb-1">Email</label>
        <input value={email} onChange={(e) => setEmail(e.target.value)}
          className="w-full bg-slate-800 text-white rounded px-3 py-2 mb-4 outline-none focus:ring-2 ring-cyan-500" />
        <label className="block text-sm text-slate-400 mb-1">Senha</label>
        <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
          className="w-full bg-slate-800 text-white rounded px-3 py-2 mb-4 outline-none focus:ring-2 ring-cyan-500" />
        {err && <div className="text-rose-400 text-sm mb-3">{err}</div>}
        <button type="submit" className="w-full bg-cyan-500 hover:bg-cyan-600 text-white py-2 rounded font-medium">
          Entrar
        </button>
      </form>
    </div>
  );
}
