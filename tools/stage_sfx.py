"""Stage the curated sound effects into assets/incoming/sfx/ for auditioning.

`assets/incoming/` is the pre-acceptance staging area — the same place
music-prompts.md sends generated music. **Nothing staged here is part of the
game.** The survivors of the audition move on to assets/library/sfx/ and are
wired into game/assets/ at the integration step.

Sources live outside the repo (see docs/design/sfx-shortlist.md). This copies
the shortlisted files in, grouped by where they would be used, under names that
say what they are — so the folder can be listened through top to bottom and
pruned without cross-referencing anything.

  Kenney + Freesound  -> copied VERBATIM (already Ogg Vorbis; re-encoding a
                         lossy file to inspect it would only degrade it)
  Sonniss             -> converted to 48 kHz Ogg (the masters are 96/192 kHz
                         WAV; 850 MB of them does not belong in the project)

Nothing is trimmed and no levels are changed: the point is to judge the sounds
as they are. Trimming the long Sonniss beds needs ears and comes later.

**assets/incoming/ is gitignored.** Prune it freely; nothing here is tracked.

    python tools/stage_sfx.py              # stage everything
    python tools/stage_sfx.py --manifest   # rebuild the manifest only

Re-run --manifest after deleting files and the reference table matches what
actually survived.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "incoming" / "sfx"

KENNEY = Path.home() / "assets" / "kenney-audio"
SONNISS = Path.home() / "assets" / "sonniss-gdc2026"
FREESOUND = Path.home() / "assets" / "freesound"

FFMPEG = r"C:\Users\yurim\Packages\ffmpeg\bin\ffmpeg.exe"
FFPROBE = r"C:\Users\yurim\Packages\ffmpeg\bin\ffprobe.exe"

LICENCE = {
    "kenney": "CC0 (public domain, no attribution)",
    "sonniss": "Sonniss GDC royalty-free (no attribution; NO AI TRAINING)",
    "freesound": "CC0 (public domain, no attribution)",
}
ROOT = {"kenney": KENNEY, "sonniss": SONNISS, "freesound": FREESOUND}


def fam(lib, folder, stem, lo, hi, cat, name, what, width=0, skip=()):
    """Expand a numbered family: fam(..., 1, 5, ...) -> stem1..stem5."""
    out = []
    n = 1
    for i in range(lo, hi + 1):
        if i in skip:
            continue
        num = str(i).zfill(width) if width else str(i)
        out.append({"lib": lib, "src": f"{folder}/{stem}{num}.ogg",
                    "cat": cat, "name": f"{name}_{n}", "what": what})
        n += 1
    return out


def one(lib, src, cat, name, what):
    return {"lib": lib, "src": src, "cat": cat, "name": name, "what": what}


KUI = "kenney_ui-audio/Audio"
KIF = "kenney_interface-sounds/Audio"
KRPG = "kenney_rpg-audio/Audio"
KIMP = "kenney_impact-sounds/Audio"
KPIZ = "kenney_music-jingles/Audio/Pizzicato jingles"

PICKS: list[dict] = []

# ---------------------------------------------------------------- Kenney ----
PICKS += fam("kenney", KUI, "click", 1, 5, "ui", "tap", "UI button tap")
PICKS += fam("kenney", KUI, "rollover", 1, 4, "ui", "focus", "focus / highlight moves")
PICKS += fam("kenney", KIF, "back_", 1, 4, "ui", "back", "back / return", width=3)
PICKS += fam("kenney", KIF, "toggle_", 1, 4, "ui", "toggle", "settings toggle", width=3)
PICKS += fam("kenney", KIF, "confirmation_", 1, 4, "ui", "confirm", "choice committed", width=3)
PICKS += fam("kenney", KIF, "select_", 1, 4, "ui", "select", "list selection", width=3)
PICKS += fam("kenney", KIF, "scroll_", 1, 3, "ui", "scroll", "journal page scroll", width=3)
# error_002 peaks at 0.0 dBFS — excluded on purpose
PICKS += fam("kenney", KIF, "error_", 1, 5, "ui", "reject",
             "rejected command (law 19: currently silent)", width=3, skip=(2,))
PICKS += fam("kenney", KIF, "maximize_", 1, 3, "ui", "modal_open", "modal opens", width=3)
PICKS += fam("kenney", KIF, "minimize_", 1, 3, "ui", "modal_close", "modal closes", width=3)

PICKS += fam("kenney", KRPG, "bookFlip", 1, 3, "book", "page_turn", "advance a story beat")
PICKS += [one("kenney", f"{KRPG}/bookOpen.ogg", "book", "book_open", "open the book / journal"),
          one("kenney", f"{KRPG}/bookClose.ogg", "book", "book_close", "close the book / journal")]

PICKS += fam("kenney", KIF, "scratch_", 1, 5, "battle", "ash_claw", "Ash claws", width=3)
PICKS += fam("kenney", KIMP, "impactSoft_medium_", 0, 2, "battle", "ash_pounce",
             "Ash pounces (soft landing hit)", width=3)
PICKS += fam("kenney", KIMP, "impactPunch_medium_", 0, 2, "battle", "enemy_hit",
             "enemy hits Ash", width=3)
PICKS += fam("kenney", KIMP, "impactSoft_heavy_", 0, 2, "battle", "heavy_blow",
             "heavy blow lands (boss beats)", width=3)
PICKS += fam("kenney", KIMP, "impactPlate_light_", 0, 2, "battle", "blocked",
             "blocked / guarded", width=3)
PICKS += fam("kenney", KRPG, "cloth", 1, 4, "battle", "play_skill", "play a skill (cloth swish)")
PICKS += fam("kenney", KIF, "switch_", 1, 3, "battle", "end_turn", "end turn", width=3)
PICKS += [one("kenney", f"{KIF}/pluck_002.ogg", "battle", "charge",
              "charge a card onto a skill (pluck_001 clips, excluded)"),
          one("kenney", f"{KIF}/bong_001.ogg", "battle", "concentrate", "concentrate")]

# All 17 — four of these become the stings in music-prompts.md.
PICKS += fam("kenney", KPIZ, "jingles_PIZZI", 0, 16, "sting", "pizzicato",
             "candidate sting (victory / defeat / achievement / sunbeam)", width=2)

PICKS += fam("kenney", KRPG, "bookPlace", 1, 3, "court", "ledger_stamp",
             "the ledger stamped (book set on desk)")
PICKS += [one("kenney", f"{KIF}/tick_001.ogg", "court", "clock_tick_1", "clock tick"),
          one("kenney", f"{KIF}/tick_002.ogg", "court", "clock_tick_2", "clock tick"),
          one("kenney", f"{KIF}/tick_004.ogg", "court", "clock_tick_3", "clock tick")]
PICKS += fam("kenney", KRPG, "creak", 1, 3, "court", "door_creak", "the Court's door")

PICKS += fam("kenney", KIMP, "footstep_wood_", 0, 2, "world", "step_wood",
             "paw step on tile / wood", width=3)
PICKS += fam("kenney", KIMP, "footstep_carpet_", 0, 2, "world", "step_soft",
             "soft paw landing", width=3)
PICKS += [one("kenney", f"{KRPG}/doorOpen_1.ogg", "world", "door_open", "enter a location"),
          one("kenney", f"{KRPG}/doorClose_1.ogg", "world", "door_close", "leave a location"),
          one("kenney", f"{KRPG}/handleCoins.ogg", "world", "coins_1", "gleam spent / purse"),
          one("kenney", f"{KRPG}/handleCoins2.ogg", "world", "coins_2", "gleam spent / purse"),
          one("kenney", f"{KRPG}/beltHandle1.ogg", "world", "equip_1", "equip to the tray"),
          one("kenney", f"{KRPG}/beltHandle2.ogg", "world", "equip_2", "equip to the tray"),
          one("kenney", f"{KRPG}/handleSmallLeather.ogg", "world", "pouch_1", "small leather handling"),
          one("kenney", f"{KRPG}/handleSmallLeather2.ogg", "world", "pouch_2", "small leather handling")]

PICKS += fam("kenney", KIF, "drop_", 1, 4, "minigame", "ward_place", "Ward: patch placed", width=3)
PICKS += fam("kenney", KIF, "question_", 1, 4, "minigame", "testimony_contradiction",
             "Testimony: contradiction found", width=3)
PICKS += fam("kenney", KIMP, "impactTin_medium_", 0, 2, "minigame", "crossing_slip",
             "Crossing: slip / lose footing", width=3)
PICKS += [one("kenney", f"{KIF}/glass_002.ogg", "minigame", "lattice_resolve",
              "Lattice: thread resolves")]

# --------------------------------------------------------------- Sonniss ----
_S = {
    # book
    "344 Audio - Antique Books/PAPRMisc_Antique Books Slow Page Turns 6_344 Audio_Antiques - Books.wav":
        ("book", "page_turn_real", "real antique page turns (several; trim later)"),
    "344 Audio - Antique Books/PAPRMisc_Antique Books Flicking Through Pages 11_344 Audio_Antiques - Books.wav":
        ("book", "page_flick", "flicking through pages"),
    "Cinematic Sound Design - Paper Foley/Encyclopedia Glossy Page Turn Muted.wav":
        ("book", "page_turn_muted", "muted single page turn"),
    "Cinematic Sound Design - Paper Foley/A4 Printing Paper Rattle Page Turn Tail.wav":
        ("book", "paper_rattle", "paper rattle + page turn"),
    "Cinematic Sound Design - Paper Foley/Newspaper Static Foley Rummage.wav":
        ("book", "paper_rummage", "rummaging through paper"),
    "344 Audio - Antique Books/PAPRMisc_Pile Of Antique Books Falling Over 8_344 Audio_Antiques - Books.wav":
        ("world", "books_fall", "a pile of books falling over"),
    # court
    "344 Audio - Antique Clocks/CLOCKTick_Crooked Antique Clock_344 Audio_Antique Clocks.wav":
        ("court", "clock_room_a", "60s of a crooked antique clock ticking"),
    "344 Audio - Antique Clocks/CLOCKTick_You're Running Late _344 Audio_Antique Clocks.wav":
        ("court", "clock_room_b", "60s of clock ticking, second take"),
    "344 Audio - Antique Typewriter/COMType_Typewriter Carriage Movement, Typewriter_344 Audio_Antiques - Typewriter_01.wav":
        ("court", "typewriter_carriage", "typewriter carriage return"),
    "344 Audio - Antique Typewriter/COMType_Typewriter Paper Movements, Typewriter 04_344 Audio_Antiques - Typewriter.wav":
        ("court", "typewriter_paper", "paper into a typewriter"),
    "344 Audio - Antique Typewriter/COMType_Typewriter Space Key, Typewriter 05_344 Audio_Antiques - Typewriter.wav":
        ("court", "typewriter_key", "single typewriter key"),
    "Epic Stock Media - Strange Game Ambient Loops 3/MAGShim_Shimmer Loop Small Bell Metal Taps_ESM_SGA3.wav":
        ("court", "shimmer_bells", "44s loop of small bell taps"),
    "344 Audio - Ghostly Presences Vol. 1/AMBDsgn_Evil Spell Ambience_344 Audio_Ghostly Presences.wav":
        ("court", "ghost_ambience", "3min dread bed — may be too horror for a deadpan Court"),
    # battle
    "InMotionAudio - Sinister Textures 5/GOREMisc_Cladding_NailScratch19_InMotionAudio_SinisterTextures5.wav":
        ("battle", "claw_wall_1", "nail scratch down cladding"),
    "InMotionAudio - Sinister Textures 5/GOREMisc_Cladding_Scratch06_InMotionAudio_SinisterTextures5.wav":
        ("battle", "claw_wall_2", "scratch down cladding"),
    "InMotionAudio - Sinister Textures 4/DSGNErie_NoiseBoxHit_10_InMotionAudio_SinisterTextures4.wav":
        ("battle", "unpicked_hit_1", "eerie noise-box hit (the Unpicked)"),
    "InMotionAudio - Sinister Textures 4/DSGNErie_NoiseBoxHit_36_InMotionAudio_SinisterTextures4.wav":
        ("battle", "unpicked_hit_2", "eerie noise-box hit (the Unpicked)"),
    "344 Audio - Casino Cards Vol. 1/GAMECas_Automatic Shuffler, Shuffling 1_344 Audio_Casino Cards Vol 1.wav":
        ("battle", "cards_shuffle", "card shuffling"),
    "344 Audio - Casino Cards Vol. 1/GAMECas_Dealing 3_344 Audio_Casino Cards Vol 1.wav":
        ("battle", "cards_deal", "dealing cards"),
    "344 Audio - Casino Cards Vol. 1/GAMECas_Pick Up Multiple Cards At Once 5_344 Audio_Casino Cards Vol 1.wav":
        ("battle", "cards_pickup", "picking up a hand"),
    "Epic Stock Media - Fantasy Game 2 - Sound Kit for Enchanted Realms/GAMEMisc_Source Card Tarot Deck Generic Neutral Dry Heavy Shuffle 01_ESM_FG2.wav":
        ("battle", "tarot_shuffle", "heavy tarot deck shuffle"),
    "Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games/PAPRHndl_Game Play Cards Dry Show Flip Toss Disgard Near 12_ESM_BG.wav":
        ("battle", "card_flip", "card flip / toss / discard"),
    "Epic Stock Media - Fantasy Game 2 - Sound Kit for Enchanted Realms/MAGAngl_Magic Light Spell Enchantment Potion Effect Tonal Bright 03_ESM_FG2.wav":
        ("battle", "magic_light", "bright magic effect"),
    "CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/GAMEMisc_Magic Creation 23_CB Sounddesign_APPlicable Sounds.wav":
        ("battle", "magic_creation", "magic creation"),
    # ui
    "Cinematic Sound Design - User Interface/Interface Plucks Happy.wav":
        ("ui", "pluck_happy", "plucked-string UI accept"),
    "Cinematic Sound Design - User Interface/Button Arp Twinkle.wav":
        ("ui", "button_twinkle", "twinkling arpeggio button"),
    "Cinematic Sound Design - Interface & Infographics/Interface Accept Glassy Snap.wav":
        ("ui", "accept_glassy", "glassy accept snap"),
    "Cinematic Sound Design - Interface & Infographics/Interface Percussion Snap.wav":
        ("ui", "snap_percussion", "percussive snap"),
    "Cinematic Sound Design - Interface & Infographics/Interface Pop High Short.wav":
        ("ui", "pop", "short high pop"),
    "Cinematic Sound Design - UI Interaction Elements/Deny Muted.wav":
        ("ui", "deny_muted", "muted deny — candidate rejected-command sound"),
    "Cinematic Sound Design - System & UI Feedback Elements/Interface Deny Low Fat Dark.wav":
        ("ui", "deny_dark", "dark deny"),
    "Cinematic Sound Design - UI Interaction Elements/Accept Boing Crunch.wav":
        ("ui", "accept_boing", "boing accept"),
    "Cinematic Sound Design - System & UI Feedback Elements/Interface Arp Reveal Down Long.wav":
        ("ui", "reveal_arp", "descending arpeggio reveal"),
    "Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games/UIClick_UI Button Analog Vintage Double Click Neutral Dry Press 11_ESM_BG.wav":
        ("ui", "button_vintage", "analog vintage button click"),
    "CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav":
        ("ui", "kalimba_up", "rising kalimba — tuned, close to the score"),
    "CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/UIMisc_Xylophone Ringtone 2_CB Sounddesign_APPlicable Sounds.wav":
        ("ui", "xylophone", "xylophone figure"),
    # stings
    "Cinematic Sound Design - Hybrid Game & UI Elements/Game Entry Happy Short.wav":
        ("sting", "game_entry", "happy short game-entry sting"),
    "Cinematic Sound Design - Hybrid Game & UI Elements/Cofetti Whoosh Pluck Spill.wav":
        ("sting", "confetti", "confetti whoosh + pluck"),
    "Sonic Bat - Music Boxes/SBmb_Music Box A 013.wav":
        ("sting", "music_box_a", "real music box phrase — the score's own instrument"),
    "Sonic Bat - Music Boxes/SBmb_Music Box B 028.wav":
        ("sting", "music_box_b", "real music box phrase"),
    "Sonic Bat - Music Boxes/SBmb_Music Box C 059.wav":
        ("sting", "music_box_c", "real music box phrase"),
    "Sonic Bat - Music Boxes/SBmb_Music Box C Wind Up 006.wav":
        ("sting", "music_box_windup", "music box being wound — title screen"),
    # minigame
    "InMotionAudio - Velcro/OBJTape_VelcroRip29_InMotionAudio_Velcro.wav":
        ("minigame", "thread_rip", "sharp fabric rip"),
    "InMotionAudio - Velcro/OBJTape_VelcroSqueeze01_InMotionAudio_Velcro.wav":
        ("minigame", "velcro_squeeze", "slow velcro squeeze"),
    "InMotionAudio - Foley T-Shirt/FOLYClth_ClothMovement24_InMotionAudio_FoleyT-Shirt.wav":
        ("minigame", "cloth_move_1", "cloth movement"),
    "InMotionAudio - Foley T-Shirt/FOLYClth_ClothMovement29_InMotionAudio_FoleyT-Shirt.wav":
        ("minigame", "cloth_move_2", "cloth movement"),
    "InMotionAudio - Foley T-Shirt/FOLYClth_SinglePats04_InMotionAudio_FoleyT-Shirt.wav":
        ("minigame", "cloth_pat", "single pat on cloth"),
    "InMotionAudio - Washing Basket Foley/FOLYMisc_WashingBasket_Pats&Movement43_InMotionAudio_WashingBasketFoley.wav":
        ("minigame", "cloth_basket", "laundry basket cloth handling"),
    "344 Audio - Antique Small Metals/METLMvmt_  Antique Measuring Tape_344 Audio_Antique Small Metals.wav":
        ("minigame", "measuring_tape", "a tailor's measuring tape"),
    "344 Audio - Antique Small Metals/METLMvmt_  Tinkering Antique Lock_344 Audio_Antique Small Metals.wav":
        ("minigame", "lock_tinker", "tinkering with an antique lock"),
    "Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games/GAMEBoard_Game Play Piece Action Organic Connect Dots Fall Bounce 04_ESM_BG.wav":
        ("minigame", "piece_place", "wooden piece connect / bounce"),
    "Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games/GAMEBoard_Event Board Reset Organic Multiple Pieces Wood Small 02_ESM_BG.wav":
        ("minigame", "board_reset", "board reset, multiple wooden pieces"),
    # world
    "Epic Stock Media - Fantasy Game 2 - Sound Kit for Enchanted Realms/CLOTHFlp_Action Inventory Open Flip Cloth Canvas Bag Slide Light 02_ESM_FG2.wav":
        ("world", "tray_open", "canvas bag / inventory open — the tray"),
    "InMotionAudio - Chimney Wind/WINDInt_ChimneyWind05_InMotionAudio_ChimneyWind.wav":
        ("world", "wind_chimney", "115s wind in a chimney"),
    "Jake Fielding - Interior Wind Rain and Storms/RAINInt_Heavy Rain on Window,  Constant _JF_INT Storm.wav":
        ("world", "rain_window", "heavy rain on a window, constant"),
    "Jake Fielding - Interior Wind Rain and Storms/HAIL_Hail on Door Window, UVPC_JF_INT Storm.wav":
        ("world", "hail_window", "hail on a door window"),
    "Jake Fielding - Interior Wind Rain and Storms/THUN_Interior Thunder Rumble_JF_INT Storm_01.wav":
        ("world", "thunder", "interior thunder rumble"),
    "Sonic Bat - Stormy Night Ambience/SBsna_City Block Square Storm 003.wav":
        ("world", "city_storm", "122s city block in a storm"),
    "Ivo Vicic - Campfire - Bonfire FX/24 Campfire, Dropping Fresh Pine Branches in Fire, Crackling, Sizzling Strong, Close 02.wav":
        ("world", "hearth", "120s fire crackling close"),
    "Ivo Vicic - Campfire - Bonfire FX/42 Campfire, Putting Out Fire, Water from Bottle, Variation, Close.wav":
        ("world", "fire_out", "a fire being put out"),
    "Ivo Vicic - Church Bells/04 Church Bells, Near Distance, In Church Tower-3 Different Bell 02.wav":
        ("world", "bells_near", "church bells, near"),
    "Ivo Vicic - Church Bells/25 Church Bells, Far Distance, Rural Soundscape Distant, Hills Ridge, Spring 02.wav":
        ("world", "bells_far", "church bells, distant"),
    "344 Audio - Antique Luggage/OBJLug_Suitcase Opening and Closing, Antique Suitcase_344 Audio_Antiques - Luggage_01.wav":
        ("world", "case_open_close", "antique suitcase opening and closing"),
    "344 Audio - Antique Luggage/OBJLug_Suitcase Being Locked, Antique Suitcase 1_344 Audio_Antiques - Luggage.wav":
        ("world", "case_lock", "suitcase being locked"),
    "344 Audio - Antique Luggage/OBJLug_Rumaging Through Suitcase, Antique Suitcase_344 Audio_Antiques - Luggage_02.wav":
        ("world", "case_rummage", "rummaging through a suitcase"),
    "InMotionAudio - Instrument Case/OBJLug_Handle_Movement15_InMotionAudio_InstrumentCase.wav":
        ("world", "case_handle", "case handle movement"),
    "InMotionAudio - Instrument Case/OBJLug_Case_Closed06_InMotionAudio_InstrumentCase.wav":
        ("world", "case_close", "case closing"),
    "CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/TOONMisc_Bird Flutes 3_CB Sounddesign_APPlicable Sounds.wav":
        ("world", "bird_flutes", "flute bird figure"),
    # beast
    "344 Audio - Dog Vocalisations Vol. 1/ANMLDog_Dog Barks, Multiple, Indoors, Perspective,_344 Audio_Dog Vocalisations_02.wav":
        ("beast", "dog_barks", "dog barking indoors — en_chained_dog"),
    "344 Audio - Dog Vocalisations Vol. 1/ANMLDog_Dog Shuffle, Grunt, Movement, Lying Down_344 Audio_Dog Vocalisations.wav":
        ("beast", "dog_settle", "dog shuffling, grunting, lying down"),
}
for _src, (_c, _n, _w) in _S.items():
    PICKS.append({"lib": "sonniss", "src": _src, "cat": _c, "name": _n, "what": _w})

# ------------------------------------------------------------- Freesound ----
_F = {
    # cat — the reason the API key mattered
    "cat/668820_Cat trill 3.ogg": ("cat", "trill_1", "Ash's chirrup"),
    "cat/668821_Cat trill 2.ogg": ("cat", "trill_2", "Ash's chirrup"),
    "cat/668822_Cat trill 1.ogg": ("cat", "trill_3", "Ash's chirrup"),
    "cat/668823_Cat trill 6.ogg": ("cat", "trill_4", "Ash's chirrup"),
    "cat/668824_Cat trill 5.ogg": ("cat", "trill_5", "Ash's chirrup"),
    "cat/668825_Cat trill 4.ogg": ("cat", "trill_6", "Ash's chirrup"),
    "cat/146960_catHisses.ogg": ("cat", "hiss_1", "hiss"),
    "cat/146961_catHisses3.ogg": ("cat", "hiss_2", "hiss"),
    "cat/146962_catHisses2.ogg": ("cat", "hiss_3", "hiss"),
    "cat/146963_catHisses1.ogg": ("cat", "hiss_4", "hiss"),
    "cat/819958_Cat hissing.ogg": ("cat", "hiss_5", "hiss"),
    "cat/826834_Cat hissing _2.ogg": ("cat", "hiss_6", "hiss"),
    "cat/559270_Hiss Roar.ogg": ("cat", "hiss_roar", "hiss into a roar"),
    "cat/337200_Cat Purr.ogg": ("cat", "purr_1", "purr"),
    "cat/575933_Cat Purr.ogg": ("cat", "purr_2", "purr"),
    "cat/779220_cat purring.ogg": ("cat", "purr_3", "purr"),
    "cat/640475_Cat purring.ogg": ("cat", "purr_4", "purr"),
    "cat/817884_Cat Meow _1.ogg": ("cat", "meow_1", "meow"),
    "cat/814893_Mature female cat - Pearl Meow.ogg": ("cat", "meow_2", "meow"),
    "cat/448018_female cat short meoow.ogg": ("cat", "meow_3", "short meow"),
    "cat/730100_Cat meowing for food 3.ogg": ("cat", "meow_4", "meowing for food"),
    "cat/534268_meow 2.ogg": ("cat", "meow_5", "meow"),
    "cat/828246_ANMLCat_angry hungry meow collar jingles_ECG_FCS2.ogg":
        ("cat", "meow_collar", "meow WITH a collar jingling — post-sc_collar Ash"),
    "cat/262306_Cat_Twit1.ogg": ("cat", "twit", "small cat twit"),
    "cat/146968_catGrowls.ogg": ("cat", "growl_1", "growl"),
    "cat/146967_catGrowlsAndHowling.ogg": ("cat", "growl_2", "growling and howling"),
    "cat/146972_catAttack.ogg": ("cat", "attack", "cat attack vocal"),
    "cat/679954_Cat Growling and Hissing.ogg": ("cat", "growl_hiss", "growling and hissing"),
    "cat/582745_Stereo cat complaint.ogg": ("cat", "complaint", "a long cat complaint"),
    # thread / stitching
    "thread/807957_Sewer Stitcher Fixer.ogg": ("minigame", "stitch_1", "literal sewing / stitching"),
    "thread/807958_Sewing Stitching Fixing Quick.ogg": ("minigame", "stitch_2", "quick stitch"),
    "thread/807959_Sewn Stitched Fixed Fast.ogg": ("minigame", "stitch_3", "fast stitch"),
    "thread/138096_tang1.ogg": ("minigame", "thread_snap_1", "plucked wire — a thread snapping"),
    "thread/138097_tang2.ogg": ("minigame", "thread_snap_2", "plucked wire — a thread snapping"),
    "thread/138098_tangcomplete.ogg": ("minigame", "thread_snap_3", "plucked wire, full"),
    "thread/667382_wire snap _ clothespin.ogg": ("minigame", "thread_snap_4", "wire snap"),
    "thread/689246_Rubber Band Thud.ogg": ("minigame", "thread_snap_5", "rubber band snap"),
    "thread/340292_guitar-twang-muted-b.ogg": ("minigame", "thread_pluck", "muted string twang"),
    "thread/554238_Cord String Pull 3.ogg": ("minigame", "string_pull", "pulling a cord"),
    "thread/802697_Rope - Quick snatch.ogg": ("minigame", "rope_snatch", "quick rope snatch"),
    "thread/335756_wire_clippers.ogg": ("minigame", "snip", "wire clippers — a snip"),
    "thread/493159_Leather Belt Stretching 1_1.ogg": ("minigame", "tension_1", "leather under tension"),
    "thread/493192_Leather Belt Stretching 1_7.ogg": ("minigame", "tension_2", "leather under tension"),
    "thread/493157_Leather Belt Stretching 1_10.ogg": ("minigame", "tension_3", "leather under tension"),
    "thread/591195_Cloth Rip Fast.ogg": ("minigame", "cloth_rip_1", "fast cloth rip"),
    "thread/591525_Cloth Rip Uneven Long.ogg": ("minigame", "cloth_rip_2", "long uneven cloth rip"),
    "thread/676626_Rip 9 - Long.ogg": ("minigame", "cloth_rip_3", "long rip"),
    "thread/565970_Tearing fabric.ogg": ("minigame", "cloth_rip_4", "tearing fabric"),
    "thread/536231_Velcro Pull 01.ogg": ("minigame", "velcro_1", "velcro pull"),
    "thread/536229_Velcro Pull 03.ogg": ("minigame", "velcro_2", "velcro pull"),
    "thread/494789_Jacket_Cloth Rustle 3.ogg": ("minigame", "rustle_1", "cloth rustle"),
    "thread/494790_Jacket_Cloth Rustle 2.ogg": ("minigame", "rustle_2", "cloth rustle"),
    "thread/494796_Jacket_Cloth Rustle 10.ogg": ("minigame", "rustle_3", "cloth rustle"),
    "thread/789038_Fabric_Foley_1.ogg": ("minigame", "fabric_foley", "general fabric foley"),
    "thread/448211_Scratch on clothes.ogg": ("battle", "claw_cloth", "claws scratching cloth"),
    # roof
    "roof/689998_Pigeon_ Flies Away_ Flapping Wings.ogg": ("world", "pigeon_flyaway", "pigeon takes off"),
    "roof/808001_Pigeons _ Doves - Homing Pigeon Cooing.ogg": ("world", "pigeon_coo", "pigeon cooing"),
    "roof/543110_bird_flapping_1.ogg": ("world", "wings_1", "wing flaps"),
    "roof/543117_bird_flapping_9.ogg": ("world", "wings_2", "wing flaps"),
    "roof/543118_bird_flapping_8.ogg": ("world", "wings_3", "wing flaps"),
    "roof/244978_Wing Flap _Flag Flapping_ 2a.ogg": ("world", "wings_4", "single wing flap"),
    "roof/507259_Bird Noise - 15.ogg": ("world", "bird_1", "bird call"),
    "roof/507264_Bird Noise - 6.ogg": ("world", "bird_2", "bird call"),
    "roof/738085_WindGust.ogg": ("world", "gust_1", "wind gust"),
    "roof/726314_wind 3.ogg": ("world", "wind_1", "wind"),
    "roof/726317_wind 6.ogg": ("world", "wind_2", "wind"),
    "roof/238379_CP_Whipping_Wind_Storm_Thin.ogg": ("world", "wind_storm", "24s whipping wind storm"),
    # room / court
    "room/362622_Stamp.ogg": ("court", "stamp_1", "a stamp on paper"),
    "room/362623_Stamp.ogg": ("court", "stamp_2", "a stamp on paper"),
    "room/362624_Stamp.ogg": ("court", "stamp_3", "a stamp on paper"),
    "room/450064_CheckPress_STAMP_Slow_01.ogg": ("court", "stamp_4", "slow press stamp"),
    "room/450066_CheckPress_STAMP_Slow_13.ogg": ("court", "stamp_5", "slow press stamp"),
    "room/256746_piecz_02.ogg": ("court", "stamp_6", "stamp / seal"),
    "room/256757_piecz_17.ogg": ("court", "stamp_7", "stamp / seal"),
    "room/675054_S11-22 Courtroom pre-trial murmuring.ogg":
        ("court", "murmur_courtroom", "courtroom pre-trial murmuring"),
    "room/506659_Wood Creak Single V4.ogg": ("world", "creak_1", "wood creak"),
    "room/506664_Wood Creak Single V9.ogg": ("world", "creak_2", "wood creak"),
    "room/590154_Creaking Wood 13.ogg": ("world", "creak_3", "wood creak"),
    "room/590157_Creaking Wood 9.ogg": ("world", "creak_4", "wood creak"),
    "room/590167_Creaking in Room 13.ogg": ("world", "creak_5", "room creak"),
    "room/795898_Fall_Landing on creaking wooden floor.ogg":
        ("world", "floor_fall", "landing on a creaking floor"),
    "room/826338_Candle flame flickers_ blown out.ogg": ("world", "candle_out", "candle blown out"),
    "room/204531_Candle flicker_ blown out x4.ogg": ("world", "candle_out_2", "candle flicker, blown out x4"),
    "room/438384_G28-24-Whispering Crowd Walla.ogg": ("world", "walla_whisper", "whispering crowd"),
    "room/480808_R16-17-Men Murmuring.ogg": ("world", "murmur_1", "men murmuring"),
    "room/438371_G28-12-Angry Men Murmuring.ogg": ("world", "murmur_2", "angry men murmuring"),
    "room/834339_Outdoors Walla.ogg": ("world", "walla_outdoor", "outdoor crowd walla"),
    # beast
    "beast/288941_rat-squeak.ogg": ("beast", "rat_1", "rat squeak"),
    "beast/428114_squeakFinal.ogg": ("beast", "rat_2", "squeak"),
    "beast/445958_Cartoon - Bat _ Mouse Squeak.ogg": ("beast", "rat_3", "mouse squeak"),
    "beast/668802_Crow 1.ogg": ("beast", "crow_1", "crow call"),
    "beast/512780_CrowOrRaven2.ogg": ("beast", "crow_2", "crow / raven"),
    "beast/512781_CrowOrRaven1.ogg": ("beast", "crow_3", "crow / raven"),
    "beast/716962_Raven Croak or Crow Caw.ogg": ("beast", "crow_4", "raven croak"),
    "cat/389708_Large Angry Cats.ogg": ("beast", "angry_cats", "large angry cats — an enemy, not Ash"),
    "cat/410343_Roar.ogg": ("beast", "roar", "roar"),
}
for _src, (_c, _n, _w) in _F.items():
    PICKS.append({"lib": "freesound", "src": _src, "cat": _c, "name": _n, "what": _w})


def probe(path: Path) -> dict:
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-select_streams", "a:0",
         "-show_entries", "stream=codec_name,sample_rate,channels",
         "-show_entries", "format=duration", "-of", "json", str(path)],
        capture_output=True, text=True).stdout
    j = json.loads(out)
    st = (j.get("streams") or [{}])[0]
    vd = subprocess.run(
        [FFMPEG, "-hide_banner", "-nostats", "-i", str(path),
         "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    pk = re.search(r"max_volume:\s*(-?[\d.]+) dB", vd)
    return {
        "sec": round(float(j["format"]["duration"]), 2),
        "codec": st.get("codec_name"),
        "hz": int(st.get("sample_rate", 0)),
        "ch": st.get("channels"),
        "peak_db": float(pk.group(1)) if pk else None,
    }


def stage() -> list[dict]:
    rows, missing = [], []
    for i, p in enumerate(PICKS, 1):
        src = ROOT[p["lib"]] / p["src"]
        if not src.exists():
            missing.append(f'{p["lib"]}: {p["src"]}')
            continue
        dst = OUT / p["cat"] / f'{p["name"]}.ogg'
        dst.parent.mkdir(parents=True, exist_ok=True)

        if src.suffix.lower() == ".ogg":
            shutil.copy2(src, dst)          # already Vorbis — do not re-encode
            conv = "copied verbatim"
        else:
            subprocess.run(
                [FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
                 "-i", str(src), "-ar", "48000", "-c:a", "libvorbis",
                 "-q:a", "6", str(dst)], check=True)
            conv = "converted to 48 kHz Ogg q6"

        info = probe(dst)
        rows.append({
            "file": f'{p["cat"]}/{p["name"]}.ogg',
            "category": p["cat"],
            "what": p["what"],
            "library": p["lib"],
            "licence": LICENCE[p["lib"]],
            "source_file": p["src"],
            "source_root": str(ROOT[p["lib"]]),
            "processing": conv,
            **info,
        })
        if i % 25 == 0:
            print(f"  {i}/{len(PICKS)}")
            sys.stdout.flush()

    if missing:
        print(f"\n!! {len(missing)} sources not found:")
        for m in missing:
            print("   ", m)
    return rows


def rebuild_manifest() -> list[dict]:
    """Re-probe whatever is actually on disk, keeping known provenance."""
    old = {}
    js = OUT / "manifest.json"
    if js.exists():
        old = {r["file"]: r for r in json.loads(js.read_text(encoding="utf-8"))}
    rows = []
    for f in sorted(OUT.rglob("*.ogg")):
        rel = f"{f.parent.name}/{f.name}"
        row = dict(old.get(rel, {"file": rel, "category": f.parent.name,
                                 "what": "?", "library": "?", "licence": "?",
                                 "source_file": "?", "source_root": "?",
                                 "processing": "?"}))
        row.update(probe(f))
        rows.append(row)
    return rows


def write_manifest(rows: list[dict]) -> None:
    (OUT / "manifest.json").write_text(json.dumps(rows, indent=1), encoding="utf-8")

    by_cat: dict[str, list[dict]] = {}
    for r in rows:
        by_cat.setdefault(r["category"], []).append(r)

    total = sum(r["sec"] for r in rows)
    lines = [
        "# Incoming SFX — reference table",
        "",
        "Candidates awaiting audition. **Nothing here is part of the game yet** —",
        "`assets/incoming/` is the pre-acceptance staging area and is gitignored,",
        "so prune freely. Survivors move to `assets/library/sfx/` and get wired",
        "into `game/assets/` at the integration step.",
        "",
        "Generated by `python tools/stage_sfx.py`.",
        "",
        f"{len(rows)} files, {round(total / 60, 1)} minutes total.",
        "",
        "After deleting the ones you don't want, run",
        "`python tools/stage_sfx.py --manifest` and this table will match what",
        "survived.",
        "",
        "Sources (all outside the repo, see `docs/design/sfx-shortlist.md`):",
        "",
        "- **Kenney** — CC0, copied verbatim (already Ogg)",
        "- **Freesound** — CC0, copied verbatim (Ogg previews)",
        "- **Sonniss** — royalty-free, converted from 96/192 kHz WAV to 48 kHz Ogg."
        "  **No AI training** permitted on these.",
        "",
        "`peak` at or above -0.1 dB will clip against the score; the wiring pass",
        "runs `loudnorm` over everything.",
        "",
    ]
    for cat in sorted(by_cat):
        lines += [f"## {cat}  ({len(by_cat[cat])} files)", "",
                  "| file | what it is | sec | peak dB | Hz | source |",
                  "|---|---|---|---|---|---|"]
        for r in sorted(by_cat[cat], key=lambda x: x["file"]):
            peak = "—" if r["peak_db"] is None else f'{r["peak_db"]:.1f}'
            lines.append(
                f'| `{Path(r["file"]).name}` | {r["what"]} | {r["sec"]:.2f} | '
                f'{peak} | {r["hz"]} | {r["library"]}: `{Path(r["source_file"]).name}` |')
        lines.append("")
    (OUT / "MANIFEST.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", action="store_true",
                    help="rebuild the manifest from what is on disk, stage nothing")
    args = ap.parse_args()

    if args.manifest:
        rows = rebuild_manifest()
    else:
        print(f"staging {len(PICKS)} files -> {OUT}")
        rows = stage()

    write_manifest(rows)
    print(f"\n{len(rows)} files in {OUT}")
    print(f"manifest: {OUT / 'MANIFEST.md'}  +  manifest.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
