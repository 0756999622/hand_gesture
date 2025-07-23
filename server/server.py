import asyncio
import websockets
import pyautogui
import logging
import json
import signal

# Disable pyautogui failsafe to avoid interruption
pyautogui.FAILSAFE = False

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

# Map commands to keyboard keys and descriptions
COMMAND_MAP = {
    'start_slide': ('f5', 'Start Slide Show (Full Screen)'),
    'next_slide': ('right', 'Next Slide'),
    'previous_slide': ('left', 'Previous Slide'),
    'stop_slide': ('esc', 'Stop Slide Show / Exit Full Screen'),
    'pause_slide': ('space', 'Pause Slide'),
    'end_slide': ('esc', 'End Slide Show'),
    'blackout': ('b', 'Blackout Screen'),
}

async def handle_command(command):
    key_action = COMMAND_MAP.get(command)
    if not key_action:
        logging.warning(f"Unknown command received: {command}")
        return f"Unknown command: {command}"

    key, action_name = key_action
    try:
        pyautogui.press(key)
        logging.info(f"Performed action: {action_name}")
        return f"Action performed: {action_name}"
    except Exception as e:
        logging.error(f"Error performing {action_name}: {e}")
        return f"Error performing {action_name}: {e}"

async def handler(websocket):
    client_ip = websocket.remote_address[0]
    logging.info(f"Client connected: {client_ip}")
    try:
        async for message in websocket:
            logging.info(f"Received message: {message}")
            try:
                data = json.loads(message)
                command = data.get('command')
            except json.JSONDecodeError:
                logging.warning("Invalid JSON received")
                command = None

            if command:
                response = await handle_command(command)
            else:
                response = "Invalid command format"

            await websocket.send(response)
    except websockets.ConnectionClosed:
        logging.info(f"Client disconnected: {client_ip}")
    except Exception as e:
        logging.error(f"Error in handler: {e}")

def shutdown(loop):
    logging.info("Shutting down server gracefully...")
    for task in asyncio.all_tasks(loop):
        task.cancel()
    loop.stop()

async def main():
    logging.info("Starting WebSocket server on ws://0.0.0.0:5000")
    async with websockets.serve(handler, "0.0.0.0", 5000):
        logging.info("Server listening on 0.0.0.0:5000")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, lambda: shutdown(loop))
    except NotImplementedError:
        # Windows may not support signal handlers in some environments
        pass

    try:
        loop.run_until_complete(main())
    except KeyboardInterrupt:
        logging.info("Server stopped by user")
    except Exception as e:
        logging.error(f"Server error: {e}")
    finally:
        loop.close()
        logging.info("Event loop closed")
