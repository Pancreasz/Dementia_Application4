"""Empirically establish the clock preprocessing transform.

The original PyTorch training script is lost, so the correct preprocessing is
unknown and must be recovered against the four labelled images
clock_0..3.png (filename == correct score). This runs the three candidate
transforms from the handout against those four images and reports which fits.

Honest interpretation (from the handout):
  - 4/4 across four classes happens by chance ~0.4% of the time, so it is
    meaningful evidence the transform is *plausible* — not that the model is
    accurate. Four images is not a test set.
  - If two transforms both score 4/4, prefer #1 (ImageNet Normalize) and say so.
  - If NONE scores 4/4, stop. A 2/4 or 3/4 transform is a model returning
    confident nonsense, not "mostly right". Report and do not ship.

Run:  python scripts/validate_clock.py     (from the backend/ directory)
"""

from __future__ import annotations

import os
import sys

import torch
from PIL import Image
from torchvision import transforms

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from clock import build_model  # noqa: E402

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEIGHTS = os.path.join(BACKEND_DIR, "moca_densenet.pth")
IMG_SIZE = 224

_RESIZE = transforms.Resize((IMG_SIZE, IMG_SIZE))
_TO_TENSOR = transforms.ToTensor()
_IMAGENET = transforms.Normalize(
    mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
)

CANDIDATES = {
    "1: Resize+ToTensor+ImageNetNorm": transforms.Compose([_RESIZE, _TO_TENSOR, _IMAGENET]),
    "2: Resize+ToTensor only [0,1]": transforms.Compose([_RESIZE, _TO_TENSOR]),
    "3: Resize+ToTensor*255 (raw 0-255)": transforms.Compose(
        [_RESIZE, _TO_TENSOR, transforms.Lambda(lambda t: t * 255.0)]
    ),
}


def load_model():
    model = build_model()
    model.load_state_dict(torch.load(WEIGHTS, map_location="cpu"))
    model.eval()
    return model


def score_all(model, transform):
    preds = {}
    for label in range(4):
        path = os.path.join(BACKEND_DIR, f"clock_{label}.png")
        image = Image.open(path).convert("RGB")
        tensor = transform(image).unsqueeze(0)
        with torch.no_grad():
            pred = int(torch.argmax(model(tensor), dim=1).item())
        preds[label] = pred
    return preds


def main():
    if not os.path.exists(WEIGHTS):
        sys.exit(f"weights not found at {WEIGHTS}; run scripts/restore_weights.py")

    model = load_model()
    print("Validating clock preprocessing against clock_0..3.png\n")

    winners = []
    for name, transform in CANDIDATES.items():
        preds = score_all(model, transform)
        correct = sum(1 for label, pred in preds.items() if label == pred)
        detail = "  ".join(f"clock_{k}->{v}" for k, v in preds.items())
        print(f"[{correct}/4] {name}")
        print(f"        {detail}")
        if correct == 4:
            winners.append(name)

    print()
    if not winners:
        print("RESULT: no transform scored 4/4. STOP — do not ship the closest fit.")
        print("The model is returning confident wrong scores. Report this.")
        sys.exit(2)

    chosen = winners[0]  # dict preserves insertion order -> #1 preferred
    print(f"RESULT: 4/4 with -> {chosen}")
    if len(winners) > 1:
        print(f"(Multiple 4/4: {winners}. Preferring #1 per the handout.)")
    print("Four images means 'plausible', not 'accurate'. Accuracy needs a test set.")


if __name__ == "__main__":
    main()
