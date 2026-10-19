import type { MonitoringFilter, TutorSort } from './types'

export function MonitoringToolbar({
  filter,
  onFilter,
  search,
  onSearch,
  sort,
  onSort,
  attentionCount,
  totalCount,
}: {
  filter: MonitoringFilter
  onFilter: (value: MonitoringFilter) => void
  search: string
  onSearch: (value: string) => void
  sort: TutorSort
  onSort: (value: TutorSort) => void
  attentionCount: number
  totalCount: number
}) {
  return (
    <div className="toolbar mtr-toolbar">
      <div className="segmented" role="group" aria-label="Saring daftar tutor">
        <button
          type="button"
          aria-pressed={filter === 'attention'}
          onClick={() => onFilter('attention')}
        >
          Perlu tindakan <span className="mtr-filter-count">{attentionCount}</span>
        </button>
        <button
          type="button"
          aria-pressed={filter === 'all'}
          onClick={() => onFilter('all')}
        >
          Semua tutor <span className="mtr-filter-count">{totalCount}</span>
        </button>
      </div>
      <div className="spacer" />
      <div className="search mtr-search">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
          <circle cx="11" cy="11" r="7" />
          <path d="m20 20-3.5-3.5" />
        </svg>
        <input
          className="input"
          type="search"
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          placeholder="Cari nama tutor"
          aria-label="Cari tutor"
        />
      </div>
      <select
        className="select mtr-sort"
        value={sort}
        onChange={(e) => onSort(e.target.value as TutorSort)}
        aria-label="Urutkan tutor"
      >
        <option value="pay">Gaji tertahan terbesar</option>
        <option value="sessions">Sesi tersedikit</option>
        <option value="name">Nama tutor A–Z</option>
      </select>
    </div>
  )
}
