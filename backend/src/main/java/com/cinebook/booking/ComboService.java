package com.cinebook.booking;

import com.cinebook.booking.dto.BookingView;
import com.cinebook.booking.dto.Combo;
import com.cinebook.booking.dto.ComboItem;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** F6, S09: combos on sale and the combos of a held booking. */
@Service
public class ComboService {

    private final JdbcClient jdbc;
    private final BookingLocks locks;
    private final BookingQueryService bookings;

    public ComboService(JdbcClient jdbc, BookingLocks locks, BookingQueryService bookings) {
        this.jdbc = jdbc;
        this.locks = locks;
        this.bookings = bookings;
    }

    @Transactional(readOnly = true)
    public List<Combo> onSale() {
        return jdbc.sql("""
                SELECT c.id, c.name, c.description, c.price, m.url AS image_url
                  FROM combos c LEFT JOIN media_assets m ON m.id = c.image_id
                 WHERE c.is_active
                 ORDER BY c.price, c.id
                """)
                .query((rs, n) -> new Combo(rs.getLong("id"), rs.getString("name"), rs.getString("description"),
                        rs.getInt("price"), rs.getString("image_url")))
                .list();
    }

    /**
     * Replaces the booking's combos and recomputes its total. Prices are today's and stay fixed for
     * this booking. Only the owner's live hold can change.
     */
    @Transactional
    public BookingView replace(long userId, long bookingId, List<ComboItem> items) {
        var booking = locks.lockHolding(userId, bookingId);
        if (new HashSet<>(items.stream().map(ComboItem::comboId).toList()).size() != items.size()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED, "Mỗi combo chỉ chọn một lần");
        }
        Map<Long, Integer> prices = onSale().stream().collect(Collectors.toMap(Combo::id, Combo::price));
        if (!prices.keySet().containsAll(items.stream().map(ComboItem::comboId).toList())) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED, "Combo không còn bán");
        }

        jdbc.sql("DELETE FROM booking_combos WHERE booking_id = :id").param("id", bookingId).update();
        int comboTotal = 0;
        for (ComboItem item : items) {
            int price = prices.get(item.comboId());
            jdbc.sql("""
                    INSERT INTO booking_combos (booking_id, combo_id, quantity, unit_price)
                    VALUES (:bookingId, :comboId, :quantity, :price)
                    """)
                    .param("bookingId", bookingId).param("comboId", item.comboId())
                    .param("quantity", item.quantity()).param("price", price)
                    .update();
            comboTotal += price * item.quantity();
        }
        jdbc.sql("""
                UPDATE bookings SET combo_total = :combo, total_amount = seat_total + :combo, updated_at = now()
                 WHERE id = :id
                """)
                .param("combo", comboTotal).param("id", booking.id()).update();
        return bookings.view(userId, bookingId);
    }
}
