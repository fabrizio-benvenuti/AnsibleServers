import eventlet
from eventlet.green import subprocess
from flask_socketio import SocketIO 

SERVERS = {
    'server1': '192.168.1.201',
    'server2': '192.168.1.204'
}
STATUS = {name: 'Unknown' for name in SERVERS}
PROCESS_LOCKS = {name: eventlet.semaphore.Semaphore(1) for name in SERVERS}
CURRENT_PROCESSES = {}

def monitor_servers():
    while True:
        for name, ip in SERVERS.items():
            result = subprocess.run(['ping', '-c', '1', '-W', '1', ip], stdout=subprocess.DEVNULL)
            STATUS[name] = 'Online' if result.returncode == 0 else 'Offline'
        eventlet.sleep(5)  # Check every 5 seconds

def get_server_status():
    return STATUS

def start_script_for_server(server, action, socketio):
    script = '/init/power_on.sh' if action == 'on' else '/init/power_off.sh'
    ip = SERVERS[server]

    # Only start if the lock is not already acquired
    if not PROCESS_LOCKS[server].locked():
        def run():
            with PROCESS_LOCKS[server]:
                if CURRENT_PROCESSES.get(server):
                    CURRENT_PROCESSES[server].terminate()
                    CURRENT_PROCESSES[server].wait()

                proc = subprocess.Popen(
                    ['stdbuf', '-oL', '-eL', script, ip],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                CURRENT_PROCESSES[server] = proc

                for line in iter(proc.stdout.readline, ''):
                    print(f"Emitting: {line.strip()}", flush=True)
                    socketio.emit(
                        'script_output',
                        {'server': server, 'line': line.rstrip()},
                    )
                    eventlet.sleep(0.1)

                proc.stdout.close()

                for line in iter(proc.stderr.readline, ''):
                    print(f"Emitting ERROR: {line.strip()}", flush=True)
                    socketio.emit(
                        'script_output',
                        {'server': server, 'line': f"ERROR: {line.rstrip()}"},
                    )
                    eventlet.sleep(0.1)

                proc.stderr.close()
                proc.wait()
                CURRENT_PROCESSES.pop(server, None)
                socketio.emit('command_finished', {'server': server})

        socketio.start_background_task(run)
    else:
        print(f"Command ignored: {server} is busy.", flush=True)
        socketio.emit('command_ignored', {'server': server})
