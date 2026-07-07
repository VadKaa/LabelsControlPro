<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'

type LayoutFieldKey = 'product_number' | 'product_name' | 'barcode' | 'qr_code' | 'item_type' | 'weight' | 'quantity' | 'details' | 'notes'

type LayoutOffset = {
  x: number
  y: number
  scale: number
}

type FontSetting = {
  family: string
  size: number
  bold: boolean
  italic: boolean
}

type DisplayOptions = {
  product_number: boolean
  product_name: boolean
  barcode: boolean
  quantity: boolean
  item_type: boolean
  weight: boolean
  notes: boolean
}

type LayoutAnchor = {
  x: number
  y: number
  w: number
  h: number
}

type LayoutAnchors = Record<LayoutFieldKey, LayoutAnchor>

type LabelPayload = {
  product_number: string
  product_name: string
  quantity: number
  item_type: string
  weight: string
  barcode: string
  notes: string
  print: boolean
  printer_name: string
  print_density: number
  label_width_mm: number
  label_length_mm: number
  layout_preset: string
  barcode_width_pct: number
  barcode_height_pct: number
  show_qr: boolean
  driver_media_name: string
  printer_profile: string
  zpl_dpi: number
  print_orientation: 'horizontal' | 'vertical'
  display_options: DisplayOptions
  font_settings: Record<LayoutFieldKey, FontSetting>
  layout_offsets: Record<LayoutFieldKey, LayoutOffset>
  preview_image_data_url?: string
}

type Printer = {
  Name: string
  DriverName: string
  PortName: string
  PrinterStatus?: string | number
  WorkOffline?: boolean
  WmiPrinterStatus?: number | null
  DetectedErrorState?: number | null
  ExtendedPrinterStatus?: number | null
  PortHostAddress?: string | null
  NetworkReachable?: boolean | null
  LocalDevicePresent?: boolean | null
  IsOnline?: boolean
  StatusDetail?: string
}

type PrintJob = {
  ID: number
  DocumentName: string
  JobStatus: string
  SubmittedTime?: string
  Size?: number
  TotalPages?: number
  PagesPrinted?: number
  PrinterName?: string
}

type LabelTemplate = {
  id: string
  name: string
  saved_at?: number
  label: LabelPayload
}

type PrinterMedia = {
  name: string
  raw_kind: number
  width_mm: number
  height_mm: number
  continuous: boolean
}

const API_BASE = import.meta.env.VITE_API_BASE ?? ''

const form = reactive<LabelPayload>({
  product_number: 'BR-99042-X',
  product_name: 'Industrial Coupler - 36mm Brass',
  quantity: 500,
  item_type: 'METALLIC COMPONENT',
  weight: '1.450 KG',
  barcode: '99042X-36MM',
  notes: 'ISO-9001 COMPLIANT',
  print: false,
  printer_name: 'Brother QL-820NWB',
  print_density: 5,
  label_width_mm: 62,
  label_length_mm: 60,
  layout_preset: 'compact_right',
  barcode_width_pct: 42,
  barcode_height_pct: 42,
  show_qr: false,
  driver_media_name: '62mm',
  printer_profile: 'brother_ql_raster',
  zpl_dpi: 203,
  print_orientation: 'horizontal',
  display_options: {
    product_number: true,
    product_name: true,
    barcode: true,
    quantity: true,
    item_type: true,
    weight: true,
    notes: true,
  },
  font_settings: {
    product_number: { family: 'Arial', size: 27, bold: true, italic: false },
    product_name: { family: 'Arial', size: 14, bold: true, italic: false },
    barcode: { family: 'Consolas', size: 8, bold: true, italic: false },
    qr_code: { family: 'Arial', size: 9, bold: false, italic: false },
    item_type: { family: 'Arial', size: 9, bold: false, italic: false },
    weight: { family: 'Arial', size: 9, bold: false, italic: false },
    quantity: { family: 'Arial', size: 9, bold: false, italic: false },
    details: { family: 'Arial', size: 9, bold: false, italic: false },
    notes: { family: 'Arial', size: 9, bold: false, italic: false },
  },
  layout_offsets: {
    product_number: { x: 0, y: 0, scale: 1 },
    product_name: { x: 0, y: 0, scale: 1 },
    barcode: { x: 0, y: 0, scale: 1 },
    qr_code: { x: 0, y: 0, scale: 1 },
    item_type: { x: 0, y: 0, scale: 1 },
    weight: { x: 0, y: 0, scale: 1 },
    quantity: { x: 0, y: 0, scale: 1 },
    details: { x: 0, y: 0, scale: 1 },
    notes: { x: 0, y: 0, scale: 1 },
  },
})

const printers = ref<Printer[]>([])
const printJobs = ref<PrintJob[]>([])
const templates = ref<LabelTemplate[]>([])
const printerMedia = ref<PrinterMedia[]>([])
const activeTab = ref<'designer' | 'queue' | 'hardware' | 'templates'>('designer')
const loading = ref(false)
const printerLoading = ref(false)
const queueLoading = ref(false)
const templatesLoading = ref(false)
const error = ref('')
const statusMessage = ref('')
const templateName = ref('')
const templateSearch = ref('')
const newTemplatesCount = ref(0)
const driverLoading = ref(false)
const printCopies = ref(1)
const printedCount = ref(0)
const snapToGrid = ref(true)
const gridSize = ref(5)
const selectedLayoutField = ref<LayoutFieldKey>('barcode')
const dragState = ref<{ field: LayoutFieldKey; startX: number; startY: number; originX: number; originY: number } | null>(null)
const fontFamilies = ['Arial', 'Helvetica', 'Times New Roman', 'sans-serif', 'serif', 'monospace', 'Consolas', 'Courier New', 'Verdana', 'Tahoma', 'Trebuchet MS', 'Georgia']
const layoutFields: Array<{ key: LayoutFieldKey; label: string }> = [
  { key: 'product_number', label: 'Product Number' },
  { key: 'product_name', label: 'Product Name' },
  { key: 'barcode', label: 'Barcode' },
  { key: 'qr_code', label: 'QR Code' },
  { key: 'item_type', label: 'Item Type' },
  { key: 'weight', label: 'Weight' },
  { key: 'quantity', label: 'Quantity' },
  { key: 'details', label: 'Details Group' },
  { key: 'notes', label: 'Notes' },
]

const selectedPrinter = computed(() => printers.value.find((printer) => printer.Name === form.printer_name))
const brotherInstalled = computed(() => printers.value.some((printer) => printer.Name.toLowerCase().includes('brother') || printer.DriverName.toLowerCase().includes('brother')))
const printerOnline = computed(() => {
  if (!selectedPrinter.value && !form.printer_name) return printers.value.some((printer) => printer.IsOnline ?? !printer.WorkOffline)
  if (!selectedPrinter.value) return false
  if (typeof selectedPrinter.value.IsOnline === 'boolean') return selectedPrinter.value.IsOnline
  return !selectedPrinter.value.WorkOffline
})
const statusLabel = computed(() => printerLoading.value ? 'SCANNING' : printerOnline.value ? 'ONLINE' : 'OFFLINE')
const statusClass = computed(() => printerLoading.value ? 'scanning' : printerOnline.value ? 'online' : 'offline')
const printerProfiles = [
  { id: 'brother_ql_raster', name: 'Brother QL Raster Direct', status: 'Recommended', note: 'Bypasses Windows layout/scaling by sending Brother QL raster commands through the Windows RAW queue. Use this for QL-820NWB to avoid Windows media-size mismatch.' },
  { id: 'brother_ql_windows', name: 'Brother QL via Windows Driver', status: 'Legacy', note: 'Uses the Windows/Brother driver. Can be affected by Windows Printing Preferences and media mismatch.' },
  { id: 'zebra_zpl', name: 'Zebra ZPL', status: 'Active', note: 'Direct ZPL output for Zebra GK/ZD/ZT/LP/TLP label printers through a Windows RAW printer queue.' },
  { id: 'epson_windows', name: 'Epson Label via Windows Driver', status: 'Active', note: 'Preset for Epson/Seiko label printers installed as normal Windows queues.' },
  { id: 'generic_windows', name: 'Generic Windows Printer', status: 'Active', note: 'Fallback path for installed Windows printers using standard driver printing and selected media.' },
]
const selectedProfile = computed(() => printerProfiles.find((profile) => profile.id === form.printer_profile) || printerProfiles[0])
const selectedMedia = computed(() => `${form.label_width_mm}mm x ${form.label_length_mm}mm`)
const selectedDriverMedia = computed(() => printerMedia.value.find((media) => media.name === form.driver_media_name))
const usefulMedia = computed(() => printerMedia.value.filter((media) => media.name.includes('62mm') || media.continuous).slice(0, 30))
const stuckJobs = computed(() => printJobs.value.filter((job) => isStuckJob(job)).length)
const normalizedPrintCopies = computed(() => Math.min(100, Math.max(1, Number(printCopies.value) || 1)))
const printProgressPercent = computed(() => Math.round((printedCount.value / normalizedPrintCopies.value) * 100))
const printProgressLabel = computed(() => `${printedCount.value} / ${normalizedPrintCopies.value} labels printed`)
const filteredTemplates = computed(() => {
  const query = templateSearch.value.trim().toLowerCase()
  if (!query) return templates.value
  return templates.value.filter((template) => {
    const fields = [
      template.name,
      template.label.product_number,
      template.label.product_name,
      template.label.barcode,
    ]
    return fields.some((field) => (field || '').toLowerCase().includes(query))
  })
})
const previewKey = computed(() => `${form.label_width_mm}-${form.label_length_mm}-${form.layout_preset}-${form.print_orientation}-${form.product_number}-${form.product_name}-${form.barcode}`)
const barcodeHeightPx = computed(() => Math.min(120, Math.max(28, Number(form.barcode_height_pct || 42) * 1.5)))
const previewSize = computed(() => {
  const isVertical = form.print_orientation === 'vertical'
  const physicalWidthMm = isVertical ? form.label_width_mm : form.label_length_mm
  const physicalHeightMm = isVertical ? form.label_length_mm : form.label_width_mm
  const scale = Math.min(9, 900 / Math.max(1, physicalWidthMm), 520 / Math.max(1, physicalHeightMm))
  return {
    width: Math.max(180, physicalWidthMm * scale),
    height: Math.max(120, physicalHeightMm * scale),
  }
})
const brotherPrintableWidthMm = 58.93
const printableSafeStyle = computed(() => {
  if (form.printer_profile !== 'brother_ql_windows' || form.label_width_mm > 62) return {}
  const safeHeightPct = Math.min(100, (brotherPrintableWidthMm / Math.max(1, form.label_width_mm)) * 100)
  const insetPct = Math.max(0, (100 - safeHeightPct) / 2)
  return {
    top: `${insetPct}%`,
    bottom: `${insetPct}%`,
  }
})
const previewScale = computed(() => {
  const isVertical = form.print_orientation === 'vertical'
  return {
    x: previewSize.value.width / Math.max(1, isVertical ? form.label_width_mm : form.label_length_mm),
    y: previewSize.value.height / Math.max(1, isVertical ? form.label_length_mm : form.label_width_mm),
  }
})
const labelTapeStyle = computed(() => {
  const isVertical = form.print_orientation === 'vertical'
  return {
    width: `${previewSize.value.width}px`,
    height: `${previewSize.value.height}px`,
    minHeight: `${previewSize.value.height}px`,
    gridTemplateColumns: isVertical || ['stacked', 'barcode_bottom'].includes(form.layout_preset) ? '1fr' : 'minmax(0, 58fr) 42fr',
    '--barcode-height': `${barcodeHeightPx.value}px`,
  }
})

function fieldStyle(field: LayoutFieldKey) {
  const offset = form.layout_offsets[field]
  const font = form.font_settings?.[field]
  return {
    transform: `translate(${offset.x * previewScale.value.x}px, ${offset.y * previewScale.value.y}px) scale(${offset.scale})`,
    transformOrigin: 'top left',
    fontFamily: font?.family || undefined,
    fontSize: font?.size ? `${font.size}px` : undefined,
    fontWeight: font?.bold ? '900' : undefined,
    fontStyle: font?.italic ? 'italic' : undefined,
  }
}

function objectStyle(field: LayoutFieldKey, xMm: number, yMm: number, widthMm: number, heightMm: number) {
  const base = fieldStyle(field)
  return {
    ...base,
    left: `${xMm * previewScale.value.x}px`,
    top: `${yMm * previewScale.value.y}px`,
    width: `${widthMm * previewScale.value.x}px`,
    height: `${heightMm * previewScale.value.y}px`,
  }
}

const layoutAnchors = computed<LayoutAnchors>(() => {
  const length = form.print_orientation === 'vertical' ? form.label_width_mm : form.label_length_mm
  const width = form.print_orientation === 'vertical' ? form.label_length_mm : form.label_width_mm
  const rightQrX = Math.max(4, length - 14)
  const bottomBarcodeY = Math.max(18, width - 18)

  const presets: Record<string, LayoutAnchors> = {
    compact_right: {
      product_number: { x: 4, y: 5, w: 20, h: 7 },
      product_name: { x: 4, y: Math.max(38, width - 10), w: Math.max(24, length - 22), h: 7 },
      details: { x: 4, y: 24, w: Math.max(28, length * 0.52), h: 12 },
      item_type: { x: 4, y: 24, w: Math.max(10, length * 0.18), h: 12 },
      weight: { x: Math.max(14, length * 0.22), y: 24, w: Math.max(10, length * 0.14), h: 12 },
      quantity: { x: Math.max(24, length * 0.36), y: 24, w: Math.max(8, length * 0.10), h: 12 },
      notes: { x: Math.max(30, length * 0.55), y: 24, w: Math.max(26, length * 0.40), h: 14 },
      barcode: { x: Math.max(10, length * 0.22), y: Math.max(34, width - 19), w: Math.max(28, length * 0.54), h: 11 },
      qr_code: { x: rightQrX, y: 5, w: 10, h: 10 },
    },
    barcode_left: {
      product_number: { x: Math.max(24, length * 0.42), y: 5, w: 24, h: 7 },
      product_name: { x: Math.max(24, length * 0.42), y: Math.max(38, width - 10), w: Math.max(22, length * 0.50), h: 7 },
      details: { x: Math.max(24, length * 0.42), y: 24, w: Math.max(28, length * 0.44), h: 12 },
      item_type: { x: Math.max(24, length * 0.42), y: 24, w: Math.max(10, length * 0.16), h: 12 },
      weight: { x: Math.max(34, length * 0.56), y: 24, w: Math.max(10, length * 0.14), h: 12 },
      quantity: { x: Math.max(44, length * 0.70), y: 24, w: Math.max(8, length * 0.10), h: 12 },
      notes: { x: Math.max(36, length * 0.58), y: 36, w: Math.max(24, length * 0.38), h: 14 },
      barcode: { x: 4, y: 20, w: Math.max(20, length * 0.35), h: 11 },
      qr_code: { x: 4, y: Math.max(40, width - 18), w: 10, h: 10 },
    },
    stacked: {
      product_number: { x: 4, y: 5, w: Math.max(24, length * 0.42), h: 7 },
      product_name: { x: 4, y: 14, w: Math.max(34, length * 0.70), h: 7 },
      details: { x: 4, y: 25, w: Math.max(32, length * 0.52), h: 12 },
      item_type: { x: 4, y: 25, w: Math.max(10, length * 0.18), h: 12 },
      weight: { x: Math.max(14, length * 0.22), y: 25, w: Math.max(10, length * 0.14), h: 12 },
      quantity: { x: Math.max(24, length * 0.36), y: 25, w: Math.max(8, length * 0.10), h: 12 },
      notes: { x: Math.max(30, length * 0.54), y: 25, w: Math.max(26, length * 0.40), h: 14 },
      barcode: { x: Math.max(4, length * 0.18), y: Math.max(39, width - 20), w: Math.max(34, length * 0.62), h: 11 },
      qr_code: { x: rightQrX, y: 5, w: 10, h: 10 },
    },
    barcode_bottom: {
      product_number: { x: 4, y: 5, w: Math.max(24, length * 0.42), h: 7 },
      product_name: { x: 4, y: 14, w: Math.max(34, length * 0.70), h: 7 },
      details: { x: 4, y: 25, w: Math.max(32, length * 0.52), h: 12 },
      item_type: { x: 4, y: 25, w: Math.max(10, length * 0.18), h: 12 },
      weight: { x: Math.max(14, length * 0.22), y: 25, w: Math.max(10, length * 0.14), h: 12 },
      quantity: { x: Math.max(24, length * 0.36), y: 25, w: Math.max(8, length * 0.10), h: 12 },
      notes: { x: Math.max(30, length * 0.54), y: 25, w: Math.max(26, length * 0.40), h: 14 },
      barcode: { x: 4, y: bottomBarcodeY, w: Math.max(44, length - 8), h: 11 },
      qr_code: { x: rightQrX, y: 5, w: 10, h: 10 },
    },
  }

  return presets[form.layout_preset] || presets.compact_right
})
const barcodeObjectStyle = computed(() => {
  const anchor = layoutAnchors.value.barcode
  return objectStyle('barcode', anchor.x, anchor.y, anchor.w, anchor.h)
})
const qrObjectStyle = computed(() => {
  const anchor = layoutAnchors.value.qr_code
  return objectStyle('qr_code', anchor.x, anchor.y, anchor.w, anchor.h)
})

const barcodeStyle = computed(() => ({
  height: `${barcodeHeightPx.value}px`,
}))

const qrCells = computed(() => {
  const source = `${form.barcode || form.product_number || 'LABEL'}|${form.product_name}`
  return Array.from({ length: 121 }, (_, index) => {
    const charCode = source.charCodeAt(index % source.length) || 31
    return ((charCode + index * 7 + Math.floor(index / 11) * 13) % 5) < 2
  })
})

function snapValue(value: number) {
  if (!snapToGrid.value) return value
  const size = Math.min(25, Math.max(1, Number(gridSize.value) || 5)) / 10
  return Number((Math.round(value / size) * size).toFixed(2))
}

function nudgeField(dx: number, dy: number) {
  const field = form.layout_offsets[selectedLayoutField.value]
  field.x = snapValue(field.x + dx / 2)
  field.y = snapValue(field.y + dy / 2)
}

function scaleField(delta: number) {
  const field = form.layout_offsets[selectedLayoutField.value]
  field.scale = Math.min(1.5, Math.max(0.65, Number((field.scale + delta).toFixed(2))))
}

function startDrag(field: LayoutFieldKey, event: PointerEvent) {
  selectedLayoutField.value = field
  const offset = form.layout_offsets[field]
  dragState.value = { field, startX: event.clientX, startY: event.clientY, originX: offset.x, originY: offset.y }
  window.addEventListener('pointermove', dragField)
  window.addEventListener('pointerup', stopDrag, { once: true })
}

function dragField(event: PointerEvent) {
  if (!dragState.value) return
  const offset = form.layout_offsets[dragState.value.field]
  offset.x = snapValue(dragState.value.originX + ((event.clientX - dragState.value.startX) / previewScale.value.x))
  offset.y = snapValue(dragState.value.originY + ((event.clientY - dragState.value.startY) / previewScale.value.y))
}

function stopDrag() {
  dragState.value = null
  window.removeEventListener('pointermove', dragField)
}

watch(printCopies, () => {
  if (loading.value) return
  printedCount.value = 0
})

function resetField() {
  form.layout_offsets[selectedLayoutField.value] = { x: 0, y: 0, scale: 1 }
}

function resetLayoutOffsets() {
  for (const field of layoutFields) {
    form.layout_offsets[field.key] = { x: 0, y: 0, scale: 1 }
  }
}

function ensureLayoutOptions() {
  if (!form.layout_offsets) form.layout_offsets = {} as Record<LayoutFieldKey, LayoutOffset>
  if (!form.font_settings) form.font_settings = {} as Record<LayoutFieldKey, FontSetting>
  if (!form.display_options) {
    form.display_options = { product_number: true, product_name: true, barcode: true, quantity: true, item_type: true, weight: true, notes: true }
  }
  for (const field of layoutFields) {
    if (!form.layout_offsets[field.key]) {
      form.layout_offsets[field.key] = { x: 0, y: 0, scale: 1 }
    }
    if (!form.font_settings[field.key]) {
      form.font_settings[field.key] = { family: field.key === 'barcode' ? 'Consolas' : 'Arial', size: field.key === 'product_number' ? 27 : 9, bold: field.key === 'product_number' || field.key === 'product_name' || field.key === 'barcode', italic: false }
    }
  }
  if (!form.barcode_height_pct) form.barcode_height_pct = 42
}

function ensureLayoutOffsets() {
  ensureLayoutOptions()
}

const code128Patterns = [
  '212222','222122','222221','121223','121322','131222','122213','122312','132212','221213','221312','231212','112232','122132','122231','113222','123122','123221','223211','221132','221231','213212','223112','312131','311222','321122','321221','312212','322112','322211','212123','212321','232121','111323','131123','131321','112313','132113','132311','211313','231113','231311','112133','112331','132131','113123','113321','133121','313121','211331','231131','213113','213311','213131','311123','311321','331121','312113','312311','332111','314111','221411','431111','111224','111422','121124','121421','141122','141221','112214','112412','122114','122411','142112','142211','241211','221114','413111','241112','134111','111242','121142','121241','114212','124112','124211','411212','421112','421211','212141','214121','412121','111143','111341','131141','114113','114311','411113','411311','113141','114131','311141','411131','211412','211214','211232','2331112'
]

const barcodeBars = computed(() => {
  const source = (form.barcode || form.product_number || '123456789012').replace(/[^\x20-\x7E]/g, ' ')
  const values = [104, ...Array.from(source).map((char) => char.charCodeAt(0) - 32)]
  const checksum = values.reduce((sum, value, index) => sum + (index === 0 ? value : value * index), 0) % 103
  const encoded = [...values, checksum, 106]
  return encoded.flatMap((value) => Array.from(code128Patterns[value]).map(Number))
})

async function loadPrinters() {
  printerLoading.value = true
  error.value = ''

  try {
    const res = await fetch(`${API_BASE}/printers`)
    const data = await res.json()

    if (data.status !== 'ok') {
      throw new Error(data.error || 'Could not load printers')
    }

    const list = Array.isArray(data.printers) ? data.printers : data.printers ? [data.printers] : []
    printers.value = list

    const brother = list.find((printer: Printer) => printer.Name === 'Brother QL-820NWB')
      || list.find((printer: Printer) => printer.Name.toLowerCase().includes('brother') || printer.DriverName.toLowerCase().includes('brother'))

    if (brother) {
      form.printer_name = brother.Name
    } else if (!form.printer_name && list.length > 0) {
      form.printer_name = list[0].Name
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown printer error'
  } finally {
    printerLoading.value = false
  }
}

function normalizeJobs(jobs: PrintJob[] | PrintJob | null | undefined) {
  if (!jobs) return []
  return Array.isArray(jobs) ? jobs : [jobs]
}

function isStuckJob(job: PrintJob) {
  return /error|offline|paused|retained|blocked|deleting/i.test(job.JobStatus || '')
}

async function loadPrintQueue() {
  queueLoading.value = true
  error.value = ''

  try {
    const params = new URLSearchParams()
    if (form.printer_name) params.set('printer_name', form.printer_name)
    const res = await fetch(`${API_BASE}/print-queue?${params.toString()}`)
    const data = await res.json()

    if (data.status !== 'ok') {
      throw new Error(data.error || 'Could not load print queue')
    }

    printJobs.value = normalizeJobs(data.jobs)
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown print queue error'
  } finally {
    queueLoading.value = false
  }
}

async function clearPrintQueue(jobId?: number) {
  queueLoading.value = true
  error.value = ''

  try {
    const res = await fetch(`${API_BASE}/print-queue/clear`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ printer_name: form.printer_name, job_id: jobId }),
    })
    const data = await res.json()

    if (data.status !== 'ok') {
      throw new Error(data.error || 'Could not clear print queue')
    }

    statusMessage.value = jobId ? 'Print job removed.' : 'Print queue cleared.'
    await loadPrintQueue()
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown clear queue error'
  } finally {
    queueLoading.value = false
  }
}

async function loadTemplates() {
  templatesLoading.value = true
  error.value = ''

  try {
    const res = await fetch(`${API_BASE}/templates`)
    const data = await res.json()
    if (data.status !== 'ok') throw new Error(data.error || 'Could not load templates')
    templates.value = Array.isArray(data.templates) ? data.templates : []
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown template error'
  } finally {
    templatesLoading.value = false
  }
}

async function saveCurrentTemplate() {
  const name = templateName.value.trim() || form.product_name || form.product_number || 'Product Label Template'
  templatesLoading.value = true
  error.value = ''

  try {
    const res = await fetch(`${API_BASE}/templates`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, label: form }),
    })
    const data = await res.json()
    if (data.status !== 'ok') throw new Error(data.error || 'Could not save template')
    templateName.value = ''
    statusMessage.value = `Template saved: ${name}`
    if (activeTab.value !== 'templates') {
      newTemplatesCount.value += 1
    }
    await loadTemplates()
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown save template error'
  } finally {
    templatesLoading.value = false
  }
}

function loadTemplate(template: LabelTemplate) {
  Object.assign(form, template.label)
  ensureLayoutOffsets()
  activeTab.value = 'designer'
  statusMessage.value = `Loaded template: ${template.name}`
}

async function deleteTemplate(template: LabelTemplate) {
  const ok = window.confirm(`Delete template "${template.name}"?`)
  if (!ok) return
  templatesLoading.value = true
  error.value = ''

  try {
    const res = await fetch(`${API_BASE}/templates/${encodeURIComponent(template.id)}`, { method: 'DELETE' })
    const text = await res.text()
    const data = text ? JSON.parse(text) : { status: res.ok ? 'ok' : 'error' }
    if (!res.ok || data.status !== 'ok') throw new Error(data.error || 'Could not delete template')
    statusMessage.value = `Deleted template: ${template.name}`
    await loadTemplates()
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown delete template error'
  } finally {
    templatesLoading.value = false
  }
}

async function loadPrinterMedia() {
  if (!form.printer_name) return
  try {
    const params = new URLSearchParams({ printer_name: form.printer_name })
    const res = await fetch(`${API_BASE}/printer-media?${params.toString()}`)
    const data = await res.json()
    if (data.status !== 'ok') throw new Error(data.error || 'Could not load printer media')
    printerMedia.value = Array.isArray(data.media) ? data.media : []
    if (!printerMedia.value.some((media) => media.name === form.driver_media_name)) {
      const continuous62 = printerMedia.value.find((media) => media.name === '62mm')
      form.driver_media_name = continuous62?.name || printerMedia.value[0]?.name || '62mm'
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown printer media error'
  }
}

function applyDriverMedia() {
  const media = selectedDriverMedia.value
  if (!media) return
  form.label_width_mm = Math.round(media.width_mm)
  if (!media.continuous) {
    form.label_length_mm = Math.round(media.height_mm)
  }
}

async function openTab(tab: 'designer' | 'queue' | 'hardware' | 'templates') {
  activeTab.value = tab
  if (tab === 'queue') await loadPrintQueue()
  if (tab === 'hardware') {
    await loadPrinters()
    await loadPrinterMedia()
  }
  if (tab === 'templates') {
    newTemplatesCount.value = 0
    await loadTemplates()
  }
}

async function runDriverAction(action: 'install' | 'uninstall') {
  const label = action === 'install' ? 'install/update' : 'uninstall'
  const ok = window.confirm(`This will launch the Brother driver ${label} tool and may show a Windows administrator/UAC prompt. Continue?`)
  if (!ok) return

  driverLoading.value = true
  error.value = ''

  try {
    const res = await fetch(`${API_BASE}/driver/${action}`, { method: 'POST' })
    const data = await res.json()

    if (data.status === 'error') {
      throw new Error(data.error || `Could not ${action} driver`)
    }

    statusMessage.value = action === 'install' ? 'Brother driver installer launched.' : 'Brother driver uninstaller launched.'
    setTimeout(async () => {
      await loadPrinters()
      await loadPrinterMedia()
    }, 1500)
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown driver action error'
  } finally {
    driverLoading.value = false
  }
}

async function generatePreviewImageDataUrl() {
  const scale = 2
  const width = Math.max(1, Math.round(previewSize.value.width * scale))
  const height = Math.max(1, Math.round(previewSize.value.height * scale))
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext('2d')
  if (!ctx) return ''

  const sx = previewScale.value.x * scale
  const sy = previewScale.value.y * scale
  const px = (mm: number) => mm * sx
  const py = (mm: number) => mm * sy
  const anchor = layoutAnchors.value
  const fieldX = (field: LayoutFieldKey) => px(anchor[field].x + form.layout_offsets[field].x)
  const fieldY = (field: LayoutFieldKey) => py(anchor[field].y + form.layout_offsets[field].y)
  const fieldW = (field: LayoutFieldKey) => px(anchor[field].w)
  const fieldH = (field: LayoutFieldKey) => py(anchor[field].h)

  function applyFont(field: LayoutFieldKey, fallbackSize: number) {
    const font = form.font_settings[field]
    const size = (font?.size || fallbackSize) * scale * form.layout_offsets[field].scale
    const style = font?.italic ? 'italic ' : ''
    const weight = font?.bold ? '900 ' : '400 '
    const family = font?.family || 'Arial'
    ctx.font = `${style}${weight}${size}px ${family}`
    ctx.fillStyle = '#020617'
    ctx.textBaseline = 'top'
  }

  function clipText(text: string, x: number, y: number, w: number, h: number, field: LayoutFieldKey, size: number) {
    ctx.save()
    ctx.beginPath()
    ctx.rect(x, y, w, h)
    ctx.clip()
    applyFont(field, size)
    ctx.fillText(text, x, y)
    ctx.restore()
  }

  ctx.fillStyle = '#ffffff'
  ctx.fillRect(0, 0, width, height)

  if (form.display_options.product_number) {
    clipText(form.product_number || 'SKU-000', fieldX('product_number'), fieldY('product_number'), fieldW('product_number'), fieldH('product_number'), 'product_number', 27)
  }
  if (form.display_options.product_name) {
    clipText(form.product_name || 'Product name', fieldX('product_name'), fieldY('product_name'), fieldW('product_name'), fieldH('product_name'), 'product_name', 14)
  }

  if (form.display_options.item_type) {
    applyFont('item_type', 9)
    const x = fieldX('item_type')
    const y = fieldY('item_type')
    ctx.fillText('ITEM TYPE', x, y)
    ctx.fillText(form.item_type || 'TYPE', x, y + py(4))
  }
  if (form.display_options.weight) {
    applyFont('weight', 9)
    const x = fieldX('weight')
    const y = fieldY('weight')
    ctx.fillText('WEIGHT', x, y)
    ctx.fillText(form.weight || '0 KG', x, y + py(4))
  }
  if (form.display_options.quantity) {
    applyFont('quantity', 9)
    const x = fieldX('quantity')
    const y = fieldY('quantity')
    ctx.fillText('QTY', x, y)
    ctx.fillText(String(form.quantity), x, y + py(4))
  }

  if (form.display_options.notes) {
    applyFont('notes', 9)
    const nx = fieldX('notes')
    const ny = fieldY('notes')
    ctx.fillText('NOTES', nx, ny)
    const noteLines = (form.notes || 'NONE').split('\n').slice(0, 3)
    noteLines.forEach((line, index) => ctx.fillText(line, nx, ny + py(4 + index * 4)))
  }

  if (form.display_options.barcode) {
    const bx = fieldX('barcode')
    const by = fieldY('barcode')
    const bw = fieldW('barcode') * form.layout_offsets.barcode.scale
    const bh = barcodeHeightPx.value * scale * form.layout_offsets.barcode.scale
    const total = barcodeBars.value.reduce((sum, bar) => sum + bar, 0)
    let x = bx
    ctx.fillStyle = '#020617'
    barcodeBars.value.forEach((bar, index) => {
      const barWidth = Math.max(1, (bar / total) * bw)
      if (index % 2 === 0) ctx.fillRect(x, by, barWidth, bh)
      x += barWidth
    })
    applyFont('barcode', 8)
    ctx.textAlign = 'center'
    ctx.fillText(form.barcode || '123456789012', bx + bw / 2, by + bh + py(1))
    ctx.textAlign = 'left'
  }

  if (form.show_qr) {
    const qx = fieldX('qr_code')
    const qy = fieldY('qr_code')
    const cell = Math.max(1, fieldW('qr_code') / 13 * form.layout_offsets.qr_code.scale)
    ctx.fillStyle = '#ffffff'
    ctx.fillRect(qx, qy, cell * 13, cell * 13)
    ctx.fillStyle = '#020617'
    qrCells.value.forEach((filled, index) => {
      if (!filled) return
      const colIndex = index % 11
      const rowIndex = Math.floor(index / 11)
      ctx.fillRect(qx + cell + colIndex * cell, qy + cell + rowIndex * cell, cell, cell)
    })
  }

  return canvas.toDataURL('image/png')
}

async function submitLabel() {
  loading.value = true
  error.value = ''
  statusMessage.value = ''
  printedCount.value = 0
  printCopies.value = normalizedPrintCopies.value

  try {
    if (form.printer_profile === 'brother_ql_windows' && form.printer_name.toLowerCase().includes('brother')) {
      form.printer_profile = 'brother_ql_raster'
      statusMessage.value = 'Switched to Brother QL Raster Direct to avoid Windows media-size mismatch.'
    }

    const totalCopies = normalizedPrintCopies.value
    const previewImageDataUrl = await generatePreviewImageDataUrl()
    if (form.printer_profile === 'brother_ql_raster' && !previewImageDataUrl) {
      throw new Error('Could not generate preview image for Brother QL Raster Direct')
    }

    for (let copy = 1; copy <= totalCopies; copy += 1) {
      const payload = { ...form, print: true, preview_image_data_url: previewImageDataUrl }
      const res = await fetch(`${API_BASE}/label`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      const text = await res.text()

      if (!res.ok) {
        throw new Error(text || `HTTP ${res.status}`)
      }

      const data = JSON.parse(text)
      if (data.print?.status === 'error') {
        const message = data.print.details?.error || data.print.error || 'Printer returned an error'
        throw new Error(message)
      }

      printedCount.value = copy
      statusMessage.value = `Printing labels: ${copy} / ${totalCopies}`
    }

    statusMessage.value = totalCopies === 1 ? 'Label sent to printer.' : `${totalCopies} labels sent to printer.`
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown error'
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await loadPrinters()
  await loadPrinterMedia()
})

onUnmounted(() => {
  window.removeEventListener('pointermove', dragField)
})
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <div>
        <div class="brand">LabelsControlPro</div>
        <div class="station">STATION 04-B / BROTHER LABEL CONTROL</div>
      </div>

      <div class="top-actions">
        <div class="printer-pill" :class="statusClass">
          <span class="dot"></span>
          {{ statusLabel }}
        </div>
        <button class="ghost" :disabled="printerLoading" type="button" @click="loadPrinters">
          {{ printerLoading ? 'SCANNING...' : 'RESCAN HARDWARE' }}
        </button>
        <button class="ghost" :disabled="templatesLoading" type="button" @click="saveCurrentTemplate">
          SAVE TEMPLATE
        </button>
        <button class="primary" :disabled="loading" type="button" @click="submitLabel">
          {{ loading ? 'PRINTING...' : 'PRINT NOW' }}
        </button>
      </div>
    </header>

    <aside class="sidebar">
      <div class="side-title">OPERATIONS</div>
      <nav>
        <button :class="{ active: activeTab === 'designer' }" type="button" @click="openTab('designer')">Label Designer</button>
        <button :class="{ active: activeTab === 'queue' }" type="button" @click="openTab('queue')">Print Queue <b v-if="stuckJobs">{{ stuckJobs }}</b></button>
        <button :class="{ active: activeTab === 'hardware' }" type="button" @click="openTab('hardware')">Printer Settings</button>
        <button :class="{ active: activeTab === 'templates' }" type="button" @click="openTab('templates')">Templates <b v-if="newTemplatesCount">{{ newTemplatesCount }}</b></button>
      </nav>

      <div class="status-card">
        <div class="status-row">
          <span>Print Status</span>
          <strong>{{ printProgressPercent }}%</strong>
        </div>
        <div class="meter"><span :style="{ width: `${printProgressPercent}%` }"></span></div>
        <small>{{ printProgressLabel }}</small>
        <small>{{ selectedPrinter?.Name || 'No printer selected' }}</small>
        <small v-if="selectedPrinter">{{ selectedPrinter.StatusDetail || selectedPrinter.PrinterStatus }}</small>
        <small v-if="!brotherInstalled" class="warn">Brother printer not detected in Windows</small>
      </div>
    </aside>

    <main class="workbench" :class="{ 'designer-workbench': activeTab === 'designer' }">
      <section v-if="activeTab === 'designer'" class="panel form-panel">
        <div class="panel-head">
          <h1>Parameters</h1>
          <span>REAL-TIME INPUT</span>
        </div>

        <form class="form-grid" @submit.prevent="submitLabel">
          <label>
            Product Number
            <input v-model="form.product_number" required placeholder="SKU-001" />
          </label>

          <label>
            Product Name
            <input v-model="form.product_name" required placeholder="Product name" />
          </label>

          <label>
            Quantity
            <input v-model.number="form.quantity" required min="1" type="number" />
          </label>

          <label>
            Weight
            <input v-model="form.weight" placeholder="1.450 KG" />
          </label>

          <label class="full">
            Item Type / Additional Data
            <input v-model="form.item_type" placeholder="Type, category, batch, location, etc." />
          </label>

          <label class="full">
            Barcode
            <input v-model="form.barcode" required placeholder="123456789012" />
          </label>

          <label class="full">
            Notes
            <textarea v-model="form.notes" rows="3" placeholder="Extra text for label"></textarea>
          </label>

          <div class="print-settings full">
            <div class="template-save-row">
              <label>
                Template Name
                <input v-model="templateName" placeholder="e.g. Brass Coupler Compact 62x60" />
              </label>
              <button class="ghost" :disabled="templatesLoading" type="button" @click="saveCurrentTemplate">
                Save Template
              </button>
            </div>

            <div class="setting-line">
              <span class="density-value">{{ form.driver_media_name || selectedMedia }} / CUT {{ form.label_length_mm }}mm / DENSITY {{ form.print_density }}/10</span>
              <span class="density-value">PRINT BUTTON SENDS DIRECTLY TO PRINTER</span>
            </div>

            <div class="media-grid">
              <label>
                Label Width mm
                <input v-model.number="form.label_width_mm" min="12" max="62" step="1" type="number" />
              </label>
              <label>
                Label Length mm
                <input v-model.number="form.label_length_mm" min="29" max="300" step="1" type="number" />
              </label>
              <label>
                Printer Driver Media
                <select v-model="form.driver_media_name" @change="applyDriverMedia">
                  <option value="62mm">62mm continuous tape / custom cut length</option>
                  <option v-for="media in usefulMedia" :key="`${media.name}-${media.raw_kind}`" :value="media.name">
                    {{ media.name }} {{ media.continuous ? '/ continuous' : '' }}
                  </option>
                </select>
              </label>
              <label v-if="form.printer_profile === 'zebra_zpl'">
                Zebra DPI
                <select v-model.number="form.zpl_dpi">
                  <option :value="203">203 DPI</option>
                  <option :value="300">300 DPI</option>
                </select>
              </label>
              <label>
                Print Orientation
                <select v-model="form.print_orientation">
                  <option value="horizontal">Horizontal / landscape</option>
                  <option value="vertical">Vertical / portrait</option>
                </select>
              </label>
              <label>
                Layout Preset
                <select v-model="form.layout_preset">
                  <option value="compact_right">Compact: barcode right</option>
                  <option value="barcode_left">Compact: barcode left</option>
                  <option value="stacked">Stacked: barcode under title</option>
                  <option value="barcode_bottom">Wide: full-width barcode</option>
                </select>
              </label>
            </div>

            <div class="layout-tuner">
              <label>
                Move Field
                <select v-model="selectedLayoutField">
                  <option v-for="field in layoutFields" :key="field.key" :value="field.key">{{ field.label }}</option>
                </select>
              </label>
              <label>
                Font
                <select v-model="form.font_settings[selectedLayoutField].family">
                  <option v-for="font in fontFamilies" :key="font" :value="font">{{ font }}</option>
                </select>
              </label>
              <label>
                Font Size
                <input v-model.number="form.font_settings[selectedLayoutField].size" min="6" max="48" type="number" />
              </label>
              <label class="check-row">
                <input v-model="form.font_settings[selectedLayoutField].bold" type="checkbox" /> Bold
              </label>
              <label class="check-row">
                <input v-model="form.font_settings[selectedLayoutField].italic" type="checkbox" /> Italic
              </label>
              <label>
                Barcode Height: {{ form.barcode_height_pct }}%
                <input v-model.number="form.barcode_height_pct" min="20" max="80" step="1" type="range" />
              </label>
              <label>
                Snap Grid px
                <input v-model.number="gridSize" min="1" max="25" type="number" />
              </label>
              <label class="check-row">
                <input v-model="snapToGrid" type="checkbox" /> Snap to grid
              </label>
              <label class="check-row">
                <input v-model="form.show_qr" type="checkbox" /> Show QR code
              </label>
              <div class="optional-fields full">
                <label><input v-model="form.display_options.product_number" type="checkbox" /> SKU</label>
                <label><input v-model="form.display_options.product_name" type="checkbox" /> Name</label>
                <label><input v-model="form.display_options.barcode" type="checkbox" /> Barcode</label>
                <label><input v-model="form.display_options.quantity" type="checkbox" /> Quantity</label>
                <label><input v-model="form.display_options.item_type" type="checkbox" /> Item Type</label>
                <label><input v-model="form.display_options.weight" type="checkbox" /> Weight</label>
                <label><input v-model="form.display_options.notes" type="checkbox" /> Notes</label>
              </div>
              <div class="nudge-pad full">
                <button class="ghost" type="button" @click="nudgeField(0, -2)">UP</button>
                <button class="ghost" type="button" @click="nudgeField(-2, 0)">LEFT</button>
                <button class="ghost" type="button" @click="nudgeField(2, 0)">RIGHT</button>
                <button class="ghost" type="button" @click="nudgeField(0, 2)">DOWN</button>
                <button class="ghost" type="button" @click="scaleField(-0.05)">SIZE -</button>
                <button class="ghost" type="button" @click="scaleField(0.05)">SIZE +</button>
                <button class="ghost" type="button" @click="resetField">RESET FIELD</button>
                <button class="ghost danger" type="button" @click="resetLayoutOffsets">RESET LAYOUT</button>
              </div>
            </div>

            <label>
              Windows Printer
              <select v-model="form.printer_name" @change="loadPrinterMedia">
                <option value="">Use default printer</option>
                <option v-for="printer in printers" :key="printer.Name" :value="printer.Name">
                  {{ printer.Name }} / {{ printer.DriverName }} / {{ printer.StatusDetail || printer.PrinterStatus }}
                </option>
              </select>
            </label>

            <label>
              Print Density Control
              <input v-model.number="form.print_density" max="10" min="1" type="range" />
            </label>

            <label>
              Labels To Print
              <input v-model.number="printCopies" max="100" min="1" type="number" />
            </label>

            <button class="primary full" :disabled="loading" type="button" @click="submitLabel">
              {{ loading ? `PRINTING ${printedCount} / ${normalizedPrintCopies}` : 'PRINT NOW' }}
            </button>
          </div>
        </form>

        <p v-if="error" class="error">{{ error }}</p>
        <p v-if="statusMessage" class="success">{{ statusMessage }}</p>
      </section>

      <section v-if="activeTab === 'designer'" class="panel preview-panel">
        <div class="panel-head preview-head">
          <div>
            <h1>Real-Time Preview</h1>
            <span>BROTHER QL / {{ selectedMedia }} SIMULATION</span>
          </div>
          <div class="preview-meta">SCALE 1:1</div>
        </div>

        <div class="canvas-grid">
          <div :key="previewKey" class="label-tape" :class="[form.layout_preset, form.print_orientation]" :style="labelTapeStyle">
            <div class="tape-meta top">Brother QL / {{ form.driver_media_name || selectedMedia }} / {{ form.print_orientation }} / CODE128</div>
            <div v-if="form.printer_profile === 'brother_ql_windows'" class="printable-safe-area" :style="printableSafeStyle"></div>

            <div
              v-if="form.display_options.product_number"
              class="label-object sku draggable-field"
              :class="{ selected: selectedLayoutField === 'product_number' }"
              :style="objectStyle('product_number', layoutAnchors.product_number.x, layoutAnchors.product_number.y, layoutAnchors.product_number.w, layoutAnchors.product_number.h)"
              @pointerdown.stop.prevent="startDrag('product_number', $event)"
            >{{ form.product_number || 'SKU-000' }}</div>

            <div
              v-if="form.display_options.product_name"
              class="label-object product draggable-field"
              :class="{ selected: selectedLayoutField === 'product_name' }"
              :style="objectStyle('product_name', layoutAnchors.product_name.x, layoutAnchors.product_name.y, layoutAnchors.product_name.w, layoutAnchors.product_name.h)"
              @pointerdown.stop.prevent="startDrag('product_name', $event)"
            >{{ form.product_name || 'Product name' }}</div>

            <div
              v-if="form.display_options.item_type"
              class="label-object label-data single-field draggable-field"
              :class="{ selected: selectedLayoutField === 'item_type' }"
              :style="objectStyle('item_type', layoutAnchors.item_type.x, layoutAnchors.item_type.y, layoutAnchors.item_type.w, layoutAnchors.item_type.h)"
              @pointerdown.stop.prevent="startDrag('item_type', $event)"
            >
              <div><span>ITEM TYPE</span><strong>{{ form.item_type || 'TYPE' }}</strong></div>
            </div>

            <div
              v-if="form.display_options.weight"
              class="label-object label-data single-field draggable-field"
              :class="{ selected: selectedLayoutField === 'weight' }"
              :style="objectStyle('weight', layoutAnchors.weight.x, layoutAnchors.weight.y, layoutAnchors.weight.w, layoutAnchors.weight.h)"
              @pointerdown.stop.prevent="startDrag('weight', $event)"
            >
              <div><span>WEIGHT</span><strong>{{ form.weight || '0 KG' }}</strong></div>
            </div>

            <div
              v-if="form.display_options.quantity"
              class="label-object label-data single-field draggable-field"
              :class="{ selected: selectedLayoutField === 'quantity' }"
              :style="objectStyle('quantity', layoutAnchors.quantity.x, layoutAnchors.quantity.y, layoutAnchors.quantity.w, layoutAnchors.quantity.h)"
              @pointerdown.stop.prevent="startDrag('quantity', $event)"
            >
              <div><span>QTY</span><strong>{{ form.quantity }}</strong></div>
            </div>

            <div
              v-if="form.display_options.notes"
              class="label-object label-data notes-object draggable-field"
              :class="{ selected: selectedLayoutField === 'notes' }"
              :style="objectStyle('notes', layoutAnchors.notes.x, layoutAnchors.notes.y, layoutAnchors.notes.w, layoutAnchors.notes.h)"
              @pointerdown.stop.prevent="startDrag('notes', $event)"
            >
              <div>
                <span>NOTES</span>
                <strong>{{ form.notes || 'NONE' }}</strong>
              </div>
            </div>

            <div
              v-if="form.display_options.barcode"
              class="label-object barcode-box draggable-field"
              :class="{ selected: selectedLayoutField === 'barcode' }"
              :style="barcodeObjectStyle"
              @pointerdown.stop.prevent="startDrag('barcode', $event)"
            >
              <div class="barcode" :style="barcodeStyle">
                <i
                  v-for="(bar, index) in barcodeBars"
                  :key="index"
                  :style="{ width: `${bar}px`, height: '100%' }"
                ></i>
              </div>
              <div class="barcode-text">{{ form.barcode || '123456789012' }}</div>
            </div>

            <div v-if="form.show_qr" class="label-object qr-code draggable-field" :class="{ selected: selectedLayoutField === 'qr_code' }" :style="qrObjectStyle" title="QR preview" @pointerdown.stop.prevent="startDrag('qr_code', $event)">
              <i v-for="(filled, index) in qrCells" :key="index" :class="{ filled }"></i>
            </div>
          </div>
        </div>


        <div class="design-guide">
          <div>
            <span>PRINT SAFE</span>
            <strong>62mm continuous / app controls cut length</strong>
          </div>
          <div>
            <span>POSITIONING</span>
            <strong>Use Layout Tuning arrows to nudge fields safely</strong>
          </div>
          <div>
            <span>LAYOUT</span>
            <strong>Keep text inside preview safe area before printing</strong>
          </div>
        </div>
      </section>

      <section v-if="activeTab === 'queue'" class="panel queue-panel wide-panel">
        <div class="panel-head">
          <div>
            <h1>Print Queue</h1>
            <span>WINDOWS JOB MONITOR / STUCK JOB CONTROL</span>
          </div>
          <div class="queue-actions">
            <button class="ghost" :disabled="queueLoading" type="button" @click="loadPrintQueue">
              {{ queueLoading ? 'REFRESHING...' : 'REFRESH QUEUE' }}
            </button>
            <button class="primary danger" :disabled="queueLoading || printJobs.length === 0" type="button" @click="clearPrintQueue()">
              CLEAR ALL JOBS
            </button>
          </div>
        </div>

        <div class="queue-summary">
          <div class="mini-card">
            <span>PRINTER</span>
            <strong>{{ form.printer_name || 'Default printer' }}</strong>
          </div>
          <div class="mini-card">
            <span>TOTAL JOBS</span>
            <strong>{{ printJobs.length }}</strong>
          </div>
          <div class="mini-card" :class="stuckJobs ? 'offline' : 'online'">
            <span>STUCK / ATTENTION</span>
            <strong>{{ stuckJobs }}</strong>
          </div>
        </div>

        <div v-if="printJobs.length === 0" class="empty-state">
          No print jobs found for this printer.
        </div>

        <div v-else class="queue-table-wrap">
          <table class="queue-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Document</th>
                <th>Status</th>
                <th>Submitted</th>
                <th>Size</th>
                <th>Pages</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="job in printJobs" :key="job.ID" :class="{ stuck: isStuckJob(job) }">
                <td>{{ job.ID }}</td>
                <td>{{ job.DocumentName }}</td>
                <td><strong>{{ job.JobStatus || 'Unknown' }}</strong></td>
                <td>{{ job.SubmittedTime || '-' }}</td>
                <td>{{ job.Size || 0 }}</td>
                <td>{{ job.PagesPrinted || 0 }} / {{ job.TotalPages || 0 }}</td>
                <td>
                  <button class="ghost danger" :disabled="queueLoading" type="button" @click="clearPrintQueue(job.ID)">
                    REMOVE
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p v-if="error" class="error">{{ error }}</p>
        <p v-if="statusMessage" class="success">{{ statusMessage }}</p>
      </section>

      <section v-if="activeTab === 'hardware'" class="panel queue-panel wide-panel">
        <div class="panel-head">
          <div>
            <h1>Printer Settings</h1>
            <span>CONNECTED PRINTERS / DRIVER TOOLS / PRINT PROFILES</span>
          </div>
          <div class="queue-actions">
            <button class="ghost" :disabled="printerLoading" type="button" @click="loadPrinters">
              {{ printerLoading ? 'SCANNING...' : 'RESCAN HARDWARE' }}
            </button>
            <button class="primary" :disabled="driverLoading" type="button" @click="runDriverAction('install')">
              INSTALL / UPDATE DRIVER
            </button>
            <button class="ghost danger" :disabled="driverLoading" type="button" @click="runDriverAction('uninstall')">
              UNINSTALL DRIVER
            </button>
          </div>
        </div>

        <div class="driver-warning">
          Driver tools use the files in <strong>printer/</strong>. Windows may ask for administrator permission. Prefer install/update; uninstall only if the Brother driver is broken.
        </div>

        <div class="queue-summary">
          <div v-for="printer in printers" :key="printer.Name" class="mini-card" :class="printer.Name === form.printer_name ? 'selected' : ''">
            <span>{{ printer.PortName }}</span>
            <strong>{{ printer.Name }}</strong>
            <small>{{ printer.DriverName }}</small>
            <small>{{ printer.StatusDetail || printer.PrinterStatus }}</small>
            <small v-if="printer.PortHostAddress">{{ printer.PortHostAddress }} / {{ printer.NetworkReachable === false ? 'not reachable' : 'reachable' }}</small>
            <small v-else-if="printer.LocalDevicePresent !== null && printer.LocalDevicePresent !== undefined">Local device: {{ printer.LocalDevicePresent ? 'detected' : 'not detected' }}</small>
          </div>
        </div>

        <div class="profile-panel">
          <div class="panel-head compact-head">
            <div>
              <h1>Printer Profile</h1>
              <span>BROTHER + GENERIC WINDOWS + ZEBRA ZPL ACTIVE</span>
            </div>
            <label>
              Active Profile
              <select v-model="form.printer_profile">
                <option v-for="profile in printerProfiles" :key="profile.id" :value="profile.id">
                  {{ profile.name }} / {{ profile.status }}
                </option>
              </select>
            </label>
          </div>

          <div class="profile-grid">
            <div v-for="profile in printerProfiles" :key="profile.id" class="mini-card" :class="{ selected: profile.id === form.printer_profile }">
              <span>{{ profile.status }}</span>
              <strong>{{ profile.name }}</strong>
              <small>{{ profile.note }}</small>
            </div>
          </div>
        </div>

        <p v-if="error" class="error">{{ error }}</p>
        <p v-if="statusMessage" class="success">{{ statusMessage }}</p>
      </section>

      <section v-if="activeTab === 'templates'" class="panel queue-panel wide-panel">
        <div class="panel-head">
          <div>
            <h1>Templates</h1>
            <span>SAVED LABEL PRESETS / PRODUCT LAYOUT LIBRARY</span>
          </div>
        </div>

        <div class="template-toolbar">
          <label>
            Template Search
            <input v-model="templateSearch" placeholder="Search template name, product number, product name, or barcode" />
          </label>
        </div>

        <div v-if="templates.length === 0" class="empty-state">
          No templates saved yet. Create a label in Label Designer, enter a template name, then save it.
        </div>
        <div v-else-if="filteredTemplates.length === 0" class="empty-state">
          No templates match your search.
        </div>

        <div v-else class="template-grid">
          <article v-for="template in filteredTemplates" :key="template.id" class="template-card">
            <div class="template-card-head">
              <div>
                <span>TEMPLATE</span>
                <h2>{{ template.name }}</h2>
              </div>
              <strong>{{ template.label.label_width_mm }}x{{ template.label.label_length_mm }}mm</strong>
            </div>

            <div class="template-preview">
              <div class="template-sku">{{ template.label.product_number }}</div>
              <div class="template-product">{{ template.label.product_name }}</div>
              <div class="template-meta">
                <span>{{ template.label.item_type }}</span>
                <span>QTY {{ template.label.quantity }}</span>
                <span>{{ template.label.barcode }}</span>
              </div>
            </div>

            <div class="template-actions">
              <button class="primary" type="button" @click="loadTemplate(template)">LOAD</button>
              <button class="ghost danger" type="button" @click="deleteTemplate(template)">DELETE</button>
            </div>
          </article>
        </div>

        <p v-if="error" class="error">{{ error }}</p>
        <p v-if="statusMessage" class="success">{{ statusMessage }}</p>
      </section>
    </main>
  </div>
</template>
