'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { apiFetch, useAuth } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Plus, Eye, Pencil, Trash2 } from 'lucide-react'
import { notifyError } from '@/lib/notify'

interface Party {
  id: string
  name: string
}

interface PurchaseBill {
  id: string
  bill_number: string
}

interface DebitNote {
  id: string
  debit_note_number: string
  party: Party
  purchase_bill: PurchaseBill
  status: string
  date: string
  total_amount: number
  reason: string
}

export default function DebitNotesPage() {
  const { user, loading: authLoading } = useAuth()
  const router = useRouter()
  const [debitNotes, setDebitNotes] = useState<DebitNote[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => { if (!authLoading && user) fetchData() }, [authLoading, user])

  const fetchData = async () => {
    try {
      const res = await apiFetch('/debit-notes')
      if (res.ok) {
        const data = await res.json()
        setDebitNotes(data.data || data)
      }
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const formatCurrency = (val: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(val)

  const getStatusBadge = (status: string) => {
    const colors: Record<string, string> = {
      draft: 'bg-gray-100 text-gray-700',
      issued: 'bg-green-100 text-green-700',
    }
    return <span className={`px-2 py-1 rounded text-xs ${colors[status] || 'bg-gray-100'}`}>{status}</span>
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this debit note?')) return
    try {
      const res = await apiFetch(`/debit-notes/${id}`, { method: 'DELETE' })
      if (res.ok) {
        fetchData()
      } else {
        notifyError('Failed to delete debit note')
      }
    } catch (err) {
      notifyError('An error occurred')
    }
  }

  if (authLoading || loading) return <div className="flex min-h-screen items-center justify-center"><div className="h-8 w-8 animate-spin rounded-full border-4 border-blue-600 border-t-transparent" /></div>

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold">Debit Notes</h1>
          <Button onClick={() => router.push('/debit-notes/create')}>
            <Plus className="mr-2 h-4 w-4" /> New Debit Note
          </Button>
        </div>

        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Note #</TableHead>
                  <TableHead>Vendor</TableHead>
                  <TableHead>Purchase Bill</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Amount</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {debitNotes.map((note) => (
                  <TableRow key={note.id}>
                    <TableCell className="font-medium">{note.debit_note_number}</TableCell>
                    <TableCell>{note.party?.name}</TableCell>
                    <TableCell>{note.purchase_bill?.bill_number}</TableCell>
                    <TableCell>{new Date(note.date).toLocaleDateString()}</TableCell>
                    <TableCell>{getStatusBadge(note.status)}</TableCell>
                    <TableCell className="text-right">{formatCurrency(note.total_amount)}</TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button variant="ghost" size="sm" onClick={() => router.push(`/debit-notes/${note.id}`)}>
                          <Eye className="h-4 w-4" />
                        </Button>
                        {note.status === 'draft' && (
                          <>
                            <Button variant="ghost" size="sm" onClick={() => router.push(`/debit-notes/${note.id}/edit`)}>
                              <Pencil className="h-4 w-4" />
                            </Button>
                            <Button variant="ghost" size="sm" onClick={() => handleDelete(note.id)}>
                              <Trash2 className="h-4 w-4 text-red-500" />
                            </Button>
                          </>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
                {debitNotes.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center py-8 text-gray-500">No debit notes found</TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  )
}
