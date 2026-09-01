-- ============================================================
-- GAMING SHOP — SUPABASE DATABASE (v2: đăng nhập quản lý bằng mật khẩu)
-- Idempotent: có thể chạy lại nhiều lần trong Supabase SQL Editor mà không lỗi.
-- ============================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ============================================================
-- 1. BẢNG
-- ============================================================

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  code_prefix text not null,
  name text not null,
  description text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_packages (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  duration_label text not null,
  duration_value text,
  price numeric(12,0) not null default 0,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.store_orders (
  id uuid primary key default gen_random_uuid(),
  order_code text not null unique,
  product_id uuid not null references public.products(id),
  product_name text not null,
  package_id uuid references public.product_packages(id),
  duration_label text not null,
  amount numeric(12,0) not null default 0,
  payment_status text not null default 'pending'
    check (payment_status in ('pending','claimed','confirmed','rejected')),
  order_status text not null default 'pending'
    check (order_status in ('pending','processing','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.redemption_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  store_order_id uuid not null references public.store_orders(id) on delete cascade,
  product_name text not null,
  status text not null default 'active'
    check (status in ('active','used','invalid','expired')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  used_at timestamptz
);

create table if not exists public.payment_claims (
  id uuid primary key default gen_random_uuid(),
  store_order_id uuid not null references public.store_orders(id) on delete cascade,
  amount numeric(12,0) not null default 0,
  status text not null default 'pending'
    check (status in ('pending','confirmed','rejected')),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz
);

create table if not exists public.payment_settings (
  id boolean primary key default true,
  bank_name text not null default '',
  account_number text not null default '',
  account_holder text not null default '',
  qr_image_url text,
  updated_at timestamptz not null default now(),
  constraint payment_settings_singleton check (id = true)
);

-- Mật khẩu quản lý duy nhất (không cần tài khoản, không cần email)
create table if not exists public.admin_config (
  id boolean primary key default true,
  password_hash text not null,
  updated_at timestamptz not null default now(),
  constraint admin_config_singleton check (id = true)
);

insert into public.payment_settings (id) values (true)
on conflict (id) do nothing;

-- Mật khẩu quản lý mặc định: 134234
-- (Đổi mật khẩu sau này bằng: update public.admin_config set password_hash = extensions.crypt('MẬT_KHẨU_MỚI', extensions.gen_salt('bf')) where id = true;)
insert into public.admin_config (id, password_hash)
values (true, extensions.crypt('134234', extensions.gen_salt('bf')))
on conflict (id) do nothing;

-- ============================================================
-- 2. INDEX
-- ============================================================

create index if not exists idx_products_category on public.products(category);
create index if not exists idx_product_packages_product_id on public.product_packages(product_id);
create index if not exists idx_redemption_codes_code on public.redemption_codes(code);
create index if not exists idx_store_orders_order_code on public.store_orders(order_code);
create index if not exists idx_store_orders_product_id on public.store_orders(product_id);
create index if not exists idx_payment_claims_status on public.payment_claims(status);
create index if not exists idx_store_orders_created_at on public.store_orders(created_at desc);

-- ============================================================
-- 3. updated_at TRIGGER
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists trg_store_orders_updated_at on public.store_orders;
create trigger trg_store_orders_updated_at
  before update on public.store_orders
  for each row execute function public.set_updated_at();

-- ============================================================
-- 4. XÁC THỰC MẬT KHẨU QUẢN LÝ
-- ============================================================

create or replace function public.admin_authenticate(p_password text)
returns boolean
language sql
security definer
set search_path = public, extensions
stable
as $$
  select exists (
    select 1 from public.admin_config
    where id = true and password_hash = extensions.crypt(coalesce(p_password, ''), password_hash)
  );
$$;

create or replace function public.gen_random_code(p_len integer)
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i integer;
begin
  for i in 1..p_len loop
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  end loop;
  return result;
end;
$$;

-- ============================================================
-- 5. RPC — KHÁCH HÀNG (không cần mật khẩu)
-- ============================================================

create or replace function public.create_store_order(p_package_id uuid)
returns table (
  order_code text,
  product_name text,
  duration_label text,
  amount numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pkg public.product_packages%rowtype;
  v_prod public.products%rowtype;
  v_code text;
  v_order_id uuid;
begin
  select * into v_pkg from public.product_packages where id = p_package_id and active = true;
  if not found then
    raise exception 'Gói sản phẩm không tồn tại hoặc đã ngừng bán';
  end if;

  select * into v_prod from public.products where id = v_pkg.product_id and active = true;
  if not found then
    raise exception 'Sản phẩm không tồn tại hoặc đã ngừng bán';
  end if;

  loop
    v_code := v_prod.code_prefix || '-' || public.gen_random_code(6);
    begin
      insert into public.store_orders (
        order_code, product_id, product_name, package_id, duration_label, amount,
        payment_status, order_status
      ) values (
        v_code, v_prod.id, v_prod.name, v_pkg.id, v_pkg.duration_label, v_pkg.price,
        'pending', 'pending'
      ) returning id into v_order_id;
      exit;
    exception when unique_violation then
      -- mã trùng, thử lại
    end;
  end loop;

  return query
    select v_code, v_prod.name, v_pkg.duration_label, v_pkg.price;
end;
$$;

create or replace function public.claim_order_payment(p_order_code text)
returns table (redemption_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.store_orders%rowtype;
  v_code text;
begin
  select * into v_order from public.store_orders where order_code = p_order_code;
  if not found then
    raise exception 'Không tìm thấy đơn hàng';
  end if;

  if v_order.payment_status <> 'pending' then
    raise exception 'Đơn hàng đã được xử lý trước đó';
  end if;

  update public.store_orders
    set payment_status = 'claimed'
    where id = v_order.id;

  insert into public.payment_claims (store_order_id, amount, status)
  values (v_order.id, v_order.amount, 'pending');

  loop
    v_code := split_part(v_order.order_code, '-', 1) || '-' ||
              public.gen_random_code(4) || '-' || public.gen_random_code(3);
    begin
      insert into public.redemption_codes (code, store_order_id, product_name, status)
      values (v_code, v_order.id, v_order.product_name, 'active');
      exit;
    exception when unique_violation then
      -- mã trùng, thử lại
    end;
  end loop;

  return query select v_code;
end;
$$;

create or replace function public.lookup_code(p_code text)
returns table (
  found boolean,
  order_code text,
  redemption_code text,
  product_name text,
  duration_label text,
  amount numeric,
  payment_status text,
  order_status text,
  redemption_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_order public.store_orders%rowtype;
  v_redemption public.redemption_codes%rowtype;
begin
  select * into v_redemption from public.redemption_codes where code = upper(p_code);
  if found then
    select * into v_order from public.store_orders where id = v_redemption.store_order_id;
  else
    select * into v_order from public.store_orders where order_code = upper(p_code);
  end if;

  if v_order.id is null then
    return query select false, null::text, null::text, null::text, null::text,
      null::numeric, null::text, null::text, null::text, null::timestamptz;
    return;
  end if;

  return query
    select true, v_order.order_code, v_redemption.code, v_order.product_name,
      v_order.duration_label, v_order.amount, v_order.payment_status,
      v_order.order_status, v_redemption.status, v_order.created_at;
end;
$$;

-- ============================================================
-- 6. RPC — QUẢN LÝ (yêu cầu p_admin_password đúng)
-- ============================================================

create or replace function public.admin_list_orders(p_limit integer, p_admin_password text)
returns setof public.store_orders
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;
  return query
    select * from public.store_orders order by created_at desc limit coalesce(p_limit, 100);
end;
$$;

create or replace function public.admin_search_orders(p_query text, p_admin_password text)
returns setof public.store_orders
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;
  return query
    select * from public.store_orders
    where order_code ilike '%'||p_query||'%' or product_name ilike '%'||p_query||'%'
    order by created_at desc
    limit 50;
end;
$$;

create or replace function public.admin_search_code(p_code text, p_admin_password text)
returns table (
  order_code text,
  product_name text,
  duration_label text,
  amount numeric,
  payment_status text,
  order_status text,
  redemption_code text,
  redemption_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.store_orders%rowtype;
  v_redemption public.redemption_codes%rowtype;
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;

  select * into v_redemption from public.redemption_codes where code = upper(p_code);
  if found then
    select * into v_order from public.store_orders where id = v_redemption.store_order_id;
  else
    select * into v_order from public.store_orders where order_code = upper(p_code);
  end if;

  if v_order.id is null then
    return;
  end if;

  return query
    select v_order.order_code, v_order.product_name, v_order.duration_label, v_order.amount,
      v_order.payment_status, v_order.order_status, v_redemption.code, v_redemption.status,
      v_order.created_at;
end;
$$;

create or replace function public.admin_confirm_payment(p_order_code text, p_admin_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;

  update public.store_orders
    set payment_status = 'confirmed', order_status = 'processing'
    where order_code = p_order_code;

  update public.payment_claims
    set status = 'confirmed', confirmed_at = now()
    where store_order_id = (select id from public.store_orders where order_code = p_order_code);
end;
$$;

create or replace function public.admin_reject_payment(p_order_code text, p_admin_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid;
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;

  select id into v_order_id from public.store_orders where order_code = p_order_code;

  update public.store_orders
    set payment_status = 'rejected', order_status = 'cancelled'
    where id = v_order_id;

  update public.payment_claims
    set status = 'rejected'
    where store_order_id = v_order_id;

  update public.redemption_codes
    set status = 'invalid'
    where store_order_id = v_order_id;
end;
$$;

create or replace function public.admin_complete_order(p_order_code text, p_admin_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;

  update public.store_orders
    set order_status = 'completed'
    where order_code = p_order_code;
end;
$$;

create or replace function public.admin_invalidate_code(p_code text, p_admin_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;

  update public.redemption_codes
    set status = 'invalid'
    where code = p_code;
end;
$$;

create or replace function public.admin_save_payment_settings(
  p_bank_name text, p_account_number text, p_account_holder text, p_qr_image_url text, p_admin_password text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;

  update public.payment_settings
    set bank_name = p_bank_name,
        account_number = p_account_number,
        account_holder = p_account_holder,
        qr_image_url = coalesce(p_qr_image_url, qr_image_url),
        updated_at = now()
    where id = true;
end;
$$;

create or replace function public.admin_upsert_product(
  p_id uuid, p_category text, p_code_prefix text, p_name text,
  p_description text, p_active boolean, p_sort_order integer, p_admin_password text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;

  if p_id is null then
    insert into public.products (category, code_prefix, name, description, active, sort_order)
    values (p_category, p_code_prefix, p_name, p_description, p_active, p_sort_order)
    returning id into v_id;
  else
    update public.products
      set category = p_category, code_prefix = p_code_prefix, name = p_name,
          description = p_description, active = p_active, sort_order = p_sort_order
      where id = p_id
      returning id into v_id;
  end if;
  return v_id;
end;
$$;

create or replace function public.admin_upsert_package(
  p_id uuid, p_product_id uuid, p_duration_label text, p_duration_value text,
  p_price numeric, p_active boolean, p_sort_order integer, p_admin_password text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.admin_authenticate(p_admin_password) then
    raise exception 'Sai mật khẩu quản lý';
  end if;

  if p_id is null then
    insert into public.product_packages (product_id, duration_label, duration_value, price, active, sort_order)
    values (p_product_id, p_duration_label, p_duration_value, p_price, p_active, p_sort_order)
    returning id into v_id;
  else
    update public.product_packages
      set duration_label = p_duration_label, duration_value = p_duration_value,
          price = p_price, active = p_active, sort_order = p_sort_order
      where id = p_id
      returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- ============================================================
-- 7. ROW LEVEL SECURITY
-- Toàn bộ thao tác ghi của quản lý đi qua các hàm SECURITY DEFINER
-- ở trên (được xác thực bằng mật khẩu), nên các bảng nghiệp vụ
-- không cần policy ghi cho client — chỉ mở SELECT công khai
-- những gì khách hàng cần thấy trực tiếp.
-- ============================================================

alter table public.products enable row level security;
alter table public.product_packages enable row level security;
alter table public.store_orders enable row level security;
alter table public.redemption_codes enable row level security;
alter table public.payment_claims enable row level security;
alter table public.payment_settings enable row level security;
alter table public.admin_config enable row level security;

drop policy if exists products_public_select on public.products;
create policy products_public_select on public.products
  for select using (active = true);

drop policy if exists products_admin_write on public.products;

drop policy if exists packages_public_select on public.product_packages;
create policy packages_public_select on public.product_packages
  for select using (active = true);

drop policy if exists packages_admin_write on public.product_packages;

drop policy if exists store_orders_admin_only on public.store_orders;
drop policy if exists redemption_codes_admin_only on public.redemption_codes;
drop policy if exists payment_claims_admin_only on public.payment_claims;

drop policy if exists payment_settings_public_select on public.payment_settings;
create policy payment_settings_public_select on public.payment_settings
  for select using (true);

drop policy if exists payment_settings_admin_write on public.payment_settings;

-- admin_config: không cấp SELECT/UPDATE trực tiếp cho client, chỉ
-- truy cập được thông qua admin_authenticate() (SECURITY DEFINER).
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'app_admins') then
    execute 'drop policy if exists app_admins_self_select on public.app_admins';
  end if;
end $$;

-- ============================================================
-- 8. DỌN DẸP CƠ CHẾ ĐĂNG NHẬP CŨ (nếu đã từng chạy bản trước)
-- ============================================================

drop function if exists public.app_is_admin();
drop table if exists public.app_admins;

-- ============================================================
-- 9. REALTIME
-- ============================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'products'
  ) then
    alter publication supabase_realtime add table public.products;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'product_packages'
  ) then
    alter publication supabase_realtime add table public.product_packages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'store_orders'
  ) then
    alter publication supabase_realtime add table public.store_orders;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'redemption_codes'
  ) then
    alter publication supabase_realtime add table public.redemption_codes;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'payment_claims'
  ) then
    alter publication supabase_realtime add table public.payment_claims;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'payment_settings'
  ) then
    alter publication supabase_realtime add table public.payment_settings;
  end if;
end $$;

-- ============================================================
-- 10. STORAGE — QR CHUYỂN KHOẢN
-- Vì quản lý không còn đăng nhập bằng tài khoản Supabase Auth,
-- bucket này cho phép upload/thay QR trực tiếp bằng anon key.
-- Chỉ nên chia sẻ đường dẫn trang /#admin và mật khẩu cho người
-- bạn tin tưởng, vì bất kỳ ai có anon key kỹ thuật đều có thể
-- ghi vào đúng bucket này (không truy cập được các bảng dữ liệu khác).
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('payment-qr', 'payment-qr', true, 5242880, array['image/png','image/jpeg','image/jpg','image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/png','image/jpeg','image/jpg','image/webp'];

drop policy if exists payment_qr_public_read on storage.objects;
create policy payment_qr_public_read on storage.objects
  for select using (bucket_id = 'payment-qr');

drop policy if exists payment_qr_admin_write on storage.objects;
create policy payment_qr_admin_write on storage.objects
  for insert with check (bucket_id = 'payment-qr');

drop policy if exists payment_qr_admin_update on storage.objects;
create policy payment_qr_admin_update on storage.objects
  for update using (bucket_id = 'payment-qr');

drop policy if exists payment_qr_admin_delete on storage.objects;
create policy payment_qr_admin_delete on storage.objects
  for delete using (bucket_id = 'payment-qr');

-- ============================================================
-- 11. DỮ LIỆU SẢN PHẨM BAN ĐẦU (idempotent theo tên sản phẩm)
-- ============================================================

do $$
declare
  v_product_id uuid;
begin
  insert into public.products (category, code_prefix, name, sort_order)
  values ('FLUORITE', 'FLR', 'Fluorite FF', 1)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Fluorite FF';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '1 ngày', 65000, 1),
      (v_product_id, '7 ngày', 180000, 2),
      (v_product_id, '31 ngày', 280000, 3);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('FREE FIRE', 'FF', 'Free Fire', 2)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Free Fire';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '1 giờ', 5000, 1),
      (v_product_id, '1 ngày', 20000, 2),
      (v_product_id, '7 ngày', 50000, 3),
      (v_product_id, '31 ngày', 100000, 4),
      (v_product_id, '999 ngày', 250000, 5);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('FLORK FREE FIRE', 'FLKM', 'Flork FF Max', 3)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Flork FF Max';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '31 ngày', 220000, 1);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('FLORK FREE FIRE', 'FLKT', 'Flork FF Thường', 4)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Flork FF Thường';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '31 ngày', 220000, 1);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('LIÊN QUÂN', 'LQCT', 'Chấp tố', 5)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Chấp tố';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '31 ngày', 250000, 1);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('LIÊN QUÂN', 'LQK', 'Kín', 6)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Kín';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '1 ngày', 15000, 1),
      (v_product_id, '7 ngày', 60000, 2),
      (v_product_id, '31 ngày', 150000, 3);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('MIGUL', 'MGLT', 'Migul Lite', 7)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Migul Lite';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '7 ngày', 150000, 1),
      (v_product_id, '31 ngày', 350000, 2);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('MIGUL', 'MGLP', 'Migul Pro', 8)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Migul Pro';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '1 giờ', 10000, 1),
      (v_product_id, '1 ngày', 65000, 2),
      (v_product_id, '7 ngày', 215000, 3),
      (v_product_id, '31 ngày', 450000, 4);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('TIPA FF', 'LVFF', 'losViet FFM', 9)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'losViet FFM';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '1 ngày', 10000, 1),
      (v_product_id, '7 ngày', 50000, 2),
      (v_product_id, '31 ngày', 140000, 3);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('TIPA FF', 'SUDO', 'Sudo Hax', 10)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Sudo Hax';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '31 ngày', 170000, 1);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('FF ANDROID', 'DRIP', 'Drip Client', 11)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Drip Client';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '1 ngày', 30000, 1),
      (v_product_id, '7 ngày', 90000, 2),
      (v_product_id, '31 ngày', 180000, 3);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('PUBG', 'PBGZ', 'Pubg Dolphy Z', 12)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Pubg Dolphy Z';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '6 giờ', 10000, 1),
      (v_product_id, '1 ngày', 20000, 2),
      (v_product_id, '7 ngày', 150000, 3),
      (v_product_id, '31 ngày', 300000, 4);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('IPA PROXY DELTA', 'IPAD', 'IPA Proxy Delta', 13)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'IPA Proxy Delta';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, price, sort_order) values
      (v_product_id, '1 ngày', 20000, 1),
      (v_product_id, '1 tuần', 40000, 2),
      (v_product_id, '1 tháng', 90000, 3);
  end if;

  insert into public.products (category, code_prefix, name, sort_order)
  values ('KEY TEST FREE', 'KEY', 'Key Test Free', 14)
  on conflict do nothing;
  select id into v_product_id from public.products where name = 'Key Test Free';
  if not exists (select 1 from public.product_packages where product_id = v_product_id) then
    insert into public.product_packages (product_id, duration_label, duration_value, price, sort_order) values
      (v_product_id, 'Proxy IPA Free', 'proxy_ipa', 0, 1),
      (v_product_id, 'Pubg Dolphy Free Key Test PUBG', 'pubg_dolphy', 0, 2),
      (v_product_id, 'Liên Quân Key Test', 'lien_quan', 0, 3),
      (v_product_id, 'Tipa Key Test', 'tipa', 0, 4);
  end if;
end $$;

-- ============================================================
-- HOÀN TẤT
-- Mật khẩu quản lý mặc định: 134234
-- Truy cập trang quản lý bằng cách mở: index.html#admin
-- ============================================================
