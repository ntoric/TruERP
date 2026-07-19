'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { apiFetch } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { formatCurrency, formatDate } from '@/lib/utils'
import { Plus, Search, PlusCircle, Loader2, Printer as ThermalPrinter } from 'lucide-react'
import ThermalPrintModal from '@/components/ThermalPrintModal'
import { notifyError } from '@/lib/notify'

interface Expense {
  id: string
  expense_number: string
  category: string
  description: string
  amount: number
  date: string
  vendor: string
  payment_mode: string
}

interface Category {
  id: string
  name: string
  description: string
}

export default function ExpensesPage() {
  const [expenses, setExpenses] = useState<Expense[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [categoryFilter, setCategoryFilter] = useState('')
  const [showCategoryDialog, setShowCategoryDialog] = useState(false)
  const [newCategory, setNewCategory] = useState({ name: '', description: '' })
  const [creatingCategory, setCreatingCategory] = useState(false)
  const [thermalPrintOpen, setThermalPrintOpen] = useState(false)
  const [selectedExpense, setSelectedExpense] = useState<Expense | null>(null)

  useEffect(() => {
    fetchExpenses()
    fetchCategories()
  }, [categoryFilter, dateFrom, dateTo])

  const fetchExpenses = async () => {
    try {
      let url = '/expenses'
      const params = new URLSearchParams()
      if (categoryFilter) params.append('category', categoryFilter)
      if (dateFrom) params.append('from', dateFrom)
      if (dateTo) params.append('to', dateTo)
      if (search) params.append('search', search)
      if (params.toString()) url += `?${params.toString()}`
      const res = await apiFetch(url)
      if (res.ok) setExpenses(await res.json())
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const fetchCategories = async () => {
    try {
      const res = await apiFetch('/categories')
      if (res.ok) setCategories(await res.json())
    } catch (err) {
      console.error(err)
    }
  }

  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault()
    setCreatingCategory(true)
    try {
      const res = await apiFetch('/categories', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newCategory)
      })
      if (res.ok) {
        setNewCategory({ name: '', description: '' })
        setShowCategoryDialog(false)
        fetchCategories()
      } else {
        const data = await res.json()
        notifyError(data.error || 'Failed to create category')
      }
    } catch (err) {
      notifyError('An error occurred')
    } finally {
      setCreatingCategory(false)
    }
  }

  const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0)

  const uniqueCategories = Array.from(new Set(expenses.map(e => e.category)))

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Expenses</h1>
            <p className="text-sm text-gray-500">Total: {formatCurrency(totalExpenses)}</p>
          </div>
          <div className="flex gap-2">
            <Dialog open={showCategoryDialog} onOpenChange={setShowCategoryDialog}>
              <DialogTrigger asChild>
                <Button variant="outline"><PlusCircle className="mr-2 h-4 w-4" /> Add Category</Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Create New Category</DialogTitle>
                </DialogHeader>
                <form onSubmit={handleCreateCategory} className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="cat-name">Category Name *</Label>
                    <Input
                      id="cat-name"
                      value={newCategory.name}
                      onChange={(e) => setNewCategory({ ...newCategory, name: e.target.value })}
                      required
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="cat-desc">Description</Label>
                    <Input
                      id="cat-desc"
                      value={newCategory.description}
                      onChange={(e) => setNewCategory({ ...newCategory, description: e.target.value })}
                    />
                  </div>
                  <Button type="submit" disabled={creatingCategory} className="w-full">
                    {creatingCategory ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Plus className="mr-2 h-4 w-4" />}
                    Create Category
                  </Button>
                </form>
              </DialogContent>
            </Dialog>
            <Link href="/expenses/create">
              <Button><Plus className="mr-2 h-4 w-4" /> Add Expense</Button>
            </Link>
          </div>
        </div>

        <Card>
          <CardHeader className="pb-4">
            <div className="flex flex-wrap items-center gap-4">
              <div className="relative flex-1 min-w-[200px] max-w-md">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                <Input
                  placeholder="Search expenses..."
                  className="pl-10"
                  value={search}
                  onChange={(e) => { setSearch(e.target.value); fetchExpenses() }}
                />
              </div>
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className="h-10 rounded-md border border-input bg-background px-3 text-sm"
              >
                <option value="">All Categories</option>
                {uniqueCategories.map(cat => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
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
                      <th className="pb-3 font-medium">Expense Number</th>
                      <th className="pb-3 font-medium">Party Name</th>
                      <th className="pb-3 font-medium">Category</th>
                      <th className="pb-3 font-medium">Amount</th>
                      <th className="pb-3 font-medium">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {expenses.map((e) => (
                      <tr key={e.id} className="border-b last:border-0 hover:bg-gray-50">
                        <td className="py-3 text-gray-600">{formatDate(e.date)}</td>
                        <td className="py-3 font-medium text-gray-900">{e.expense_number}</td>
                        <td className="py-3 text-gray-600">{e.vendor || '-'}</td>
                        <td className="py-3">
                          <span className="rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-700">
                            {e.category}
                          </span>
                        </td>
                        <td className="py-3 font-medium text-gray-900">{formatCurrency(e.amount)}</td>
                        <td className="py-3">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => { setSelectedExpense(e); setThermalPrintOpen(true) }}
                          >
                            <ThermalPrinter className="h-4 w-4" />
                          </Button>
                        </td>
                      </tr>
                    ))}
                    {expenses.length === 0 && (
                      <tr>
                        <td colSpan={6} className="py-8 text-center text-gray-500">
                          No expenses recorded yet
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>

        {selectedExpense && (
          <ThermalPrintModal
            isOpen={thermalPrintOpen}
            onClose={() => setThermalPrintOpen(false)}
            documentType="expense"
            documentId={selectedExpense.id}
            documentNumber={selectedExpense.expense_number}
          />
        )}
      </div>
    </DashboardLayout>
  )
}
