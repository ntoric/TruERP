'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'
import { Search, Filter, Download, Trash2, Settings, Archive, BarChart3, Activity, Users, Clock } from 'lucide-react'
import { notifySuccess } from '@/lib/notify'

interface AuditLog {
  id: string
  user_name: string
  action: string
  entity_type: string
  entity_id?: string
  entity_name: string
  description: string
  ip_address: string
  user_agent: string
  status: string
  created_at: string
}

interface AuditStats {
  total_logs: number
  today_logs: number
  success_count: number
  failed_count: number
  top_actions: { action: string; count: number }[]
  top_users: { user_name: string; count: number }[]
}

export default function AuditDashboard() {
  const [logs, setLogs] = useState<AuditLog[]>([])
  const [stats, setStats] = useState<AuditStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [actionFilter, setActionFilter] = useState('all')
  const [entityFilter, setEntityFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [dateFilter, setDateFilter] = useState('all')
  const [page, setPage] = useState(1)
  const [total, setTotal] = useState(0)
  const [retentionDays, setRetentionDays] = useState(90)

  useEffect(() => {
    fetchStats()
    fetchLogs()
  }, [page, actionFilter, entityFilter, statusFilter, dateFilter])

  const fetchStats = async () => {
    try {
      const token = localStorage.getItem('token')
      const response = await fetch('/api/v1/audit/stats', {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (response.ok) {
        const data = await response.json()
        setStats(data)
      }
    } catch (error) {
      console.error('Failed to fetch stats:', error)
    }
  }

  const fetchLogs = async () => {
    setLoading(true)
    try {
      const token = localStorage.getItem('token')
      const params = new URLSearchParams({
        page: page.toString(),
        per_page: '50',
      })
      
      if (search) params.append('search', search)
      if (actionFilter !== 'all') params.append('action', actionFilter)
      if (entityFilter !== 'all') params.append('entity_type', entityFilter)
      if (statusFilter !== 'all') params.append('status', statusFilter)
      if (dateFilter !== 'all') params.append('date_filter', dateFilter)

      const response = await fetch(`/api/v1/audit/logs?${params}`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (response.ok) {
        const data = await response.json()
        setLogs(data.data || [])
        setTotal(data.total || 0)
      }
    } catch (error) {
      console.error('Failed to fetch logs:', error)
    } finally {
      setLoading(false)
    }
  }

  const exportLogs = async () => {
    try {
      const token = localStorage.getItem('token')
      const params = new URLSearchParams()
      if (actionFilter !== 'all') params.append('action', actionFilter)
      if (entityFilter !== 'all') params.append('entity_type', entityFilter)
      if (statusFilter !== 'all') params.append('status', statusFilter)
      
      const response = await fetch(`/api/v1/audit/logs/export?${params}`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (response.ok) {
        const blob = await response.blob()
        const url = window.URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `audit_logs_${new Date().toISOString().split('T')[0]}.csv`
        document.body.appendChild(a)
        a.click()
        window.URL.revokeObjectURL(url)
        document.body.removeChild(a)
      }
    } catch (error) {
      console.error('Failed to export logs:', error)
    }
  }

  const deleteLogs = async () => {
    if (!confirm('Are you sure you want to delete all filtered audit logs? This action cannot be undone.')) return
    
    try {
      const token = localStorage.getItem('token')
      const params = new URLSearchParams()
      if (actionFilter !== 'all') params.append('action', actionFilter)
      if (entityFilter !== 'all') params.append('entity_type', entityFilter)
      
      const response = await fetch(`/api/v1/audit/logs?${params}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      })
      if (response.ok) {
        fetchLogs()
        fetchStats()
      }
    } catch (error) {
      console.error('Failed to delete logs:', error)
    }
  }

  const archiveLogs = async () => {
    const fromDate = prompt('Enter from date (YYYY-MM-DD):')
    const toDate = prompt('Enter to date (YYYY-MM-DD):')
    
    if (!fromDate || !toDate) return
    
    try {
      const token = localStorage.getItem('token')
      const response = await fetch('/api/v1/audit/archive', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ from_date: fromDate, to_date: toDate })
      })
      if (response.ok) {
        const data = await response.json()
        notifySuccess(`Archived ${data.count} logs successfully`)
      }
    } catch (error) {
      console.error('Failed to archive logs:', error)
    }
  }

  const updateRetention = async () => {
    const days = prompt('Enter retention days (7-365):', retentionDays.toString())
    if (!days) return
    
    try {
      const token = localStorage.getItem('token')
      const response = await fetch('/api/v1/audit/retention', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ retention_days: parseInt(days) })
      })
      if (response.ok) {
        setRetentionDays(parseInt(days))
        notifySuccess('Retention settings updated')
      }
    } catch (error) {
      console.error('Failed to update retention:', error)
    }
  }

  const getActionColor = (action: string) => {
    const colors: Record<string, string> = {
      create: 'bg-green-500',
      update: 'bg-blue-500',
      delete: 'bg-red-500',
      login: 'bg-purple-500',
      logout: 'bg-gray-500',
      view: 'bg-cyan-500',
      export: 'bg-orange-500',
    }
    return colors[action] || 'bg-gray-500'
  }

  const getStatusColor = (status: string) => {
    return status === 'success' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">Audit Logs</h1>
          <p className="text-muted-foreground">Track and monitor all user activities</p>
        </div>
        <div className="flex gap-2">
          <Button onClick={exportLogs} variant="outline">
            <Download className="mr-2 h-4 w-4" />
            Export
          </Button>
          <Button onClick={archiveLogs} variant="outline">
            <Archive className="mr-2 h-4 w-4" />
            Archive
          </Button>
          <Button onClick={updateRetention} variant="outline">
            <Settings className="mr-2 h-4 w-4" />
            Retention ({retentionDays} days)
          </Button>
          <Button onClick={deleteLogs} variant="destructive">
            <Trash2 className="mr-2 h-4 w-4" />
            Delete
          </Button>
        </div>
      </div>

      {/* Stats Cards */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Logs</CardTitle>
              <Activity className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.total_logs}</div>
              <p className="text-xs text-muted-foreground">All time</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Today's Logs</CardTitle>
              <Clock className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.today_logs}</div>
              <p className="text-xs text-muted-foreground">Last 24 hours</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Success Rate</CardTitle>
              <BarChart3 className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {stats.total_logs > 0 ? Math.round((stats.success_count / stats.total_logs) * 100) : 0}%
              </div>
              <p className="text-xs text-muted-foreground">
                {stats.success_count} success, {stats.failed_count} failed
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Active Users</CardTitle>
              <Users className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.top_users.length}</div>
              <p className="text-xs text-muted-foreground">Unique users</p>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Filters */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Filter className="h-5 w-5" />
            Filters
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap gap-4">
            <div className="flex-1 min-w-[200px]">
              <Input
                placeholder="Search logs..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && fetchLogs()}
              />
            </div>
            <Select value={actionFilter} onValueChange={setActionFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Action" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Actions</SelectItem>
                <SelectItem value="create">Create</SelectItem>
                <SelectItem value="update">Update</SelectItem>
                <SelectItem value="delete">Delete</SelectItem>
                <SelectItem value="login">Login</SelectItem>
                <SelectItem value="logout">Logout</SelectItem>
                <SelectItem value="view">View</SelectItem>
                <SelectItem value="export">Export</SelectItem>
              </SelectContent>
            </Select>
            <Select value={entityFilter} onValueChange={setEntityFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Entity Type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Entities</SelectItem>
                <SelectItem value="invoice">Invoice</SelectItem>
                <SelectItem value="payment">Payment</SelectItem>
                <SelectItem value="expense">Expense</SelectItem>
                <SelectItem value="party">Party</SelectItem>
                <SelectItem value="user">User</SelectItem>
              </SelectContent>
            </Select>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="success">Success</SelectItem>
                <SelectItem value="failed">Failed</SelectItem>
              </SelectContent>
            </Select>
            <Select value={dateFilter} onValueChange={setDateFilter}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Date Filter" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Time</SelectItem>
                <SelectItem value="today">Today</SelectItem>
                <SelectItem value="yesterday">Yesterday</SelectItem>
                <SelectItem value="this_week">This Week</SelectItem>
                <SelectItem value="this_month">This Month</SelectItem>
                <SelectItem value="this_year">This Year</SelectItem>
              </SelectContent>
            </Select>
            <Button onClick={fetchLogs}>
              <Search className="mr-2 h-4 w-4" />
              Search
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Audit Logs Table */}
      <Card>
        <CardHeader>
          <CardTitle>Audit Log Entries</CardTitle>
          <CardDescription>
            Showing {logs.length} of {total} entries
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="text-center py-8">Loading...</div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Timestamp</TableHead>
                    <TableHead>User</TableHead>
                    <TableHead>Action</TableHead>
                    <TableHead>Entity</TableHead>
                    <TableHead>Description</TableHead>
                    <TableHead>IP Address</TableHead>
                    <TableHead>Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {logs.map((log) => (
                    <TableRow key={log.id}>
                      <TableCell className="text-sm">
                        {new Date(log.created_at).toLocaleString()}
                      </TableCell>
                      <TableCell className="font-medium">{log.user_name}</TableCell>
                      <TableCell>
                        <Badge className={getActionColor(log.action)}>
                          {log.action}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div>
                          <div className="font-medium">{log.entity_type}</div>
                          {log.entity_name && (
                            <div className="text-xs text-muted-foreground">{log.entity_name}</div>
                          )}
                        </div>
                      </TableCell>
                      <TableCell className="max-w-md truncate text-sm">
                        {log.description}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {log.ip_address}
                      </TableCell>
                      <TableCell>
                        <Badge className={getStatusColor(log.status)}>
                          {log.status}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
          
          {/* Pagination */}
          <div className="flex items-center justify-between mt-4">
            <div className="text-sm text-muted-foreground">
              Page {page} of {Math.ceil(total / 50)}
            </div>
            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={page === 1}
              >
                Previous
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPage(p => p + 1)}
                disabled={page >= Math.ceil(total / 50)}
              >
                Next
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Top Actions & Users */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>Top Actions</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {stats.top_actions.slice(0, 5).map((item, index) => (
                  <div key={index} className="flex justify-between items-center">
                    <span className="capitalize">{item.action}</span>
                    <Badge variant="secondary">{item.count}</Badge>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Top Users</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                {stats.top_users.slice(0, 5).map((item, index) => (
                  <div key={index} className="flex justify-between items-center">
                    <span>{item.user_name}</span>
                    <Badge variant="secondary">{item.count}</Badge>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
