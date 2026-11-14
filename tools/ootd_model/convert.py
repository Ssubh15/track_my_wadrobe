"""Convert mattmdjaga/segformer_b2_clothes to Core ML and write PyTorch goldens."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as functional
from PIL import Image
from transformers import AutoImageProcessor, SegformerForSemanticSegmentation


ROOT = Path(__file__).resolve().parent
MODEL_ID = "mattmdjaga/segformer_b2_clothes"
SIZE = 512


class SegmentationWrapper(nn.Module):
    def __init__(self, model: SegformerForSemanticSegmentation) -> None:
        super().__init__()
        self.model = model
        self.register_buffer(
            "mean", torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1)
        )
        self.register_buffer(
            "std", torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1)
        )

    def forward(self, image: torch.Tensor) -> torch.Tensor:
        normalized = (image - self.mean) / self.std
        logits = self.model(pixel_values=normalized).logits
        logits = functional.interpolate(
            logits, size=(SIZE, SIZE), mode="bilinear", align_corners=False
        )
        return torch.argmax(logits, dim=1).to(torch.int32)


def image_tensor(path: Path) -> torch.Tensor:
    with Image.open(path) as source:
        # Match the evaluated preprocessing: stretch to a square without preserving ratio.
        resized = source.convert("RGB").resize((SIZE, SIZE), Image.Resampling.BILINEAR)
        pixels = np.asarray(resized, dtype=np.float32) / 255.0
    return torch.from_numpy(pixels).permute(2, 0, 1).unsqueeze(0)


def save_goldens(wrapper: nn.Module) -> None:
    input_dir = ROOT / "test_images"
    output_dir = ROOT / "golden"
    output_dir.mkdir(parents=True, exist_ok=True)
    for old_file in output_dir.glob("*.png"):
        old_file.unlink()
    paths = sorted(p for p in input_dir.iterdir() if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"})
    for path in paths:
        with torch.inference_mode():
            labels = wrapper(image_tensor(path))[0].cpu().numpy().astype(np.uint8)
        Image.fromarray(labels, mode="L").save(output_dir / f"{path.stem}.png")
        print(f"Golden: {path.name}")
    if not paths:
        print("No test images found; golden/ remains empty.")


def package_size(path: Path) -> int:
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def main(goldens_only: bool = False) -> None:
    processor = AutoImageProcessor.from_pretrained(MODEL_ID)
    del processor  # The wrapper uses the explicitly specified normalization and resize.
    model = SegformerForSemanticSegmentation.from_pretrained(MODEL_ID).eval()
    labels = {str(index): label for index, label in model.config.id2label.items()}
    print("Model labels (id2label):")
    print(json.dumps(labels, indent=2, ensure_ascii=False))
    (ROOT / "labels.json").write_text(json.dumps(labels, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    wrapper = SegmentationWrapper(model).eval()
    save_goldens(wrapper)
    if goldens_only:
        return

    import coremltools as ct
    import coremltools.optimize as cto

    example = torch.zeros((1, 3, SIZE, SIZE), dtype=torch.float32)
    traced = torch.jit.trace(wrapper, example, strict=False)
    coreml_model = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, SIZE, SIZE), scale=1 / 255.0, color_layout=ct.colorlayout.RGB)],
        outputs=[ct.TensorType(name="labels")],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS16,
    )
    fp16_path = ROOT / "OOTDClothSegmenter.mlpackage"
    w8_path = ROOT / "OOTDClothSegmenter_w8.mlpackage"
    for path in (fp16_path, w8_path):
        if path.exists():
            shutil.rmtree(path)
    coreml_model.save(str(fp16_path))

    config = cto.coreml.OptimizationConfig(
        global_config=cto.coreml.OpLinearQuantizerConfig(mode="linear", dtype=np.uint8, weight_threshold=0)
    )
    quantized = cto.coreml.linear_quantize_weights(coreml_model, config=config)
    quantized.save(str(w8_path))
    print(f"FP16 package size: {package_size(fp16_path):,} bytes")
    print(f"W8 package size:   {package_size(w8_path):,} bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--goldens-only",
        action="store_true",
        help="Run PyTorch inference on test_images without converting Core ML packages.",
    )
    main(goldens_only=parser.parse_args().goldens_only)
