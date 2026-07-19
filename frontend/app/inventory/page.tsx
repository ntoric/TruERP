'use client'

import { useEffect, useState, useRef } from 'react'
import { apiFetch, useAuth } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import BarcodeScanner from '@/components/ui/BarcodeScanner'
import { Warehouse, ArrowDownLeft, ArrowUpRight, RotateCcw, Plus, Search, Truck, AlertTriangle, Barcode } from 'lucide-react'

interface StockBalance {
  product_id: string
  product_name: string
  sku: string
  stock_qty: number
  cost_price: number
  value: number
  outlet_id: string
  outlet_name: string
}

interface StockEntry {
  id: string
  product?: { name: string; sku: string }
  item_name: string
  entry_type: string
  quantity: number
  balance_qty: number
  cost_price: number
  batch_no: string
  item_code: string
  entry_date: string
  notes: string
  outlet_id: string
  outlet_name: string
  mfg_date?: string
  exp_date?: string
}

interface StockTransfer {
  id: string
  from_outlet_id: string
  to_outlet_id: string
  status: string
  total_items: number
  total_quantity: number
  created_at: string
}

interface InventoryStock {
  id: string
  product_id: string
  product?: { name: string; sku: string }
  outlet_id: string
  outlet_name: string
  quantity: number
  reserved_qty: number
  available_qty: number
  average_cost: number
  last_updated: string
}

interface LowStockAlert {
  product_id: string
  product_name: string
  sku: string
  current_stock: number
  min_stock: number
  outlet_id: string
  outlet_name: string
}

export default function InventoryPage() {
  const { user, loading: authLoading } = useAuth()
  const [balance, setBalance] = useState<StockBalance[]>([])
  const [entries, setEntries] = useState<StockEntry[]>([])
  const [transfers, setTransfers] = useState<StockTransfer[]>([])
  const [stocks, setStocks] = useState<InventoryStock[]>([])
  const [lowStockAlerts, setLowStockAlerts] = useState<LowStockAlert[]>([])
  const [loading, setLoading] = useState(true)
  const [showCreateEntryModal, setShowCreateEntryModal] = useState(false)
  const [showAdjustStockModal, setShowAdjustStockModal] = useState(false)
  const [showTransferModal, setShowTransferModal] = useState(false)
  const [showEditEntryModal, setShowEditEntryModal] = useState(false)
  const [showReserveModal, setShowReserveModal] = useState(false)
  const [showReleaseModal, setShowReleaseModal] = useState(false)
  const [inventoryItems, setInventoryItems] = useState<any[]>([])
  const [warehouses, setWarehouses] = useState<any[]>([])
  const [editingEntry, setEditingEntry] = useState<StockEntry | null>(null)
  const [reserveStock, setReserveStock] = useState({
    product_id: '',
    outlet_id: '',
    quantity: 0,
    reason: ''
  })
  const [releaseStock, setReleaseStock] = useState({
    product_id: '',
    outlet_id: '',
    quantity: 0,
    reason: ''
  })
  const [newEntry, setNewEntry] = useState({
    item_name: '',
    product_id: '',
    outlet_id: '',
    entry_type: 'purchase',
    quantity: 0,
    cost_price: 0,
    batch_no: '',
    item_code: '',
    notes: ''
  })
  const [showBarcodeScanner, setShowBarcodeScanner] = useState(false)
  const [isEditingBarcode, setIsEditingBarcode] = useState(false)
  const [adjustStock, setAdjustStock] = useState({
    item_name: '',
    product_id: '',
    outlet_id: '',
    quantity: 0,
    reason: ''
  })

  useEffect(() => { if (!authLoading && user) fetchData() }, [authLoading, user])
  useEffect(() => { if (!authLoading && user) fetchInventoryItems() }, [authLoading, user])
  useEffect(() => { if (!authLoading && user) fetchWarehouses() }, [authLoading, user])

  const fetchData = async () => {
    try {
      const [b, e, t, s, l] = await Promise.all([
        apiFetch('/inventory/balance'),
        apiFetch('/inventory/entries'),
        apiFetch('/inventory/transfers'),
        apiFetch('/inventory/stocks'),
        apiFetch('/inventory/alerts/low-stock')
      ])
      if (b.ok) { const d = await b.json(); setBalance(Array.isArray(d.data) ? d.data : Array.isArray(d) ? d : []) }
      if (e.ok) { const d = await e.json(); setEntries(Array.isArray(d.data) ? d.data : Array.isArray(d) ? d : []) }
      if (t.ok) { const d = await t.json(); setTransfers(Array.isArray(d.data) ? d.data : Array.isArray(d) ? d : []) }
      if (s.ok) { const d = await s.json(); setStocks(Array.isArray(d) ? d : Array.isArray(d.data) ? d.data : []) }
      if (l.ok) { const d = await l.json(); setLowStockAlerts(Array.isArray(d) ? d : Array.isArray(d.data) ? d.data : []) }
    } catch (err) { console.error(err) }
    finally { setLoading(false) }
  }

  const fetchInventoryItems = async () => {
    try {
      const res = await apiFetch('/inventory/items')
      if (res.ok) {
        const d = await res.json()
        setInventoryItems(Array.isArray(d) ? d : Array.isArray(d.data) ? d.data : [])
      }
    } catch (err) { console.error(err) }
  }

  const fetchWarehouses = async () => {
    try {
      const res = await apiFetch('/warehouses?is_active=true')
      if (res.ok) {
        const d = await res.json()
        setWarehouses(Array.isArray(d) ? d : Array.isArray(d.data) ? d.data : [])
      }
    } catch (err) { console.error(err) }
  }

  const handleCreateEntry = async () => {
    try {
      const res = await apiFetch('/inventory/entries', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...newEntry,
          product_id: newEntry.product_id || null
        })
      })
      if (res.ok) {
        setShowCreateEntryModal(false)
        setNewEntry({
          item_name: '',
          product_id: '',
          outlet_id: '',
          entry_type: 'purchase',
          quantity: 0,
          cost_price: 0,
          batch_no: '',
          item_code: '',
          notes: ''
        })
        fetchData()
      }
    } catch (err) { console.error(err) }
  }

  const handleStockBarcodeScan = async (code: string) => {
    try {
      const res = await apiFetch(`/inventory/stocks/search?item_code=${encodeURIComponent(code)}`)
      
      if (res.ok) {
        const data = await res.json()
        const stockMatches = data.data || []
        
        if (stockMatches.length > 0) {
          const stockMatch = stockMatches[0]
          setNewEntry({
            ...newEntry,
            item_name: stockMatch.product_name,
            product_id: stockMatch.product_id,
            item_code: stockMatch.item_code || code,
          })
        }
      }
    } catch (err) {
      console.error(err)
    }
  }

  const handleEditBarcodeScan = (code: string) => {
    if (!editingEntry) return
    setEditingEntry({
      ...editingEntry,
      item_code: code,
    })
  }

  const handleAdjustStock = async () => {
    try {
      const res = await apiFetch('/inventory/stocks/adjust', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...adjustStock,
          product_id: adjustStock.product_id || null
        })
      })
      if (res.ok) {
        setShowAdjustStockModal(false)
        setAdjustStock({
          item_name: '',
          product_id: '',
          outlet_id: '',
          quantity: 0,
          reason: ''
        })
        fetchData()
      }
    } catch (err) { console.error(err) }
  }

  const handleEditEntry = (entry: StockEntry) => {
    // Format dates for date input (YYYY-MM-DD)
    const formatDate = (dateStr: string | undefined) => {
      if (!dateStr) return ''
      const date = new Date(dateStr)
      if (isNaN(date.getTime())) return ''
      return date.toISOString().split('T')[0]
    }
    
    setEditingEntry({
      ...entry,
      mfg_date: formatDate(entry.mfg_date),
      exp_date: formatDate(entry.exp_date)
    })
    setShowEditEntryModal(true)
  }

  const handleUpdateEntry = async () => {
    if (!editingEntry) return
    try {
      const res = await apiFetch(`/inventory/entries/${editingEntry.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          quantity: editingEntry.quantity,
          cost_price: editingEntry.cost_price,
          batch_no: editingEntry.batch_no,
          item_code: editingEntry.item_code,
          mfg_date: editingEntry.mfg_date || '',
          exp_date: editingEntry.exp_date || '',
          notes: editingEntry.notes
        })
      })
      if (res.ok) {
        setShowEditEntryModal(false)
        setEditingEntry(null)
        fetchData()
      }
    } catch (err) { console.error(err) }
  }

  const handleReserveStock = async () => {
    try {
      const res = await apiFetch('/inventory/stocks/reserve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(reserveStock)
      })
      if (res.ok) {
        setShowReserveModal(false)
        setReserveStock({
          product_id: '',
          outlet_id: '',
          quantity: 0,
          reason: ''
        })
        fetchData()
      }
    } catch (err) { console.error(err) }
  }

  const handleReleaseStock = async () => {
    try {
      const res = await apiFetch('/inventory/stocks/release', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(releaseStock)
      })
      if (res.ok) {
        setShowReleaseModal(false)
        setReleaseStock({
          product_id: '',
          outlet_id: '',
          quantity: 0,
          reason: ''
        })
        fetchData()
      }
    } catch (err) { console.error(err) }
  }

  const getEntryTypeColor = (type: string) => {
    switch (type) {
      case 'purchase': return 'bg-green-100 text-green-800'
      case 'sale': return 'bg-red-100 text-red-800'
      case 'adjustment': return 'bg-yellow-100 text-yellow-800'
      case 'transfer': return 'bg-blue-100 text-blue-800'
      case 'opening': return 'bg-purple-100 text-purple-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getTransferStatusColor = (status: string) => {
    switch (status) {
      case 'draft': return 'bg-gray-100 text-gray-800'
      case 'submitted': return 'bg-blue-100 text-blue-800'
      case 'received': return 'bg-green-100 text-green-800'
      case 'cancelled': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
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
            <h1 className="text-2xl font-bold text-gray-900">Inventory Management</h1>
            <p className="text-gray-500">Track stock levels, movements, and transfers</p>
          </div>
          <div className="flex gap-2">
            <Dialog open={showCreateEntryModal} onOpenChange={setShowCreateEntryModal}>
              <DialogTrigger asChild>
                <Button>
                  <Plus className="h-4 w-4 mr-2" />
                  Stock Entry
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Create Stock Entry</DialogTitle>
                </DialogHeader>
                <div className="space-y-4">
                  <div>
                    <Label>Item Name</Label>
                    <Select
                      value={newEntry.item_name}
                      onValueChange={(value) => {
                        const selectedItem = inventoryItems.find(item => item.id === value)
                        setNewEntry({
                          ...newEntry,
                          item_name: selectedItem?.name || value,
                          product_id: selectedItem?.type === 'product' ? selectedItem.id : ''
                        })
                      }}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select item" />
                      </SelectTrigger>
                      <SelectContent>
                        {inventoryItems.map((item) => (
                          <SelectItem key={item.id} value={item.id}>
                            {item.name} {item.sku && `(${item.sku})`}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Outlet / Warehouse</Label>
                    <Select
                      value={newEntry.outlet_id}
                      onValueChange={(value) => setNewEntry({ ...newEntry, outlet_id: value })}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select outlet" />
                      </SelectTrigger>
                      <SelectContent>
                        {warehouses.map((wh) => (
                          <SelectItem key={wh.id} value={wh.id}>
                            {wh.name} ({wh.code})
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Entry Type</Label>
                    <Select value={newEntry.entry_type} onValueChange={(v) => setNewEntry({ ...newEntry, entry_type: v })}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="purchase">Purchase</SelectItem>
                        <SelectItem value="sale">Sale</SelectItem>
                        <SelectItem value="adjustment">Adjustment</SelectItem>
                        <SelectItem value="transfer">Transfer</SelectItem>
                        <SelectItem value="opening">Opening Stock</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Quantity</Label>
                    <Input
                      type="number"
                      value={newEntry.quantity}
                      onChange={(e) => setNewEntry({ ...newEntry, quantity: parseFloat(e.target.value) || 0 })}
                    />
                  </div>
                  <div>
                    <Label>Cost Price</Label>
                    <Input
                      type="number"
                      value={newEntry.cost_price}
                      onChange={(e) => setNewEntry({ ...newEntry, cost_price: parseFloat(e.target.value) || 0 })}
                    />
                  </div>
                  <div>
                    <Label>Batch No</Label>
                    <Input
                      value={newEntry.batch_no}
                      onChange={(e) => setNewEntry({ ...newEntry, batch_no: e.target.value })}
                    />
                  </div>
                  <div>
                    <Label>Item code</Label>
                    <div className="flex gap-2">
                      <Input
                        value={newEntry.item_code}
                        onChange={(e) => setNewEntry({ ...newEntry, item_code: e.target.value })}
                        placeholder="Enter item code or scan"
                      />
                      <Button
                        type="button"
                        variant="outline"
                        size="icon"
                        onClick={() => setShowBarcodeScanner(true)}
                      >
                        <Barcode className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                  <div>
                    <Label>Notes</Label>
                    <Input
                      value={newEntry.notes}
                      onChange={(e) => setNewEntry({ ...newEntry, notes: e.target.value })}
                    />
                  </div>
                  <Button onClick={handleCreateEntry} className="w-full">Create Entry</Button>
                </div>
              </DialogContent>
            </Dialog>
            <Dialog open={showAdjustStockModal} onOpenChange={setShowAdjustStockModal}>
              <DialogTrigger asChild>
                <Button variant="outline">
                  <RotateCcw className="h-4 w-4 mr-2" />
                  Adjust Stock
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Adjust Stock</DialogTitle>
                </DialogHeader>
                <div className="space-y-4">
                  <div>
                    <Label>Item Name</Label>
                    <Select
                      value={adjustStock.item_name}
                      onValueChange={(value) => {
                        const selectedItem = inventoryItems.find(item => item.id === value)
                        setAdjustStock({
                          ...adjustStock,
                          item_name: selectedItem?.name || value,
                          product_id: selectedItem?.type === 'product' ? selectedItem.id : ''
                        })
                      }}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select item" />
                      </SelectTrigger>
                      <SelectContent>
                        {inventoryItems.map((item) => (
                          <SelectItem key={item.id} value={item.id}>
                            {item.name} {item.sku && `(${item.sku})`}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Outlet / Warehouse</Label>
                    <Select
                      value={adjustStock.outlet_id}
                      onValueChange={(value) => setAdjustStock({ ...adjustStock, outlet_id: value })}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="Select outlet" />
                      </SelectTrigger>
                      <SelectContent>
                        {warehouses.map((wh) => (
                          <SelectItem key={wh.id} value={wh.id}>
                            {wh.name} ({wh.code})
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label>Quantity (+/-)</Label>
                    <Input
                      type="number"
                      value={adjustStock.quantity}
                      onChange={(e) => setAdjustStock({ ...adjustStock, quantity: parseFloat(e.target.value) || 0 })}
                      placeholder="Positive to add, negative to reduce"
                    />
                  </div>
                  <div>
                    <Label>Reason</Label>
                    <Input
                      value={adjustStock.reason}
                      onChange={(e) => setAdjustStock({ ...adjustStock, reason: e.target.value })}
                      placeholder="Reason for adjustment"
                    />
                  </div>
                  <Button onClick={handleAdjustStock} className="w-full">Adjust Stock</Button>
                </div>
              </DialogContent>
            </Dialog>
            <Button variant="outline" onClick={() => setShowReserveModal(true)}>
              <Warehouse className="h-4 w-4 mr-2" />
              Reserve Stock
            </Button>
            <Button variant="outline" onClick={() => setShowReleaseModal(true)}>
              <ArrowDownLeft className="h-4 w-4 mr-2" />
              Release Stock
            </Button>
          </div>
        </div>

        {/* Edit Stock Entry Modal */}
        <Dialog open={showEditEntryModal} onOpenChange={setShowEditEntryModal}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Edit Stock Entry</DialogTitle>
            </DialogHeader>
                {editingEntry && (
                  <div className="space-y-4">
                    <div>
                      <Label>Item</Label>
                      <Input
                        value={editingEntry.product?.name || editingEntry.item_name}
                        disabled
                      />
                    </div>
                    <div>
                      <Label>Quantity</Label>
                      <Input
                        type="number"
                        value={editingEntry.quantity}
                        onChange={(e) => setEditingEntry({ ...editingEntry, quantity: parseFloat(e.target.value) || 0 })}
                      />
                    </div>
                    <div>
                      <Label>Cost Price</Label>
                      <Input
                        type="number"
                        value={editingEntry.cost_price}
                        onChange={(e) => setEditingEntry({ ...editingEntry, cost_price: parseFloat(e.target.value) || 0 })}
                      />
                    </div>
                    <div>
                      <Label>Batch No</Label>
                      <Input
                        value={editingEntry.batch_no}
                        onChange={(e) => setEditingEntry({ ...editingEntry, batch_no: e.target.value })}
                      />
                    </div>
                    <div>
                      <Label>Item code</Label>
                      <div className="flex gap-2">
                        <Input
                          value={editingEntry.item_code || ''}
                          onChange={(e) => setEditingEntry({ ...editingEntry, item_code: e.target.value })}
                          placeholder="Enter item code or scan"
                        />
                        <Button
                          type="button"
                          variant="outline"
                          size="icon"
                          onClick={() => setShowBarcodeScanner(true)}
                        >
                          <Barcode className="h-4 w-4" />
                        </Button>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <Label>Manufacturing Date</Label>
                        <Input
                          type="date"
                          value={editingEntry.mfg_date || ''}
                          onChange={(e) => setEditingEntry({ ...editingEntry, mfg_date: e.target.value })}
                        />
                      </div>
                      <div>
                        <Label>Expiry Date</Label>
                        <Input
                          type="date"
                          value={editingEntry.exp_date || ''}
                          onChange={(e) => setEditingEntry({ ...editingEntry, exp_date: e.target.value })}
                        />
                      </div>
                    </div>
                    <div>
                      <Label>Notes</Label>
                      <Input
                        value={editingEntry.notes}
                        onChange={(e) => setEditingEntry({ ...editingEntry, notes: e.target.value })}
                      />
                    </div>
                    <div className="flex gap-2">
                      <Button onClick={handleUpdateEntry} className="flex-1">Update Entry</Button>
                      <Button variant="outline" onClick={() => setShowEditEntryModal(false)} className="flex-1">Cancel</Button>
                    </div>
                  </div>
                )}
          </DialogContent>
        </Dialog>

        {/* Reserve Stock Modal */}
        <Dialog open={showReserveModal} onOpenChange={setShowReserveModal}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Reserve Stock</DialogTitle>
            </DialogHeader>
            <div className="space-y-4">
              <div>
                <Label>Product</Label>
                <Select
                  value={reserveStock.product_id}
                  onValueChange={(value) => setReserveStock({ ...reserveStock, product_id: value })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select product" />
                  </SelectTrigger>
                  <SelectContent>
                    {inventoryItems.filter(item => item.type === 'product').map((item) => (
                      <SelectItem key={item.id} value={item.id}>
                        {item.name} {item.sku && `(${item.sku})`}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Outlet / Warehouse</Label>
                <Select
                  value={reserveStock.outlet_id}
                  onValueChange={(value) => setReserveStock({ ...reserveStock, outlet_id: value })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select outlet" />
                  </SelectTrigger>
                  <SelectContent>
                    {warehouses.map((wh) => (
                      <SelectItem key={wh.id} value={wh.id}>
                        {wh.name} ({wh.code})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Quantity</Label>
                <Input
                  type="number"
                  value={reserveStock.quantity}
                  onChange={(e) => setReserveStock({ ...reserveStock, quantity: parseFloat(e.target.value) || 0 })}
                  placeholder="0"
                />
              </div>
              <div>
                <Label>Reason</Label>
                <Input
                  value={reserveStock.reason}
                  onChange={(e) => setReserveStock({ ...reserveStock, reason: e.target.value })}
                  placeholder="Reason for reservation"
                />
              </div>
              <Button onClick={handleReserveStock} className="w-full">Reserve Stock</Button>
            </div>
          </DialogContent>
        </Dialog>

        {/* Release Stock Modal */}
        <Dialog open={showReleaseModal} onOpenChange={setShowReleaseModal}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Release Reserved Stock</DialogTitle>
            </DialogHeader>
            <div className="space-y-4">
              <div>
                <Label>Product</Label>
                <Select
                  value={releaseStock.product_id}
                  onValueChange={(value) => setReleaseStock({ ...releaseStock, product_id: value })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select product" />
                  </SelectTrigger>
                  <SelectContent>
                    {inventoryItems.filter(item => item.type === 'product').map((item) => (
                      <SelectItem key={item.id} value={item.id}>
                        {item.name} {item.sku && `(${item.sku})`}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Outlet / Warehouse</Label>
                <Select
                  value={releaseStock.outlet_id}
                  onValueChange={(value) => setReleaseStock({ ...releaseStock, outlet_id: value })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select outlet" />
                  </SelectTrigger>
                  <SelectContent>
                    {warehouses.map((wh) => (
                      <SelectItem key={wh.id} value={wh.id}>
                        {wh.name} ({wh.code})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Quantity</Label>
                <Input
                  type="number"
                  value={releaseStock.quantity}
                  onChange={(e) => setReleaseStock({ ...releaseStock, quantity: parseFloat(e.target.value) || 0 })}
                  placeholder="0"
                />
              </div>
              <div>
                <Label>Reason</Label>
                <Input
                  value={releaseStock.reason}
                  onChange={(e) => setReleaseStock({ ...releaseStock, reason: e.target.value })}
                  placeholder="Reason for release"
                />
              </div>
              <Button onClick={handleReleaseStock} className="w-full">Release Stock</Button>
            </div>
          </DialogContent>
        </Dialog>

        {/* Low Stock Alerts */}
        {lowStockAlerts.length > 0 && (
          <Card className="border-orange-200 bg-orange-50">
            <CardHeader>
              <CardTitle className="text-orange-800 flex items-center gap-2">
                <AlertTriangle className="h-5 w-5" />
                Low Stock Alerts ({lowStockAlerts.length})
              </CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Product</TableHead>
                    <TableHead>SKU</TableHead>
                    <TableHead>Current Stock</TableHead>
                    <TableHead>Min Stock</TableHead>
                    <TableHead>Outlet</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {lowStockAlerts.map((alert) => (
                    <TableRow key={`${alert.product_id}-${alert.outlet_id}`}>
                      <TableCell className="font-medium">{alert.product_name}</TableCell>
                      <TableCell>{alert.sku}</TableCell>
                      <TableCell className="text-red-600 font-medium">{alert.current_stock}</TableCell>
                      <TableCell>{alert.min_stock}</TableCell>
                      <TableCell>{alert.outlet_name || alert.outlet_id}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        )}

        <Tabs defaultValue="balance">
          <TabsList>
            <TabsTrigger value="balance">Stock Balance</TabsTrigger>
            <TabsTrigger value="entries">Stock Entries</TabsTrigger>
            <TabsTrigger value="transfers">Transfers</TabsTrigger>
            <TabsTrigger value="stocks">Inventory Stocks</TabsTrigger>
          </TabsList>

          <TabsContent value="balance">
            <Card>
              <CardHeader>
                <CardTitle>Stock Balance</CardTitle>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Product</TableHead>
                      <TableHead>SKU</TableHead>
                      <TableHead>Stock Qty</TableHead>
                      <TableHead>Cost Price</TableHead>
                      <TableHead>Value</TableHead>
                      <TableHead>Outlet</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {balance.map((item) => (
                      <TableRow key={`${item.product_id}-${item.outlet_id}`}>
                        <TableCell className="font-medium">{item.product_name}</TableCell>
                        <TableCell>{item.sku}</TableCell>
                        <TableCell>{item.stock_qty}</TableCell>
                        <TableCell>₹{item.cost_price.toFixed(2)}</TableCell>
                        <TableCell>₹{item.value.toFixed(2)}</TableCell>
                        <TableCell>{item.outlet_name || item.outlet_id}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="entries">
            <Card>
              <CardHeader>
                <CardTitle>Stock Entries</CardTitle>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Item</TableHead>
                      <TableHead>Type</TableHead>
                      <TableHead>Quantity</TableHead>
                      <TableHead>Cost Price</TableHead>
                      <TableHead>Batch No</TableHead>
                      <TableHead>Item code</TableHead>
                      <TableHead>Outlet</TableHead>
                      <TableHead>Date</TableHead>
                      <TableHead>Notes</TableHead>
                      <TableHead>Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {entries.map((entry) => (
                      <TableRow key={entry.id}>
                        <TableCell className="font-medium">
                          {entry.product?.name || entry.item_name}
                          {entry.product?.sku && <span className="text-gray-500 text-xs ml-2">({entry.product.sku})</span>}
                        </TableCell>
                        <TableCell>
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getEntryTypeColor(entry.entry_type)}`}>
                            {entry.entry_type}
                          </span>
                        </TableCell>
                        <TableCell className={entry.quantity < 0 ? 'text-red-600' : 'text-green-600'}>
                          {entry.quantity}
                        </TableCell>
                        <TableCell>₹{entry.cost_price.toFixed(2)}</TableCell>
                        <TableCell>{entry.batch_no || '-'}</TableCell>
                        <TableCell>{entry.item_code || '-'}</TableCell>
                        <TableCell>{entry.outlet_name || entry.outlet_id}</TableCell>
                        <TableCell>{new Date(entry.entry_date).toLocaleDateString()}</TableCell>
                        <TableCell>{entry.notes || '-'}</TableCell>
                        <TableCell>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleEditEntry(entry)}
                          >
                            Edit
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="transfers">
            <Card>
              <CardHeader>
                <CardTitle>Stock Transfers</CardTitle>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>From Outlet</TableHead>
                      <TableHead>To Outlet</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Items</TableHead>
                      <TableHead>Quantity</TableHead>
                      <TableHead>Date</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {transfers.map((transfer) => (
                      <TableRow key={transfer.id}>
                        <TableCell>{transfer.from_outlet_id || '-'}</TableCell>
                        <TableCell>{transfer.to_outlet_id}</TableCell>
                        <TableCell>
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getTransferStatusColor(transfer.status)}`}>
                            {transfer.status}
                          </span>
                        </TableCell>
                        <TableCell>{transfer.total_items}</TableCell>
                        <TableCell>{transfer.total_quantity}</TableCell>
                        <TableCell>{new Date(transfer.created_at).toLocaleDateString()}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="stocks">
            <Card>
              <CardHeader>
                <CardTitle>Inventory Stocks</CardTitle>
              </CardHeader>
              <CardContent>
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Product</TableHead>
                      <TableHead>SKU</TableHead>
                      <TableHead>Quantity</TableHead>
                      <TableHead>Reserved</TableHead>
                      <TableHead>Available</TableHead>
                      <TableHead>Avg Cost</TableHead>
                      <TableHead>Outlet</TableHead>
                      <TableHead>Last Updated</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {stocks.map((stock) => (
                      <TableRow key={stock.id}>
                        <TableCell className="font-medium">{stock.product?.name || '-'}</TableCell>
                        <TableCell>{stock.product?.sku || '-'}</TableCell>
                        <TableCell>{stock.quantity}</TableCell>
                        <TableCell>{stock.reserved_qty}</TableCell>
                        <TableCell className="font-medium text-green-600">{stock.available_qty}</TableCell>
                        <TableCell>₹{stock.average_cost.toFixed(2)}</TableCell>
                        <TableCell>{stock.outlet_name || stock.outlet_id}</TableCell>
                        <TableCell>{new Date(stock.last_updated).toLocaleDateString()}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
      
      <BarcodeScanner
        open={showBarcodeScanner}
        onOpenChange={setShowBarcodeScanner}
        onScan={showEditEntryModal ? handleEditBarcodeScan : handleStockBarcodeScan}
      />
    </DashboardLayout>
  )
}
