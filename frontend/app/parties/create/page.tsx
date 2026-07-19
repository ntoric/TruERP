'use client'

import { useEffect, useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { apiFetch } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ArrowLeft, Loader2, Save } from 'lucide-react'
import { FieldError } from '@/components/ui/field-error'
import { useFormErrors } from '@/hooks/useFormErrors'
import { cn } from '@/lib/utils'

export default function CreatePartyPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const typeParam = searchParams.get('type') || 'customer'
  const {
    fieldErrors,
    clearFieldError,
    setError,
    handleApiError,
    showErrorToast,
  } = useFormErrors()
  
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [partyCategories, setPartyCategories] = useState<string[]>([])
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    email: '',
    category: '',
    party_type: typeParam,
    opening_balance: 0,
    credit_limit: 0,
    gstin: '',
    address: '',
    city: '',
    state: '',
    pincode: '',
    tan: '',
    pan: '',
    notes: ''
  })

  useEffect(() => {
    if (typeParam) {
      setFormData(prev => ({ ...prev, party_type: typeParam }))
    }
  }, [typeParam])

  useEffect(() => {
    const loadCategories = async () => {
      try {
        const res = await apiFetch('/parties')
        if (res.ok) {
          const data = await res.json()
          setPartyCategories(
            Array.from(new Set(data.map((p: { category?: string }) => p.category).filter(Boolean))) as string[]
          )
        }
      } catch {
        // ignore
      }
    }
    loadCategories()
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formData.name) {
      setError('name', 'Name is required')
      showErrorToast('Name is required')
      return
    }
    if (!formData.party_type) {
      setError('party_type', 'Party type is required')
      showErrorToast('Party type is required')
      return
    }
    setSaving(true)
    try {
      const res = await apiFetch('/parties', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      })
      if (res.ok) {
        router.push('/parties')
      } else {
        await handleApiError(res)
      }
    } catch (err) {
      showErrorToast('An error occurred')
    } finally {
      setSaving(false)
    }
  }

  return (
    <DashboardLayout>
      <div className="max-w-3xl space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="outline" size="icon" onClick={() => router.back()}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <h1 className="text-2xl font-bold text-gray-900">
            Create New {formData.party_type === 'customer' ? 'Customer' : 'Vendor'}
          </h1>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Basic Information</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="name">Name *</Label>
                <Input 
                  id="name" 
                  value={formData.name} 
                  onChange={e => {
                    clearFieldError('name')
                    setFormData({ ...formData, name: e.target.value })
                  }} 
                  className={cn(fieldErrors.name && 'border-red-500')}
                  required
                />
                <FieldError message={fieldErrors.name} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="phone">Mobile</Label>
                <Input 
                  id="phone" 
                  value={formData.phone} 
                  onChange={e => setFormData({ ...formData, phone: e.target.value })} 
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input 
                  id="email" 
                  type="email" 
                  value={formData.email} 
                  onChange={e => setFormData({ ...formData, email: e.target.value })} 
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="category">Category</Label>
                <Select
                  value={formData.category || undefined}
                  onValueChange={v => setFormData({ ...formData, category: v })}
                >
                  <SelectTrigger id="category">
                    <SelectValue placeholder="Select category" />
                  </SelectTrigger>
                  <SelectContent>
                    {partyCategories.map(cat => (
                      <SelectItem key={cat} value={cat}>{cat}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="party_type">Party Type *</Label>
                <Select 
                  value={formData.party_type} 
                  onValueChange={v => {
                    clearFieldError('party_type')
                    setFormData({ ...formData, party_type: v })
                  }}
                >
                  <SelectTrigger className={cn(fieldErrors.party_type && 'border-red-500')}>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="customer">Customer</SelectItem>
                    <SelectItem value="vendor">Vendor</SelectItem>
                  </SelectContent>
                </Select>
                <FieldError message={fieldErrors.party_type} />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Financial Information</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="opening_balance">Opening Balance</Label>
                <Input 
                  id="opening_balance" 
                  type="number" 
                  value={formData.opening_balance} 
                  onChange={e => setFormData({ ...formData, opening_balance: parseFloat(e.target.value) || 0 })} 
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="credit_limit">Credit Limit</Label>
                <Input 
                  id="credit_limit" 
                  type="number" 
                  value={formData.credit_limit} 
                  onChange={e => setFormData({ ...formData, credit_limit: parseFloat(e.target.value) || 0 })} 
                />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>GST & Tax Information</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="gstin">GSTIN</Label>
                <Input 
                  id="gstin" 
                  value={formData.gstin} 
                  onChange={e => setFormData({ ...formData, gstin: e.target.value })} 
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="pan">PAN</Label>
                <Input 
                  id="pan" 
                  value={formData.pan} 
                  onChange={e => setFormData({ ...formData, pan: e.target.value })} 
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="tan">TAN</Label>
                <Input 
                  id="tan" 
                  value={formData.tan} 
                  onChange={e => setFormData({ ...formData, tan: e.target.value })} 
                />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Address Information</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 gap-4">
              <div className="space-y-2">
                <Label htmlFor="address">Address</Label>
                <Input 
                  id="address" 
                  value={formData.address} 
                  onChange={e => setFormData({ ...formData, address: e.target.value })} 
                />
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div className="space-y-2">
                  <Label htmlFor="city">City</Label>
                  <Input 
                    id="city" 
                    value={formData.city} 
                    onChange={e => setFormData({ ...formData, city: e.target.value })} 
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="state">State</Label>
                  <Input 
                    id="state" 
                    value={formData.state} 
                    onChange={e => setFormData({ ...formData, state: e.target.value })} 
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="pincode">Pincode</Label>
                  <Input 
                    id="pincode" 
                    value={formData.pincode} 
                    onChange={e => setFormData({ ...formData, pincode: e.target.value })} 
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Additional Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="notes">Notes</Label>
                <textarea
                  id="notes"
                  value={formData.notes}
                  onChange={e => setFormData({ ...formData, notes: e.target.value })}
                  className="min-h-[100px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                  placeholder="Additional notes..."
                />
              </div>
            </CardContent>
          </Card>

          <div className="flex gap-4">
            <Button type="button" variant="outline" onClick={() => router.back()}>
              Cancel
            </Button>
            <Button type="submit" disabled={saving} className="flex-1">
              {saving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Save className="mr-2 h-4 w-4" />}
              Save {formData.party_type === 'customer' ? 'Customer' : 'Vendor'}
            </Button>
          </div>
        </form>
      </div>
    </DashboardLayout>
  )
}
