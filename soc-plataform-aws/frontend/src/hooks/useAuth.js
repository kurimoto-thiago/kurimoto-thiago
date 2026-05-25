import { create } from 'zustand';

export const useAuth = create((set) => ({
  token: localStorage.getItem('soc_token'),
  user: JSON.parse(localStorage.getItem('soc_user') || 'null'),
  login: (token, user) => {
    localStorage.setItem('soc_token', token);
    localStorage.setItem('soc_user', JSON.stringify(user));
    set({ token, user });
  },
  logout: () => {
    localStorage.removeItem('soc_token');
    localStorage.removeItem('soc_user');
    set({ token: null, user: null });
  },
}));
