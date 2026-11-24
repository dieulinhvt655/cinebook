package com.cinebook.booking;

import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * Server-side copy of the seat rules the app already checks (design doc 1.3, items 4 and 7):
 * couple seats go in pairs, and a selection may not strand a single free seat.
 */
final class SeatRules {

    /** One active seat of the room. {@code free} means nobody else holds or bought it. */
    record RoomSeat(long id, String row, int col, String type, int surcharge, Long pairSeatId, boolean free) {

        String label() {
            return row + col;
        }

        boolean couple() {
            return pairSeatId != null;
        }
    }

    private SeatRules() {
    }

    /** A selected couple seat whose other half is not selected, if any. */
    static Optional<RoomSeat> splitCouple(Collection<RoomSeat> room, Set<Long> selected) {
        return room.stream()
                .filter(s -> s.couple() && selected.contains(s.id()) && !selected.contains(s.pairSeatId()))
                .findFirst();
    }

    /**
     * The first single free seat the selection would strand: both neighbours are selected, taken,
     * an aisle or the wall, and at least one of them is selected (gaps that were already there do
     * not count). Couple seats are never orphans. Same rule as the app's {@code findOrphan}.
     */
    static Optional<RoomSeat> orphan(List<RoomSeat> room, Set<Long> selected) {
        Map<String, RoomSeat> byPosition = new HashMap<>();
        room.forEach(s -> byPosition.put(s.row() + "#" + s.col(), s));
        for (RoomSeat seat : room) {
            if (seat.couple() || !seat.free() || selected.contains(seat.id())) {
                continue;
            }
            RoomSeat left = byPosition.get(seat.row() + "#" + (seat.col() - 1));
            RoomSeat right = byPosition.get(seat.row() + "#" + (seat.col() + 1));
            if (blocked(left, selected) && blocked(right, selected)
                    && (isSelected(left, selected) || isSelected(right, selected))) {
                return Optional.of(seat);
            }
        }
        return Optional.empty();
    }

    private static boolean isSelected(RoomSeat s, Set<Long> selected) {
        return s != null && selected.contains(s.id());
    }

    private static boolean blocked(RoomSeat s, Set<Long> selected) {
        return s == null || !s.free() || selected.contains(s.id());
    }
}
