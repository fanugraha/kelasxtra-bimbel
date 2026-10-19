import type { StudentStat } from './types'

export function StudentProgressCard({ students }: { students: StudentStat[] }) {
  return (
    <div className="card" style={{ marginTop: 14 }}>
      <div className="card-head">
        <div>
          <h2 className="card-title">Progres siswa</h2>
          <p className="card-sub">{students.length} siswa pada periode ini</p>
        </div>
      </div>
      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>Siswa</th>
              <th>Jenjang</th>
              <th className="num">Sesi selesai</th>
              <th className="num">Latihan bank soal</th>
            </tr>
          </thead>
          <tbody>
            {students.slice(0, 12).map((s) => (
              <tr key={s.id}>
                <td className="strong">{s.full_name}</td>
                <td>{s.jenjang}</td>
                <td className="num">{s.sessions}</td>
                <td className="num">{s.attempts}</td>
              </tr>
            ))}
            {students.length === 0 && (
              <tr>
                <td colSpan={4}>
                  <div className="empty-state">
                    <strong>Belum ada data siswa</strong>
                    <span>Data muncul setelah ada sesi atau latihan pada periode ini.</span>
                  </div>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
