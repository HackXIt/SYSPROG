gcc -o server_shm server_shm.c
gcc -o client_shm client_shm.c

# Example-Execution server_shm
# ./server_shm 
# Server läuft mit Shared-Memory-ID 360939526
# Warte ...

# Example-Execution client_shm
# ./client_shm 360939526
# Client: Shared-Memory-ID: 360939526, Semaphor-ID: 12345
# Menu
# 1. Eine Nachricht verschicken
# 2. Client-Ende
# 1
# Warte ...
# ... fertig
# Eingabe machen: Hallo, das geht durch den gemeinsamen Speicher
# Menu
# 1. Eine Nachricht verschicken
# 2. Client-Ende
