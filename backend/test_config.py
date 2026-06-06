import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.append('..')

# Test config import
from config import Config

print("=" * 50)
print("Config Test from Backend Directory")
print("=" * 50)
print(f"GOOGLE_API_KEY found: {'Yes' if Config.GOOGLE_API_KEY else 'No'}")
if Config.GOOGLE_API_KEY:
    print(f"API Key length: {len(Config.GOOGLE_API_KEY)}")
    print(f"API Key preview: {Config.GOOGLE_API_KEY[:10]}...")
else:
    print("API Key is None or empty")
print(f"GEMINI_MODEL: {Config.GEMINI_MODEL}")
print(f"BASE_PROMPT length: {len(Config.BASE_PROMPT) if Config.BASE_PROMPT else 0}")
print(f"Validation: {'PASSED' if Config.validate_required() else 'FAILED'}")
print("=" * 50)

