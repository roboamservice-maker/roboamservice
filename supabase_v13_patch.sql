-- ROBOAM SERVICE V13 : à exécuter UNE fois APRÈS supabase_v12_complet.sql (SQL Editor)
alter table public.categories add column if not exists image_url text;
-- Sécurité : plus d'insertion directe de commandes (prix/statut falsifiables)
drop policy if exists "users own orders insert" on public.orders;
drop policy if exists "users own order items insert" on public.order_items;
drop policy if exists "payments own insert" on public.payment_transactions;
drop policy if exists "admins products read all" on public.products;
create policy "admins products read all" on public.products for select using (exists(select 1 from public.admin_users a where a.user_id=auth.uid()));

-- Commande atomique : prix et stock vérifiés côté serveur
create or replace function public.create_order(p_items jsonb,p_phone text,p_method text,p_commune text,p_quartier text)
returns bigint language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_total numeric:=0; v_id bigint; it jsonb; pr record; v_prov text; v_q int;
begin
 if v_uid is null then raise exception 'Connexion requise'; end if;
 if p_method not in ('wave','orange','mtn','cash') then raise exception 'Moyen de paiement invalide'; end if;
 if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'Panier vide'; end if;
 v_prov:=case p_method when 'orange' then 'orange_money' when 'mtn' then 'mtn_momo' else p_method end;
 insert into orders(user_id,total,phone,payment_method,delivery_commune,delivery_quartier,delivery_address,payment_status,payment_provider)
 values(v_uid,0,p_phone,p_method,p_commune,p_quartier,p_commune||', '||coalesce(p_quartier,''),case when p_method='cash' then 'cash_on_delivery' else 'pending' end,v_prov) returning id into v_id;
 for it in select * from jsonb_array_elements(p_items) loop
  v_q:=(it->>'qty')::int;
  select * into pr from products where id=(it->>'id')::bigint and active for update;
  if not found then raise exception 'Produit indisponible'; end if;
  if v_q<=0 or pr.stock<v_q then raise exception 'Stock insuffisant : %',pr.name; end if;
  update products set stock=stock-v_q where id=pr.id;
  insert into order_items(order_id,product_id,product_name,quantity,unit_price) values(v_id,pr.id,pr.name,v_q,pr.price);
  v_total:=v_total+pr.price*v_q;
 end loop;
 update orders set total=v_total where id=v_id;
 insert into payment_transactions(order_id,user_id,provider,amount) values(v_id,v_uid,v_prov,v_total);
 return v_id;
end;$$;
grant execute on function public.create_order(jsonb,text,text,text,text) to authenticated;

-- Notes des produits mises à jour automatiquement
create or replace function public.refresh_rating() returns trigger language plpgsql security definer set search_path=public as $$
declare pid bigint:=coalesce(new.product_id,old.product_id);
begin
 update products set rating=coalesce((select round(avg(rating),1) from product_reviews where product_id=pid),0),
  review_count=(select count(*) from product_reviews where product_id=pid) where id=pid;
 return null;
end;$$;
drop trigger if exists trg_rating on public.product_reviews;
create trigger trg_rating after insert or update or delete on public.product_reviews for each row execute function public.refresh_rating();
