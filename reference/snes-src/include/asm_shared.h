#ifndef ASM_SHARED_H
#define ASM_SHARED_H

/*
 * Numbers shared with hand-written assembly (src/asm/). The asset build
 * turns every "#define NAME value" here into assets/generated/asm_shared.inc
 * for WLA-DX, and test/test_layout.c checks each against the C definitions
 * (offsetof, enums), so C and asm cannot drift apart.
 */

/* The swing lookahead's probe (include/ai.h AiProbe) and the gravity it
 * falls by (include/ball.h BALL_GRAVITY_FP, negated: the include takes
 * numbers >= 0), for src/asm/ai_probe.asm. */
#define ASM_PROBE_X 0
#define ASM_PROBE_Y 2
#define ASM_PROBE_Z 4
#define ASM_PROBE_VX 6
#define ASM_PROBE_VY 8
#define ASM_PROBE_VZ 10
#define ASM_BALL_FALL 3

/* The HUD map's upload (include/hud.h, include/render.h) for
 * src/asm/hud_commit.asm: 4-row bands of 32 words, at most three a VBlank. */
#define ASM_HUD_MAP_ADDR 0x5C00
#define ASM_HUD_BANDS 7
#define ASM_HUD_BAND_BYTES 256
#define ASM_HUD_MAX_BANDS 3

/* The camera (src/asm/camera.asm, ADR-050): the ball's fields
 * (include/ball.h) and the court's centre and the lean's reach in 1/16 px
 * (include/court.h: the net x, the centre line y; 128 and 32 px). */
#define ASM_BALL_ACTIVE 0
#define ASM_BALL_X 2
#define ASM_BALL_Y 4
#define ASM_CAM_CENTER_X_FP 2048
#define ASM_CAM_CENTER_Y_FP 2080
#define ASM_CAM_REACH_X_FP 2048
#define ASM_CAM_REACH_Y_FP 512
/* Parallax (ADR-051): the backdrop is scene rows 0-73 (lines 0-73 at no
 * vertical scroll, checked in MesenCE), the court from row 74, the net
 * post's cap (tools/assetgen/scene.py checks it), to 185, then the near
 * fence. A table half: 3 + 3 + 4 x 3 + 1 bytes, padded. */
#define ASM_CAM_FAR_LINES 74
#define ASM_CAM_COURT_LINES 112
#define ASM_CAM_TABLE_BYTES 20

/* Player struct layout (include/player.h). */
#define ASM_PLAYER_SIZE 28
#define ASM_PLAYER_ACTIVE 0
#define ASM_PLAYER_X 4
#define ASM_PLAYER_Y 6
#define ASM_PLAYER_FACING_LEFT 14
#define ASM_PLAYER_ANIM_FRAME 15
#define ASM_PLAYER_STATE 17
#define ASM_PLAYER_POSE 21
#define ASM_PLAYER_PALETTE 22
#define ASM_PLAYER_FLASH 23
#define ASM_PLAYER_VARIANT 25
/* ...and the fields player_step.asm moves. */
#define ASM_PLAYER_TEAM 1
#define ASM_PLAYER_VX 8
#define ASM_PLAYER_VY 10
#define ASM_PLAYER_MAX_SPEED 12
#define ASM_PLAYER_ANIM_TIMER 16
#define ASM_PLAYER_STATE_FRAMES 18
#define ASM_PLAYER_CONTACT 19
#define ASM_PLAYER_FROZEN 20
#define ASM_PLAYER_SHOT_TYPE 24
#define ASM_PLAYER_PADDLE 26

/* PlayerIntent fields (include/input.h). */
#define ASM_INTENT_MOVE_X 0
#define ASM_INTENT_MOVE_Y 2
#define ASM_INTENT_HIT 8
#define ASM_INTENT_SHOT 9

/* Player movement (include/player.h, include/court.h); clamps in 12.4. */
#define ASM_WINDUP_FRAMES 4
#define ASM_ACTIVE_FRAMES 3
#define ASM_ACCEL 4
#define ASM_DIAGONAL_ACCEL 3
#define ASM_FRICTION 6
#define ASM_IDLE_CEL_FRAMES 20
#define ASM_RUN_CEL_FRAMES 6
#define ASM_CLAMP_MIN_X_FP 64
#define ASM_CLAMP_MAX_X_FP 1920
#define ASM_RIGHT_CLAMP_MIN_X_FP 2176
#define ASM_RIGHT_CLAMP_MAX_X_FP 4032
#define ASM_CLAMP_MIN_Y_FP 1344
#define ASM_CLAMP_MAX_Y_FP 2880

/* Player states and poses (include/player.h). */
#define ASM_STATE_MOVE 1
#define ASM_STATE_WINDUP 2
#define ASM_STATE_ACTIVE 3
#define ASM_STATE_RECOVERY 4
#define ASM_POSE_TOSS 1
#define ASM_POSE_CHEER 2

/* Sprite placement (include/court.h) and OAM slots (include/render.h). */
#define ASM_SPRITE_HALF_WIDTH 16
#define ASM_SPRITE_FOOT_Y 30
#define ASM_OAM_BODIES 2
#define ASM_OAM_GROUP_SIZE 3
#define ASM_OAM_GROUP_BODY 2
#define ASM_OAM_SHADOWS 14
#define ASM_OAM_ACCESSORIES 22
#define ASM_OBJ_PRIORITY_ATTR 0x20

/* Projection table rows (assets/generated/court_projection.h). */
#define ASM_PROJECTION_ROWS 224

#endif
