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
import { Calendar, CheckCircle, XCircle, Clock, Coffee, Home, Save } from 'lucide-react'

interface Staff {
  id: string
  name: string
  designation: string
}

interface Attendance {
  id: string
  staff_id: string
  staff: Staff
  date: string
  status: string
  check_in_time: string
  check_out_time: string
  work_hours: number
  notes: string
}

interface AttendanceStats {
  total_staff: number
  present: number
  absent: number
  half_day: number
  paid_leave: number
  weekly_off: number
  date: string
}

export default function AttendancePage() {
  const { user, loading: authLoading } = useAuth()
  const [staffs, setStaffs] = useState<Staff[]>([])
  const [attendances, setAttendances] = useState<Attendance[]>([])
  const [stats, setStats] = useState<AttendanceStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0])
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [selectedStaff, setSelectedStaff] = useState<Staff | null>(null)
  const [formData, setFormData] = useState({
    staff_id: '',
    date: selectedDate,
    status: 'present',
    check_in_time: '',
    check_out_time: '',
    work_hours: 0,
    notes: ''
  })

  useEffect(() => { if (!authLoading && user) { fetchStaffs(); fetchAttendance(); fetchStats() } }, [authLoading, user, selectedDate])

  const fetchStaffs = async () => {
    try {
      const res = await apiFetch('/staff')
      if (res.ok) setStaffs(await res.json())
    } catch (err) { console.error(err) }
  }

  const fetchAttendance = async () => {
    try {
      const res = await apiFetch(`/attendance?start_date=${selectedDate}&end_date=${selectedDate}`)
      if (res.ok) setAttendances(await res.json())
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const fetchStats = async () => {
    try {
      const res = await apiFetch(`/attendance/stats?date=${selectedDate}`)
      if (res.ok) setStats(await res.json())
    } catch (err) { console.error(err) }
  }

  const handleSubmit = async () => {
    try {
      const res = await apiFetch('/attendance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...formData,
          date: selectedDate,
          check_in_time: formData.check_in_time ? new Date(`${selectedDate}T${formData.check_in_time}`).toISOString() : null,
          check_out_time: formData.check_out_time ? new Date(`${selectedDate}T${formData.check_out_time}`).toISOString() : null
        })
      })
      if (res.ok) { setIsDialogOpen(false); resetForm(); fetchAttendance(); fetchStats() }
    } catch (err) { console.error(err) }
  }

  const resetForm = () => {
    setFormData({
      staff_id: '',
      date: selectedDate,
      status: 'present',
      check_in_time: '',
      check_out_time: '',
      work_hours: 0,
      notes: ''
    })
    setSelectedStaff(null)
  }

  const handleQuickMark = async (staffId: string, status: string) => {
    try {
      const res = await apiFetch('/attendance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          staff_id: staffId,
          date: selectedDate,
          status,
          work_hours: status === 'half_day' ? 4 : status === 'present' ? 8 : 0
        })
      })
      if (res.ok) { fetchAttendance(); fetchStats() }
    } catch (err) { console.error(err) }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'present': return <CheckCircle className="h-5 w-5 text-green-600" />
      case 'absent': return <XCircle className="h-5 w-5 text-red-600" />
      case 'half_day': return <Clock className="h-5 w-5 text-yellow-600" />
      case 'paid_leave': return <Coffee className="h-5 w-5 text-blue-600" />
      case 'weekly_off': return <Home className="h-5 w-5 text-purple-600" />
      default: return <Clock className="h-5 w-5 text-gray-400" />
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'present': return 'bg-green-100 text-green-700'
      case 'absent': return 'bg-red-100 text-red-700'
      case 'half_day': return 'bg-yellow-100 text-yellow-700'
      case 'paid_leave': return 'bg-blue-100 text-blue-700'
      case 'weekly_off': return 'bg-purple-100 text-purple-700'
      default: return 'bg-gray-100 text-gray-700'
    }
  }

  if (authLoading || loading) return <div className="flex min-h-screen items-center justify-center"><div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" /></div>

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold">Attendance Management</h1>
          <div className="flex items-center gap-4">
            <Input
              type="date"
              value={selectedDate}
              onChange={(e) => setSelectedDate(e.target.value)}
              className="w-auto"
            />
            <Button onClick={() => { resetForm(); setIsDialogOpen(true) }}><Save className="mr-2 h-4 w-4" /> Mark Attendance</Button>
          </div>
        </div>

        {/* Attendance Stats Widget */}
        {stats && (
          <div className="grid grid-cols-2 md:grid-cols-6 gap-4">
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold">{stats.total_staff}</div>
                <div className="text-sm text-gray-600">Total Staff</div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-green-600">{stats.present}</div>
                <div className="text-sm text-gray-600">Present</div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-red-600">{stats.absent}</div>
                <div className="text-sm text-gray-600">Absent</div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-yellow-600">{stats.half_day}</div>
                <div className="text-sm text-gray-600">Half Day</div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-blue-600">{stats.paid_leave}</div>
                <div className="text-sm text-gray-600">Paid Leave</div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-purple-600">{stats.weekly_off}</div>
                <div className="text-sm text-gray-600">Weekly Off</div>
              </CardContent>
            </Card>
          </div>
        )}

        <Card>
          <CardHeader>
            <CardTitle>Attendance for {new Date(selectedDate).toLocaleDateString('en-IN', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Staff Name</TableHead>
                  <TableHead>Designation</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Check In</TableHead>
                  <TableHead>Check Out</TableHead>
                  <TableHead>Work Hours</TableHead>
                  <TableHead>Quick Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {staffs.map((staff) => {
                  const attendance = attendances.find(a => a.staff_id === staff.id)
                  return (
                    <TableRow key={staff.id}>
                      <TableCell className="font-medium">{staff.name}</TableCell>
                      <TableCell>{staff.designation}</TableCell>
                      <TableCell>
                        {attendance ? (
                          <div className="flex items-center gap-2">
                            {getStatusIcon(attendance.status)}
                            <span className={`px-2 py-1 rounded-full text-xs ${getStatusColor(attendance.status)}`}>
                              {attendance.status.replace('_', ' ').toUpperCase()}
                            </span>
                          </div>
                        ) : (
                          <span className="text-gray-400">Not marked</span>
                        )}
                      </TableCell>
                      <TableCell>{attendance?.check_in_time ? new Date(attendance.check_in_time).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : '-'}</TableCell>
                      <TableCell>{attendance?.check_out_time ? new Date(attendance.check_out_time).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) : '-'}</TableCell>
                      <TableCell>{attendance?.work_hours || 0} hrs</TableCell>
                      <TableCell>
                        <div className="flex gap-1">
                          <Button size="sm" variant="outline" onClick={() => handleQuickMark(staff.id, 'present')} className="text-green-600 hover:bg-green-50">P</Button>
                          <Button size="sm" variant="outline" onClick={() => handleQuickMark(staff.id, 'absent')} className="text-red-600 hover:bg-red-50">A</Button>
                          <Button size="sm" variant="outline" onClick={() => handleQuickMark(staff.id, 'half_day')} className="text-yellow-600 hover:bg-yellow-50">H</Button>
                          <Button size="sm" variant="outline" onClick={() => handleQuickMark(staff.id, 'paid_leave')} className="text-blue-600 hover:bg-blue-50">L</Button>
                          <Button size="sm" variant="outline" onClick={() => handleQuickMark(staff.id, 'weekly_off')} className="text-purple-600 hover:bg-purple-50">W</Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  )
                })}
                {staffs.length === 0 && <TableRow><TableCell colSpan={7} className="text-center py-8 text-gray-500">No staff found. Add staff first.</TableCell></TableRow>}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
          <DialogContent>
            <DialogHeader><DialogTitle>Mark Attendance</DialogTitle></DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="space-y-2">
                <Label>Staff *</Label>
                <Select value={formData.staff_id} onValueChange={(v) => setFormData({...formData, staff_id: v})}>
                  <SelectTrigger><SelectValue placeholder="Select staff" /></SelectTrigger>
                  <SelectContent>
                    {staffs.map(s => <SelectItem key={s.id} value={s.id}>{s.name} - {s.designation}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Status *</Label>
                <Select value={formData.status} onValueChange={(v) => setFormData({...formData, status: v})}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="present">Present</SelectItem>
                    <SelectItem value="absent">Absent</SelectItem>
                    <SelectItem value="half_day">Half Day</SelectItem>
                    <SelectItem value="paid_leave">Paid Leave</SelectItem>
                    <SelectItem value="weekly_off">Weekly Off</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Check In Time</Label><Input type="time" value={formData.check_in_time} onChange={(e) => setFormData({...formData, check_in_time: e.target.value})} /></div>
                <div className="space-y-2"><Label>Check Out Time</Label><Input type="time" value={formData.check_out_time} onChange={(e) => setFormData({...formData, check_out_time: e.target.value})} /></div>
              </div>
              <div className="space-y-2"><Label>Work Hours</Label><Input type="number" value={formData.work_hours} onChange={(e) => setFormData({...formData, work_hours: parseFloat(e.target.value) || 0})} /></div>
              <div className="space-y-2"><Label>Notes</Label><Input value={formData.notes} onChange={(e) => setFormData({...formData, notes: e.target.value})} /></div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsDialogOpen(false)}>Cancel</Button>
              <Button onClick={handleSubmit}>Save</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </DashboardLayout>
  )
}
