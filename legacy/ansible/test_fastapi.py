import httpx
import sys
import os
import re
import time

def get_ips():
    """Manually parses hosts.ini to avoid configparser whitespace issues."""
    if not os.path.exists('hosts.ini'):
        print("Error: hosts.ini not found in current directory.")
        sys.exit(1)
        
    pub_ip = None
    priv_ip = None
    
    try:
        with open('hosts.ini', 'r') as f:
            lines = f.readlines()
            
        in_fastapi_section = False
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
            if line == '[fastapi]':
                in_fastapi_section = True
                continue
            
            if in_fastapi_section and line.startswith('['):
                # We've entered a new section without finding the IP
                break
                
            if in_fastapi_section:
                # This is the host line
                parts = line.split()
                # The first part is always the public-facing address
                pub_ip = parts[0]
                
                # Use regex to find private_ip=... anywhere in the line
                match = re.search(r'private_ip=([0-9.]+)', line)
                if match:
                    priv_ip = match.group(1)
                break

        if not pub_ip or not priv_ip:
            raise ValueError(f"Could not extract IPs. Found Pub: {pub_ip}, Priv: {priv_ip}")
            
        return pub_ip, priv_ip
        
    except Exception as e:
        print(f"Error parsing hosts.ini: {e}")
        sys.exit(1)

def populate_data(pub_ip, priv_ip, count=20):
    """Generates hits to make the dashboard charts look active."""
    print(f"\n--- Populating Dashboard with {count} hits ---")
    with httpx.Client(timeout=5.0) as client:
        for i in range(count):
            try:
                # Increment Public
                client.get(f"http://{pub_ip}:8000/status")
                # Increment Secure
                client.get(f"http://{priv_ip}:8000/secure-status")
                print(f"  Progress: {i+1}/{count}", end="\r")
                # Small sleep to ensure timestamps in history are slightly spread out
                time.sleep(0.1) 
            except Exception as e:
                print(f"\n  Error during population at hit {i+1}: {e}")
                break
    print("\nDone! Refresh your browser at http://{}:8000 to see the results.".format(pub_ip))

def test_api():
    pub_ip, priv_ip = get_ips()
    print(f"--- Inventory Loaded ---")
    print(f"Detected Public IP:  {pub_ip}")
    print(f"Detected Private IP: {priv_ip}")
    print("-" * 35)

    with httpx.Client(timeout=5.0) as client:
        # TASK 1: Public /status
        print("\n[TASK 1] Testing Public /status...")
        try:
            url = f"http://{pub_ip}:8000/status"
            r = client.get(url)
            print(f"  URL: {url}")
            print(f"  Status: {r.status_code}")
            print(f"  Response: {r.text}")
        except Exception as e:
            print(f"  FAILED: {e}")

        # TASK 2: Secure /secure-status (via VPN)
        print("\n[TASK 2] Testing Secure /secure-status (via VPN)...")
        try:
            url = f"http://{priv_ip}:8000/secure-status"
            r = client.get(url)
            print(f"  URL: {url}")
            print(f"  Status: {r.status_code}")
            print(f"  Response: {r.text}")
        except httpx.ConnectTimeout:
            print("  TIMEOUT: Cannot reach Private IP. WireGuard active?")
        except Exception as e:
            print(f"  ERROR: {e}")

        # SECURITY: Verify 403 on Public IP
        print("\n[SECURITY] Testing Secure endpoint via Public IP...")
        try:
            url = f"http://{pub_ip}:8000/secure-status"
            r = client.get(url)
            print(f"  URL: {url}")
            print(f"  Status: {r.status_code}")
            if r.status_code == 403:
                print("  PASS: Access Denied (Correct).")
            else:
                print(f"  WARN: Got {r.status_code}, expected 403.")
        except Exception as e:
            print(f"  ERROR: {e}")

    # CALL THE POPULATE FUNCTION HERE
    populate_data(pub_ip, priv_ip)

if __name__ == "__main__":
    test_api()
