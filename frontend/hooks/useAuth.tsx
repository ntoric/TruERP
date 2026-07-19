'use client'

import { useState, useEffect, createContext, useContext, ReactNode } from 'react'
import Cookies from 'js-cookie'
import { API_BASE } from '@/lib/utils'

interface User {
  id: string
  name: string
  email: string
  phone: string
  role: string
}

interface AuthContextType {
  user: User | null
  token: string | null
  login: (email: string, password: string, totpCode?: string) => Promise<void>
  register: (name: string, email: string, password: string, phone?: string) => Promise<void>
  logout: () => void
  loading: boolean
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

function clearAuthAndRedirect() {
  Cookies.remove('token')
  if (typeof window === 'undefined') return
  const path = window.location.pathname
  if (path === '/login' || path === '/register') return
  if (path.startsWith('/portal')) return
  window.location.href = `/login?next=${encodeURIComponent(path)}`
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [token, setToken] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const storedToken = Cookies.get('token')
    if (storedToken) {
      setToken(storedToken)
      fetchProfile(storedToken)
    } else {
      setLoading(false)
    }
  }, [])

  const fetchProfile = async (authToken: string) => {
    try {
      const res = await fetch(`${API_BASE}/auth/profile`, {
        headers: { Authorization: `Bearer ${authToken}` },
      })
      if (res.ok) {
        const data = await res.json()
        setUser({
          id: data.id,
          name: data.name,
          email: data.email,
          phone: data.phone,
          role: data.role,
        })
      } else {
        Cookies.remove('token')
        setToken(null)
        if (res.status === 401) clearAuthAndRedirect()
      }
    } catch (err) {
      console.error('Fetch profile error:', err)
    } finally {
      setLoading(false)
    }
  }

  const login = async (email: string, password: string, totpCode?: string) => {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, totp_code: totpCode || '' }),
    })
    const data = await res.json()
    if (!res.ok) {
      const err = new Error(data.error || 'Login failed') as Error & { requires2fa?: boolean }
      if (data.requires_2fa) err.requires2fa = true
      throw err
    }

    Cookies.set('token', data.token, { expires: 1 })
    setToken(data.token)
    setUser(data.user)
  }

  const register = async (name: string, email: string, password: string, phone?: string) => {
    const res = await fetch(`${API_BASE}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, email, password, phone }),
    })
    const data = await res.json()
    if (!res.ok) throw new Error(data.error || 'Registration failed')

    Cookies.set('token', data.token, { expires: 1 })
    setToken(data.token)
    setUser(data.user)
  }

  const logout = () => {
    Cookies.remove('token')
    setToken(null)
    setUser(null)
    window.location.href = '/login'
  }

  return (
    <AuthContext.Provider value={{ user, token, login, register, logout, loading }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}

export async function apiFetch(path: string, options: RequestInit = {}) {
  const token = Cookies.get('token')
  const isFormData = options.body instanceof FormData
  const hasContentType = options.headers && 'Content-Type' in (options.headers as Record<string, string>)
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      ...(options.headers || {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(!isFormData && !hasContentType ? { 'Content-Type': 'application/json' } : {}),
    },
  })
  if (res.status === 401) {
    clearAuthAndRedirect()
  }
  return res
}
