-- Ensure Admin > Live receives cross-device session inserts, heartbeats,
-- sign-outs, and force-logouts. Realtime is disabled by default for newly
-- exposed tables, so keep this guard even though a fresh 0001 install adds it.
do $$
begin
  if not exists (
    select 1
    from pg_publication_rel publication_relation
    join pg_publication publication
      on publication.oid = publication_relation.prpubid
    join pg_class relation
      on relation.oid = publication_relation.prrelid
    join pg_namespace schema
      on schema.oid = relation.relnamespace
    where publication.pubname = 'supabase_realtime'
      and schema.nspname = 'public'
      and relation.relname = 'active_sessions'
  ) then
    alter publication supabase_realtime add table public.active_sessions;
  end if;
end
$$;
