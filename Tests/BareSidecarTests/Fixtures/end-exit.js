Bare.IPC.on('close', () => setTimeout(() => Bare.exit(3), 200))
Bare.IPC.end()
