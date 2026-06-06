import google.generativeai as genai
from config import Config

#adding tts here
import requests
import urllib.parse
import platform
import subprocess
import os

def Model_speak(text):
    # Free StreamElements voice
    voice = "Joanna"
    encoded = urllib.parse.quote(text)
    url = f"https://api.streamelements.com/kappa/v2/speech?voice={voice}&text={encoded}"

    print(f"[MODEL] Speaking: {text}")
    response = requests.get(url)
    print("voice response generated..")

    if response.status_code == 200:
        with open("model_voice.mp3", "wb") as f:
            f.write(response.content)
        
        # Cross-platform audio playback
        if platform.system() == "Windows":
            os.startfile("model_voice.mp3")
        else:
            subprocess.run(["mpg123", "model_voice.mp3"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("done..")
    else:
        print(" Voice generation failed. Check your internet connection.")

# Validate required configuration
if not Config.validate_required():
    exit(1)

#Google LLM API
genai.configure(api_key=Config.GOOGLE_API_KEY)
model = genai.GenerativeModel(Config.GEMINI_MODEL)

#Prompting and context inserting
prompt = input("Enter your query: ") # it's your prompt here 
full_prompt = Config.BASE_PROMPT + prompt
response = model.generate_content(full_prompt)
Model_speak(response.text)

