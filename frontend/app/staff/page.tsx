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
import { Plus, Pencil, Trash2, Search } from 'lucide-react'

interface Staff {
  id: string
  name: string
  phone: string
  email: string
  designation: string
  department: string
  salary: number
  salary_type: string
  is_active: boolean
  joining_date: string
}

export default function StaffPage() {
  const { user, loading: authLoading } = useAuth()
  const [staffs, setStaffs] = useState<Staff[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingStaff, setEditingStaff] = useState<Staff | null>(null)
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    email: '',
    address: '',
    designation: '',
    department: '',
    joining_date: '',
    salary: 0,
    salary_type: 'monthly',
    bank_name: '',
    account_number: '',
    ifsc_code: '',
    aadhar_number: '',
    pan_number: '',
    notes: ''
  })

  useEffect(() => { if (!authLoading && user) fetchStaffs() }, [authLoading, user])

  const fetchStaffs = async () => {
    try {
      const res = await apiFetch('/staff')
      if (res.ok) setStaffs(await res.json())
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const handleSubmit = async () => {
    try {
      const url = editingStaff ? `/staff/${editingStaff.id}` : '/staff'
      const method = editingStaff ? 'PUT' : 'POST'
      const res = await apiFetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(formData) })
      if (res.ok) { setIsDialogOpen(false); setEditingStaff(null); resetForm(); fetchStaffs() }
    } catch (err) { console.error(err) }
  }

  const resetForm = () => {
    setFormData({
      name: '',
      phone: '',
      email: '',
      address: '',
      designation: '',
      department: '',
      joining_date: '',
      salary: 0,
      salary_type: 'monthly',
      bank_name: '',
      account_number: '',
      ifsc_code: '',
      aadhar_number: '',
      pan_number: '',
      notes: ''
    })
  }

  const handleEdit = (s: Staff) => {
    setEditingStaff(s)
    setFormData({
      name: s.name,
      phone: s.phone,
      email: s.email,
      address: '',
      designation: s.designation,
      department: s.department,
      joining_date: s.joining_date?.split('T')[0] || '',
      salary: s.salary,
      salary_type: s.salary_type,
      bank_name: '',
      account_number: '',
      ifsc_code: '',
      aadhar_number: '',
      pan_number: '',
      notes: ''
    })
    setIsDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this staff member?')) return
    try {
      const res = await apiFetch(`/staff/${id}`, { method: 'DELETE' })
      if (res.ok) fetchStaffs()
    } catch (err) { console.error(err) }
  }

  const formatCurrency = (val: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(val)

  const filteredStaffs = staffs.filter(s =>
    s.name.toLowerCase().includes(search.toLowerCase()) ||
    s.phone?.includes(search) ||
    s.email?.toLowerCase().includes(search.toLowerCase()) ||
    s.designation?.toLowerCase().includes(search.toLowerCase())
  )

  if (authLoading || loading) return <div className="flex min-h-screen items-center justify-center"><div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" /></div>

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold">Staff Management</h1>
          <Button onClick={() => { setEditingStaff(null); resetForm(); setIsDialogOpen(true) }}><Plus className="mr-2 h-4 w-4" /> Add Staff</Button>
        </div>

        <Card>
          <CardHeader className="pb-4">
            <div className="relative max-w-md">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
              <Input
                placeholder="Search staff..."
                className="pl-10"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Phone</TableHead>
                  <TableHead>Designation</TableHead>
                  <TableHead>Department</TableHead>
                  <TableHead>Salary</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredStaffs.map((s) => (
                  <TableRow key={s.id}>
                    <TableCell className="font-medium">{s.name}</TableCell>
                    <TableCell>{s.phone}</TableCell>
                    <TableCell>{s.designation}</TableCell>
                    <TableCell>{s.department}</TableCell>
                    <TableCell>{formatCurrency(s.salary)}/{s.salary_type === 'monthly' ? 'mo' : s.salary_type === 'daily' ? 'day' : 'hr'}</TableCell>
                    <TableCell>
                      <span className={`px-2 py-1 rounded-full text-xs ${s.is_active ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                        {s.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" onClick={() => handleEdit(s)}><Pencil className="h-4 w-4" /></Button>
                      <Button variant="ghost" size="sm" onClick={() => handleDelete(s.id)} className="text-red-600"><Trash2 className="h-4 w-4" /></Button>
                    </TableCell>
                  </TableRow>
                ))}
                {filteredStaffs.length === 0 && <TableRow><TableCell colSpan={7} className="text-center py-8 text-gray-500">No staff found</TableCell></TableRow>}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
          <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
            <DialogHeader><DialogTitle>{editingStaff ? 'Edit Staff' : 'Add Staff'}</DialogTitle></DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Name *</Label><Input value={formData.name} onChange={(e) => setFormData({...formData, name: e.target.value})} /></div>
                <div className="space-y-2"><Label>Phone</Label><Input value={formData.phone} onChange={(e) => setFormData({...formData, phone: e.target.value})} /></div>
                <div className="space-y-2"><Label>Email</Label><Input type="email" value={formData.email} onChange={(e) => setFormData({...formData, email: e.target.value})} /></div>
                <div className="space-y-2"><Label>Designation</Label><Input value={formData.designation} onChange={(e) => setFormData({...formData, designation: e.target.value})} /></div>
                <div className="space-y-2"><Label>Department</Label><Input value={formData.department} onChange={(e) => setFormData({...formData, department: e.target.value})} /></div>
                <div className="space-y-2"><Label>Joining Date</Label><Input type="date" value={formData.joining_date} onChange={(e) => setFormData({...formData, joining_date: e.target.value})} /></div>
                <div className="space-y-2"><Label>Salary</Label><Input type="number" value={formData.salary} onChange={(e) => setFormData({...formData, salary: parseFloat(e.target.value) || 0})} /></div>
                <div className="space-y-2"><Label>Salary Type</Label>
                  <Select value={formData.salary_type} onValueChange={(v) => setFormData({...formData, salary_type: v})}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent><SelectItem value="monthly">Monthly</SelectItem><SelectItem value="daily">Daily</SelectItem><SelectItem value="hourly">Hourly</SelectItem></SelectContent>
                  </Select>
                </div>
              </div>
              <div className="space-y-2"><Label>Address</Label><Input value={formData.address} onChange={(e) => setFormData({...formData, address: e.target.value})} /></div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Bank Name</Label><Input value={formData.bank_name} onChange={(e) => setFormData({...formData, bank_name: e.target.value})} /></div>
                <div className="space-y-2"><Label>Account Number</Label><Input value={formData.account_number} onChange={(e) => setFormData({...formData, account_number: e.target.value})} /></div>
                <div className="space-y-2"><Label>IFSC Code</Label><Input value={formData.ifsc_code} onChange={(e) => setFormData({...formData, ifsc_code: e.target.value})} /></div>
                <div className="space-y-2"><Label>Aadhar Number</Label><Input value={formData.aadhar_number} onChange={(e) => setFormData({...formData, aadhar_number: e.target.value})} /></div>
                <div className="space-y-2"><Label>PAN Number</Label><Input value={formData.pan_number} onChange={(e) => setFormData({...formData, pan_number: e.target.value})} /></div>
              </div>
              <div className="space-y-2"><Label>Notes</Label><Input value={formData.notes} onChange={(e) => setFormData({...formData, notes: e.target.value})} /></div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsDialogOpen(false)}>Cancel</Button>
              <Button onClick={handleSubmit}>{editingStaff ? 'Update' : 'Create'}</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </DashboardLayout>
  )
}
