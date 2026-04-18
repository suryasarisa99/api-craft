import base64
import frida
import sys
import json
import argparse
import time

PREFIX = "DART_DATA:"

def send_to_dart(data_dict):
    try:
        json_str = json.dumps(data_dict)
        print(f"{PREFIX}{json_str}", flush=True)
    except Exception as e:
        print(f"{PREFIX}" + json.dumps({"type": "fatal", "msg": f"Serialization error: {e}"}), flush=True)

def on_message(message, data):
    if message['type'] == 'send':
        payload = message['payload']
        # If the JS sends a list/app info, we pass it through
        send_to_dart({
            "type": "app_list_item" if "icon" in payload else "message",
            "payload": payload
        })
    elif message['type'] == 'error':
        send_to_dart({
            "type": "error",
            "description": message.get('description', 'Unknown Error'),
            "stack": message.get('stack', '')
        })

def list_apps_no_icons(device):
    """
    Standard Frida enumeration. Fast, but NO ICONS.
    """
    try:
        # device.enumerate_applications() is the python equivalent of 'frida-ps -Uai'
        apps = device.enumerate_applications()
        
        # Notify Dart about the total count
        # send_to_dart({"type": "message", "payload": {"total": len(apps)}})

        send_to_dart({
            "type": "app_list",
            "payload": [
                {"name": app.name, "id": app.identifier} for app in apps
            ]
        })
        # for app in apps:
        #     send_to_dart({
        #         "type": "app_list_item",
        #         "payload": {
        #             "name": app.name,
        #             "id": app.identifier,
        #         }
        #     })

    except Exception as e:
        send_to_dart({"type": "fatal", "msg": f"Failed to list apps: {str(e)}"})

def list_apps(device):
    try:
        # Native API with scope='full' fetches icons automatically
        # This is what 'frida-ps -Uai' uses.
        apps = device.enumerate_applications(scope='full')
        
        send_to_dart({"type": "apps_count", "payload": len(apps)})

        for app in apps:
            icon_b64 = ""
            
            # Extract Icon
            # Frida returns icons in the 'parameters' dictionary
            params = app.parameters if hasattr(app, 'parameters') else {}
            icons = params.get('icons', [])
            
            # Find the best PNG icon
            if icons:
                for icon in icons:
                    if icon.get('format') == 'png' and 'image' in icon:
                        # Convert binary bytes to Base64 string
                        icon_bytes = icon['image']
                        icon_b64 = base64.b64encode(icon_bytes).decode('utf-8')
                        break
                
                # Fallback: take the first icon if no PNG found
                if not icon_b64 and len(icons) > 0 and 'image' in icons[0]:
                     icon_b64 = base64.b64encode(icons[0]['image']).decode('utf-8')

            send_to_dart({
                "type": "app_list_item",
                "payload": {
                    "name": app.name,
                    "id": app.identifier,
                    "pid": app.pid if app.pid != 0 else None,
                    "icon": icon_b64
                }
            })

    except Exception as e:
        send_to_dart({"type": "fatal", "msg": f"Failed to list apps: {e}"})

def run_hook(device, package, script_content):
    pid = device.spawn([package])
    session = device.attach(pid)
    session.on('detached', lambda r, c: send_to_dart({"type": "detached", "reason": str(r)}))
    
    script = session.create_script(script_content)
    script.on('message', on_message)
    script.load()
    
    device.resume(pid)
    
    send_to_dart({"type": "status", "msg": f"Attached to {package} (PID: {pid})"})
    sys.stdin.read()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--action", choices=['hook', 'list_apps','list_apps_no_icons'], default='hook')
    parser.add_argument("--device", required=True)
    parser.add_argument("--package", default="")
    parser.add_argument("--script", default="")
    args = parser.parse_args()

    try:
        # Connect Device
        device = None
        if args.device == 'usb':
            device = frida.get_usb_device()
        elif args.device == 'remote':
            device = frida.get_remote_device()
        else:
            try:
                device = frida.get_device(args.device)
            except:
                device = frida.get_usb_device()

        if args.action == 'list_apps':
            list_apps(device)
        elif args.action == 'list_apps_no_icons':
            list_apps_no_icons(device)
        else:
            run_hook(device, args.package, args.script)

    except Exception as e:
        send_to_dart({"type": "fatal", "msg": str(e)})

if __name__ == '__main__':
    main()