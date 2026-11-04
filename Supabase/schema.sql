-- =====================================================================
-- نخبة: مخطط قاعدة البيانات (Supabase / Postgres)
-- مُستنتَج من استخدام التطبيق للجداول والدوال، وليس نسخة من قاعدتك الحالية.
-- قبل التشغيل: قارنه بقاعدتك الفعلية (Table Editor / SQL: \d+ table)، واستخدمه
-- كمرجع أو لإنشاء مشروع Supabase جديد. السياسات (RLS) أدناه نقطة بداية ويجب مراجعتها.
-- =====================================================================

create table if not exists profiles (
  username text primary key,                       -- نفس username في auth (البريد: username@nokhba.school)
  role     text not null check (role in ('admin','teacher','staff')),
  name     text
);

create table if not exists teachers (
  id uuid primary key default gen_random_uuid(),
  username text unique references profiles(username) on delete set null,
  name text not null,
  specialty text,
  photo text,                                      -- data:image/jpeg;base64,...
  bio text,
  category text default 'teacher',                 -- teacher|assistant|diwan|counselor|librarian|accountant|nurse
  gender text check (gender in ('m','f')),
  years_experience int,
  classes text,                                    -- "7-a,7-b,8-c"
  tasks jsonb default '[]'::jsonb,                 -- [{id,text,date,classes[],sections[],images[]}]
  tasks_text text,
  tasks_images jsonb default '[]'::jsonb,
  notices jsonb default '[]'::jsonb,               -- [{id,date,text}]
  created_at timestamptz default now()
);

create table if not exists schedules (            -- key: g7_a ... g12_c  |  exams_g7 ...
  key text primary key,
  data jsonb not null
);

create table if not exists announcements (
  id bigint generated always as identity primary key,
  text text not null,
  by_name text,
  created_at timestamptz default now()
);

create table if not exists gallery (
  id bigint generated always as identity primary key,
  img text not null,
  created_at timestamptz default now()
);

create table if not exists library_loans (
  id bigint generated always as identity primary key,
  student_name text not null,
  book_title text,
  due_date date not null,
  returned boolean not null default false,
  created_at timestamptz default now()
);

create table if not exists mood_checkins (
  id bigint generated always as identity primary key,
  mood text not null,
  reason text,
  created_at timestamptz default now()
);

create table if not exists support_requests (
  id bigint generated always as identity primary key,
  message text not null,
  contact text,
  status text not null default 'new' check (status in ('new','progress','contacted','done')),
  note text,
  created_at timestamptz default now()
);

-- ---------- دوال مساعدة ----------
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles
                 where username = split_part(auth.jwt() ->> 'email', '@', 1) and role = 'admin');
$$;

-- إحصاءات المزاج (للمدير/المرشد فقط)
create or replace function care_mood_stats(p_days int)
returns table (mood text, n bigint)
language sql stable security definer set search_path = public as $$
  select m.mood, count(*) from mood_checkins m
  where is_admin() and m.created_at >= now() - make_interval(days => p_days)
  group by m.mood;
$$;

-- مهام الصف: يقرأها الطالب بدون تسجيل دخول
create or replace function tasks_for_grade(p_grade text)
returns table (teacher_id uuid, task_id text, teacher_name text, specialty text,
               classes jsonb, sections jsonb, task_date text, task_text text, image_count int)
language sql stable security definer set search_path = public as $$
  select t.id, x->>'id', t.name, t.specialty, x->'classes', x->'sections',
         x->>'date', x->>'text', coalesce(jsonb_array_length(x->'images'), 0)
  from teachers t, jsonb_array_elements(t.tasks) x
  where (x->'classes') ? p_grade
  order by x->>'date' desc nulls last;
$$;

create or replace function task_images(p_teacher uuid, p_task text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(x->'images', '[]'::jsonb)
  from teachers t, jsonb_array_elements(t.tasks) x
  where t.id = p_teacher and x->>'id' = p_task;
$$;

-- تحديث المعلم لبطاقته فقط
create or replace function update_my_card_v3(p_name text, p_specialty text, p_bio text, p_photo text, p_years int)
returns void language sql security definer set search_path = public as $$
  update teachers set name = coalesce(p_name, name), specialty = p_specialty, bio = p_bio,
         photo = coalesce(p_photo, photo), years_experience = p_years
  where username = split_part(auth.jwt() ->> 'email', '@', 1);
$$;

create or replace function update_my_classes(p_classes text) returns void
language sql security definer set search_path = public as $$
  update teachers set classes = p_classes where username = split_part(auth.jwt() ->> 'email', '@', 1);
$$;
create or replace function update_my_tasks(p_tasks jsonb) returns void
language sql security definer set search_path = public as $$
  update teachers set tasks = p_tasks, tasks_text = null, tasks_images = null
  where username = split_part(auth.jwt() ->> 'email', '@', 1);
$$;
create or replace function update_my_notices(p_notices jsonb) returns void
language sql security definer set search_path = public as $$
  update teachers set notices = p_notices where username = split_part(auth.jwt() ->> 'email', '@', 1);
$$;
create or replace function update_my_work(p_classes text, p_tasks_text text, p_tasks_images jsonb) returns void
language sql security definer set search_path = public as $$
  update teachers set classes = coalesce(p_classes, classes), tasks_text = coalesce(p_tasks_text, tasks_text),
         tasks_images = coalesce(p_tasks_images, tasks_images)
  where username = split_part(auth.jwt() ->> 'email', '@', 1);
$$;

-- ---------- RLS (نقطة بداية) ----------
alter table profiles          enable row level security;
alter table teachers          enable row level security;
alter table schedules         enable row level security;
alter table announcements     enable row level security;
alter table gallery           enable row level security;
alter table library_loans     enable row level security;
alter table mood_checkins     enable row level security;
alter table support_requests  enable row level security;

-- قراءة عامة (الطالب بلا دخول)
create policy read_all_ann   on announcements for select using (true);
create policy read_all_sched on schedules     for select using (true);
create policy read_all_gal   on gallery       for select using (true);
create policy read_teachers  on teachers      for select using (true);   -- راجع: الحقول tasks/notices ظاهرة للجميع هنا
-- المدير يكتب
create policy admin_ann   on announcements for all using (is_admin()) with check (is_admin());
create policy admin_sched on schedules     for all using (is_admin()) with check (is_admin());
create policy admin_gal   on gallery       for all using (is_admin()) with check (is_admin());
create policy admin_teach on teachers      for all using (is_admin()) with check (is_admin());
-- الطالب يسجل مزاجه ويرسل للمرشد دون هوية
create policy ins_mood on mood_checkins    for insert with check (true);
create policy ins_help on support_requests for insert with check (true);
create policy admin_help on support_requests for all using (is_admin()) with check (is_admin());
-- المكتبة: المدير وكادر المكتبة
create policy loans_staff on library_loans for all
  using (exists (select 1 from profiles p where p.username = split_part(auth.jwt() ->> 'email','@',1) and p.role in ('admin','staff')))
  with check (true);
-- كل مستخدم يقرأ صف profiles الخاص به
create policy own_profile on profiles for select using (username = split_part(auth.jwt() ->> 'email','@',1));
