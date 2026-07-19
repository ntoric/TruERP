'use client'

import { useCallback, useEffect, useState } from 'react'
import { apiFetch } from '@/hooks/useAuth'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Switch } from '@/components/ui/switch'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import ThermalInvoicePreviewSample, {
  type ThermalPreviewBusiness,
} from '@/components/ThermalInvoicePreviewSample'
import { Check, Loader2, Printer, Save } from 'lucide-react'

export interface PrintSettings {
  paper_size: string
  orientation: string
  margin_top: number
  margin_bottom: number
  margin_left: number
  margin_right: number
  font_size: number
  print_header: boolean
  print_footer: boolean
  thermal_print_size: '2inch' | '3inch'
  barcode_print_mode: 'label' | 'a4'
}

const DEFAULT_PRINT_SETTINGS: PrintSettings = {
  paper_size: 'a4',
  orientation: 'portrait',
  margin_top: 0.5,
  margin_bottom: 0.5,
  margin_left: 0.5,
  margin_right: 0.5,
  font_size: 12,
  print_header: true,
  print_footer: true,
  thermal_print_size: '2inch',
  barcode_print_mode: 'a4',
}

function mergePrintSettings(raw: Partial<PrintSettings>): PrintSettings {
  return {
    ...DEFAULT_PRINT_SETTINGS,
    ...raw,
    thermal_print_size:
      raw.thermal_print_size === '3inch' ? '3inch' : DEFAULT_PRINT_SETTINGS.thermal_print_size,
    barcode_print_mode:
      raw.barcode_print_mode === 'label' ? 'label' : DEFAULT_PRINT_SETTINGS.barcode_print_mode,
  }
}

function ThemeOption({
  label,
  selected,
  onSelect,
}: {
  label: string
  selected: boolean
  onSelect: () => void
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className={`relative flex w-full items-center justify-between rounded-lg border-2 px-4 py-3 text-left text-sm font-medium transition-colors ${
        selected
          ? 'border-blue-600 bg-blue-50 text-blue-900'
          : 'border-gray-200 bg-white text-gray-800 hover:border-gray-300'
      }`}
    >
      {label}
      {selected ? (
        <span className="flex h-5 w-5 items-center justify-center rounded-full bg-blue-600 text-white">
          <Check className="h-3 w-3" />
        </span>
      ) : null}
    </button>
  )
}

export default function PrintSettingsCard() {
  const [settings, setSettings] = useState<PrintSettings>(DEFAULT_PRINT_SETTINGS)
  const [businessPreview, setBusinessPreview] = useState<ThermalPreviewBusiness>({})
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')
  const [barcodePreviewHtml, setBarcodePreviewHtml] = useState('')
  const [previewLoading, setPreviewLoading] = useState(false)
  const [printTab, setPrintTab] = useState<'thermal' | 'barcode'>('thermal')

  const update = <K extends keyof PrintSettings>(key: K, value: PrintSettings[K]) => {
    setSettings((prev) => ({ ...prev, [key]: value }))
  }

  const loadBarcodePreview = useCallback(async (mode: PrintSettings['barcode_print_mode']) => {
    try {
      const res = await apiFetch(`/printer/barcode/preview?mode=${mode}`)
      if (res.ok) {
        const data = await res.json()
        setBarcodePreviewHtml(data.html || '')
      }
    } catch {
      setBarcodePreviewHtml('')
    }
  }, [])

  useEffect(() => {
    const load = async () => {
      try {
        const [printRes, businessRes] = await Promise.all([
          apiFetch('/settings/print'),
          apiFetch('/business'),
        ])
        if (businessRes.ok) {
          const biz = await businessRes.json()
          setBusinessPreview({
            name: biz.name,
            address: biz.address,
            city: biz.city,
            state: biz.state,
            pincode: biz.pincode,
            phone: biz.phone,
            logo_url: biz.logo_url,
          })
        }
        if (printRes.ok) {
          const merged = mergePrintSettings(await printRes.json())
          setSettings(merged)
          setPreviewLoading(true)
          await loadBarcodePreview(merged.barcode_print_mode)
          setPreviewLoading(false)
        }
      } catch {
        /* defaults */
      } finally {
        setLoading(false)
      }
    }
    void load()
  }, [loadBarcodePreview])

  useEffect(() => {
    if (loading) return
    void loadBarcodePreview(settings.barcode_print_mode)
  }, [loading, loadBarcodePreview, settings.barcode_print_mode])

  const handleSave = async (event: React.FormEvent) => {
    event.preventDefault()
    setSaving(true)
    setMessage('')
    try {
      const res = await apiFetch('/settings/print', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings),
      })
      if (res.ok) {
        setSettings(mergePrintSettings(await res.json()))
        setMessage('Print settings saved successfully')
      } else {
        const data = await res.json().catch(() => ({}))
        setMessage(data.error || 'Failed to update print settings')
      }
    } catch {
      setMessage('Failed to update print settings')
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <Card>
        <CardContent className="flex h-40 items-center justify-center">
          <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
        </CardContent>
      </Card>
    )
  }

  const thermalWidthLabel = settings.thermal_print_size === '3inch' ? '80mm (3 inch)' : '58mm (2 inch)'

  return (
    <Card>
      <CardHeader className="flex flex-row items-center gap-2">
        <Printer className="h-5 w-5 text-blue-600" />
        <CardTitle>Print Settings</CardTitle>
      </CardHeader>
      <CardContent>
        {message && (
          <div
            className={`mb-4 rounded-lg p-3 text-sm ${
              message.includes('success') ? 'bg-green-50 text-green-600' : 'bg-red-50 text-red-600'
            }`}
          >
            {message}
          </div>
        )}

        <form onSubmit={handleSave} className="space-y-6">
          <Tabs value={printTab} onValueChange={(v) => setPrintTab(v as 'thermal' | 'barcode')}>
            <TabsList className="mb-4 h-auto w-full justify-start gap-6 rounded-none border-b bg-transparent p-0">
              <TabsTrigger
                value="thermal"
                className="rounded-none border-b-2 border-transparent px-1 pb-2 data-[state=active]:border-blue-600 data-[state=active]:bg-transparent data-[state=active]:shadow-none"
              >
                Thermal Printer
              </TabsTrigger>
              <TabsTrigger
                value="barcode"
                className="rounded-none border-b-2 border-transparent px-1 pb-2 data-[state=active]:border-blue-600 data-[state=active]:bg-transparent data-[state=active]:shadow-none"
              >
                Barcode Printer
              </TabsTrigger>
            </TabsList>

            <TabsContent value="thermal" className="mt-0">
              <div className="grid gap-6 lg:grid-cols-[minmax(240px,280px)_1fr]">
                <div className="space-y-6 rounded-lg bg-gray-50 p-4">
                  <div>
                    <p className="mb-3 text-sm font-semibold text-gray-900">Select your Invoice theme</p>
                    <div className="space-y-2">
                      <ThemeOption
                        label="2 Inch"
                        selected={settings.thermal_print_size === '2inch'}
                        onSelect={() => update('thermal_print_size', '2inch')}
                      />
                      <ThemeOption
                        label="3 Inch"
                        selected={settings.thermal_print_size === '3inch'}
                        onSelect={() => update('thermal_print_size', '3inch')}
                      />
                    </div>
                  </div>
                  <div>
                    <p className="mb-2 text-sm font-semibold text-gray-900">Business Logo</p>
                    <div className="rounded-md border border-dashed border-gray-300 bg-white p-3 text-center text-xs text-muted-foreground">
                      {businessPreview.logo_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={businessPreview.logo_url}
                          alt="Business logo"
                          className="mx-auto mb-2 max-h-[70px] max-w-[210px] object-contain grayscale"
                        />
                      ) : (
                        <p className="py-4">Upload logo in Business settings</p>
                      )}
                      <p className="text-left leading-relaxed">
                        For best thermal results use a monochrome logo (max 210×70 px). Color logos are
                        shown in preview as grayscale.
                      </p>
                    </div>
                  </div>
                </div>

                <div className="min-w-0">
                  <p className="mb-3 text-sm text-muted-foreground">
                    This is a preview of the thermal print of your invoice. Sample line items and totals
                    are shown for layout only.
                  </p>
                  <div className="flex justify-center overflow-auto rounded-lg border bg-gray-100 p-4 lg:justify-start">
                    <ThermalInvoicePreviewSample
                      printSize={settings.thermal_print_size}
                      business={businessPreview}
                    />
                  </div>
                  <p className="mt-2 text-xs text-muted-foreground">Receipt width: {thermalWidthLabel}</p>
                </div>
              </div>
            </TabsContent>

            <TabsContent value="barcode" className="mt-0">
              <div className="grid gap-6 lg:grid-cols-[minmax(240px,280px)_1fr]">
                <div className="space-y-4 rounded-lg bg-gray-50 p-4">
                  <p className="text-sm font-semibold text-gray-900">Barcode print mode</p>
                  <div className="space-y-2">
                    <ThemeOption
                      label="Label Print"
                      selected={settings.barcode_print_mode === 'label'}
                      onSelect={() => update('barcode_print_mode', 'label')}
                    />
                    <ThemeOption
                      label="A4 Print"
                      selected={settings.barcode_print_mode === 'a4'}
                      onSelect={() => update('barcode_print_mode', 'a4')}
                    />
                  </div>
                  <p className="text-xs text-muted-foreground">
                    A4 layout uses label size and grid from Business → Label Printing Settings.
                  </p>
                </div>
                <div>
                  <div className="mb-2 flex items-center justify-between">
                    <span className="text-sm font-medium text-gray-700">
                      {settings.barcode_print_mode === 'label' ? 'Label preview' : 'A4 sheet preview'}
                    </span>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      disabled={previewLoading}
                      onClick={() => {
                        setPreviewLoading(true)
                        void loadBarcodePreview(settings.barcode_print_mode).finally(() =>
                          setPreviewLoading(false)
                        )
                      }}
                    >
                      {previewLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Refresh'}
                    </Button>
                  </div>
                  {barcodePreviewHtml ? (
                    <iframe
                      title="Barcode print preview"
                      srcDoc={barcodePreviewHtml}
                      className="h-[420px] w-full rounded border bg-white"
                    />
                  ) : (
                    <p className="text-sm text-muted-foreground">Preview unavailable</p>
                  )}
                </div>
              </div>
            </TabsContent>
          </Tabs>

          <details className="rounded-lg border px-4 py-3">
            <summary className="cursor-pointer text-sm font-semibold text-gray-900">
              Document printing (PDF / A4)
            </summary>
            <div className="mt-4 space-y-4">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="paper_size">Paper Size</Label>
                  <Select
                    value={settings.paper_size}
                    onValueChange={(value) => update('paper_size', value)}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="a4">A4</SelectItem>
                      <SelectItem value="letter">Letter</SelectItem>
                      <SelectItem value="legal">Legal</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="orientation">Orientation</Label>
                  <Select
                    value={settings.orientation}
                    onValueChange={(value) => update('orientation', value)}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="portrait">Portrait</SelectItem>
                      <SelectItem value="landscape">Landscape</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="font_size">Font Size</Label>
                  <Input
                    id="font_size"
                    type="number"
                    value={settings.font_size}
                    onChange={(e) => update('font_size', parseInt(e.target.value, 10) || 12)}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="margin_top">Margin Top (inches)</Label>
                  <Input
                    id="margin_top"
                    type="number"
                    step="0.1"
                    value={settings.margin_top}
                    onChange={(e) => update('margin_top', parseFloat(e.target.value) || 0)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="margin_bottom">Margin Bottom (inches)</Label>
                  <Input
                    id="margin_bottom"
                    type="number"
                    step="0.1"
                    value={settings.margin_bottom}
                    onChange={(e) => update('margin_bottom', parseFloat(e.target.value) || 0)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="margin_left">Margin Left (inches)</Label>
                  <Input
                    id="margin_left"
                    type="number"
                    step="0.1"
                    value={settings.margin_left}
                    onChange={(e) => update('margin_left', parseFloat(e.target.value) || 0)}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="margin_right">Margin Right (inches)</Label>
                  <Input
                    id="margin_right"
                    type="number"
                    step="0.1"
                    value={settings.margin_right}
                    onChange={(e) => update('margin_right', parseFloat(e.target.value) || 0)}
                  />
                </div>
              </div>
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <Label htmlFor="print_header">Print Header</Label>
                  <Switch
                    id="print_header"
                    checked={settings.print_header}
                    onCheckedChange={(checked) => update('print_header', checked)}
                  />
                </div>
                <div className="flex items-center justify-between">
                  <Label htmlFor="print_footer">Print Footer</Label>
                  <Switch
                    id="print_footer"
                    checked={settings.print_footer}
                    onCheckedChange={(checked) => update('print_footer', checked)}
                  />
                </div>
              </div>
            </div>
          </details>

          <Button type="submit" disabled={saving}>
            {saving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Save className="mr-2 h-4 w-4" />}
            Save Print Settings
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}
