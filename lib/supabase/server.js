import { createClient as createSupabaseClient } from "@supabase/supabase-js";

/**
 * Membuat koneksi Supabase di sisi server menggunakan kredensial rahasia (service role).
 * Hanya boleh digunakan di Server Component, Server Action, atau Route Handler.
 */
export function createServerClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseSecretKey = process.env.SUPABASE_SECRET_KEY;

  if (!supabaseUrl || !supabaseSecretKey) {
    throw new Error(
      "SUPABASE_URL dan SUPABASE_SECRET_KEY harus diatur di environment variable."
    );
  }

  return createSupabaseClient(supabaseUrl, supabaseSecretKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export const createClient = createServerClient;
export const getSupabaseServer = createServerClient;

// Proxy agar bisa langsung dipanggil seperti `supabase.from(...)`
export const supabase = new Proxy(
  {},
  {
    get(_target, prop) {
      const client = createServerClient();
      const value = client[prop];
      return typeof value === "function" ? value.bind(client) : value;
    },
  }
);

export default supabase;

