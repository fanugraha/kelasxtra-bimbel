import type { GroupFilter, GroupSort } from './types'

export function GroupToolbar({
  filter,
  onFilter,
  search,
  onSearch,
  sort,
  onSort,
  total,
  attentionCount,
}: {
  filter: GroupFilter
  onFilter: (value: GroupFilter) => void
  search: string
  onSearch: (value: string) => void
  sort: GroupSort
  onSort: (value: GroupSort) => void
  total: number
  attentionCount: number
}) {
  return (
    <div className="toolbar grp-toolbar">
      <div className="segmented" role="group" aria-label="Saring program grup">
        <button aria-pressed={filter === 'all'} onClick={() => onFilter('all')}>
          Semua <span className="grp-filter-count">{total}</span>
        </button>
        <button aria-pressed={filter === 'attention'} onClick={() => onFilter('attention')}>
          Perlu tindakan <span className="grp-filter-count">{attentionCount}</span>
        </button>
      </div>
      <div className="spacer" />
      <div className="search grp-search">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
          <circle cx="11" cy="11" r="7" />
          <path d="m20 20-3.5-3.5" />
        </svg>
        <input
          className="input"
          type="search"
          placeholder="Cari program atau tutor"
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          aria-label="Cari program"
        />
      </div>
      <select className="select grp-sort" value={sort} onChange={(e) => onSort(e.target.value as GroupSort)} aria-label="Urutkan program">
        <option value="fill">Keterisian terendah</option>
        <option value="due">Batas waktu terdekat</option>
        <option value="name">Nama program A–Z</option>
      </select>
    </div>
  )
}
