import os
from dotenv import load_dotenv
from pathlib import Path

# Get the directory where this config.py file is located
BASE_DIR = Path(__file__).resolve().parent

# Load .env file from the same directory as config.py
env_path = BASE_DIR / '.env'
load_dotenv(dotenv_path=env_path)

class Config:
    GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
    GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    BASE_PROMPT = os.getenv("BASE_PROMPT", "Act as an ai mother which is playing a role of a doctor and answer me in that reference, do not add any extra details be concise, answer in short phrase in around 1 to 2 paragraphs, ")
    
    @classmethod
    def validate_required(cls):
        if not cls.GOOGLE_API_KEY:
            print("Error: GOOGLE_API_KEY not set!")
            return False
        return True

