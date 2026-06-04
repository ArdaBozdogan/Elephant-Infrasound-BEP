import queue
import threading
import sounddevice as sd
import numpy as np
import time
from ULTRABASS_ALGO_python import process_buffer

"""

This part can be uncommented when this system is being used in the field.

def recorder_thread(q):
    
    fs = 44100
    chunk_size = fs

    while True:
        chunk = sd.rec(chunk_size, samplerate=fs, channels=1, dtype='float32')
        sd.wait()
        q.put(chunk)
        
"""

def recorder_thread(q):
    fs = 44100
    chunk_size = fs
    t = 0
    while True:
        samples = np.arange(chunk_size) / fs + t
        chunk = 0.5 * np.sin(2 * np.pi * 15 * samples).reshape(-1, 1)
        t += chunk_size / fs
        q.put(chunk)
        time.sleep(1)


def processor_thread(q):
    fs = 44100
    buffer = []
    
    while True:
        # Drain excess chunks to keep only the 2 most recent so the queue isn't stuck
        while q.qsize() > 2:
            q.get()  # discard unused chunk

        for i in range(2):
            chunk = q.get()
            buffer.append(chunk)
        
        #this is to combine chunks into one array
        audio = np.concatenate(buffer).flatten()
        buffer = []
        
        #processing
        final_sig = process_buffer(audio, fs)
        
        #playback
        sd.play(final_sig.astype(np.float32), samplerate=fs)
        sd.wait()

if __name__ == "__main__":
    q = queue.Queue()
    t1 = threading.Thread(target=recorder_thread, args=(q,))
    t2 = threading.Thread(target=processor_thread, args=(q,))
    t1.start()
    t2.start()


