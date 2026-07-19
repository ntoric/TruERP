'use client'

import { useEffect, useState } from 'react'
import { apiFetch, useAuth } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Plus, FileText, Truck } from 'lucide-react'

interface PurchaseOrder {
  id: string
  order_number: string
  vendor: { name: string }
  status: string
  order_date: string
  total_amount: number
}

interface PurchaseReceipt {
  id: string
  receipt_number: string
  vendor: { name: string }
  status: string
  receipt_date: string
  total_amount: number
}

interface PurchaseBill {
  id: string
  bill_number: string
  vendor: { name: string }
  status: string
  bill_date: string
  total_amount: number
  balance_due: number
}

export default function PurchasesPage() {
  const { user, loading: authLoading } = useAuth()
  const [orders, setOrders] = useState<PurchaseOrder[]>([])
  const [receipts, setReceipts] = useState<PurchaseReceipt[]>([])
  const [bills, setBills] = useState<PurchaseBill[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => { if (!authLoading && user) fetchData() }, [authLoading, user])

  const fetchData = async () => {
    try {
      const [o, r, b] = await Promise.all([
        apiFetch('/purchase/orders'),
        apiFetch('/purchase/receipts'),
        apiFetch('/purchase/bills')
      ])
      if (o.ok) { const d = await o.json(); setOrders(d.data || d) }
      if (r.ok) { const d = await r.json(); setReceipts(d.data || d) }
      if (b.ok) setBills(await b.json())
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const formatCurrency = (val: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(val)

  const getStatusBadge = (status: string) => {
    const colors: Record<string, string> = { draft: 'bg-gray-100 text-gray-700', submitted: 'bg-blue-100 text-blue-700', received: 'bg-green-100 text-green-700', cancelled: 'bg-red-100 text-red-700', unpaid: 'bg-orange-100 text-orange-700', paid: 'bg-green-100 text-green-700' }
    return <span className={`px-2 py-1 rounded text-xs ${colors[status] || 'bg-gray-100'}`}>{status}</span>
  }

  if (authLoading || loading) return <div className="flex min-h-screen items-center justify-center"><div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" /></div>

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold">Purchases</h1>
          <Button><Plus className="mr-2 h-4 w-4" /> New Purchase Order</Button>
        </div>

        <Tabs defaultValue="orders">
          <TabsList><TabsTrigger value="orders">Orders</TabsTrigger><TabsTrigger value="receipts">Receipts (GRN)</TabsTrigger><TabsTrigger value="bills">Bills</TabsTrigger></TabsList>
          
          <TabsContent value="orders">
            <Card><CardContent className="p-0">
              <Table>
                <TableHeader><TableRow><TableHead>Order #</TableHead><TableHead>Vendor</TableHead><TableHead>Date</TableHead><TableHead>Status</TableHead><TableHead className="text-right">Amount</TableHead></TableRow></TableHeader>
                <TableBody>
                  {orders.map((o) => (
                    <TableRow key={o.id}>
                      <TableCell className="font-medium">{o.order_number}</TableCell>
                      <TableCell>{o.vendor?.name}</TableCell>
                      <TableCell>{new Date(o.order_date).toLocaleDateString()}</TableCell>
                      <TableCell>{getStatusBadge(o.status)}</TableCell>
                      <TableCell className="text-right">{formatCurrency(o.total_amount)}</TableCell>
                    </TableRow>
                  ))}
                  {orders.length === 0 && <TableRow><TableCell colSpan={5} className="text-center py-8 text-gray-500">No orders</TableCell></TableRow>}
                </TableBody>
              </Table>
            </CardContent></Card>
          </TabsContent>

          <TabsContent value="receipts">
            <Card><CardContent className="p-0">
              <Table>
                <TableHeader><TableRow><TableHead>Receipt #</TableHead><TableHead>Vendor</TableHead><TableHead>Date</TableHead><TableHead>Status</TableHead><TableHead className="text-right">Amount</TableHead></TableRow></TableHeader>
                <TableBody>
                  {receipts.map((r) => (
                    <TableRow key={r.id}>
                      <TableCell className="font-medium">{r.receipt_number}</TableCell>
                      <TableCell>{r.vendor?.name}</TableCell>
                      <TableCell>{new Date(r.receipt_date).toLocaleDateString()}</TableCell>
                      <TableCell>{getStatusBadge(r.status)}</TableCell>
                      <TableCell className="text-right">{formatCurrency(r.total_amount)}</TableCell>
                    </TableRow>
                  ))}
                  {receipts.length === 0 && <TableRow><TableCell colSpan={5} className="text-center py-8 text-gray-500">No receipts</TableCell></TableRow>}
                </TableBody>
              </Table>
            </CardContent></Card>
          </TabsContent>

          <TabsContent value="bills">
            <Card><CardContent className="p-0">
              <Table>
                <TableHeader><TableRow><TableHead>Bill #</TableHead><TableHead>Vendor</TableHead><TableHead>Date</TableHead><TableHead>Status</TableHead><TableHead className="text-right">Amount</TableHead><TableHead className="text-right">Balance</TableHead></TableRow></TableHeader>
                <TableBody>
                  {bills.map((b) => (
                    <TableRow key={b.id}>
                      <TableCell className="font-medium">{b.bill_number}</TableCell>
                      <TableCell>{b.vendor?.name}</TableCell>
                      <TableCell>{new Date(b.bill_date).toLocaleDateString()}</TableCell>
                      <TableCell>{getStatusBadge(b.status)}</TableCell>
                      <TableCell className="text-right">{formatCurrency(b.total_amount)}</TableCell>
                      <TableCell className="text-right">{formatCurrency(b.balance_due)}</TableCell>
                    </TableRow>
                  ))}
                  {bills.length === 0 && <TableRow><TableCell colSpan={6} className="text-center py-8 text-gray-500">No bills</TableCell></TableRow>}
                </TableBody>
              </Table>
            </CardContent></Card>
          </TabsContent>
        </Tabs>
      </div>
    </DashboardLayout>
  )
}
