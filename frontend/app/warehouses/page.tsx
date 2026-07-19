'use client'

import { useEffect, useState } from 'react'
import { apiFetch, useAuth } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Warehouse, Plus, Edit, Trash2, MapPin, Phone, Mail, Building2 } from 'lucide-react'

interface WarehouseData {
  id: string
  name: string
  code: string
  address: string
  city: string
  state: string
  pincode: string
  contact_person: string
  contact_phone: string
  contact_email: string
  is_active: boolean
  is_default: boolean
  notes: string
  created_at: string
}

export default function WarehousesPage() {
  const { user, loading: authLoading } = useAuth()
  const [warehouses, setWarehouses] = useState<WarehouseData[]>([])
  const [loading, setLoading] = useState(true)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [showEditModal, setShowEditModal] = useState(false)
  const [editingWarehouse, setEditingWarehouse] = useState<WarehouseData | null>(null)
  const [newWarehouse, setNewWarehouse] = useState({
    name: '',
    code: '',
    address: '',
    city: '',
    state: '',
    pincode: '',
    contact_person: '',
    contact_phone: '',
    contact_email: '',
    is_default: false,
    notes: ''
  })

  useEffect(() => { if (!authLoading && user) fetchWarehouses() }, [authLoading, user])

  const fetchWarehouses = async () => {
    try {
      const res = await apiFetch('/warehouses')
      if (res.ok) {
        const d = await res.json()
        setWarehouses(Array.isArray(d) ? d : Array.isArray(d.data) ? d.data : [])
      }
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const handleCreateWarehouse = async () => {
    try {
      const res = await apiFetch('/warehouses', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newWarehouse)
      })
      if (res.ok) {
        setShowCreateModal(false)
        setNewWarehouse({
          name: '',
          code: '',
          address: '',
          city: '',
          state: '',
          pincode: '',
          contact_person: '',
          contact_phone: '',
          contact_email: '',
          is_default: false,
          notes: ''
        })
        fetchWarehouses()
      }
    } catch (err) { console.error(err) }
  }

  const handleUpdateWarehouse = async () => {
    if (!editingWarehouse) return
    try {
      const res = await apiFetch(`/warehouses/${editingWarehouse.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newWarehouse)
      })
      if (res.ok) {
        setShowEditModal(false)
        setEditingWarehouse(null)
        setNewWarehouse({
          name: '',
          code: '',
          address: '',
          city: '',
          state: '',
          pincode: '',
          contact_person: '',
          contact_phone: '',
          contact_email: '',
          is_default: false,
          notes: ''
        })
        fetchWarehouses()
      }
    } catch (err) { console.error(err) }
  }

  const handleDeleteWarehouse = async (id: string) => {
    if (!confirm('Are you sure you want to delete this warehouse?')) return
    try {
      const res = await apiFetch(`/warehouses/${id}`, { method: 'DELETE' })
      if (res.ok) {
        fetchWarehouses()
      }
    } catch (err) { console.error(err) }
  }

  const handleEditClick = (warehouse: WarehouseData) => {
    setEditingWarehouse(warehouse)
    setNewWarehouse({
      name: warehouse.name,
      code: warehouse.code,
      address: warehouse.address,
      city: warehouse.city,
      state: warehouse.state,
      pincode: warehouse.pincode,
      contact_person: warehouse.contact_person,
      contact_phone: warehouse.contact_phone,
      contact_email: warehouse.contact_email,
      is_default: warehouse.is_default,
      notes: warehouse.notes
    })
    setShowEditModal(true)
  }

  if (authLoading || loading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-64">
          <div className="text-gray-500">Loading...</div>
        </div>
      </DashboardLayout>
    )
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Warehouses / Outlets</h1>
            <p className="text-gray-500">Manage your storage locations and outlets</p>
          </div>
          <Dialog open={showCreateModal} onOpenChange={setShowCreateModal}>
            <DialogTrigger asChild>
              <Button className="gap-2">
                <Plus className="h-4 w-4" />
                Add Warehouse
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
              <DialogHeader>
                <DialogTitle>Add New Warehouse</DialogTitle>
              </DialogHeader>
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="name">Warehouse Name *</Label>
                    <Input
                      id="name"
                      value={newWarehouse.name}
                      onChange={(e) => setNewWarehouse({ ...newWarehouse, name: e.target.value })}
                      placeholder="Main Warehouse"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="code">Code *</Label>
                    <Input
                      id="code"
                      value={newWarehouse.code}
                      onChange={(e) => setNewWarehouse({ ...newWarehouse, code: e.target.value.toUpperCase() })}
                      placeholder="WH01"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="address">Address</Label>
                  <Input
                    id="address"
                    value={newWarehouse.address}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, address: e.target.value })}
                    placeholder="123 Business Street"
                  />
                </div>

                <div className="grid grid-cols-3 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="city">City</Label>
                    <Input
                      id="city"
                      value={newWarehouse.city}
                      onChange={(e) => setNewWarehouse({ ...newWarehouse, city: e.target.value })}
                      placeholder="Mumbai"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="state">State</Label>
                    <Input
                      id="state"
                      value={newWarehouse.state}
                      onChange={(e) => setNewWarehouse({ ...newWarehouse, state: e.target.value })}
                      placeholder="Maharashtra"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="pincode">Pincode</Label>
                    <Input
                      id="pincode"
                      value={newWarehouse.pincode}
                      onChange={(e) => setNewWarehouse({ ...newWarehouse, pincode: e.target.value })}
                      placeholder="400001"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="contact_person">Contact Person</Label>
                  <Input
                    id="contact_person"
                    value={newWarehouse.contact_person}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, contact_person: e.target.value })}
                    placeholder="John Doe"
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="contact_phone">Contact Phone</Label>
                    <Input
                      id="contact_phone"
                      value={newWarehouse.contact_phone}
                      onChange={(e) => setNewWarehouse({ ...newWarehouse, contact_phone: e.target.value })}
                      placeholder="+91 9876543210"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="contact_email">Contact Email</Label>
                    <Input
                      id="contact_email"
                      type="email"
                      value={newWarehouse.contact_email}
                      onChange={(e) => setNewWarehouse({ ...newWarehouse, contact_email: e.target.value })}
                      placeholder="contact@example.com"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="notes">Notes</Label>
                  <Input
                    id="notes"
                    value={newWarehouse.notes}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, notes: e.target.value })}
                    placeholder="Additional notes..."
                  />
                </div>

                <div className="flex items-center space-x-2">
                  <Switch
                    id="is_default"
                    checked={newWarehouse.is_default}
                    onCheckedChange={(checked) => setNewWarehouse({ ...newWarehouse, is_default: checked })}
                  />
                  <Label htmlFor="is_default">Set as Default Warehouse</Label>
                </div>

                <Button onClick={handleCreateWarehouse} className="w-full">Create Warehouse</Button>
              </div>
            </DialogContent>
          </Dialog>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>All Warehouses</CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Code</TableHead>
                  <TableHead>Name</TableHead>
                  <TableHead>Location</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Default</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {warehouses.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center text-gray-500">
                      No warehouses found. Create your first warehouse to get started.
                    </TableCell>
                  </TableRow>
                ) : (
                  warehouses.map((warehouse) => (
                    <TableRow key={warehouse.id}>
                      <TableCell className="font-medium">{warehouse.code}</TableCell>
                      <TableCell>{warehouse.name}</TableCell>
                      <TableCell>
                        <div className="text-sm">
                          {warehouse.city && <div>{warehouse.city}</div>}
                          {warehouse.state && <div className="text-gray-500">{warehouse.state}</div>}
                        </div>
                      </TableCell>
                      <TableCell>
                        <div className="text-sm">
                          {warehouse.contact_person && <div>{warehouse.contact_person}</div>}
                          {warehouse.contact_phone && <div className="text-gray-500">{warehouse.contact_phone}</div>}
                        </div>
                      </TableCell>
                      <TableCell>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${warehouse.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                          {warehouse.is_active ? 'Active' : 'Inactive'}
                        </span>
                      </TableCell>
                      <TableCell>
                        {warehouse.is_default && (
                          <span className="px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            Default
                          </span>
                        )}
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => handleEditClick(warehouse)}
                          >
                            <Edit className="h-4 w-4" />
                          </Button>
                          {!warehouse.is_default && (
                            <Button
                              size="sm"
                              variant="destructive"
                              onClick={() => handleDeleteWarehouse(warehouse.id)}
                            >
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          )}
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        {/* Edit Modal */}
        <Dialog open={showEditModal} onOpenChange={setShowEditModal}>
          <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle>Edit Warehouse</DialogTitle>
            </DialogHeader>
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="edit_name">Warehouse Name *</Label>
                  <Input
                    id="edit_name"
                    value={newWarehouse.name}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, name: e.target.value })}
                    placeholder="Main Warehouse"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="edit_code">Code *</Label>
                  <Input
                    id="edit_code"
                    value={newWarehouse.code}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, code: e.target.value.toUpperCase() })}
                    placeholder="WH01"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="edit_address">Address</Label>
                <Input
                  id="edit_address"
                  value={newWarehouse.address}
                  onChange={(e) => setNewWarehouse({ ...newWarehouse, address: e.target.value })}
                  placeholder="123 Business Street"
                />
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="edit_city">City</Label>
                  <Input
                    id="edit_city"
                    value={newWarehouse.city}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, city: e.target.value })}
                    placeholder="Mumbai"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="edit_state">State</Label>
                  <Input
                    id="edit_state"
                    value={newWarehouse.state}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, state: e.target.value })}
                    placeholder="Maharashtra"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="edit_pincode">Pincode</Label>
                  <Input
                    id="edit_pincode"
                    value={newWarehouse.pincode}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, pincode: e.target.value })}
                    placeholder="400001"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="edit_contact_person">Contact Person</Label>
                <Input
                  id="edit_contact_person"
                  value={newWarehouse.contact_person}
                  onChange={(e) => setNewWarehouse({ ...newWarehouse, contact_person: e.target.value })}
                  placeholder="John Doe"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="edit_contact_phone">Contact Phone</Label>
                  <Input
                    id="edit_contact_phone"
                    value={newWarehouse.contact_phone}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, contact_phone: e.target.value })}
                    placeholder="+91 9876543210"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="edit_contact_email">Contact Email</Label>
                  <Input
                    id="edit_contact_email"
                    type="email"
                    value={newWarehouse.contact_email}
                    onChange={(e) => setNewWarehouse({ ...newWarehouse, contact_email: e.target.value })}
                    placeholder="contact@example.com"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="edit_notes">Notes</Label>
                <Input
                  id="edit_notes"
                  value={newWarehouse.notes}
                  onChange={(e) => setNewWarehouse({ ...newWarehouse, notes: e.target.value })}
                  placeholder="Additional notes..."
                />
              </div>

              <div className="flex items-center space-x-2">
                <Switch
                  id="edit_is_default"
                  checked={newWarehouse.is_default}
                  onCheckedChange={(checked) => setNewWarehouse({ ...newWarehouse, is_default: checked })}
                />
                <Label htmlFor="edit_is_default">Set as Default Warehouse</Label>
              </div>

              <Button onClick={handleUpdateWarehouse} className="w-full">Update Warehouse</Button>
            </div>
          </DialogContent>
        </Dialog>
      </div>
    </DashboardLayout>
  )
}
