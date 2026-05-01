# Crit & Damage Prediction — Feature Journal

## What this feature does

`predict_crit_wait` (gambits.lua ~line 791) decides whether the triggerbot should
fire now or hold for one more Surgical aim-time stack.  It returns `"fire"` or
`"wait"`.  The caller (triggerbot tick) suppresses the shot while the return is
`"wait"`.

The algorithm:
1. **Early-out** on guaranteed / prevented crit keywords.
2. **Read** `seed` and `prd_state` from the `critical_strike` unit-data component.
3. **Simulate Leadbelcher lucky-strike seed advance** (see bug below).
4. **PRD check at current crit chance** — if it crits now, fire.
5. **Early-out** if not aiming (Surgical only accumulates while ADS).
6. **Find the Surgical buff** instance to get `current_stacks`, `chance_per_step`,
   and `max_steps` from the live buff template.
7. **Loop** over each remaining stack: if any future stack would crit the PRD,
   estimate damage and decide whether waiting is worth the DPS cost.

---

## Crit system internals (Darktide)

### PseudoRandomDistribution (`pseudo_random_distribution.lua`)

`PseudoRandomDistribution.flip_coin(chance, state, seed)` always consumes
**two** values from the seed chain via `math.next_random`:

```
first_value  = next_random(seed)          -- decides "early trigger" path vs normal
second_value = next_random(new_seed)      -- the actual result
```

Early-trigger path (`first_value < P2C[floor(chance*100)]`): second roll is an
independent bernoulli(chance) — **does NOT update prd_state**.

Normal path: result is `second_value < n*c` where `n = prd_state or floor(chance/c)`.
On crit → resets state to 1; on miss → state = clamp(1+n, 1, MAX_PRD_STATE).

`CriticalStrike.is_critical_strike(chance, prd_state, seed)` wraps flip_coin,
rounds chance to 2 decimal places first.

### `_check_for_lucky_strike` vs `_check_for_critical_strike`

Both live in `action_weapon_base.lua`.

| Function | Always updates seed? | Always updates prd_state? |
|---|---|---|
| `_check_for_lucky_strike` | **Yes** | Only if lucky strike triggered |
| `_check_for_critical_strike` | **Yes** | **Yes** |

---

## Bug: incorrect seed for crit prediction (Leadbelcher)

### Root cause

`action_shoot.lua` calls `_check_for_lucky_strike` **before**
`_check_for_critical_strike` every shot.  Leadbelcher (`ogryn_leadbelcher` /
`ogryn_leadbelcher_improved`) is the trigger for lucky strike.  Because lucky
strike unconditionally advances `component.seed`, the actual crit check runs
on a seed 1–2 steps ahead of what we read from the component:

- **Semi-auto or continuing auto action**: 1 LB advance before crit check
  (`action_shoot.lua` line 1005 in `_check_for_auto_critical_strike`).
- **Fresh auto action** (`action_one_hold` just started): 2 LB advances —
  one in `start()` line 141, one in `_check_for_auto_critical_strike` line 1005.

Without compensation, `predict_crit_wait` sees the wrong PRD inputs and can
predict "no crit" when the real shot would crit, causing the triggerbot to
withhold a shot that should fire.

### Fix (gambits.lua ~line 823)

Before the `prd_would_crit` check, simulate the same lucky-strike PRD advance(s):

```lua
local talent_ext = ScriptUnit_has_extension(player_unit, "talent_system")
if talent_ext and _prd_available then
    local sr = SpecialRulesSettings.special_rules
    local has_lb     = talent_ext:has_special_rule(sr.ogryn_leadbelcher)
    local has_lb_imp = talent_ext:has_special_rule(sr.ogryn_leadbelcher_improved)
    if has_lb or has_lb_imp then
        local lb_base   = has_lb
            and TalentSettings.ogryn_1.passive_1.free_ammo_proc_chance      -- 0.15
            or  TalentSettings.ogryn_1.spec_passive_2.increased_passive_proc_chance -- 0.12
        local sb_lb     = buff_ext:stat_buffs()
        local lb_chance = lb_base + (sb_lb.leadbelcher_chance_bonus or 0)
        if buff_ext:has_keyword("guaranteed_leadbelcher") then lb_chance = 1 end
        local lb_rounded = math.round_with_precision(lb_chance, 2)
        local fire_rate  = weapon_handling_template.fire_rate_settings or {}
        local is_auto    = fire_rate.auto_fire_time ~= nil
                        and (fire_rate.max_shots == nil or fire_rate.max_shots == math.huge)
        local action_comp    = unit_data_ext:read_component("weapon_action")
        local action_running = action_comp and action_comp.current_action_name == "action_one_hold"
        local lb_advances    = (is_auto and not action_running) and 2 or 1
        for _ = 1, lb_advances do
            local is_lucky, lb_new_state, lb_new_seed = prd_flip(lb_rounded, prd_state, seed)
            seed = lb_new_seed
            if is_lucky then prd_state = lb_new_state end
        end
    end
end
```

`prd_flip` is a new helper (alongside the existing `prd_would_crit`) that returns
all three values `(result, new_state, new_seed)` so callers can chain multiple
PRD checks.  Both helpers use the same lazy-init / pcall-probe pattern to defer
the `require("scripts/utilities/pseudo_random_distribution")` call until
`NetworkConstants` is available.

---

## PRD helper design (`prd_would_crit` / `prd_flip`)

`CriticalStrike.is_critical_strike` internally does
`require("scripts/utilities/pseudo_random_distribution")`.  That module reads
`NetworkConstants.max_prd_state` at load time; calling it before the network
layer initialises causes a crash.  The helpers use a self-replacing probe
pattern:

1. First call: `pcall` the real function.  On success → replace both helpers
   with zero-overhead direct closures.  On failure → replace with safe
   always-false fallbacks (prediction fires immediately rather than over-waiting).
2. Subsequent calls: no overhead.

`_prd_available` (module-level bool) gates the Leadbelcher simulation — if the
PRD system isn't available yet we skip it (the result would be meaningless).

---

## Damage estimation (`_estimate_shot_damage`)

Used inside the "should I wait?" loop.  Returns `(normal_dmg, crit_dmg)`.

Key considerations baked into the estimate:
- Reads `weapon_handling_template` for `damage_type` / `critical_strike` fields.
- Looks up the correct `attack_type` (light / heavy / ranged) from the template.
- Applies `ArmorSettings` ADM (armor damage multiplier) for the target's
  `armor_type`.
- `super_armor` (Carapace) and `armored` (Flak) targets get tighter wait
  thresholds — crits matter more there.

---

## Surgical buff reading

The Surgical perk (`crit_chance_based_on_aim_time`) is detected by name-find on
live buff instances.  Per-step crit chance and max stacks are read from the live
buff template rather than hardcoded because they vary by weapon tier/level:

- `buff._template_context.template_override_data.conditional_stat_buffs[crit_key]`
  (weapon-specific override, checked first)
- `tmpl.conditional_stat_buffs[crit_key]` (base template fallback)
- `SURGICAL_CHANCE_PER_STEP_FALLBACK = 0.05` (last resort)

`max_steps` is read via `tmpl.min_max_step_func` (called with pcall).

---

## Lucky Bullet auto-crit early exit

### Background

The `ogryn_leadbelcher_auto_crit` special rule (a perk the Ogryn can equip) makes
every Lucky Bullet shot a guaranteed crit.  `action_shoot.lua` implements this as:

```lua
if self._leadbelcher_shot then
    leadbelcher_auto_crit = talent_extension:has_special_rule(
        special_rules.ogryn_leadbelcher_auto_crit)
end
self:_check_for_critical_strike(false, true, leadbelcher_auto_crit)
```

When `leadbelcher_auto_crit = true`, `_check_for_critical_strike` fires a
guaranteed crit regardless of PRD state — there is nothing Surgical stacks can
add.

### Fix (gambits.lua ~line 847)

After simulating the LB seed advance(s), capture `last_is_lucky` from the final
iteration of the loop (the advance that corresponds to `_check_for_auto_critical_strike`
for auto-fire weapons, or the sole start() advance for semi-auto).  If that
advance would produce a Lucky Bullet **and** the player has `ogryn_leadbelcher_auto_crit`,
return `"fire"` immediately before entering the Surgical wait loop:

```lua
local last_is_lucky = false
for _ = 1, lb_advances do
    local is_lucky, lb_new_state, lb_new_seed = prd_flip(lb_rounded, prd_state, seed)
    seed = lb_new_seed
    if is_lucky then prd_state = lb_new_state end
    last_is_lucky = is_lucky
end
if last_is_lucky and talent_ext:has_special_rule(sr.ogryn_leadbelcher_auto_crit) then
    return "fire"
end
```

---

## Live session validation (2026-05-01, 25-minute run)

### What was confirmed

- **LB seed advance works**: `lucky=true` fired 2,261 times across 309 distinct PRD
  seed states, confirming `prd_flip` correctly advances the seed on every prediction
  tick regardless of whether LB triggered.
- **Surgical wait is correct**: The bot counted stacks 0→N on `chaos_ogryn_executor`
  (super_armor, 6500 HP) and released shots at `extra_needed=1` — 440 such release
  decisions observed.
- **Bypass works correctly**: The three `crit=false` hits on the Executor are all
  explainable — two were bypass fires (`hp ≤ normal_dmg`, `ceil(hp/n_dmg)=1`), one
  was a shot already in-flight (51 ms gap, faster than the Surgical tick cadence).
  No confirmed mispredictions.
- **60% crit rate** on `surgical_srv` events (311/518) vs a 2.5% base weapon chance —
  confirms the wait logic is selecting the right moments.
- `super_armor` and `armored` targets both received crit-wait treatment; horde/normal
  targets fired immediately via bypass.

### Logging problem identified and fixed

The `lb_adj` debug line (`[surgical_prd] lb_adj advances=...`) fired on **every
prediction tick** (~120 Hz during any wait period), producing 38,000+ lines in 25
minutes.  It was useful for verifying the seed advance but is now redundant.
**Removed** — the remaining logs (`surgical_dbg` once per new unit/stacks,
`lucky_bullet_auto_crit` once per early exit) are infrequent enough to be useful.

---

## Key source files

| File | Role |
|---|---|
| `scripts/mods/gir489/gambits.lua` | Main mod — `predict_crit_wait`, `prd_would_crit`, `prd_flip` |
| `Darktide-Source-Code/scripts/utilities/pseudo_random_distribution.lua` | PRD flip_coin algorithm |
| `Darktide-Source-Code/scripts/utilities/attack/critical_strike.lua` | `CriticalStrike.is_critical_strike`, `CriticalStrike.chance` |
| `Darktide-Source-Code/scripts/extension_systems/weapon/actions/action_weapon_base.lua` | `_check_for_lucky_strike` (line 187), `_check_for_critical_strike` (line 149) |
| `Darktide-Source-Code/scripts/extension_systems/weapon/actions/action_shoot.lua` | LB-before-crit ordering (line 141, 1005, 1032) |
| `Darktide-Source-Code/scripts/settings/talent/talent_settings_ogryn.lua` | LB proc chances (0.15 / 0.12) |
| `Darktide-Source-Code/scripts/settings/ability/special_rules_settings.lua` | `ogryn_leadbelcher` / `ogryn_leadbelcher_improved` enum keys |
