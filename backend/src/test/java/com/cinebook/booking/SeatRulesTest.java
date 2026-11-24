package com.cinebook.booking;

import static org.assertj.core.api.Assertions.assertThat;

import com.cinebook.booking.SeatRules.RoomSeat;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

class SeatRulesTest {

    // Row A: A1 A2 A3 A4 [aisle] A6 ; row B: B1+B2 couple.
    static final RoomSeat A1 = seat(1, "A", 1, true);
    static final RoomSeat A2 = seat(2, "A", 2, true);
    static final RoomSeat A3 = seat(3, "A", 3, true);
    static final RoomSeat A4 = seat(4, "A", 4, true);
    static final RoomSeat A6 = seat(6, "A", 6, true);
    static final RoomSeat B1 = new RoomSeat(11, "B", 1, "COUPLE", 30000, 12L, true);
    static final RoomSeat B2 = new RoomSeat(12, "B", 2, "COUPLE", 30000, 11L, true);

    static RoomSeat seat(long id, String row, int col, boolean free) {
        return new RoomSeat(id, row, col, "STANDARD", 0, null, free);
    }

    @Test
    void leavingOneSeatBetweenTwoSelectedIsRefused() {
        var orphan = SeatRules.orphan(List.of(A1, A2, A3, A4, A6), Set.of(1L, 3L));
        assertThat(orphan).contains(A2);
    }

    @Test
    void oneSeatLeftAgainstTheWallOrAisleIsRefused() {
        // A1 against the wall, A4 next to the aisle.
        assertThat(SeatRules.orphan(List.of(A1, A2, A3, A4, A6), Set.of(2L, 3L))).contains(A1);
        assertThat(SeatRules.orphan(List.of(A1, A2, A3, A4), Set.of(1L, 2L, 3L))).contains(A4);
    }

    @Test
    void takenSeatsCountAsBlockingButOldGapsDoNot() {
        RoomSeat soldA3 = seat(3, "A", 3, false);
        // Selecting A1 strands A2 between A1 and the sold A3.
        assertThat(SeatRules.orphan(List.of(A1, A2, soldA3, A4), Set.of(1L))).contains(A2);
        // A6 alone by the aisle was already a gap: selecting A1+A2 is fine.
        assertThat(SeatRules.orphan(List.of(A1, A2, soldA3, A4, A6), Set.of(1L, 2L))).isEmpty();
    }

    @Test
    void adjacentSelectionsAreFine() {
        assertThat(SeatRules.orphan(List.of(A1, A2, A3, A4, A6), Set.of(1L, 2L))).isEmpty();
        assertThat(SeatRules.orphan(List.of(A1, A2, A3, A4, A6), Set.of(6L))).isEmpty();
    }

    @Test
    void coupleSeatsMustBeSelectedTogetherAndAreNeverOrphans() {
        var room = List.of(A1, B1, B2);
        assertThat(SeatRules.splitCouple(room, Set.of(11L))).contains(B1);
        assertThat(SeatRules.splitCouple(room, Set.of(11L, 12L))).isEmpty();
        assertThat(SeatRules.orphan(room, Set.of(11L))).isEmpty();
    }

    @Test
    void bookingCodesAreEightCharactersWithoutLookAlikes() {
        for (int i = 0; i < 200; i++) {
            assertThat(BookingCodes.next()).matches("CB[A-HJKMNP-Z2-9]{6}");
        }
    }
}
