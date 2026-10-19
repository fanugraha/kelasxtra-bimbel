import { useMemo } from 'react'
import { InlineMath } from 'react-katex'
import 'katex/dist/katex.min.css'
import { mathSegments } from '../lib/mathText'

/** Render teks biasa maupun rumus (otomatis dari notasi sehari-hari). */
export function MathText({ text }: { text: string }) {
  const parts = useMemo(() => mathSegments(text), [text])
  return (
    <>
      {parts.map((p, i) =>
        p.math ? <InlineMath key={i} math={p.value} /> : <span key={i}>{p.value}</span>,
      )}
    </>
  )
}
