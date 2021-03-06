import json
import os
from functools import lru_cache

from fsgs.option import Option
from fsgs.platforms.c64 import C64_MODEL_C64C
from fsgs.platforms.c64.vicec64driver import ViceC64Driver


class PlatformHandler(object):
    def __init__(self, loader_class=None, runner_class=None):
        self.loader_class = loader_class
        self.runner_class = runner_class

    @classmethod
    def create(cls, platform_id):
        class_ = cls.get_platform_class(platform_id)
        return class_()

    @classmethod
    def get_platform_class(cls, platform_id):
        platform_id = platform_id.lower()
        try:
            return platforms[platform_id]
        except KeyError:
            return UnsupportedPlatform

    @classmethod
    @lru_cache()
    def get_platform_name(cls, platform_id):
        return cls.get_platform_class(platform_id).PLATFORM_NAME

    @classmethod
    @lru_cache()
    def get_platform_ids(cls):
        return sorted(platforms.keys())

    def get_loader(self, fsgs):
        if self.loader_class is None:
            raise Exception("loader class is None for " + repr(self))
        return self.loader_class(fsgs)

    def get_runner(self, fsgs):
        if self.runner_class is None:
            raise Exception("runner class is None for " + repr(self))
        return self.runner_class(fsgs)


from fsgs.platforms.amiga import AmigaPlatformHandler
from fsgs.platforms.amstrad_cpc import AmstradCPCPlatformHandler
from fsgs.platforms.arcade.arcadeplatform import ArcadePlatformHandler
from fsgs.platforms.atari_2600 import Atari2600PlatformHandler
from fsgs.platforms.atari_5200 import Atari5200PlatformHandler
from fsgs.platforms.atari_7800 import Atari7800PlatformHandler
from fsgs.platforms.atari.atariplatform import AtariSTPlatformHandler
from fsgs.platforms.cd32 import CD32PlatformHandler
from fsgs.platforms.cdtv import CDTVPlatformHandler
from fsgs.platforms.dos.dosplatform import DOSPlatformHandler
from fsgs.platforms.game_boy import GameBoyPlatformHandler
from fsgs.platforms.game_boy_advance import GameBoyAdvancePlatformHandler
from fsgs.platforms.game_boy_color import GameBoyColorPlatformHandler
from fsgs.platforms.game_gear import GameGearPlatformHandler
from fsgs.platforms.loader import SimpleLoader
from fsgs.platforms.lynx import LynxPlatformHandler
from fsgs.platforms.master_system import MasterSystemPlatformHandler
from fsgs.platforms.mega_drive import MegaDrivePlatformHandler
from fsgs.platforms.msx import MsxPlatformHandler
from fsgs.platforms.nintendo import NintendoPlatformHandler
from fsgs.platforms.psx.psxplatform import PlayStationPlatformHandler
from fsgs.platforms.super_nintendo import SuperNintendoPlatformHandler
from fsgs.platforms.turbografx_16 import TurboGrafx16PlatformHandler
from fsgs.platforms.zxs import SpectrumPlatformHandler


class UnsupportedPlatform(PlatformHandler):
    PLATFORM_NAME = "Unsupported"


class C64Loader(SimpleLoader):
    def load_files(self, values):
        file_list = json.loads(values["file_list"])
        # assert len(file_list) == 1
        for i, item in enumerate(file_list):
            _, ext = os.path.splitext(item["name"])
            ext = ext.upper()
            if ext in [".TAP", ".T64"]:
                if i == 0:
                    self.config["tape_drive_0"] = "sha1://{0}/{1}".format(
                        item["sha1"], item["name"])
                self.config["tape_image_{0}".format(i)] = \
                    "sha1://{0}/{1}".format(item["sha1"], item["name"])
            elif ext in [".D64"]:
                if i == 0:
                    self.config["floppy_drive_0"] = "sha1://{0}/{1}".format(
                        item["sha1"], item["name"])
                self.config["floppy_image_{0}".format(i)] = \
                    "sha1://{0}/{1}".format(item["sha1"], item["name"])

    def load_extra(self, values):
        self.config[Option.C64_MODEL] = values["model"]
        if not self.config[Option.C64_MODEL]:
            self.config[Option.C64_MODEL] = C64_MODEL_C64C
        self.config["model"] = ""


class C64Platform(PlatformHandler):
    PLATFORM_NAME = "Commodore 64"

    def __init__(self):
        super().__init__(C64Loader, ViceC64Driver)


class Platform:
    AMIGA = "amiga"
    ARCADE = "arcade"
    A2600 = "a2600"
    A5200 = "a5200"
    A7800 = "a7800"
    ATARI = "atari"
    C64 = "c64"
    CD32 = "cd32"
    CDTV = "cdtv"
    CPC = "cpc"
    DOS = "dos"
    GB = "gb"
    GBA = "gba"
    GBC = "gbc"
    GAME_GEAR = "game-gear"
    LYNX = "lynx"
    MSX = "msx"
    NES = "nes"
    PSX = "psx"
    SNES = "snes"
    SMD = "smd"
    SMS = "sms"
    TG16 = "tg16"
    ZXS = "zxs"

platforms = {
    Platform.AMIGA: AmigaPlatformHandler,
    Platform.ARCADE: ArcadePlatformHandler,
    Platform.A2600: Atari2600PlatformHandler,
    Platform.A5200: Atari5200PlatformHandler,
    Platform.A7800: Atari7800PlatformHandler,
    Platform.ATARI: AtariSTPlatformHandler,
    Platform.C64: C64Platform,
    Platform.CD32: CD32PlatformHandler,
    Platform.CDTV: CDTVPlatformHandler,
    Platform.CPC: AmstradCPCPlatformHandler,
    Platform.DOS: DOSPlatformHandler,
    Platform.GB: GameBoyPlatformHandler,
    Platform.GBA: GameBoyAdvancePlatformHandler,
    Platform.GBC: GameBoyColorPlatformHandler,
    Platform.GAME_GEAR: GameGearPlatformHandler,
    Platform.LYNX: LynxPlatformHandler,
    Platform.MSX: MsxPlatformHandler,
    Platform.NES: NintendoPlatformHandler,
    Platform.SNES: SuperNintendoPlatformHandler,
    Platform.PSX: PlayStationPlatformHandler,
    Platform.SMD: MegaDrivePlatformHandler,
    Platform.SMS: MasterSystemPlatformHandler,
    Platform.TG16: TurboGrafx16PlatformHandler,
    Platform.ZXS: SpectrumPlatformHandler,
}
PLATFORM_IDS = platforms.keys()


def normalize_platform_id(platform_id):
    platform_id = platform_id.lower().replace("-", "").replace("_", "")
    # noinspection SpellCheckingInspection
    if platform_id in ["st", "atarist"]:
        return Platform.ATARI
    elif platform_id in ["commodorecdtv"]:
        return Platform.CDTV
    elif platform_id in ["amigacd32"]:
        return Platform.CD32
    elif platform_id in ["amstradcpc"]:
        return Platform.CPC
    elif platform_id in ["msdos"]:
        return Platform.DOS
    elif platform_id in ["gameboy"]:
        return Platform.GB
    elif platform_id in ["gameboyadvance"]:
        return Platform.GBA
    elif platform_id in ["gameboycolor"]:
        return Platform.GBC
    elif platform_id in ["nintendo", "famicom"]:
        return Platform.NES
    elif platform_id in ["supernintendo", "supernes", "superfamicom"]:
        return Platform.SNES
    elif platform_id in ["zxspectrum"]:
        return Platform.ZXS
    elif platform_id in ["mastersystem"]:
        return Platform.SMS
    elif platform_id in ["megadrive"]:
        return Platform.SMD
    elif platform_id in ["atari2600"]:
        return Platform.A2600
    elif platform_id in ["atari5200"]:
        return Platform.A5200
    elif platform_id in ["atari78600"]:
        return Platform.A7800
    elif platform_id in ["turbografx16"]:
        return Platform.TG16
    return platform_id
