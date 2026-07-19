'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { apiFetch } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { formatCurrency, formatDate } from '@/lib/utils'
import { Plus, Search, FileText, Download, MoreVertical, Edit, X, Trash2, Truck } from 'lucide-react'

interface DeliveryChallan {
  id: string
  challan_number: string
  party: { name: string }
  total_quantity: number
  sub_total: number
  status: string
  date: string
  due_date?: string
}

export default function DeliveryChallansPage() {
  const [challans, setChallans] = useState<DeliveryChallan[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [actionMenu, setActionMenu] = useState<string | null>(null)

  useEffect(() => {
    fetchChallans()
  }, [filter, dateFrom, dateTo])

  const fetchChallans = async () => {
    try {
      let url = '/delivery-challans'
      const params = new URLSearchParams()
      if (filter) params.append('status', filter)
      if (dateFrom) params.append('from', dateFrom)
      if (dateTo) params.append('to', dateTo)
      if (params.toString()) url += `?${params.toString()}`
      const res = await apiFetch(url)
      if (res.ok) setChallans(await res.json())
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const filteredChallans = challans.filter(challan =>
    challan.challan_number.toLowerCase().includes(search.toLowerCase()) ||
    challan.party?.name?.toLowerCase().includes(search.toLowerCase())
  )

  const getStatusBadge = (status: string) => {
    const variants: Record<string, string> = {
      delivered: 'bg-green-100 text-green-700',
      draft: 'bg-gray-100 text-gray-700',
      cancelled: 'bg-red-100 text-red-700',
    }
    return <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${variants[status] || variants.draft}`}>{status}</span>
  }

  const handleExport = () => {
    const headers = ['Date', 'Challan #', 'Party Name', 'Quantity', 'Amount', 'Status']
    const rows = filteredChallans.map(challan => [
      formatDate(challan.date),
      challan.challan_number,
      challan.party?.name || 'N/A',
      challan.total_quantity.toString(),
      formatCurrency(challan.sub_total),
      challan.status
    ])
    const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'delivery-challans.csv'
    a.click()
  }

  const handleCancelChallan = async (id: string) => {
    try {
      const res = await apiFetch(`/delivery-challans/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'cancelled' })
      })
      if (res.ok) {
        fetchChallans()
      }
    } catch (err) {
      console.error(err)
    }
    setActionMenu(null)
  }

  const handleDeleteChallan = async (id: string) => {
    if (!confirm('Are you sure you want to delete this delivery challan?')) return
    try {
      const res = await apiFetch(`/delivery-challans/${id}`, { method: 'DELETE' })
      if (res.ok) {
        fetchChallans()
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
          <h1 className="text-2xl font-bold text-gray-900">Delivery Challans</h1>
          <div className="flex gap-2">
            <Button variant="outline" onClick={handleExport}>
              <Download className="mr-2 h-4 w-4" /> Export
            </Button>
            <Link href="/delivery-challans/create">
              <Button><Plus className="mr-2 h-4 w-4" /> New Delivery Challan</Button>
            </Link>
          </div>
        </div>

        <Card>
          <CardHeader className="pb-4">
            <div className="flex flex-wrap items-center gap-4">
              <div className="relative flex-1 min-w-[200px] max-w-md">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                <Input
                  placeholder="Search challans..."
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
                <option value="delivered">Delivered</option>
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
                      <th className="pb-3 font-medium">Challan #</th>
                      <th className="pb-3 font-medium">Party Name</th>
                      <th className="pb-3 font-medium">Quantity</th>
                      <th className="pb-3 font-medium">Amount</th>
                      <th className="pb-3 font-medium">Status</th>
                      <th className="pb-3 font-medium">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredChallans.map((challan) => (
                      <tr key={challan.id} className="border-b last:border-0 hover:bg-gray-50">
                        <td className="py-3 text-gray-500">{formatDate(challan.date)}</td>
                        <td className="py-3">
                          <Link href={`/delivery-challans/view?id=${challan.id}`} className="font-medium text-blue-600 hover:underline">
                            {challan.challan_number}
                          </Link>
                        </td>
                        <td className="py-3 text-gray-600">{challan.party?.name || 'N/A'}</td>
                        <td className="py-3 text-gray-500">{challan.total_quantity}</td>
                        <td className="py-3 font-medium text-gray-900">{formatCurrency(challan.sub_total)}</td>
                        <td className="py-3">{getStatusBadge(challan.status)}</td>
                        <td className="py-3">
                          <div className="relative">
                            <button
                              onClick={() => setActionMenu(actionMenu === challan.id ? null : challan.id)}
                              className="p-1 hover:bg-gray-100 rounded"
                            >
                              <MoreVertical className="h-4 w-4 text-gray-500" />
                            </button>
                            {actionMenu === challan.id && (
                              <div className="absolute right-0 top-full z-10 mt-1 w-40 rounded-md border bg-white shadow-lg">
                                <div className="py-1">
                                  <Link
                                    href={`/delivery-challans/create?id=${challan.id}`}
                                    className="flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100"
                                    onClick={() => setActionMenu(null)}
                                  >
                                    <Edit className="h-4 w-4" /> Edit
                                  </Link>
                                  {challan.status !== 'cancelled' && challan.status !== 'delivered' && (
                                    <button
                                      onClick={() => handleCancelChallan(challan.id)}
                                      className="flex w-full items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100"
                                    >
                                      <X className="h-4 w-4" /> Cancel
                                    </button>
                                  )}
                                  <button
                                    onClick={() => handleDeleteChallan(challan.id)}
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
                    {filteredChallans.length === 0 && (
                      <tr>
                        <td colSpan={7} className="py-8 text-center text-gray-500">
                          No delivery challans found
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
