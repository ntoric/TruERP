'use client'

import { useAuth } from '@/hooks/useAuth'
import { User, Bell } from 'lucide-react'

export default function Header() {
  const { user } = useAuth()

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center justify-between border-b bg-white px-8">
      <h1 className="text-lg font-semibold text-gray-900">MyBillBook</h1>
      <div className="flex items-center gap-4">
        <button className="relative rounded-full p-2 text-gray-500 hover:bg-gray-100">
          <Bell className="h-5 w-5" />
          <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-red-500" />
        </button>
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 text-blue-700">
            <User className="h-5 w-5" />
          </div>
          <div className="hidden md:block">
            <p className="text-sm font-medium text-gray-900">{user?.name || 'User'}</p>
            <p className="text-xs text-gray-500">{user?.role || 'Owner'}</p>
          </div>
        </div>
      </div>
    </header>
  )
}
