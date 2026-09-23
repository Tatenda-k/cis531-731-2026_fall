import torch

print("PyTorch version:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("GPU Pool Active - Batch Embedding/Whisper Ready")
    print("GPU:", torch.cuda.get_device_name(0))
else:
    print("CPU-Only Fallback Active")