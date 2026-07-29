export interface DesktopPrinterInfo {
  name: string
  is_default: boolean
}

type DesktopAppBridge = {
  HasNativePrinting?: () => Promise<boolean>
  ListPrinters?: () => Promise<DesktopPrinterInfo[]>
  PrintPDF?: (pdfBase64: string, printerName: string, jobTitle: string) => Promise<void>
}

type TauriCore = {
  invoke?: (cmd: string, args?: Record<string, unknown>) => Promise<unknown>
}

function getTauriCore(): TauriCore | null {
  if (typeof window === 'undefined') return null
  const tauri = (window as unknown as { __TAURI__?: { core?: TauriCore } }).__TAURI__
  return tauri?.core ?? null
}

function getDesktopApp(): DesktopAppBridge | null {
  if (typeof window === 'undefined') return null
  const go = (window as unknown as { go?: { main?: { App?: DesktopAppBridge } } }).go
  if (go?.main?.App) return go.main.App

  // Tauri desktop shell (desktop-tauri/) — same print surface via invoke().
  const core = getTauriCore()
  if (!core?.invoke) return null
  const invoke = core.invoke.bind(core)
  return {
    HasNativePrinting: () => invoke('has_native_printing') as Promise<boolean>,
    ListPrinters: () => invoke('list_printers') as Promise<DesktopPrinterInfo[]>,
    PrintPDF: (pdfBase64, printerName, jobTitle) =>
      invoke('print_pdf', {
        pdfBase64,
        printerName,
        jobTitle,
      }) as Promise<void>,
  }
}

export function isDesktopApp(): boolean {
  return !!getDesktopApp()
}

export async function hasNativePrinting(): Promise<boolean> {
  const app = getDesktopApp()
  if (!app?.HasNativePrinting) return false
  try {
    return await app.HasNativePrinting()
  } catch {
    return false
  }
}

export async function listDesktopPrinters(): Promise<DesktopPrinterInfo[]> {
  const app = getDesktopApp()
  if (!app?.ListPrinters) return []
  try {
    return (await app.ListPrinters()) || []
  } catch {
    return []
  }
}

export async function desktopPrintPDF(
  pdfBase64: string,
  printerName = '',
  jobTitle = 'TruERP Document'
): Promise<boolean> {
  const app = getDesktopApp()
  if (!app?.PrintPDF) return false
  await app.PrintPDF(pdfBase64, printerName, jobTitle)
  return true
}
