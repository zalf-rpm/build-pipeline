import torch
import torch.nn as nn
import os
print("CUDA_VISIBLE_DEVICES:", os.environ.get("CUDA_VISIBLE_DEVICES"))

print("CUDA available:", torch.cuda.is_available())
print("GPU count:", torch.cuda.device_count())
if torch.cuda.is_available():
    for i in range(torch.cuda.device_count()):
        print(f"GPU {i}: {torch.cuda.get_device_name(i)}")

# Simple model
class TinyNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.linear = nn.Linear(10, 1)
    def forward(self, x):
        return self.linear(x)
    
device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

model = TinyNet().to(device)
print("Model loaded on", device)

# Run forward pass
x = torch.randn(4, 10).to(device)
y = model(x)

print("Output:", y)
print("Success — GPU is working!")