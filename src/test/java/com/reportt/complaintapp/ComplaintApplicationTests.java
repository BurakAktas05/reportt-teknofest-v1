package com.reportt.complaintapp;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

import org.junit.jupiter.api.Test;
class ComplaintApplicationTests {

    @Test
    void applicationClassLoads() {
        assertDoesNotThrow(() -> Class.forName("com.reportt.complaintapp.ComplaintApplication"));
    }
}
