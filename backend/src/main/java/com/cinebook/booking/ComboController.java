package com.cinebook.booking;

import com.cinebook.booking.dto.Combo;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Bookings")
public class ComboController {

    private final ComboService combos;

    public ComboController(ComboService combos) {
        this.combos = combos;
    }

    @GetMapping("/combos")
    @Operation(summary = "Combo bắp nước đang bán (S09)")
    public List<Combo> list() {
        return combos.onSale();
    }
}
