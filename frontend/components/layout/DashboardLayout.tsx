'use client'

import { ReactNode, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Sidebar from './Sidebar'
import Header from './Header'
import { useAuth } from '@/hooks/useAuth'

export default function DashboardLayout({ children, hideNavigation = false }: { children: ReactNode; hideNavigation?: boolean }) {
  const { user, loading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!loading && !user) {
      const next = typeof window !== 'undefined' ? window.location.pathname : '/dashboard'
      router.replace(`/login?next=${encodeURIComponent(next)}`)
    }
  }, [loading, user, router])

  if (loading || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gray-50">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
      </div>
    )
  }

  if (hideNavigation) {
    return (
      <div className="min-h-screen bg-gray-50">
        <main className="p-8">{children}</main>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Sidebar />
      <div className="ml-64">
        <Header />
        <main className="p-8">{children}</main>
      </div>
    </div>
  )
}
