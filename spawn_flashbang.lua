function get_crosshair_pos_new()
    local player_unit = managers.player:player_unit()
    local mvec_to = Vector3()
    mvector3.set(mvec_to, player_unit:camera():forward())
    mvector3.multiply(mvec_to, 20000)
    mvector3.add(mvec_to, player_unit:camera():position())
    return World:raycast(
        "ray",
        player_unit:camera():position(),
        mvec_to,
        "slot_mask",
        managers.slot:get_mask("bullet_impact_targets")
    )
end

GroupAIStateBesiege:detonate_smoke_grenade(
    get_crosshair_pos_new().hit_position,
    get_crosshair_pos_new().hit_position,
    1,
    true
)
