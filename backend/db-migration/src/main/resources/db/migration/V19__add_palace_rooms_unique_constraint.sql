alter table palace_rooms
    add constraint uq_palace_rooms_wing_room unique (wing, room);

alter table palace_bridge_edges
    add constraint uq_palace_bridge_edges_room_pair unique (room_a_id, room_b_id);
