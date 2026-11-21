package com.cinebook.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import com.cinebook.common.ApiException;
import java.time.Clock;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;

class MovieQueryServiceTest {

    @Test
    void searchTermIsMatchedLiterally() {
        assertThat(MovieQueryService.escapeLike("100%_a\\b")).isEqualTo("100\\%\\_a\\\\b");
        assertThat(MovieQueryService.escapeLike("đất rừng")).isEqualTo("đất rừng");
    }

    @Test
    void rejectsOverlongQueryWithoutHittingTheDatabase() {
        JdbcClient jdbc = mock(JdbcClient.class);
        var service = new MovieQueryService(jdbc, Clock.systemUTC());

        assertThatThrownBy(() -> service.list(null, "a".repeat(101)))
                .isInstanceOf(ApiException.class)
                .hasMessage("Từ khoá tìm kiếm tối đa 100 ký tự");
        verifyNoInteractions(jdbc);
    }
}
