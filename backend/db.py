from supabase import create_client, Client
import os
from dotenv import load_dotenv
from pathlib import Path

# Load .env from parent directory (where config.py is located)
BASE_DIR = Path(__file__).resolve().parent.parent
env_path = BASE_DIR / '.env'
load_dotenv(dotenv_path=env_path)

# Support both naming conventions
SUPABASE_URL = os.getenv("SUPABASE_URL") or os.getenv("SUPABASE_PROJECT_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY") or os.getenv("SUPABASE_API_KEY")

# Create supabase client only if credentials are provided
supabase = None
if SUPABASE_URL and SUPABASE_KEY and SUPABASE_URL != "your_supabase_url_here" and SUPABASE_KEY != "your_supabase_anon_key_here":
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("Supabase client initialized successfully")
else:
    print("Warning: Supabase credentials not configured. Database features will be disabled.")
