-- Soal dummy untuk uji latihan & tryout (5 soal per topik).
-- Aman dijalankan berulang: soal dengan body sama di jenjang sama dilewati.
-- Jalankan di SQL editor / `supabase db reset` tidak memuat file ini otomatis.

do $$
declare
  r record;
  qid uuid;
  tid uuid;
begin
  for r in
    select * from (values
      -- Trigonometri (SMA)
      ('Trigonometri', 'SMA', 'Nilai dari tan 60 derajat adalah ...',
       '[{"key":"A","text":"1"},{"key":"B","text":"akar3"},{"key":"C","text":"akar2"},{"key":"D","text":"0"}]'::jsonb,
       'B', 'tan 60 = akar3.'),

      -- Kalkulus Dasar (SMA)
      ('Kalkulus Dasar', 'SMA', 'Turunan dari f(x) = x^3 adalah ...',
       '[{"key":"A","text":"x^2"},{"key":"B","text":"3x^2"},{"key":"C","text":"x^4/4"},{"key":"D","text":"3x"}]'::jsonb,
       'B', 'Aturan pangkat: d(x^n)/dx = n x^(n-1).'),
      ('Kalkulus Dasar', 'SMA', 'Turunan dari f(x) = x^2 + 5x adalah ...',
       '[{"key":"A","text":"2x + 5"},{"key":"B","text":"x + 5"},{"key":"C","text":"2x"},{"key":"D","text":"x^2"}]'::jsonb,
       'A', 'Turunkan tiap suku: 2x + 5.'),
      ('Kalkulus Dasar', 'SMA', 'Hasil integral x dx adalah ...',
       '[{"key":"A","text":"x^2 + C"},{"key":"B","text":"x^2/2 + C"},{"key":"C","text":"2x + C"},{"key":"D","text":"1 + C"}]'::jsonb,
       'B', 'Integral x^n = x^(n+1)/(n+1) + C, jadi x^2/2 + C.'),
      ('Kalkulus Dasar', 'SMA', 'Nilai limit x menuju 2 dari (x^2 - 4)/(x - 2) adalah ...',
       '[{"key":"A","text":"0"},{"key":"B","text":"2"},{"key":"C","text":"4"},{"key":"D","text":"tidak ada"}]'::jsonb,
       'C', 'Faktorkan: (x-2)(x+2)/(x-2) = x+2, lalu substitusi x=2 menjadi 4.'),
      ('Kalkulus Dasar', 'SMA', 'Turunan dari sin x adalah ...',
       '[{"key":"A","text":"cos x"},{"key":"B","text":"-cos x"},{"key":"C","text":"sin x"},{"key":"D","text":"-sin x"}]'::jsonb,
       'A', 'Turunan sin x = cos x.'),

      -- Kinematika (SMA)
      ('Kinematika', 'SMA', 'Benda 2 kg dipercepat 3 m/s^2. Gaya yang bekerja adalah ...',
       '[{"key":"A","text":"1,5 N"},{"key":"B","text":"5 N"},{"key":"C","text":"6 N"},{"key":"D","text":"9 N"}]'::jsonb,
       'C', 'F = m a = 2 x 3 = 6 N.'),
      ('Kinematika', 'SMA', 'Dari keadaan diam, benda dipercepat 2 m/s^2 selama 5 s. Kecepatannya menjadi ...',
       '[{"key":"A","text":"2 m/s"},{"key":"B","text":"5 m/s"},{"key":"C","text":"10 m/s"},{"key":"D","text":"25 m/s"}]'::jsonb,
       'C', 'v = v0 + a t = 0 + 2 x 5 = 10 m/s.'),
      ('Kinematika', 'SMA', 'Dari keadaan diam, benda dipercepat 2 m/s^2 selama 5 s. Jarak tempuhnya ...',
       '[{"key":"A","text":"10 m"},{"key":"B","text":"20 m"},{"key":"C","text":"25 m"},{"key":"D","text":"50 m"}]'::jsonb,
       'C', 's = v0 t + 1/2 a t^2 = 0 + 1/2 x 2 x 25 = 25 m.'),
      ('Kinematika', 'SMA', 'Benda bergerak 10 m/s selama 4 s. Jarak tempuhnya ...',
       '[{"key":"A","text":"4 m"},{"key":"B","text":"14 m"},{"key":"C","text":"40 m"},{"key":"D","text":"100 m"}]'::jsonb,
       'C', 's = v t = 10 x 4 = 40 m.'),
      ('Kinematika', 'SMA', 'Kecepatan benda berubah dari 0 menjadi 20 m/s dalam 4 s. Percepatannya ...',
       '[{"key":"A","text":"4 m/s^2"},{"key":"B","text":"5 m/s^2"},{"key":"C","text":"10 m/s^2"},{"key":"D","text":"20 m/s^2"}]'::jsonb,
       'B', 'a = selisih kecepatan / waktu = 20/4 = 5 m/s^2.'),

      -- Dinamika (SMA)
      ('Dinamika', 'SMA', 'Berat benda 5 kg jika g = 10 m/s^2 adalah ...',
       '[{"key":"A","text":"0,5 N"},{"key":"B","text":"2 N"},{"key":"C","text":"50 N"},{"key":"D","text":"500 N"}]'::jsonb,
       'C', 'W = m g = 5 x 10 = 50 N.'),
      ('Dinamika', 'SMA', 'Hubungan gaya, massa, dan percepatan dinyatakan oleh ...',
       '[{"key":"A","text":"F = m / a"},{"key":"B","text":"F = m a"},{"key":"C","text":"F = a / m"},{"key":"D","text":"F = m + a"}]'::jsonb,
       'B', 'Hukum Newton II: F = m a.'),
      ('Dinamika', 'SMA', 'Gaya 20 N bekerja pada benda 4 kg. Percepatannya ...',
       '[{"key":"A","text":"0,2 m/s^2"},{"key":"B","text":"4 m/s^2"},{"key":"C","text":"5 m/s^2"},{"key":"D","text":"80 m/s^2"}]'::jsonb,
       'C', 'a = F/m = 20/4 = 5 m/s^2.'),
      ('Dinamika', 'SMA', 'Resultan dua gaya searah 10 N dan 15 N adalah ...',
       '[{"key":"A","text":"5 N"},{"key":"B","text":"12,5 N"},{"key":"C","text":"25 N"},{"key":"D","text":"150 N"}]'::jsonb,
       'C', 'Gaya searah dijumlahkan: 10 + 15 = 25 N.'),
      ('Dinamika', 'SMA', 'Massa 3 kg dipercepat 4 m/s^2. Gaya yang diperlukan ...',
       '[{"key":"A","text":"7 N"},{"key":"B","text":"12 N"},{"key":"C","text":"16 N"},{"key":"D","text":"24 N"}]'::jsonb,
       'B', 'F = m a = 3 x 4 = 12 N.'),

      -- Stoikiometri (SMA)
      ('Stoikiometri', 'SMA', 'Jumlah mol dari 18 g air (Mr = 18) adalah ...',
       '[{"key":"A","text":"0,5 mol"},{"key":"B","text":"1 mol"},{"key":"C","text":"2 mol"},{"key":"D","text":"18 mol"}]'::jsonb,
       'B', 'n = massa/Mr = 18/18 = 1 mol.'),
      ('Stoikiometri', 'SMA', 'Jumlah mol dari 44 g CO2 (Mr = 44) adalah ...',
       '[{"key":"A","text":"0,5 mol"},{"key":"B","text":"1 mol"},{"key":"C","text":"2 mol"},{"key":"D","text":"44 mol"}]'::jsonb,
       'B', 'n = 44/44 = 1 mol.'),
      ('Stoikiometri', 'SMA', 'Massa 0,5 mol NaCl (Mr = 58,5) adalah ...',
       '[{"key":"A","text":"11,7 g"},{"key":"B","text":"29,25 g"},{"key":"C","text":"58,5 g"},{"key":"D","text":"117 g"}]'::jsonb,
       'B', 'm = n x Mr = 0,5 x 58,5 = 29,25 g.'),
      ('Stoikiometri', 'SMA', 'Volume 2 mol gas pada keadaan STP (22,4 L/mol) adalah ...',
       '[{"key":"A","text":"11,2 L"},{"key":"B","text":"22,4 L"},{"key":"C","text":"44,8 L"},{"key":"D","text":"89,6 L"}]'::jsonb,
       'C', 'V = n x 22,4 = 2 x 22,4 = 44,8 L.'),
      ('Stoikiometri', 'SMA', 'Jumlah partikel dalam 1 mol zat adalah ...',
       '[{"key":"A","text":"6,02 x 10^23"},{"key":"B","text":"3,01 x 10^23"},{"key":"C","text":"1 x 10^23"},{"key":"D","text":"22,4 x 10^23"}]'::jsonb,
       'A', 'Bilangan Avogadro = 6,02 x 10^23 partikel/mol.'),

      -- Genetika (SMA)
      ('Genetika', 'SMA', 'Genotipe heterozigot ditulis sebagai ...',
       '[{"key":"A","text":"AA"},{"key":"B","text":"Aa"},{"key":"C","text":"aa"},{"key":"D","text":"AABb"}]'::jsonb,
       'B', 'Heterozigot = dua alel berbeda, misalnya Aa.'),
      ('Genetika', 'SMA', 'Persilangan Aa x Aa menghasilkan perbandingan fenotip dominan : resesif ...',
       '[{"key":"A","text":"1 : 1"},{"key":"B","text":"2 : 1"},{"key":"C","text":"3 : 1"},{"key":"D","text":"4 : 1"}]'::jsonb,
       'C', 'AA : Aa : aa = 1 : 2 : 1, sehingga fenotip 3 : 1.'),
      ('Genetika', 'SMA', 'Jumlah kromosom sel tubuh manusia adalah ...',
       '[{"key":"A","text":"23"},{"key":"B","text":"44"},{"key":"C","text":"46"},{"key":"D","text":"48"}]'::jsonb,
       'C', 'Manusia memiliki 46 kromosom (23 pasang).'),
      ('Genetika', 'SMA', 'Sifat resesif muncul bila genotipnya ...',
       '[{"key":"A","text":"homozigot dominan"},{"key":"B","text":"heterozigot"},{"key":"C","text":"homozigot resesif"},{"key":"D","text":"haploid"}]'::jsonb,
       'C', 'Sifat resesif tampak pada homozigot resesif (aa).'),
      ('Genetika', 'SMA', 'Genotipe kromosom seks pria adalah ...',
       '[{"key":"A","text":"XX"},{"key":"B","text":"XY"},{"key":"C","text":"YY"},{"key":"D","text":"XO"}]'::jsonb,
       'B', 'Pria XY, perempuan XX.'),

      -- Aljabar (SMP)
      ('Aljabar', 'SMP', 'Nilai x dari 2x + 3 = 11 adalah ...',
       '[{"key":"A","text":"2"},{"key":"B","text":"4"},{"key":"C","text":"6"},{"key":"D","text":"7"}]'::jsonb,
       'B', '2x = 8, jadi x = 4.'),
      ('Aljabar', 'SMP', 'Hasil (x + 3)(x - 3) adalah ...',
       '[{"key":"A","text":"x^2 - 9"},{"key":"B","text":"x^2 + 9"},{"key":"C","text":"x^2 - 6x + 9"},{"key":"D","text":"x^2 + 6x + 9"}]'::jsonb,
       'A', 'Selisih kuadrat: x^2 - 9.'),
      ('Aljabar', 'SMP', 'Nilai 2x + 1 untuk x = 3 adalah ...',
       '[{"key":"A","text":"5"},{"key":"B","text":"6"},{"key":"C","text":"7"},{"key":"D","text":"8"}]'::jsonb,
       'C', '2(3) + 1 = 7.'),
      ('Aljabar', 'SMP', 'Faktor dari x^2 - 5x + 6 adalah ...',
       '[{"key":"A","text":"(x - 1)(x - 6)"},{"key":"B","text":"(x - 2)(x - 3)"},{"key":"C","text":"(x + 2)(x + 3)"},{"key":"D","text":"(x + 1)(x + 6)"}]'::jsonb,
       'B', 'Cari dua bilangan berjumlah -5 dan berkali 6: -2 dan -3.'),
      ('Aljabar', 'SMP', 'Bentuk sederhana dari 4x + 3x adalah ...',
       '[{"key":"A","text":"7x"},{"key":"B","text":"12x"},{"key":"C","text":"7x^2"},{"key":"D","text":"x"}]'::jsonb,
       'A', 'Suku sejenis dijumlahkan: 7x.'),

      -- Geometri (SMP)
      ('Geometri', 'SMP', 'Luas persegi dengan sisi 6 cm adalah ...',
       '[{"key":"A","text":"12 cm^2"},{"key":"B","text":"24 cm^2"},{"key":"C","text":"36 cm^2"},{"key":"D","text":"48 cm^2"}]'::jsonb,
       'C', 'L = s^2 = 6 x 6 = 36 cm^2.'),
      ('Geometri', 'SMP', 'Keliling segitiga dengan sisi 3 cm, 4 cm, dan 5 cm adalah ...',
       '[{"key":"A","text":"7 cm"},{"key":"B","text":"12 cm"},{"key":"C","text":"15 cm"},{"key":"D","text":"20 cm"}]'::jsonb,
       'B', 'K = 3 + 4 + 5 = 12 cm.'),
      ('Geometri', 'SMP', 'Jumlah sudut dalam sebuah segitiga adalah ...',
       '[{"key":"A","text":"90 derajat"},{"key":"B","text":"180 derajat"},{"key":"C","text":"270 derajat"},{"key":"D","text":"360 derajat"}]'::jsonb,
       'B', 'Jumlah sudut dalam segitiga 180 derajat.'),
      ('Geometri', 'SMP', 'Luas lingkaran berjari-jari 7 cm (pi = 22/7) adalah ...',
       '[{"key":"A","text":"44 cm^2"},{"key":"B","text":"77 cm^2"},{"key":"C","text":"154 cm^2"},{"key":"D","text":"308 cm^2"}]'::jsonb,
       'C', 'L = pi r^2 = 22/7 x 49 = 154 cm^2.'),
      ('Geometri', 'SMP', 'Volume kubus dengan sisi 4 cm adalah ...',
       '[{"key":"A","text":"12 cm^3"},{"key":"B","text":"16 cm^3"},{"key":"C","text":"48 cm^3"},{"key":"D","text":"64 cm^3"}]'::jsonb,
       'D', 'V = s^3 = 4 x 4 x 4 = 64 cm^3.'),

      -- Teks Eksposisi (SMP)
      ('Teks Eksposisi', 'SMP', 'Tujuan utama teks eksposisi adalah ...',
       '[{"key":"A","text":"menghibur pembaca"},{"key":"B","text":"menjelaskan informasi disertai fakta"},{"key":"C","text":"menceritakan pengalaman"},{"key":"D","text":"mengajak membeli produk"}]'::jsonb,
       'B', 'Eksposisi memaparkan informasi dan argumen berbasis fakta.'),
      ('Teks Eksposisi', 'SMP', 'Struktur teks eksposisi adalah ...',
       '[{"key":"A","text":"orientasi, komplikasi, resolusi"},{"key":"B","text":"tesis, argumen, penegasan ulang"},{"key":"C","text":"pembuka, isi, penutup"},{"key":"D","text":"abstraksi, krisis, koda"}]'::jsonb,
       'B', 'Urutan eksposisi: tesis, rangkaian argumen, penegasan ulang.'),
      ('Teks Eksposisi', 'SMP', 'Ciri kebahasaan teks eksposisi yang menonjol adalah ...',
       '[{"key":"A","text":"banyak kalimat perintah"},{"key":"B","text":"banyak kata sapaan"},{"key":"C","text":"menggunakan fakta dan istilah teknis"},{"key":"D","text":"banyak dialog tokoh"}]'::jsonb,
       'C', 'Eksposisi memakai fakta, istilah teknis, dan konjungsi sebab-akibat.'),
      ('Teks Eksposisi', 'SMP', 'Kalimat berikut yang merupakan opini adalah ...',
       '[{"key":"A","text":"Air mendidih pada suhu 100 derajat Celsius."},{"key":"B","text":"Indonesia memiliki dua musim."},{"key":"C","text":"Belajar daring kurang efektif bagi sebagian siswa."},{"key":"D","text":"Bumi mengelilingi matahari."}]'::jsonb,
       'C', 'Kalimat C berisi penilaian pribadi, bukan fakta umum.'),
      ('Teks Eksposisi', 'SMP', 'Kata penghubung yang menyatakan sebab-akibat adalah ...',
       '[{"key":"A","text":"karena"},{"key":"B","text":"dan"},{"key":"C","text":"atau"},{"key":"D","text":"tetapi"}]'::jsonb,
       'A', 'Karena menghubungkan sebab dengan akibat.'),

      -- Tenses (SMP)
      ('Tenses', 'SMP', 'She ... to school every day.',
       '[{"key":"A","text":"go"},{"key":"B","text":"goes"},{"key":"C","text":"going"},{"key":"D","text":"went"}]'::jsonb,
       'B', 'Simple present untuk subjek she: goes.'),
      ('Tenses', 'SMP', 'They ... to the beach yesterday.',
       '[{"key":"A","text":"go"},{"key":"B","text":"goes"},{"key":"C","text":"went"},{"key":"D","text":"will go"}]'::jsonb,
       'C', 'Keterangan yesterday menandakan simple past: went.'),
      ('Tenses', 'SMP', 'I ... English now.',
       '[{"key":"A","text":"study"},{"key":"B","text":"am studying"},{"key":"C","text":"studied"},{"key":"D","text":"have studied"}]'::jsonb,
       'B', 'Present continuous untuk kegiatan sekarang: am studying.'),
      ('Tenses', 'SMP', 'We ... to Bandung tomorrow.',
       '[{"key":"A","text":"went"},{"key":"B","text":"go"},{"key":"C","text":"will go"},{"key":"D","text":"have gone"}]'::jsonb,
       'C', 'Tomorrow menandakan future: will go.'),
      ('Tenses', 'SMP', 'He ... his homework.',
       '[{"key":"A","text":"has finished"},{"key":"B","text":"finish"},{"key":"C","text":"finishing"},{"key":"D","text":"will finished"}]'::jsonb,
       'A', 'Present perfect: has + past participle.')
    ) as t(topic, jenjang, body, options, answer, explanation)
  loop
    if not exists (
      select 1
      from public.questions q
      join public.question_versions v
        on v.question_id = q.id and v.version = q.current_version
      where q.jenjang = r.jenjang and v.body = r.body
    ) then
      select t.id into tid
      from public.topics t
      where t.name = r.topic and t.jenjang = r.jenjang;

      if tid is null then
        raise notice 'Topik tidak ditemukan: % (%)', r.topic, r.jenjang;
        continue;
      end if;

      insert into public.questions
        (subject_id, topic_id, jenjang, type, status, current_version)
      select t.subject_id, t.id, r.jenjang, 'pg', 'published', 1
      from public.topics t where t.id = tid
      returning id into qid;

      insert into public.question_versions
        (question_id, version, body, options, answer, explanation)
      values (qid, 1, r.body, r.options, r.answer, r.explanation);
    end if;
  end loop;
end $$;
