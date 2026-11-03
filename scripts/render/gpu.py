"""Enable Cycles GPU rendering on Apple Silicon (Metal).

The playbook targets NVIDIA (CUDA/OptiX); this machine is an Apple M3, so Metal is used.
GPU choice is a *preference*, not saved in the .blend, so pass this script on every
Cycles run:  tools/bl scene.blend -P scripts/render/gpu.py -P scripts/render/render.py -- ...
"""

import bpy


def enable_gpu(preferred=("METAL", "OPTIX", "CUDA", "HIP", "ONEAPI")) -> str:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    chosen = "NONE"
    for backend in preferred:
        try:
            prefs.compute_device_type = backend
        except TypeError:
            continue
        prefs.get_devices()
        devices = [d for d in prefs.devices if d.type == backend]
        if devices:
            for d in prefs.devices:
                d.use = d.type == backend
            chosen = backend
            break
    for scene in bpy.data.scenes:
        scene.cycles.device = "GPU" if chosen != "NONE" else "CPU"
    names = [d.name for d in prefs.devices if d.use]
    print(f"GPU_SETUP backend={chosen} devices={names}")
    return chosen


if __name__ == "__main__":
    enable_gpu()
