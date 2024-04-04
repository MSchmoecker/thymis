from thymis_controller.models import Module, Setting
from thymis_controller.models.setting import ModuleSettings


class Kiosk(Module):
    displayName: str = "Kiosk"

    kiosk_url: Setting = Setting(
        name="kiosk.url",
        type="string",
        default="https://example.com",
        description="The URL to display in kiosk mode.",
        example="https://example.com",
    )

    def write_nix_settings(self, f, module_settings: ModuleSettings, priority: int):
        kiosk_url = (
            module_settings.settings["kiosk_url"].value
            if "kiosk_url" in module_settings.settings
            else self.kiosk_url.default
        )

        f.write(f'  hardware.raspberry-pi."4".fkms-3d.enable = true;\n')
        f.write(
            f"""
services.xserver.windowManager.i3.configFile = lib.mkForce (pkgs.writeText "i3-config" ''
# i3 config file (v4)
bar {{
    mode invisible
}}
exec echo 1
exec "/run/current-system/sw/bin/xrandr --newmode 1024x600_60.00  48.96  1024 1064 1168 1312  600 601 604 622  -HSync +Vsync"
exec echo 2
exec "/run/current-system/sw/bin/xrandr --addmode HDMI-1 1024x600_60.00"
exec echo 3
exec "/run/current-system/sw/bin/xrandr --output HDMI-1 --mode 1024x600_60.00"
exec echo 4
exec "/run/current-system/sw/bin/xset s off"
exec "/run/current-system/sw/bin/xset s off"
exec "/run/current-system/sw/bin/xset -dpms"
exec "${{pkgs.unclutter}}/bin/unclutter"
# exec ${{pkgs.firefox}}/bin/firefox
exec ${{pkgs.firefox}}/bin/firefox --kiosk {kiosk_url}
'');
        """
        )
        f.write(
            f"  systemd.services.display-manager.restartIfChanged = lib.mkForce true;\n"
        )
        f.write(
            f'  systemd.services.display-manager.environment.NONCE = "{kiosk_url}";\n'
        )
