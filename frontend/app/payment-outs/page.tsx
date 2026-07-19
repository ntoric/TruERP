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
import { Plus, CreditCard, Trash2 } from 'lucide-react'

interface PaymentOut {
  id: string
  amount_paid: number
  payment_out_discount: number
  payment_out_number: string
  mode: string
  date: string
  reference: string
  notes: string
  vendor?: {
    id: string
    name: string
  }
  purchase_bill?: {
    id: string
    bill_number: string
  }
}

interface Vendor {
  id: string
  name: string
}

interface PurchaseBill {
  id: string
  bill_number: string
  vendor_id: string
  total_amount: number
  balance_due: number
}

export default function PaymentOutsPage() {
  const [paymentOuts, setPaymentOuts] = useState<PaymentOut[]>([])
  const [vendors, setVendors] = useState<Vendor[]>([])
  const [bills, setBills] = useState<PurchaseBill[]>([])
  const [loading, setLoading] = useState(true)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [formData, setFormData] = useState({
    vendor_id: '',
    purchase_bill_id: '',
    amount_paid: '',
    payment_out_discount: '0',
    payment_out_number: '',
    mode: '',
    date: new Date().toISOString().split('T')[0],
    reference: '',
    notes: ''
  })

  useEffect(() => {
    fetchPaymentOuts()
    fetchVendors()
    fetchBills()
  }, [])

  const fetchPaymentOuts = async () => {
    try {
      const res = await apiFetch('/payment-outs')
      if (res.ok) setPaymentOuts(await res.json())
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const fetchVendors = async () => {
    try {
      const res = await apiFetch('/vendors')
      if (res.ok) setVendors(await res.json())
    } catch (err) {
      console.error(err)
    }
  }

  const fetchBills = async () => {
    try {
      const res = await apiFetch('/purchase/bills')
      if (res.ok) setBills(await res.json())
    } catch (err) {
      console.error(err)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    try {
      const payload: any = {
        vendor_id: formData.vendor_id,
        amount_paid: parseFloat(formData.amount_paid),
        payment_out_discount: parseFloat(formData.payment_out_discount),
        payment_out_number: formData.payment_out_number,
        mode: formData.mode,
        date: formData.date,
        reference: formData.reference,
        notes: formData.notes
      }
      
      if (formData.purchase_bill_id) {
        payload.purchase_bill_id = formData.purchase_bill_id
      }

      const res = await apiFetch('/payment-outs', {
        method: 'POST',
        body: JSON.stringify(payload)
      })
      if (res.ok) {
        setDialogOpen(false)
        setFormData({
          vendor_id: '',
          purchase_bill_id: '',
          amount_paid: '',
          payment_out_discount: '0',
          payment_out_number: '',
          mode: '',
          date: new Date().toISOString().split('T')[0],
          reference: '',
          notes: ''
        })
        fetchPaymentOuts()
      }
    } catch (err) {
      console.error(err)
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this payment out?')) return
    try {
      const res = await apiFetch(`/payment-outs/${id}`, { method: 'DELETE' })
      if (res.ok) fetchPaymentOuts()
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

  const getVendorName = (paymentOut: PaymentOut) => {
    return paymentOut.vendor?.name || '-'
  }

  const getBillNumber = (paymentOut: PaymentOut) => {
    return paymentOut.purchase_bill?.bill_number || '-'
  }

  const getNetAmount = (paymentOut: PaymentOut) => {
    return paymentOut.amount_paid - paymentOut.payment_out_discount
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-gray-900">Payments Out</h1>
          <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
            <DialogTrigger asChild>
              <Button className="flex items-center gap-2">
                <Plus className="h-4 w-4" />
                Create Payment Out
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create Payment Out</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <Label htmlFor="vendor">Vendor Name</Label>
                  <Select value={formData.vendor_id} onValueChange={(value) => setFormData({ ...formData, vendor_id: value })}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select vendor" />
                    </SelectTrigger>
                    <SelectContent>
                      {vendors.map((vendor) => (
                        <SelectItem key={vendor.id} value={vendor.id}>
                          {vendor.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="purchase_bill">Purchase Bill (Optional)</Label>
                  <Select value={formData.purchase_bill_id} onValueChange={(value) => setFormData({ ...formData, purchase_bill_id: value })}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select bill" />
                    </SelectTrigger>
                    <SelectContent>
                      {bills.filter(b => !formData.vendor_id || b.vendor_id === formData.vendor_id).map((bill) => (
                        <SelectItem key={bill.id} value={bill.id}>
                          {bill.bill_number} - {formatCurrency(bill.balance_due)} due
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="amount_paid">Amount Paid</Label>
                  <Input
                    id="amount_paid"
                    type="number"
                    step="0.01"
                    value={formData.amount_paid}
                    onChange={(e) => setFormData({ ...formData, amount_paid: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="payment_out_discount">Payment Out Discount</Label>
                  <Input
                    id="payment_out_discount"
                    type="number"
                    step="0.01"
                    value={formData.payment_out_discount}
                    onChange={(e) => setFormData({ ...formData, payment_out_discount: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <Label htmlFor="payment_out_number">Payment Out Number</Label>
                  <Input
                    id="payment_out_number"
                    value={formData.payment_out_number}
                    onChange={(e) => setFormData({ ...formData, payment_out_number: e.target.value })}
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
                  <Label htmlFor="reference">Reference</Label>
                  <Input
                    id="reference"
                    value={formData.reference}
                    onChange={(e) => setFormData({ ...formData, reference: e.target.value })}
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
            <CardTitle>Payment Out History</CardTitle>
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
                      <th className="pb-3 font-medium">Vendor Name</th>
                      <th className="pb-3 font-medium">Bill #</th>
                      <th className="pb-3 font-medium">Amount Paid</th>
                      <th className="pb-3 font-medium">Discount</th>
                      <th className="pb-3 font-medium">Net Amount</th>
                      <th className="pb-3 font-medium">Payment Mode</th>
                      <th className="pb-3 font-medium">Payment Out Number</th>
                      <th className="pb-3 font-medium">Notes</th>
                      <th className="pb-3 font-medium">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {paymentOuts.map((p) => (
                      <tr key={p.id} className="border-b last:border-0 hover:bg-gray-50">
                        <td className="py-3 text-gray-600">{formatDate(p.date)}</td>
                        <td className="py-3 text-gray-600 font-mono text-xs">{p.id.slice(0, 8)}...</td>
                        <td className="py-3 font-medium text-gray-900">{getVendorName(p)}</td>
                        <td className="py-3 text-gray-600">{getBillNumber(p)}</td>
                        <td className="py-3 font-medium text-gray-900">{formatCurrency(p.amount_paid)}</td>
                        <td className="py-3 font-medium text-gray-900">{formatCurrency(p.payment_out_discount)}</td>
                        <td className="py-3 font-medium text-gray-900">{formatCurrency(getNetAmount(p))}</td>
                        <td className="py-3">{getModeIcon(p.mode)}</td>
                        <td className="py-3 text-gray-600">{p.payment_out_number || '-'}</td>
                        <td className="py-3 text-gray-600">{p.notes || '-'}</td>
                        <td className="py-3">
                          <button
                            onClick={() => handleDelete(p.id)}
                            className="text-red-500 hover:text-red-700"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </td>
                      </tr>
                    ))}
                    {paymentOuts.length === 0 && (
                      <tr>
                        <td colSpan={11} className="py-8 text-center text-gray-500">
                          No payment outs recorded yet
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
