-- Enable the pgvector extension
create extension if not exists vector;

-- Create the documentation chunks table
create table public.documents (
  id bigserial not null,
  file_name character varying not null,
  title character varying null,
  summary character varying null,
  content text null,
  metadata jsonb null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint documents_pkey primary key (id)
) TABLESPACE pg_default;

-- Create the documentation chunks table
create table public.chunks (
  id bigserial not null,
  doc_id bigint not null,
  chunk_number integer not null,
  title character varying null,
  summary character varying null,
  content text null,
  metadata jsonb null default '{}'::jsonb,
  embedding public.vector null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  constraint chunks_pkey primary key (id),
  constraint chunks_doc_id_chunk_number_key unique (doc_id, chunk_number),
  constraint chunks_doc_id_fkey foreign KEY (doc_id) references documents (id)
) TABLESPACE pg_default;

create index IF not exists chunks_embedding_idx on public.chunks using ivfflat (embedding vector_cosine_ops) TABLESPACE pg_default;

create index IF not exists idx_chunks_metadata on public.chunks using gin (metadata) TABLESPACE pg_default;


-- Create a function to search for documentation chunks
create function match_chunks (
  query_embedding vector(1536),
  match_count int default 10,
  filter jsonb DEFAULT '{}'::jsonb
) returns table (
  id bigint,
  doc_id bigint,
  chunk_number integer,
  title varchar,
  summary varchar,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    doc_id,
    chunk_number,
    title,
    summary,
    content,
    metadata,
    1 - (site_pages.embedding <=> query_embedding) as similarity
  from chunks
  where metadata @> filter
  order by site_pages.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- Everything above will work for any PostgreSQL database. The below commands are for Supabase security

-- Enable RLS on the table
alter table site_pages enable row level security;

-- Create a policy that allows anyone to read
create policy "Allow public read access documents"
  on documents
  for select
  to public
  using (true);
create policy "Allow public read access documents"
  on chunks
  for select
  to public
  using (true);
