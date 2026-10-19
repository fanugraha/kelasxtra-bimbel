const MATH_WORDS = new Set([
  'sin', 'cos', 'tan', 'akar', 'pi', 'derajat', 'celsius', 'mol', 'cm', 'km',
  'mm', 'kg', 'gram', 'liter', 'l', 'n', 'j', 'w', 'v', 's', 'm', 'g', 'c',
])

const FN_TEX: Record<string, string> = {
  sin: String.raw`\sin`,
  cos: String.raw`\cos`,
  tan: String.raw`\tan`,
}

function isMathToken(raw: string): boolean {
  const t = raw.replace(/^[([{]+|[)\]},.;:]+$/g, '')
  if (!t) return true
  if (/^[+\-−×=:/<>]+$/.test(t)) return true
  if (/[0-9]/.test(t)) return true
  if (/^[A-Za-z]$/.test(t)) return true
  return MATH_WORDS.has(t.toLowerCase())
}

function looksLikeMathExpression(input: string): boolean {
  const s = input.trim()
  if (!s || s.includes('$')) return false
  const tokens = s.split(/\s+/)
  if (tokens.length > 10) return false
  return tokens.every(isMathToken)
}

/** Ubah satu ekspresi matematika utuh menjadi TeX (tanpa dolar). */
function toTexExpression(input: string): string {
  let s = input.trim().replace(/[.]$/, '')

  s = s.replace(/akar\s*(\d+)\s*\/\s*(\d+)/g, String.raw`\sqrt{$1}/$2`)
  s = s.replace(/akar\s*(\d+)/g, String.raw`\sqrt{$1}`)

  s = s.replace(
    /\b(sin|cos|tan)\s*(\d+)\s*derajat/g,
    (_, fn: string, deg: string) => `${FN_TEX[fn]} ${deg}^\\circ`,
  )
  s = s.replace(/(\d+)\s*derajat\s*Celsius/g, '$1^\\circ C')
  s = s.replace(/(\d+)\s*derajat/g, '$1^\\circ')
  s = s.replace(/(?<!\\)\b(sin|cos|tan)\b/g, (fn) => FN_TEX[fn] ?? fn)
  s = s.replace(/\bpi\b/g, String.raw`\pi`)

  s = s.replace(
    /(\d+(?:,\d+)?)\s*[x×]\s*10\^\(?(\d+)\)?/g,
    (_, a: string, b: string) => `${a} \\times 10^{${b}}`,
  )
  s = s.replace(/\s+[x×]\s+/g, String.raw` \times `)
  s = s.replace(/\^\(([^)]*)\)|\^([A-Za-z0-9]+)/g, (_, a, b) => `^{${a ?? b}}`)
  s = s.replace(/(\d),(\d)/g, '$1{,}$2')
  return s
}

/** Ubah notasi matematika sehari-hari menjadi potongan TeX `$...$`. */
export function mathizeText(input: string): string {
  let s = input

  s = s.replace(
    /(\d+(?:,\d+)?)\s*x\s*10\^(\d+)/g,
    (_, a: string, b: string) => `$${a} \\times 10^{${b}}$`,
  )
  s = s.replace(/\b(CO|NO|SO)(\d+)\b/g, (_, f: string, n: string) =>
    `$\\mathrm{${f}_${n}}$`,
  )
  s = s.replace(/\bv0\b/g, '$v_0$')
  s = s.replace(/akar\s*(\d+)\s*\/\s*(\d+)/g, String.raw`$\sqrt{$1}/$2$`)
  s = s.replace(/akar\s*(\d+)/g, String.raw`$\sqrt{$1}$`)

  s = s.replace(
    /\b(sin|cos|tan)\s*(\d+)(\s*derajat)?\b/g,
    (_, fn: string, deg: string, word?: string) =>
      `$${FN_TEX[fn]} ${deg}${word ? '^\\circ' : ''}$`,
  )
  s = s.replace(
    /\b(sin|cos|tan)\s*x\b/g,
    (_, fn: string) => `$${FN_TEX[fn]} x$`,
  )

  s = s.replace(
    /(\d+)\s*derajat\s*Celsius/g,
    (_, n: string) => `$${n}^\\circ$C`,
  )
  s = s.replace(/(\d+)\s*derajat/g, (_, n: string) => `$${n}^\\circ$`)
  s = s.replace(/\bpi\b/g, '$\\pi$')
  s = s.replace(/([A-Za-z])\s+x\s+([A-Za-z])/g, '$1 × $2')
  s = s.replace(
    /(\d+(?:,\d+)?)\s*x\s*(\d+(?:,\d+)?)/g,
    (_, a: string, b: string) => `$${a} \\times ${b}$`,
  )
  s = s.replace(
    /\b(\d+)([A-Za-z])\b/g,
    (_, n: string, v: string) => `$${n}${v}$`,
  )
  return s
}

export interface MathSegment {
  math: boolean
  value: string
}

/** Pecah teks menjadi potongan teks biasa dan rumus TeX. */
export function mathSegments(text: string): MathSegment[] {
  if (looksLikeMathExpression(text)) {
    return [{ math: true, value: toTexExpression(text) }]
  }
  return mathizeText(text)
    .split(/(\$[^$]+\$)/g)
    .filter((p) => p.length > 0)
    .map((p) =>
      p.startsWith('$') && p.endsWith('$') && p.length > 2
        ? { math: true, value: p.slice(1, -1) }
        : { math: false, value: p },
    )
}
