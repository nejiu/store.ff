-- ============================================================
-- PHẦN 1: THÊM CỘT is_addon
-- Cột này đánh dấu sản phẩm nào thuộc nhóm "Kho Files" (mục bổ
-- sung, gộp lại một chỗ, khách bấm mới hiện ra) thay vì hiện
-- thẳng ngoài trang chủ như các sản phẩm chính.
-- ============================================================
alter table public.products
  add column if not exists is_addon boolean not null default false;

-- ============================================================
-- PHẦN 2: THÊM CÁC SẢN PHẨM MỚI TỪ BẢNG GIÁ (đều is_addon = true
-- nên sẽ tự động nằm trong khối "📦 KHO FILES" có thể thu gọn)
-- Mỗi sản phẩm có 1 gói giá duy nhất (không có nhiều mốc thời hạn).
--
-- LƯU Ý: cột "code_prefix" trong bảng products là NOT NULL nên
-- mỗi sản phẩm mới đều phải có 1 giá trị code_prefix riêng.
-- ============================================================
do $$
declare
  v_id uuid;
begin
  -- FILE CƠ BẢN
  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('File Cơ Bản', 'File Thường', 'Mượt máy, nhẹ tâm', 1, true, true, 'FTHUONG')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 50000, true, 1);

  -- FILE AIM
  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('File AIM', 'AIM Bụng', 'Auto full đỏ khi bắn vào bụng', 1, true, true, 'AIMBUNG')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 100000, true, 1);

  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('File AIM', 'AIM Neck', 'Headshot khi bắn vào vùng cổ', 2, true, true, 'AIMNECK')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 80000, true, 1);

  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('File AIM', 'AIM Drag', 'Tăng phạm vi kéo tâm vào đầu, tối ưu headshot', 3, true, true, 'AIMDRAG')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 80000, true, 1);

  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('File AIM', 'AIM Magic', 'Đạn ma thuật đen, xuyên tâm, bách phát bách trúng', 4, true, true, 'AIMMAGIC')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 70000, true, 1);

  -- DPI
  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('DPI', 'DPI Chuẩn', 'Kéo tâm ổn định, dễ kiểm soát', 1, true, true, 'DPICHUAN')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 100000, true, 1);

  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('DPI', 'DPI Pro', 'Siêu nhẹ tâm, kéo dính đầu hơn', 2, true, true, 'DPIPRO')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 150000, true, 1);

  -- MOD SKIN
  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('Mod Skin', 'Mod Skin Theo Yêu Cầu', 'Mod skin theo yêu cầu', 1, true, true, 'MODSKIN')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 50000, true, 1);

  -- CHỨNG CHỈ IPHONE
  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('Chứng Chỉ iPhone', 'Chứng Chỉ iPhone', 'Không bảo hành', 1, true, true, 'CCIP')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 50000, true, 1);

  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('Chứng Chỉ iPhone', 'Chứng Chỉ (Bảo hành)', 'Bảo hành 30 ngày', 2, true, true, 'CCIPBH')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 100000, true, 1);

  -- FILE ORDER
  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('File Order', 'File Order', 'Chức năng tự order, bám đầu tối thiểu 90%', 1, true, true, 'FORDER')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 300000, true, 1);

  -- FILE ĐẶC BIỆT
  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('File Đặc Biệt', 'File Đặc Biệt', 'Tối ưu toàn diện, bám đầu từ 80-100%', 1, true, true, 'FDACBIET')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 200000, true, 1);

  -- FILE SUPER
  insert into public.products (category, name, description, sort_order, active, is_addon, code_prefix)
  values ('File Super', 'File Super', 'Siêu ổn định, bám đầu từ 95-100%', 1, true, true, 'FSUPER')
  returning id into v_id;
  insert into public.product_packages (product_id, duration_label, price, active, sort_order)
  values (v_id, 'Trọn gói', 250000, true, 1);
end $$;

-- ============================================================
-- PHẦN 3: HÀM QUẢN LÝ TỒN KHO (CÒN HÀNG / HẾT HÀNG)
-- Thay vì đoán cách bạn kiểm tra mật khẩu bên trong các hàm
-- admin_ khác, 2 hàm dưới đây TÁI SỬ DỤNG chính hàm
-- admin_list_orders() đang chạy tốt để xác thực mật khẩu: nếu
-- mật khẩu sai, admin_list_orders() sẽ tự báo lỗi và toàn bộ
-- hàm dừng lại ngay — không cần biết cơ chế xác thực gốc là gì,
-- và tự động ăn khớp 100% với cách bạn đã đặt mật khẩu quản lý.
-- ============================================================
create or replace function public.admin_list_all_products(p_admin_password text)
returns table (id uuid, category text, name text, active boolean, sort_order int)
language plpgsql
security definer
as $$
begin
  -- Xác thực mật khẩu bằng cách gọi lại hàm admin_ đã có sẵn.
  -- Nếu sai mật khẩu, dòng này tự raise exception và dừng hàm.
  perform public.admin_list_orders(p_limit := 1, p_admin_password := p_admin_password);

  return query
    select p.id, p.category, p.name, p.active, p.sort_order
    from public.products p
    order by p.category, p.sort_order;
end;
$$;

create or replace function public.admin_set_product_stock(
  p_product_id uuid,
  p_active boolean,
  p_admin_password text
)
returns void
language plpgsql
security definer
as $$
begin
  -- Xác thực mật khẩu bằng cách gọi lại hàm admin_ đã có sẵn.
  perform public.admin_list_orders(p_limit := 1, p_admin_password := p_admin_password);

  update public.products set active = p_active where id = p_product_id;
end;
$$;
