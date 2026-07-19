'use client'

import { useEffect, useState } from 'react'
import { apiFetch } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from '@/components/ui/dialog'
import { formatCurrency, formatDate } from '@/lib/utils'
import { Plus, CreditCard } from 'lucide-react'

interface Payment {
  id: string
  amount_received: number
  payment_in_discount: number
  payment_in_number: string
  mode: string
  date: string
  reference: string
  notes: string
  customer?: {
    id: string
    name: string
  }
  party?: {
    id: string
    name: string
  }
}

interface Party {
  id: string
  name: string
  party_type: string
}

export default function PaymentsPage() {
  const [payments, setPayments] = useState<Payment[]>([])
  const [parties, setParties] = useState<Party[]>([])
  const [loading, setLoading] = useState(true)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [formData, setFormData] = useState({
    party_id: '',
    amount_received: '',
    payment_in_discount: '0',
    payment_in_number: '',
    mode: '',
    date: new Date().toISOString().split('T')[0],
    notes: ''
  })

  useEffect(() => {
    fetchPayments()
    fetchParties()
  }, [])

  const fetchPayments = async () => {
    try {
      const res = await apiFetch('/payments')
      if (res.ok) setPayments(await res.json())
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const fetchParties = async () => {
    try {
      const res = await apiFetch('/parties')
      if (res.ok) {
        const data = await res.json()
        setParties(data.filter((p: Party) => p.party_type === 'customer'))
      }
    } catch (err) {
      console.error(err)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      const res = await apiFetch('/payments', {
        method: 'POST',
        body: JSON.stringify({
          party_id: formData.party_id || null,
          amount_received: parseFloat(formData.amount_received),
          payment_in_discount: parseFloat(formData.payment_in_discount),
          payment_in_number: formData.payment_in_number,
          mode: formData.mode,
          date: formData.date,
          notes: formData.notes
        })
      })
      if (res.ok) {
        setDialogOpen(false)
        setFormData({
          party_id: '',
          amount_received: '',
          payment_in_discount: '0',
          payment_in_number: '',
          mode: '',
          date: new Date().toISOString().split('T')[0],
          notes: ''
        })
        fetchPayments()
      }
    } catch (err) {
      console.error(err)
    }
  }

  const getModeIcon = (mode: string) => {
    const colors: Record<string, string> = {
      cash: 'bg-green-100 text-green-700',
      upi: 'bg-blue-100 text-blue-700',
      bank_transfer: 'bg-purple-100 text-purple-700',
      cheque: 'bg-orange-100 text-orange-700',
      card: 'bg-pink-100 text-pink-700',
    }
    return <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${colors[mode] || 'bg-gray-100 text-gray-700'}`}>{mode.replace('_', ' ')}</span>
  }

  const getPartyName = (payment: Payment) => {
    if (payment.party) return payment.party.name
    if (payment.customer) return payment.customer.name
    return '-'
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-gray-900">Payments In</h1>
          <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
            <DialogTrigger asChild>
              <Button className="flex items-center gap-2">
                <Plus className="h-4 w-4" />
                Create Payment In
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create Payment In</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <Label htmlFor="party">Party Name</Label>
                  <Select value={formData.party_id} onValueChange={(value) => setFormData({ ...formData, party_id: value })}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select party" />
                    </SelectTrigger>
                    <SelectContent>
                      {parties.map((party) => (
                        <SelectItem key={party.id} value={party.id}>
                          {party.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="amount_received">Amount Received</Label>
                  <Input
                    id="amount_received"
                    type="number"
                    step="0.01"
                    value={formData.amount_received}
                    onChange={(e) => setFormData({ ...formData, amount_received: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="payment_in_discount">Payment In Discount</Label>
                  <Input
                    id="payment_in_discount"
                    type="number"
                    step="0.01"
                    value={formData.payment_in_discount}
                    onChange={(e) => setFormData({ ...formData, payment_in_discount: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="payment_in_number">Payment In Number</Label>
                  <Input
                    id="payment_in_number"
                    value={formData.payment_in_number}
                    onChange={(e) => setFormData({ ...formData, payment_in_number: e.target.value })}
                  />
                </div>
                <div>
                  <Label htmlFor="mode">Payment Mode</Label>
                  <Select value={formData.mode} onValueChange={(value) => setFormData({ ...formData, mode: value })}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select mode" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="cash">Cash</SelectItem>
                      <SelectItem value="upi">UPI</SelectItem>
                      <SelectItem value="bank_transfer">Bank Transfer</SelectItem>
                      <SelectItem value="cheque">Cheque</SelectItem>
                      <SelectItem value="card">Card</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="date">Payment Date</Label>
                  <Input
                    id="date"
                    type="date"
                    value={formData.date}
                    onChange={(e) => setFormData({ ...formData, date: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="notes">Notes</Label>
                  <Input
                    id="notes"
                    value={formData.notes}
                    onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                  />
                </div>
                <DialogFooter>
                  <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                    Cancel
                  </Button>
                  <Button type="submit">Create Payment</Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Payment In History</CardTitle>
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
                      <th className="pb-3 font-medium">Payment ID</th>
                      <th className="pb-3 font-medium">Party Name</th>
                      <th className="pb-3 font-medium">Amount Received</th>
                      <th className="pb-3 font-medium">Payment In Discount</th>
                      <th className="pb-3 font-medium">Payment Mode</th>
                      <th className="pb-3 font-medium">Payment In Number</th>
                      <th className="pb-3 font-medium">Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    {payments.map((p) => (
                      <tr key={p.id} className="border-b last:border-0 hover:bg-gray-50">
                        <td className="py-3 text-gray-600">{formatDate(p.date)}</td>
                        <td className="py-3 text-gray-600 font-mono text-xs">{p.id.slice(0, 8)}...</td>
                        <td className="py-3 font-medium text-gray-900">{getPartyName(p)}</td>
                        <td className="py-3 font-medium text-gray-900">{formatCurrency(p.amount_received)}</td>
                        <td className="py-3 font-medium text-gray-900">{formatCurrency(p.payment_in_discount)}</td>
                        <td className="py-3">{getModeIcon(p.mode)}</td>
                        <td className="py-3 text-gray-600">{p.payment_in_number || '-'}</td>
                        <td className="py-3 text-gray-600">{p.notes || '-'}</td>
                      </tr>
                    ))}
                    {payments.length === 0 && (
                      <tr>
                        <td colSpan={8} className="py-8 text-center text-gray-500">
                          No payments recorded yet
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
