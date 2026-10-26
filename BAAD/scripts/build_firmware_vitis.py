"""Vitis 2025.2 Unified CLI build. Run through build_firmware.ps1.

Creates a separate release workspace, never modifies the historical platform.
The PowerShell launcher records/checks XSA identity and verifies ELF placement.
"""
import os
from pathlib import Path
import vitis

root = Path(os.environ["BAAD_FW_ROOT"]).resolve()
workspace = Path(os.environ["BAAD_FW_WORKSPACE"]).resolve()
xsa = Path(os.environ["BAAD_FW_XSA"]).resolve()
resume = os.environ.get("BAAD_FW_RESUME") == "1"
platform_name = "baad_release_platform"
app_name = "baad_release_firmware"
domain_name = "standalone_psu_cortexa53_0"

def checked(result, description):
    print(f"BAAD_STAGE {description}: {result}", flush=True)
    failed_status = str(result).upper() in ("FAILURE", "FAILED", "ERROR")
    failed_exit_code = isinstance(result, int) and not isinstance(result, bool) and result != 0
    if result is False or failed_status or failed_exit_code:
        raise RuntimeError(description + " failed")

client = vitis.create_client()
try:
    client.set_workspace(str(workspace))
    if resume and (workspace / platform_name / "vitis-comp.json").exists():
        platform = client.get_component(name=platform_name)
        print("BAAD_STAGE Resuming existing matching-XSA platform", flush=True)
    else:
        platform = client.create_platform_component(
            name=platform_name, hw_design=str(xsa), os="standalone",
            cpu="psu_cortexa53_0", domain_name=domain_name,
            no_boot_bsp=False, fsbl_target="psu_cortexa53_0",
            is_pmufw_req=True, generate_dtb=False)
        print("BAAD_STAGE Fresh platform created", flush=True)
    checked(platform.build(), "Platform / BSP / FSBL / PMU build")
    platform_file = client.find_platform_in_repos(platform_name)
    if resume and (workspace / app_name / "vitis-comp.json").exists():
        app = client.get_component(name=app_name)
    else:
        app = client.create_app_component(name=app_name, platform=platform_file,
                                          domain=domain_name, template="empty_application")
    checked(app.import_files(from_loc=str(root / "baad_serial_firmware" / "src"),
                             files=["firmware.c"]), "Import firmware")
    checked(app.import_files(from_loc=str(root / "common"),
                             files=["baad_serial_protocol.h"]), "Import matched protocol")
    # Preserve the already-board-used low-DDR linker layout from the main app.
    checked(app.import_files(from_loc=str(root / "baad_software_v2" / "src"),
                             files=["lscript.ld"]), "Import low DDR linker layout")
    checked(app.set_app_config(key="USER_LINKER_SCRIPT",
                              values=str(workspace / app_name / "src" / "lscript.ld")), "Linker config")
    checked(app.set_app_config(key="USER_COMPILE_OPTIMIZATION_LEVEL", values="-O2"), "Optimization config")
    checked(app.set_app_config(key="USER_COMPILE_DEBUG_LEVEL", values="-g3"), "Debug config")
    # Unified Vitis config values are literal compiler options.  Supplying the
    # string "TRUE" makes GCC treat TRUE as an input filename; use the flag.
    checked(app.set_app_config(key="USER_COMPILE_WARNINGS_AS_ERRORS", values="-Werror"), "Warnings config")
    app.get_app_config()
    checked(app.build(), "Firmware application build")
    print("BAAD_FIRMWARE_BUILD_SUCCESS", flush=True)
finally:
    vitis.dispose()
