-- Enable the pgvector extension
create extension if not exists vector;

-- Create the documentation chunks table
create table document_chunks (
    id bigserial not null,
    file_name varchar not null,
    chunk_number integer not null,
    title varchar null,
    summary varchar null,
    content text null,  -- Added content column
    metadata jsonb null default '{}'::jsonb,  -- Added metadata column
    embedding vector(1536),  -- OpenAI embeddings are 1536 dimensions
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    constraint chunks_pkey primary key (id),
    -- Add a unique constraint to prevent duplicate chunks for the same URL
    constraint document_chunks_file_name_chunk_number_key unique(file_name, chunk_number)
) TABLESPACE pg_default;

-- Create an index for better vector similarity search performance
create index IF not exists chunks_embedding_idx on public.document_chunks using ivfflat (embedding vector_cosine_ops) TABLESPACE pg_default;

-- Create an index on metadata for faster filtering
create index IF not exists idx_chunks_metadata on public.document_chunks using gin (metadata) TABLESPACE pg_default;

-- Create a function to search for documentation chunks
create function match_chunks (
  query_embedding vector(1536),
  match_count int default 10,
  filter jsonb DEFAULT '{}'::jsonb
) returns table (
  id bigint,
  file_name varchar,
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
    file_name,
    chunk_number,
    title,
    summary,
    content,
    metadata,
    1 - (site_pages.embedding <=> query_embedding) as similarity
  from document_chunks
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
  on document_chunks
  for select
  to public
  using (true);
