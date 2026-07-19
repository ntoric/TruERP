'use client'

import { useEffect, useState } from 'react'
import { apiFetch } from '@/hooks/useAuth'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Printer, X, Eye } from 'lucide-react'

interface ThermalPrintModalProps {
  isOpen: boolean
  onClose: () => void
  documentType: 'invoice' | 'expense'
  documentId: string
  documentNumber: string
}

export default function ThermalPrintModal({
  isOpen,
  onClose,
  documentType,
  documentId,
  documentNumber
}: ThermalPrintModalProps) {
  const [printSize, setPrintSize] = useState<'2inch' | '3inch'>('2inch')
  const [printContent, setPrintContent] = useState<string>('')
  const [printWidth, setPrintWidth] = useState<number>(58)
  const [loading, setLoading] = useState(false)
  const [previewMode, setPreviewMode] = useState(false)

  useEffect(() => {
    if (!isOpen) return
    const loadDefaultSize = async () => {
      try {
        const res = await apiFetch('/settings/print')
        if (res.ok) {
          const data = await res.json()
          if (data.thermal_print_size === '3inch' || data.thermal_print_size === '2inch') {
            setPrintSize(data.thermal_print_size)
          }
        }
      } catch {
        /* keep default */
      }
    }
    void loadDefaultSize()
  }, [isOpen])

  const handleGenerate = async () => {
    setLoading(true)
    try {
      const res = await apiFetch('/printer/thermal', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          document_type: documentType,
          document_id: documentId,
          print_size: printSize
        })
      })
      if (res.ok) {
        const data = await res.json()
        setPrintContent(data.content)
        setPrintWidth(data.width)
        setPreviewMode(true)
      }
    } catch (err) {
      console.error('Failed to generate thermal print:', err)
    } finally {
      setLoading(false)
    }
  }

  const handlePrint = () => {
    if (!printContent) return

    const printWindow = window.open('', '_blank')
    if (printWindow) {
      printWindow.document.write(`
        <html>
        <head>
          <title>Print - ${documentNumber}</title>
          <style>
            body {
              font-family: 'Courier New', monospace;
              font-size: 12px;
              margin: 0;
              padding: 10px;
              white-space: pre;
              line-height: 1.2;
            }
            @media print {
              body {
                margin: 0;
                padding: 0;
              }
            }
          </style>
        </head>
        <body>${printContent.replace(/\n/g, '<br>')}</body>
        </html>
      `)
      printWindow.document.close()
      printWindow.print()
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <Card className="w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto">
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <Printer className="h-5 w-5" />
            Thermal Printer
          </CardTitle>
          <Button variant="ghost" size="icon" onClick={onClose}>
            <X className="h-4 w-4" />
          </Button>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-4">
            <div className="flex-1">
              <label className="text-sm font-medium text-gray-700 mb-1 block">Print Size</label>
              <Select value={printSize} onValueChange={(value: '2inch' | '3inch') => setPrintSize(value)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="2inch">2-inch (58mm)</SelectItem>
                  <SelectItem value="3inch">3-inch (80mm)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <Button onClick={handleGenerate} disabled={loading} className="mt-6">
              {loading ? 'Generating...' : 'Generate'}
            </Button>
          </div>

          {previewMode && printContent && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-medium text-gray-700">Preview ({printWidth}mm)</h3>
                <div className="flex gap-2">
                  <Button variant="outline" size="sm" onClick={() => setPreviewMode(false)}>
                    <Eye className="h-4 w-4 mr-2" />
                    Hide Preview
                  </Button>
                  <Button size="sm" onClick={handlePrint}>
                    <Printer className="h-4 w-4 mr-2" />
                    Print
                  </Button>
                </div>
              </div>
              <div
                className="bg-white border-2 border-gray-300 p-4 mx-auto overflow-auto"
                style={{
                  width: printSize === '2inch' ? '232px' : '320px',
                  fontFamily: 'Courier New, monospace',
                  fontSize: '12px',
                  whiteSpace: 'pre',
                  lineHeight: '1.2'
                }}
              >
                {printContent}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
