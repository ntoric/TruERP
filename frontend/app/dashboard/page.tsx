'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { apiFetch, useAuth } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { formatCurrency, formatDate } from '@/lib/utils'
import {
  TrendingUp,
  FileText,
  Users,
  Package,
  AlertTriangle,
  Clock,
  IndianRupee,
  ArrowUpRight,
} from 'lucide-react'
import StatWidget from '@/components/widgets/StatWidget'
import ListWidget from '@/components/widgets/ListWidget'
import AlertWidget from '@/components/widgets/AlertWidget'

interface DashboardStats {
  total_sales: number
  total_invoices: number
  total_customers: number
  total_products: number
  pending_amount: number
  today_sales: number
  today_invoices: number
  low_stock_products: number
  overdue_invoices: number
}

interface Invoice {
  id: string
  invoice_number: string
  customer: { name: string }
  total_amount: number
  status: string
  date: string
}

export default function DashboardPage() {
  const { user, loading: authLoading } = useAuth()
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [recentInvoices, setRecentInvoices] = useState<Invoice[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!authLoading && user) {
      fetchDashboardData()
    }
  }, [authLoading, user])

  const fetchDashboardData = async () => {
    try {
      const [statsRes, invoicesRes] = await Promise.all([
        apiFetch('/dashboard/stats'),
        apiFetch('/dashboard/recent-invoices'),
      ])
      if (statsRes.ok) {
        setStats(await statsRes.json())
      } else {
        console.error('Failed to fetch stats:', statsRes.status)
      }
      if (invoicesRes.ok) {
        setRecentInvoices(await invoicesRes.json())
      } else {
        console.error('Failed to fetch invoices:', invoicesRes.status)
      }
    } catch (err) {
      console.error('Failed to fetch dashboard data:', err)
    } finally {
      setLoading(false)
    }
  }

  if (authLoading || loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
      </div>
    )
  }

  const statCards = [
    { title: 'Total Sales', value: formatCurrency(stats?.total_sales || 0), icon: TrendingUp, color: 'success' as const },
    { title: 'Today Sales', value: formatCurrency(stats?.today_sales || 0), icon: IndianRupee, color: 'primary' as const },
    { title: 'Total Invoices', value: stats?.total_invoices || 0, icon: FileText, color: 'info' as const },
    { title: 'Customers', value: stats?.total_customers || 0, icon: Users, color: 'warning' as const },
    { title: 'Products', value: stats?.total_products || 0, icon: Package, color: 'info' as const },
    { title: 'Pending Amount', value: formatCurrency(stats?.pending_amount || 0), icon: Clock, color: 'danger' as const },
  ]

  const getStatusVariant = (status: string): 'success' | 'warning' | 'danger' | 'info' | 'default' => {
    const variants: Record<string, 'success' | 'warning' | 'danger' | 'info' | 'default'> = {
      paid: 'success',
      sent: 'info',
      draft: 'default',
      overdue: 'danger',
      cancelled: 'warning',
    }
    return variants[status] || 'default'
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-sm text-gray-500">Welcome back, {user?.name}</p>
        </div>
          {/* Stats Grid */}
          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {statCards.map((card) => (
              <StatWidget
                key={card.title}
                title={card.title}
                value={card.value}
                icon={card.icon}
                color={card.color}
              />
            ))}
          </div>

          {/* Alerts */}
          {(stats?.low_stock_products || 0) > 0 && (
            <AlertWidget
              icon={AlertTriangle}
              message={`${stats?.low_stock_products} products are running low on stock`}
              variant="warning"
              action={{ label: 'View Products', href: '/products?low_stock=true' }}
            />
          )}

          {/* Recent Invoices */}
          <ListWidget
            title="Recent Invoices"
            icon={FileText}
            viewAllLink="/invoices"
            items={recentInvoices.map((inv) => ({
              id: inv.id,
              title: inv.invoice_number,
              subtitle: inv.customer?.name || 'N/A',
              value: formatCurrency(inv.total_amount),
              status: {
                text: inv.status,
                variant: getStatusVariant(inv.status),
              },
            }))}
            emptyMessage="No invoices yet"
            emptyAction={{ label: 'Create one', href: '/invoices' }}
          />
        </div>
    </DashboardLayout>
  )
}
