import {
  convertScaleWeightToProductQuantity,
  normalizeScaleWeightKg,
  type WeighingScaleCsvItemMatchField,
  type WeighingScaleSettings,
} from '@/lib/weighingScale'
import { findProductByItemCode, type WeighingScaleProductRef } from '@/lib/weighingScaleCsv'

export type WeighingScaleBarcodePayloadType = 'weight_grams' | 'weight_kg_thousandths' | 'price_paise'

export interface ParsedWeighingScaleBarcode {
  raw: string
  prefix: number
  plu: string
  payload: string
  weightKg: number
}

function pluLookupCodes(plu: string): string[] {
  const codes = new Set<string>()
  codes.add(plu)
  const trimmed = plu.replace(/^0+/, '')
  if (trimmed) codes.add(trimmed)
  codes.add(plu.padStart(5, '0'))
  if (trimmed) codes.add(trimmed.padStart(5, '0'))
  return [...codes]
}

export function parseWeighingScaleBarcode(
  rawBarcode: string,
  settings: Pick<
    WeighingScaleSettings,
    | 'barcode_scan_enabled'
    | 'barcode_prefix_start'
    | 'barcode_prefix_end'
    | 'barcode_plu_digits'
    | 'barcode_payload_digits'
    | 'barcode_payload_type'
    | 'scale_weight_unit'
    | 'tare_weight'
    | 'min_weight'
  >
): ParsedWeighingScaleBarcode | null {
  if (!settings.barcode_scan_enabled) return null

  const digits = rawBarcode.replace(/\D/g, '')
  const pluLen = settings.barcode_plu_digits
  const payloadLen = settings.barcode_payload_digits
  const minLen = 2 + pluLen + payloadLen

  if (digits.length < minLen) return null

  const body = digits.length >= minLen + 1 ? digits.slice(0, -1) : digits.slice(0, minLen)
  if (body.length < minLen) return null

  const prefix = parseInt(body.slice(0, 2), 10)
  if (
    Number.isNaN(prefix) ||
    prefix < settings.barcode_prefix_start ||
    prefix > settings.barcode_prefix_end
  ) {
    return null
  }

  const plu = body.slice(2, 2 + pluLen)
  const payload = body.slice(2 + pluLen, 2 + pluLen + payloadLen)
  if (!/^\d+$/.test(payload)) return null

  const payloadValue = parseInt(payload, 10)
  if (!Number.isFinite(payloadValue)) return null

  let weightKg: number
  switch (settings.barcode_payload_type) {
    case 'weight_kg_thousandths':
      weightKg = payloadValue / 1000
      break
    case 'price_paise':
      weightKg = 0
      break
    case 'weight_grams':
    default:
      weightKg = payloadValue / 1000
      break
  }

  if (settings.barcode_payload_type !== 'price_paise') {
    weightKg = normalizeScaleWeightKg(weightKg, 'kg', settings.tare_weight)
    if (weightKg < settings.min_weight) return null
  } else if (payloadValue <= 0) {
    return null
  }

  return {
    raw: rawBarcode.trim(),
    prefix,
    plu,
    payload,
    weightKg,
  }
}

export function findProductByScalePlu(
  plu: string,
  matchField: WeighingScaleCsvItemMatchField,
  products: WeighingScaleProductRef[]
): WeighingScaleProductRef | null {
  for (const code of pluLookupCodes(plu)) {
    const product = findProductByItemCode(code, matchField, products)
    if (product) return product
  }
  return null
}

export function quantityFromScaleBarcode(
  parsed: ParsedWeighingScaleBarcode,
  productUnit: string,
  decimalPlaces: number,
  salePricePerUnit?: number,
  payloadType?: WeighingScaleBarcodePayloadType
): number | null {
  if (payloadType === 'price_paise' && salePricePerUnit && salePricePerUnit > 0) {
    const priceRupees = parseInt(parsed.payload, 10) / 100
    return convertScaleWeightToProductQuantity(
      priceRupees / salePricePerUnit,
      productUnit,
      decimalPlaces
    )
  }
  return convertScaleWeightToProductQuantity(parsed.weightKg, productUnit, decimalPlaces)
}

export interface ScaleBarcodeCartResult {
  product: WeighingScaleProductRef & { sale_price: number; unit: string }
  quantity: number
}

export function resolveScaleBarcodeForPos(
  rawBarcode: string,
  settings: WeighingScaleSettings,
  products: Array<WeighingScaleProductRef & { sale_price: number; unit: string }>
): ScaleBarcodeCartResult | null {
  const parsed = parseWeighingScaleBarcode(rawBarcode, settings)
  if (!parsed) return null

  const product = findProductByScalePlu(parsed.plu, settings.csv_item_match_field, products)
  if (!product) return null

  const full = products.find((p) => p.id === product.id)
  if (!full) return null

  let quantity: number | null
  if (settings.barcode_payload_type === 'price_paise') {
    quantity = quantityFromScaleBarcode(
      parsed,
      full.unit,
      settings.decimal_places,
      full.sale_price,
      'price_paise'
    )
  } else {
    quantity = quantityFromScaleBarcode(parsed, full.unit, settings.decimal_places)
  }

  if (quantity === null || quantity <= 0) return null

  return { product: full, quantity }
}
