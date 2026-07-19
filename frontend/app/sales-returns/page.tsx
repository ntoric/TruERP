'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { apiFetch } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { formatCurrency, formatDate } from '@/lib/utils'
import { Plus, Search, MoreVertical, Edit, Trash2, CheckCircle } from 'lucide-react'

interface SalesReturn {
  id: string
  return_number: string
  party: { name: string }
  invoice?: { invoice_number: string }
  date: string
  amount: number
  status: string
}

export default function SalesReturnsPage() {
  const [returns, setReturns] = useState<SalesReturn[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [actionMenu, setActionMenu] = useState<string | null>(null)

  useEffect(() => {
    fetchReturns()
  }, [filter, dateFrom, dateTo])

  const fetchReturns = async () => {
    try {
      let url = '/sales-returns'
      const params = new URLSearchParams()
      if (filter) params.append('status', filter)
      if (dateFrom) params.append('from_date', dateFrom)
      if (dateTo) params.append('to_date', dateTo)
      if (params.toString()) url += `?${params.toString()}`
      const res = await apiFetch(url)
      if (res.ok) {
        const data = await res.json()
        setReturns(data.data || [])
      }
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const filteredReturns = returns.filter(ret =>
    ret.return_number.toLowerCase().includes(search.toLowerCase()) ||
    ret.party?.name?.toLowerCase().includes(search.toLowerCase()) ||
    ret.invoice?.invoice_number?.toLowerCase().includes(search.toLowerCase())
  )

  const getStatusBadge = (status: string) => {
    const variants: Record<string, string> = {
      draft: 'bg-gray-100 text-gray-700',
      processed: 'bg-green-100 text-green-700',
      cancelled: 'bg-red-100 text-red-700',
    }
    return <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${variants[status] || variants.draft}`}>{status}</span>
  }

  const handleProcessReturn = async (id: string) => {
    try {
      const res = await apiFetch(`/sales-returns/${id}/process`, { method: 'POST' })
      if (res.ok) {
        fetchReturns()
      }
    } catch (err) {
      console.error(err)
    }
    setActionMenu(null)
  }

  const handleDeleteReturn = async (id: string) => {
    if (!confirm('Are you sure you want to delete this sales return?')) return
    try {
      const res = await apiFetch(`/sales-returns/${id}`, { method: 'DELETE' })
      if (res.ok) {
        fetchReturns()
      }
    } catch (err) {
      console.error(err)
    }
    setActionMenu(null)
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-gray-900">Sales Returns</h1>
          <Link href="/sales-returns/create">
            <Button><Plus className="mr-2 h-4 w-4" /> New Sales Return</Button>
          </Link>
        </div>

        <Card>
          <CardHeader className="pb-4">
            <div className="flex flex-wrap items-center gap-4">
              <div className="relative flex-1 min-w-[200px] max-w-md">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                <Input
                  placeholder="Search sales returns..."
                  className="pl-10"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </div>
              <select
                value={filter}
                onChange={(e) => setFilter(e.target.value)}
                className="h-10 rounded-md border border-input bg-background px-3 text-sm"
              >
                <option value="">All Status</option>
                <option value="draft">Draft</option>
                <option value="processed">Processed</option>
                <option value="cancelled">Cancelled</option>
              </select>
              <Input
                type="date"
                className="h-10 w-auto"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
              />
              <Input
                type="date"
                className="h-10 w-auto"
                value={dateTo}
                onChange={(e) => setDateTo(e.target.value)}
              />
            </div>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="flex h-32 items-center justify-center">
                <div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" />
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b text-left text-gray-500">
                      <th className="pb-3 font-medium">Date</th>
                      <th className="pb-3 font-medium">Sales Return #</th>
                      <th className="pb-3 font-medium">Party Name</th>
                      <th className="pb-3 font-medium">Invoice #</th>
                      <th className="pb-3 font-medium">Amount</th>
                      <th className="pb-3 font-medium">Status</th>
                      <th className="pb-3 font-medium">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredReturns.map((ret) => (
                      <tr key={ret.id} className="border-b last:border-0 hover:bg-gray-50">
                        <td className="py-3 text-gray-500">{formatDate(ret.date)}</td>
                        <td className="py-3">
                          <Link href={`/sales-returns/view?id=${ret.id}`} className="font-medium text-blue-600 hover:underline">
                            {ret.return_number}
                          </Link>
                        </td>
                        <td className="py-3 text-gray-600">{ret.party?.name || 'N/A'}</td>
                        <td className="py-3 text-gray-500">{ret.invoice?.invoice_number || '-'}</td>
                        <td className="py-3 font-medium text-gray-900">{formatCurrency(ret.amount)}</td>
                        <td className="py-3">{getStatusBadge(ret.status)}</td>
                        <td className="py-3">
                          <div className="relative">
                            <button
                              onClick={() => setActionMenu(actionMenu === ret.id ? null : ret.id)}
                              className="p-1 hover:bg-gray-100 rounded"
                            >
                              <MoreVertical className="h-4 w-4 text-gray-500" />
                            </button>
                            {actionMenu === ret.id && (
                              <div className="absolute right-0 top-full z-10 mt-1 w-40 rounded-md border bg-white shadow-lg">
                                <div className="py-1">
                                  <Link
                                    href={`/sales-returns/create?id=${ret.id}`}
                                    className="flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100"
                                    onClick={() => setActionMenu(null)}
                                  >
                                    <Edit className="h-4 w-4" /> Edit
                                  </Link>
                                  {ret.status === 'draft' && (
                                    <button
                                      onClick={() => handleProcessReturn(ret.id)}
                                      className="flex w-full items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100"
                                    >
                                      <CheckCircle className="h-4 w-4" /> Process
                                    </button>
                                  )}
                                  <button
                                    onClick={() => handleDeleteReturn(ret.id)}
                                    className="flex w-full items-center gap-2 px-3 py-2 text-sm text-red-600 hover:bg-gray-100"
                                  >
                                    <Trash2 className="h-4 w-4" /> Delete
                                  </button>
                                </div>
                              </div>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                    {filteredReturns.length === 0 && (
                      <tr>
                        <td colSpan={7} className="py-8 text-center text-gray-500">
                          No sales returns found
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  )
}
