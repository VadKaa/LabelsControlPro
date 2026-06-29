<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'

type LayoutFieldKey = 'product_number' | 'product_name' | 'barcode' | 'details' | 'notes'

type LayoutOffset = {
  x: number
  y: number
  scale: number
}

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
  driver_media_name: string
  printer_profile: string
  zpl_dpi: number
  layout_offsets: Record<LayoutFieldKey, LayoutOffset>
}

type Printer = {
  Name: string
  DriverName: string
  PortName: string
  PrinterStatus?: string | number
  WorkOffline?: boolean
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

const API_BASE = 'http://localhost:9000'

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
  driver_media_name: '62mm',
  printer_profile: 'brother_ql_windows',
  zpl_dpi: 203,
  layout_offsets: {
    product_number: { x: 0, y: 0, scale: 1 },
    product_name: { x: 0, y: 0, scale: 1 },
    barcode: { x: 0, y: 0, scale: 1 },
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
const selectedLayoutField = ref<LayoutFieldKey>('barcode')
const layoutFields: Array<{ key: LayoutFieldKey; label: string }> = [
  { key: 'product_number', label: 'Product Number' },
  { key: 'product_name', label: 'Product Name' },
  { key: 'barcode', label: 'Barcode' },
  { key: 'details', label: 'Qty / Type / Weight' },
  { key: 'notes', label: 'Notes' },
]

const selectedPrinter = computed(() => printers.value.find((printer) => printer.Name === form.printer_name))
const brotherInstalled = computed(() => printers.value.some((printer) => printer.Name.toLowerCase().includes('brother') || printer.DriverName.toLowerCase().includes('brother')))
const printerOnline = computed(() => {
  if (!selectedPrinter.value && !form.printer_name) return printers.value.length > 0
  if (!selectedPrinter.value) return false
  return !selectedPrinter.value.WorkOffline
})
const statusLabel = computed(() => printerOnline.value ? 'ONLINE' : 'OFFLINE')
const statusClass = computed(() => printerOnline.value ? 'online' : 'offline')
const printerProfiles = [
  { id: 'brother_ql_windows', name: 'Brother QL via Windows Driver', status: 'Active', note: 'Current stable path for QL-820NWB and other Brother QL printers installed in Windows.' },
  { id: 'generic_windows', name: 'Generic Windows Printer', status: 'Active', note: 'Fallback path for installed Windows printers using standard driver printing and selected media.' },
  { id: 'zebra_zpl', name: 'Zebra ZPL', status: 'Active', note: 'Direct ZPL output for Zebra GK/ZD/ZT/LP/TLP label printers through a Windows RAW printer queue.' },
]
const selectedProfile = computed(() => printerProfiles.find((profile) => profile.id === form.printer_profile) || printerProfiles[0])
const selectedMedia = computed(() => `${form.label_width_mm}mm x ${form.label_length_mm}mm`)
const selectedDriverMedia = computed(() => printerMedia.value.find((media) => media.name === form.driver_media_name))
const usefulMedia = computed(() => printerMedia.value.filter((media) => media.name.includes('62mm') || media.continuous).slice(0, 30))
const stuckJobs = computed(() => printJobs.value.filter((job) => isStuckJob(job)).length)
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
const previewKey = computed(() => `${form.label_width_mm}-${form.label_length_mm}-${form.layout_preset}-${JSON.stringify(form.layout_offsets)}-${form.product_number}-${form.product_name}-${form.barcode}`)
const labelTapeStyle = computed(() => {
  const width = Math.min(900, Math.max(320, form.label_length_mm * 9))
  const height = Math.min(320, Math.max(145, form.label_width_mm * 2.35))
  return {
    width: `${width}px`,
    minHeight: `${height}px`,
    gridTemplateColumns: ['stacked', 'barcode_bottom', 'minimal'].includes(form.layout_preset) ? '1fr' : 'minmax(0, 58fr) 42fr',
  }
})

function fieldStyle(field: LayoutFieldKey) {
  const offset = form.layout_offsets[field]
  return {
    transform: `translate(${offset.x}px, ${offset.y}px) scale(${offset.scale})`,
    transformOrigin: 'top left',
  }
}

function nudgeField(dx: number, dy: number) {
  const field = form.layout_offsets[selectedLayoutField.value]
  field.x += dx
  field.y += dy
}

function scaleField(delta: number) {
  const field = form.layout_offsets[selectedLayoutField.value]
  field.scale = Math.min(1.5, Math.max(0.65, Number((field.scale + delta).toFixed(2))))
}

function resetField() {
  form.layout_offsets[selectedLayoutField.value] = { x: 0, y: 0, scale: 1 }
}

function resetLayoutOffsets() {
  for (const field of layoutFields) {
    form.layout_offsets[field.key] = { x: 0, y: 0, scale: 1 }
  }
}

function ensureLayoutOffsets() {
  if (!form.layout_offsets) form.layout_offsets = {} as Record<LayoutFieldKey, LayoutOffset>
  for (const field of layoutFields) {
    if (!form.layout_offsets[field.key]) {
      form.layout_offsets[field.key] = { x: 0, y: 0, scale: 1 }
    }
  }
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

async function submitLabel() {
  loading.value = true
  error.value = ''
  statusMessage.value = ''

  try {
    const payload = { ...form, print: true }
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
    statusMessage.value = data.print?.status === 'printed' ? 'Label sent to printer.' : 'Label saved.'
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
          <span>Printer Status</span>
          <strong :class="statusClass">{{ statusLabel }}</strong>
        </div>
        <div class="meter"><span :style="{ width: printerOnline ? '85%' : '8%' }"></span></div>
        <small>{{ selectedPrinter?.Name || 'No printer selected' }}</small>
        <small>USB media: {{ selectedMedia }}</small>
        <small v-if="!brotherInstalled" class="warn">Brother printer not detected in Windows</small>
      </div>
    </aside>

    <main class="workbench">
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
                Layout Preset
                <select v-model="form.layout_preset">
                  <option value="compact_right">Compact: barcode right</option>
                  <option value="barcode_left">Compact: barcode left</option>
                  <option value="stacked">Stacked: barcode under title</option>
                  <option value="barcode_bottom">Wide: full-width barcode</option>
                  <option value="minimal">Minimal: SKU + barcode only</option>
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
              <div class="nudge-pad">
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
                  {{ printer.Name }} / {{ printer.DriverName }}
                </option>
              </select>
            </label>

            <label>
              Print Density Control
              <input v-model.number="form.print_density" max="10" min="1" type="range" />
            </label>

            <button class="primary full" :disabled="loading" type="button" @click="submitLabel">
              {{ loading ? 'PRINTING...' : 'PRINT NOW' }}
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
          <div :key="previewKey" class="label-tape" :class="form.layout_preset" :style="labelTapeStyle">
            <div class="tape-meta top">Brother QL / {{ form.driver_media_name || selectedMedia }} / Code128</div>
            <div class="label-left">
              <div>
                <div class="sku" :style="fieldStyle('product_number')">{{ form.product_number || 'SKU-000' }}</div>
                <div class="product" :style="fieldStyle('product_name')">{{ form.product_name || 'Product name' }}</div>
              </div>

              <div class="label-data" :style="fieldStyle('details')">
                <div>
                  <span>ITEM TYPE</span>
                  <strong>{{ form.item_type || 'TYPE' }}</strong>
                </div>
                <div>
                  <span>WEIGHT</span>
                  <strong>{{ form.weight || '0 KG' }}</strong>
                </div>
                <div>
                  <span>QTY</span>
                  <strong>{{ form.quantity }}</strong>
                </div>
                <div>
                  <span>NOTES</span>
                  <strong :style="fieldStyle('notes')">{{ form.notes || 'NONE' }}</strong>
                </div>
              </div>
            </div>

            <div class="barcode-box" :style="fieldStyle('barcode')">
              <div class="barcode">
                <i
                  v-for="(bar, index) in barcodeBars"
                  :key="index"
                  :style="{ width: `${bar}px`, height: '100%' }"
                ></i>
              </div>
              <div class="barcode-text">{{ form.barcode || '123456789012' }}</div>
            </div>
          </div>
        </div>

        <div class="hardware-grid">
          <div class="mini-card">
            <span>PRINTER</span>
            <strong>{{ selectedPrinter?.Name || 'Default printer' }}</strong>
          </div>
          <div class="mini-card">
            <span>PORT</span>
            <strong>{{ selectedPrinter?.PortName || 'AUTO' }}</strong>
          </div>
          <div class="mini-card">
            <span>MEDIA</span>
            <strong>{{ form.driver_media_name || selectedMedia }}</strong>
          </div>
          <div class="mini-card" :class="statusClass">
            <span>STATUS</span>
            <strong>{{ statusLabel }}</strong>
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
