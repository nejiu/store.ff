-- ============================================================
-- SCRIPT DỌN DẸP TỰ ĐỘNG — CHẠY 1 LẦN LÀ XONG
-- ============================================================

-- BƯỚC A: ẨN các sản phẩm chưa có gói giá nào đang active
-- (không xoá, chỉ ẩn khỏi trang web — có thể bật lại sau khi
--  bạn thêm giá bằng cách sửa active = true trong bảng products)
update public.products p
set active = false
where not exists (
  select 1 from public.product_packages pk
  where pk.product_id = p.id and pk.active = true
);

-- BƯỚC B: XOÁ các sản phẩm bị trùng tên trong cùng category,
-- chỉ giữ lại 1 bản tốt nhất mỗi nhóm (ưu tiên: nhiều gói giá
-- active nhất, rồi đến bản được tạo sớm nhất)
with ranked as (
  select
    p.id,
    row_number() over (
      partition by p.category, p.name
      order by
        (select count(*) from public.product_packages pk
         where pk.product_id = p.id and pk.active = true) desc,
        p.created_at asc
    ) as rn
  from public.products p
),
to_delete as (
  select id from ranked where rn > 1
)
delete from public.product_packages
where product_id in (select id from to_delete);

with ranked as (
  select
    p.id,
    row_number() over (
      partition by p.category, p.name
      order by
        (select count(*) from public.product_packages pk
         where pk.product_id = p.id and pk.active = true) desc,
        p.created_at asc
    ) as rn
  from public.products p
),
to_delete as (
  select id from ranked where rn > 1
)
delete from public.products
where id in (select id from to_delete);

-- BƯỚC C: XEM KẾT QUẢ SAU KHI DỌN
select category, name, active, id
from public.products
order by category, name;
