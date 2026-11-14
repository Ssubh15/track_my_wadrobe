# OOTD clothing segmentation model

Converts [`mattmdjaga/segformer_b2_clothes`](https://huggingface.co/mattmdjaga/segformer_b2_clothes) to a 512 × 512 Core ML semantic segmentation model. Inputs are stretched to 512 × 512 (no aspect-ratio preservation), interpreted as RGB pixels in 0–1, and normalized inside the traced module with ImageNet mean/std. The output is an int32 label map named `labels` with shape `1 × 512 × 512`.

## Reproduce

Run from the repository root in a Python environment supported by the installed Core ML Tools release. macOS/Linux:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r tools/ootd_model/requirements.txt
python tools/ootd_model/convert.py
```

On Windows PowerShell, run:

```powershell
py -3.11 -m venv .venv
.venv\\Scripts\\Activate.ps1
python -m pip install -r tools/ootd_model/requirements.txt
python tools/ootd_model/convert.py
```

The script loads the Hugging Face model and processor, prints and writes the model's actual `id2label` mapping to `labels.json`, traces the normalization/segmentation/upsampling/argmax wrapper, and saves both `OOTDClothSegmenter.mlpackage` and linearly weight-quantized `OOTDClothSegmenter_w8.mlpackage`. It reports package sizes in bytes. Put PNG, JPEG, or WebP evaluation photos in `test_images/` before running; a same-basename grayscale PNG label map is written for each under `golden/` (pixel values are class IDs). The app build workflow stages the W8 package under the app target and checks for its compiled `.mlmodelc` in the built app.

To generate only PyTorch golden PNGs on a machine without Core ML Tools support, use `python tools/ootd_model/convert.py --goldens-only` after installing the dependencies needed for inference (`torch`, `transformers`, `pillow`, and `numpy`).

## Labels

The Hugging Face model card lists labels 0 Background, 1 Hat, 2 Hair, 3 Sunglasses, 4 Upper-clothes, 5 Skirt, 6 Pants, 7 Dress, 8 Belt, 9 Left-shoe, 10 Right-shoe, 11 Face, 12 Left-leg, 13 Right-leg, 14 Left-arm, 15 Right-arm, 16 Bag, and 17 Scarf. `labels.json` is regenerated from the downloaded model configuration, so that configuration is authoritative if it differs.

## License

Hugging Face marks the repository license as `other`; its model card links to the [NVIDIA Source Code License for SegFormer](https://github.com/NVlabs/SegFormer/blob/master/LICENSE). That license permits distribution subject to its terms and limits use of the work and derivatives to non-commercial research or evaluation. Confirm that this license fits the app's intended use before distributing the bundled model.
