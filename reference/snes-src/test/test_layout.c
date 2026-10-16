#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include "ai.h"
#include "asm_shared.h"
#include "ball.h"
#include "court.h"
#include "court_projection.h"
#include "hud.h"
#include "player.h"
#include "render.h"

/* Every number the assembly uses must match the C definitions. */
int main(void)
{
    /* src/asm/camera.asm (ADR-050). */
    assert(offsetof(Ball, active) == ASM_BALL_ACTIVE);
    assert(offsetof(Ball, x_fp) == ASM_BALL_X);
    assert(offsetof(Ball, y_fp) == ASM_BALL_Y);
    assert(TO_FP(COURT_NET_X) == ASM_CAM_CENTER_X_FP);
    assert(TO_FP(COURT_CENTERLINE_Y) == ASM_CAM_CENTER_Y_FP);
    /* src/asm/hud_commit.asm: one bit per band in a byte. */
    assert(ASM_HUD_MAP_ADDR == RENDER_BG3_MAP_ADDR);
    assert(ASM_HUD_BANDS == HUD_BANDS && HUD_BANDS < 8);
    assert(ASM_HUD_BAND_BYTES == 32 * HUD_BAND_ROWS * 2);
    assert(HUD_BANDS * HUD_BAND_ROWS == HUD_ROWS);
    assert(offsetof(AiProbe, x) == ASM_PROBE_X);
    assert(offsetof(AiProbe, y) == ASM_PROBE_Y);
    assert(offsetof(AiProbe, z) == ASM_PROBE_Z);
    assert(offsetof(AiProbe, vx) == ASM_PROBE_VX);
    assert(offsetof(AiProbe, vy) == ASM_PROBE_VY);
    assert(offsetof(AiProbe, vz) == ASM_PROBE_VZ);
    assert(BALL_GRAVITY_FP == -ASM_BALL_FALL);
    assert(sizeof(Player) == ASM_PLAYER_SIZE);
    assert(offsetof(Player, active) == ASM_PLAYER_ACTIVE);
    assert(offsetof(Player, x_fp) == ASM_PLAYER_X);
    assert(offsetof(Player, y_fp) == ASM_PLAYER_Y);
    assert(offsetof(Player, facing_left) == ASM_PLAYER_FACING_LEFT);
    assert(offsetof(Player, animation_frame) == ASM_PLAYER_ANIM_FRAME);
    assert(offsetof(Player, state) == ASM_PLAYER_STATE);
    assert(offsetof(Player, pose) == ASM_PLAYER_POSE);
    assert(offsetof(Player, palette) == ASM_PLAYER_PALETTE);
    assert(offsetof(Player, flash_timer) == ASM_PLAYER_FLASH);
    assert(offsetof(Player, variant) == ASM_PLAYER_VARIANT);
    assert(offsetof(Player, team) == ASM_PLAYER_TEAM);
    assert(offsetof(Player, vx_fp) == ASM_PLAYER_VX);
    assert(offsetof(Player, vy_fp) == ASM_PLAYER_VY);
    assert(offsetof(Player, max_speed_fp) == ASM_PLAYER_MAX_SPEED);
    assert(offsetof(Player, animation_timer) == ASM_PLAYER_ANIM_TIMER);
    assert(offsetof(Player, state_frames_remaining) ==
        ASM_PLAYER_STATE_FRAMES);
    assert(offsetof(Player, contact_consumed) == ASM_PLAYER_CONTACT);
    assert(offsetof(Player, frozen) == ASM_PLAYER_FROZEN);
    assert(offsetof(Player, shot_type) == ASM_PLAYER_SHOT_TYPE);
    assert(offsetof(Player, paddle) == ASM_PLAYER_PADDLE);
    /* player_step.asm stores state and its frame count as one word, and
     * the animation frame and timer as one word. */
    assert(ASM_PLAYER_STATE_FRAMES == ASM_PLAYER_STATE + 1);
    assert(ASM_PLAYER_ANIM_TIMER == ASM_PLAYER_ANIM_FRAME + 1);
    assert(offsetof(PlayerIntent, move_x) == ASM_INTENT_MOVE_X);
    assert(offsetof(PlayerIntent, move_y) == ASM_INTENT_MOVE_Y);
    assert(offsetof(PlayerIntent, hit_pressed) == ASM_INTENT_HIT);
    assert(offsetof(PlayerIntent, shot) == ASM_INTENT_SHOT);
    assert(PLAYER_WINDUP_FRAMES == ASM_WINDUP_FRAMES);
    assert(PLAYER_ACTIVE_FRAMES == ASM_ACTIVE_FRAMES);
    assert(PLAYER_ACCEL_FP == ASM_ACCEL);
    assert(PLAYER_DIAGONAL_ACCEL_FP == ASM_DIAGONAL_ACCEL);
    assert(PLAYER_FRICTION_FP == ASM_FRICTION);
    assert(PLAYER_IDLE_CEL_FRAMES == ASM_IDLE_CEL_FRAMES);
    assert(PLAYER_RUN_CEL_FRAMES == ASM_RUN_CEL_FRAMES);
    assert(TO_FP(PLAYER_CLAMP_MIN_X) == ASM_CLAMP_MIN_X_FP);
    assert(TO_FP(PLAYER_CLAMP_MAX_X) == ASM_CLAMP_MAX_X_FP);
    assert(TO_FP(PLAYER_RIGHT_CLAMP_MIN_X) == ASM_RIGHT_CLAMP_MIN_X_FP);
    assert(TO_FP(PLAYER_RIGHT_CLAMP_MAX_X) == ASM_RIGHT_CLAMP_MAX_X_FP);
    assert(TO_FP(PLAYER_CLAMP_MIN_Y) == ASM_CLAMP_MIN_Y_FP);
    assert(TO_FP(PLAYER_CLAMP_MAX_Y) == ASM_CLAMP_MAX_Y_FP);
    assert(RENDER_OAM_ACCESSORIES == ASM_OAM_ACCESSORIES);
    assert(PLAYER_STATE_MOVE == ASM_STATE_MOVE);
    assert(PLAYER_STATE_WINDUP == ASM_STATE_WINDUP);
    assert(PLAYER_STATE_ACTIVE == ASM_STATE_ACTIVE);
    assert(PLAYER_STATE_RECOVERY == ASM_STATE_RECOVERY);
    assert(PLAYER_POSE_TOSS == ASM_POSE_TOSS);
    assert(PLAYER_POSE_CHEER == ASM_POSE_CHEER);
    assert(PLAYER_SPRITE_HALF_WIDTH == ASM_SPRITE_HALF_WIDTH);
    assert(PLAYER_SPRITE_FOOT_Y == ASM_SPRITE_FOOT_Y);
    assert(RENDER_OAM_BODIES == ASM_OAM_BODIES);
    assert(RENDER_OAM_GROUP_SIZE == ASM_OAM_GROUP_SIZE);
    assert(RENDER_OAM_GROUP_BODY == ASM_OAM_GROUP_BODY);
    assert(RENDER_OAM_SHADOWS == ASM_OAM_SHADOWS);
    assert(COURT_PROJECTION_ROWS == ASM_PROJECTION_ROWS);
    puts("layout host checks passed");
    return 0;
}
