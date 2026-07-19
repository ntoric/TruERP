'use client'

import { useEffect, useState } from 'react'
import { apiFetch, useAuth } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Plus, DollarSign, Calendar, Download } from 'lucide-react'

interface Staff {
  id: string
  name: string
  designation: string
  salary: number
  salary_type: string
}

interface Payroll {
  id: string
  staff_id: string
  staff: Staff
  payment_number: string
  payment_date: string
  start_date: string
  end_date: string
  basic_salary: number
  working_days: number
  present_days: number
  absent_days: number
  half_days: number
  paid_leave_days: number
  weekly_off_days: number
  deductions: number
  bonus: number
  net_salary: number
  payment_mode: string
  reference: string
  notes: string
  status: string
}

interface PayrollStats {
  total_payments: number
  total_payrolls: number
  this_month: number
}

export default function PayrollPage() {
  const { user, loading: authLoading } = useAuth()
  const [staffs, setStaffs] = useState<Staff[]>([])
  const [payrolls, setPayrolls] = useState<Payroll[]>([])
  const [stats, setStats] = useState<PayrollStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [paymentNumber, setPaymentNumber] = useState('')
  const [formData, setFormData] = useState({
    staff_id: '',
    payment_date: new Date().toISOString().split('T')[0],
    start_date: new Date().toISOString().split('T')[0],
    end_date: new Date().toISOString().split('T')[0],
    basic_salary: 0,
    deductions: 0,
    bonus: 0,
    payment_mode: 'bank_transfer',
    reference: '',
    notes: ''
  })

  useEffect(() => { if (!authLoading && user) { fetchStaffs(); fetchPayrolls(); fetchStats(); fetchNextNumber() } }, [authLoading, user])

  const fetchStaffs = async () => {
    try {
      const res = await apiFetch('/staff')
      if (res.ok) setStaffs(await res.json())
    } catch (err) { console.error(err) }
  }

  const fetchPayrolls = async () => {
    try {
      const res = await apiFetch('/payroll')
      if (res.ok) setPayrolls(await res.json())
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const fetchStats = async () => {
    try {
      const res = await apiFetch('/payroll/stats')
      if (res.ok) setStats(await res.json())
    } catch (err) { console.error(err) }
  }

  const fetchNextNumber = async () => {
    try {
      const res = await apiFetch('/payroll/next-number')
      if (res.ok) {
        const data = await res.json()
        setPaymentNumber(data.payment_number)
      }
    } catch (err) { console.error(err) }
  }

  const handleSubmit = async () => {
    try {
      const res = await apiFetch('/payroll', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...formData,
          payment_date: new Date(formData.payment_date).toISOString(),
          start_date: new Date(formData.start_date).toISOString(),
          end_date: new Date(formData.end_date).toISOString()
        })
      })
      if (res.ok) { setIsDialogOpen(false); resetForm(); fetchPayrolls(); fetchStats(); fetchNextNumber() }
    } catch (err) { console.error(err) }
  }

  const resetForm = () => {
    setFormData({
      staff_id: '',
      payment_date: new Date().toISOString().split('T')[0],
      start_date: new Date().toISOString().split('T')[0],
      end_date: new Date().toISOString().split('T')[0],
      basic_salary: 0,
      deductions: 0,
      bonus: 0,
      payment_mode: 'bank_transfer',
      reference: '',
      notes: ''
    })
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this payroll record?')) return
    try {
      const res = await apiFetch(`/payroll/${id}`, { method: 'DELETE' })
      if (res.ok) { fetchPayrolls(); fetchStats() }
    } catch (err) { console.error(err) }
  }

  const formatCurrency = (val: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(val)

  if (authLoading || loading) return <div className="flex min-h-screen items-center justify-center"><div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" /></div>

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold">Payroll Management</h1>
          <Button onClick={() => { resetForm(); setIsDialogOpen(true) }}><Plus className="mr-2 h-4 w-4" /> Make Payment</Button>
        </div>

        {/* Payroll Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center gap-2">
                  <DollarSign className="h-5 w-5 text-blue-600" />
                  <div>
                    <div className="text-2xl font-bold">{formatCurrency(stats.total_payments)}</div>
                    <div className="text-sm text-gray-600">Total Payments</div>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center gap-2">
                  <Calendar className="h-5 w-5 text-green-600" />
                  <div>
                    <div className="text-2xl font-bold">{stats.total_payrolls}</div>
                    <div className="text-sm text-gray-600">Total Payrolls</div>
                  </div>
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center gap-2">
                  <Download className="h-5 w-5 text-purple-600" />
                  <div>
                    <div className="text-2xl font-bold">{formatCurrency(stats.this_month)}</div>
                    <div className="text-sm text-gray-600">This Month</div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        <Card>
          <CardHeader>
            <CardTitle>Payment History</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Payment No</TableHead>
                  <TableHead>Staff</TableHead>
                  <TableHead>Period</TableHead>
                  <TableHead>Payment Date</TableHead>
                  <TableHead>Days</TableHead>
                  <TableHead>Basic Salary</TableHead>
                  <TableHead>Deductions</TableHead>
                  <TableHead>Bonus</TableHead>
                  <TableHead>Net Salary</TableHead>
                  <TableHead>Mode</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {payrolls.map((p) => (
                  <TableRow key={p.id}>
                    <TableCell className="font-medium">{p.payment_number}</TableCell>
                    <TableCell>
                      <div>
                        <div className="font-medium">{p.staff?.name}</div>
                        <div className="text-sm text-gray-500">{p.staff?.designation}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="text-sm">
                        {new Date(p.start_date).toLocaleDateString('en-IN')} - {new Date(p.end_date).toLocaleDateString('en-IN')}
                      </div>
                    </TableCell>
                    <TableCell>{new Date(p.payment_date).toLocaleDateString('en-IN')}</TableCell>
                    <TableCell>
                      <div className="text-sm">
                        P: {p.present_days} | A: {p.absent_days} | H: {p.half_days} | L: {p.paid_leave_days} | W: {p.weekly_off_days}
                      </div>
                    </TableCell>
                    <TableCell>{formatCurrency(p.basic_salary)}</TableCell>
                    <TableCell className="text-red-600">{formatCurrency(p.deductions)}</TableCell>
                    <TableCell className="text-green-600">{formatCurrency(p.bonus)}</TableCell>
                    <TableCell className="font-bold">{formatCurrency(p.net_salary)}</TableCell>
                    <TableCell>{p.payment_mode.replace('_', ' ')}</TableCell>
                    <TableCell>
                      <span className={`px-2 py-1 rounded-full text-xs ${p.status === 'paid' ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'}`}>
                        {p.status.toUpperCase()}
                      </span>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" onClick={() => handleDelete(p.id)} className="text-red-600">
                        Delete
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
                {payrolls.length === 0 && <TableRow><TableCell colSpan={12} className="text-center py-8 text-gray-500">No payroll records found</TableCell></TableRow>}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
          <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
            <DialogHeader><DialogTitle>Make Payment - {paymentNumber}</DialogTitle></DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="space-y-2">
                <Label>Staff *</Label>
                <Select value={formData.staff_id} onValueChange={(v) => {
                  setFormData({...formData, staff_id: v})
                  const staff = staffs.find(s => s.id === v)
                  if (staff) setFormData({...formData, staff_id: v, basic_salary: staff.salary})
                }}>
                  <SelectTrigger><SelectValue placeholder="Select staff" /></SelectTrigger>
                  <SelectContent>
                    {staffs.map(s => <SelectItem key={s.id} value={s.id}>{s.name} - {s.designation} ({formatCurrency(s.salary)}/{s.salary_type})</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Payment Date *</Label><Input type="date" value={formData.payment_date} onChange={(e) => setFormData({...formData, payment_date: e.target.value})} /></div>
                <div className="space-y-2"><Label>Payment Mode</Label>
                  <Select value={formData.payment_mode} onValueChange={(v) => setFormData({...formData, payment_mode: v})}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="cash">Cash</SelectItem>
                      <SelectItem value="bank_transfer">Bank Transfer</SelectItem>
                      <SelectItem value="upi">UPI</SelectItem>
                      <SelectItem value="cheque">Cheque</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Start Date *</Label><Input type="date" value={formData.start_date} onChange={(e) => setFormData({...formData, start_date: e.target.value})} /></div>
                <div className="space-y-2"><Label>End Date *</Label><Input type="date" value={formData.end_date} onChange={(e) => setFormData({...formData, end_date: e.target.value})} /></div>
              </div>
              <div className="grid grid-cols-3 gap-4">
                <div className="space-y-2"><Label>Basic Salary</Label><Input type="number" value={formData.basic_salary} onChange={(e) => setFormData({...formData, basic_salary: parseFloat(e.target.value) || 0})} /></div>
                <div className="space-y-2"><Label>Deductions</Label><Input type="number" value={formData.deductions} onChange={(e) => setFormData({...formData, deductions: parseFloat(e.target.value) || 0})} /></div>
                <div className="space-y-2"><Label>Bonus</Label><Input type="number" value={formData.bonus} onChange={(e) => setFormData({...formData, bonus: parseFloat(e.target.value) || 0})} /></div>
              </div>
              <div className="space-y-2"><Label>Reference</Label><Input value={formData.reference} onChange={(e) => setFormData({...formData, reference: e.target.value})} placeholder="Transaction ID, Cheque No, etc." /></div>
              <div className="space-y-2"><Label>Notes</Label><Input value={formData.notes} onChange={(e) => setFormData({...formData, notes: e.target.value})} /></div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsDialogOpen(false)}>Cancel</Button>
              <Button onClick={handleSubmit}>Process Payment</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </DashboardLayout>
  )
}
