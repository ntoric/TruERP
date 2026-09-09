'use client'

import { useRef, useState } from 'react'
import { apiFetch, useAuth } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Upload, Loader2, FileArchive, CheckCircle2, AlertTriangle, FileUp } from 'lucide-react'
import { notifyError, notifySuccess } from '@/lib/notify'
import { isSuperAdmin } from '@/lib/roles'

interface MigrationStep {
  step: string
  imported: number
  errors: string[]
}

interface MigrationResult {
  steps: MigrationStep[]
}

export default function MigrationPage() {
  const { user } = useAuth()
  const [zipFile, setZipFile] = useState<File | null>(null)
  const [snapshotHtml, setSnapshotHtml] = useState(false)
  const [running, setRunning] = useState(false)
  const [result, setResult] = useState<MigrationResult | null>(null)
  const [error, setError] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  if (!user || !isSuperAdmin(user.role)) {
    return (
      <DashboardLayout>
        <Card className="max-w-lg">
          <CardHeader>
            <CardTitle>Access denied</CardTitle>
            <p className="text-sm text-gray-500">
              Only Super Admins can access Data Migration.
            </p>
          </CardHeader>
        </Card>
      </DashboardLayout>
    )
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]
    setZipFile(f ?? null)
    setResult(null)
    setError(null)
  }

  const handleRun = async () => {
    if (!zipFile) {
      notifyError('Please select a myBillBook ZIP export first')
      return
    }
    setRunning(true)
    setError(null)
    setResult(null)
    try {
      const form = new FormData()
      form.append('file', zipFile)
      if (snapshotHtml) form.append('snapshot_html', 'true')
      const res = await apiFetch('/migration/mybillbook', {
        method: 'POST',
        body: form,
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Migration failed')
      }
      const data = (await res.json()) as MigrationResult
      setResult(data)
      const totalImported = (data.steps || []).reduce((s, st) => s + st.imported, 0)
      notifySuccess(`Migration complete — ${totalImported} record${totalImported === 1 ? '' : 's'} imported`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Migration failed')
      notifyError(err instanceof Error ? err.message : 'Migration failed')
    } finally {
      setRunning(false)
    }
  }

  const totalImported = result?.steps.reduce((s, st) => s + st.imported, 0) ?? 0
  const totalErrors = result?.steps.reduce((s, st) => s + st.errors.length, 0) ?? 0

  return (
    <DashboardLayout>
      <div className="mx-auto max-w-4xl space-y-6">
        <div>
          <h1 className="text-2xl font-bold">Data Migration</h1>
          <p className="mt-1 text-sm text-gray-500">
            Import data exported from myBillBook into TruERP. Upload the ZIP of
            report CSVs and the migration orchestrator will run a phased import
            (parties, purchase bills, payments, expenses) with row-level error
            reporting.
          </p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <FileArchive className="h-5 w-5" /> myBillBook ZIP import
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="zip-file">myBillBook export ZIP</Label>
              <div className="flex items-center gap-3">
                <Input
                  id="zip-file"
                  ref={inputRef}
                  type="file"
                  accept=".zip,application/zip"
                  onChange={handleFileChange}
                  disabled={running}
                />
                {zipFile && (
                  <span className="whitespace-nowrap text-sm text-gray-500">
                    {zipFile.name} ({(zipFile.size / 1024).toFixed(0)} KB)
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-400">
                The ZIP should contain the myBillBook report CSVs
                (all_party_balance_*.csv, purchase_summary_report_*.csv,
                cash_and_bank_statement_*.csv, expense_transactions_*.csv).
                File matching is by name substring, so the date suffix does not
                matter.
              </p>
            </div>

            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={snapshotHtml}
                onChange={(e) => setSnapshotHtml(e.target.checked)}
                disabled={running}
                className="h-4 w-4 rounded border-gray-300"
              />
              <span>
                Snapshot purchase source pages as HTML during import
                (recommended — preserves the original source document even if
                the myBillBook link later disappears)
              </span>
            </label>

            <div className="flex items-center gap-3">
              <Button onClick={() => void handleRun()} disabled={running || !zipFile}>
                {running ? (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                ) : (
                  <Upload className="mr-2 h-4 w-4" />
                )}
                {running ? 'Running migration…' : 'Run migration'}
              </Button>
              {zipFile && !running && (
                <Button
                  variant="outline"
                  onClick={() => {
                    setZipFile(null)
                    setResult(null)
                    setError(null)
                    if (inputRef.current) inputRef.current.value = ''
                  }}
                >
                  Clear
                </Button>
              )}
            </div>

            {error && (
              <div className="flex items-start gap-2 rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
                <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
                <span>{error}</span>
              </div>
            )}
          </CardContent>
        </Card>

        {result && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <CheckCircle2 className="h-5 w-5 text-green-600" /> Migration results
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex flex-wrap gap-4 text-sm">
                <div className="rounded-md bg-green-50 px-3 py-2">
                  <span className="font-medium text-green-700">{totalImported}</span>
                  <span className="ml-1 text-green-600">records imported</span>
                </div>
                <div className="rounded-md bg-amber-50 px-3 py-2">
                  <span className="font-medium text-amber-700">{totalErrors}</span>
                  <span className="ml-1 text-amber-600">row warnings/errors</span>
                </div>
              </div>

              <div className="space-y-3">
                {result.steps.map((step) => (
                  <div key={step.step} className="rounded-md border p-3">
                    <div className="flex items-center justify-between">
                      <span className="font-medium capitalize">
                        {step.step.replace(/_/g, ' ')}
                      </span>
                      <span className="text-sm text-gray-500">
                        {step.imported} imported
                        {step.errors.length > 0 && (
                          <span className="ml-2 text-amber-600">
                            · {step.errors.length} error{step.errors.length === 1 ? '' : 's'}
                          </span>
                        )}
                      </span>
                    </div>
                    {step.errors.length > 0 && (
                      <details className="mt-2">
                        <summary className="cursor-pointer text-xs text-gray-500">
                          Show row errors
                        </summary>
                        <ul className="mt-2 max-h-48 space-y-1 overflow-auto text-xs text-amber-700">
                          {step.errors.map((e, i) => (
                            <li key={i} className="font-mono">{e}</li>
                          ))}
                        </ul>
                      </details>
                    )}
                  </div>
                ))}
              </div>

              <p className="text-xs text-gray-400">
                Re-running the migration with the same ZIP is safe — already
                imported records (matched by party name or bill number) are
                skipped. Purchase bills imported from myBillBook keep their
                original source link on the purchase invoice page, where you can
                open or download the source document.
              </p>
            </CardContent>
          </Card>
        )}

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <FileUp className="h-5 w-5" /> Individual CSV importers
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-gray-500">
              You can also import a single report CSV without the orchestrator.
              These endpoints accept one CSV at a time and return the imported
              count and row-level errors as JSON.
            </p>
            <ul className="mt-3 space-y-1 text-sm text-gray-600">
              <li><code className="rounded bg-gray-100 px-1">POST /api/v1/parties/import/csv</code> — parties</li>
              <li><code className="rounded bg-gray-100 px-1">POST /api/v1/purchase/bills/import/csv</code> — purchase bills</li>
              <li><code className="rounded bg-gray-100 px-1">POST /api/v1/payments/import/csv</code> — payments (in + out)</li>
              <li><code className="rounded bg-gray-100 px-1">POST /api/v1/expenses/import/csv</code> — expenses</li>
            </ul>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  )
}
