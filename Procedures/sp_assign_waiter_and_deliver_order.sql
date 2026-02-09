DELIMITER $$

CREATE PROCEDURE sp_assign_waiter_and_deliver_order(
    IN p_order_id INT,
    IN p_waiter_id INT,
    OUT p_delivery_time_minutes INT,
    OUT p_result_message VARCHAR(255)
)
BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_order_type VARCHAR(20);
    DECLARE v_table_id INT;
    DECLARE v_completed_at TIMESTAMP;
    DECLARE v_waiter_exists INT DEFAULT 0;
    DECLARE v_current_tables INT;
    DECLARE v_max_tables INT;
    DECLARE v_delivery_minutes INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_delivery_time_minutes = NULL;
        SET p_result_message = 'Error: Failed to assign waiter.';
    END;
    
    START TRANSACTION;
    -- Get order details
    SELECT status, order_type, table_id, completed_at
    INTO v_order_status, v_order_type, v_table_id, v_completed_at
    FROM customer_order
    WHERE order_id = p_order_id;
    
    IF v_order_status IS NULL THEN
        SET p_delivery_time_minutes = NULL;
        SET p_result_message = 'Error: Order not found.';
        ROLLBACK;
        
    ELSEIF v_order_status != 'COMPLETED' THEN
        SET p_delivery_time_minutes = NULL;
        SET p_result_message = 'Error: Order not ready for delivery (must be COMPLETED).';
        ROLLBACK;
        
    ELSEIF v_order_type = 'TAKEOUT' THEN
        SET p_delivery_time_minutes = NULL;
        SET p_result_message = 'Error: Takeout orders do not require waiter delivery.';
        ROLLBACK;
        
    ELSEIF v_completed_at IS NULL THEN
        SET p_delivery_time_minutes = NULL;
        SET p_result_message = 'Error: Order has no completion time.';
        ROLLBACK;
        
    ELSE
        -- Verify waiter exists, is active, and check capacity
        SELECT COUNT(*), w.current_table_count, w.max_tables
        INTO v_waiter_exists, v_current_tables, v_max_tables
        FROM waiter w
        JOIN employee e ON w.waiter_id = e.employee_id
        WHERE w.waiter_id = p_waiter_id
          AND e.employment_status = 'ACTIVE'
        GROUP BY w.current_table_count, w.max_tables;
        
        IF v_waiter_exists = 0 THEN
            SET p_delivery_time_minutes = NULL;
            SET p_result_message = 'Error: Waiter not found or inactive.';
            ROLLBACK;
            
        ELSEIF v_current_tables >= v_max_tables THEN
            SET p_delivery_time_minutes = NULL;
            SET p_result_message = 'Error: Waiter at full capacity (max tables reached).';
            ROLLBACK;
            
        ELSE
            -- Calculate delivery time
            SET v_delivery_minutes = TIMESTAMPDIFF(MINUTE, v_completed_at, NOW());
            
            -- Update order: assign waiter and mark as delivered
            UPDATE customer_order
            SET waiter_id = p_waiter_id,
                status = 'DELIVERED',
                delivered_at = NOW(),
                status_updated_at = NOW()
            WHERE order_id = p_order_id;
            
            -- Update waiter statistics
            UPDATE waiter
            SET current_table_count = current_table_count + 1,
                total_deliveries = total_deliveries + 1,
                average_delivery_time = (
                    (COALESCE(average_delivery_time, 0) * total_deliveries + v_delivery_minutes)
                    / (total_deliveries + 1)
                )
            WHERE waiter_id = p_waiter_id;
            
            -- Link waiter to table
            UPDATE restaurant_table
            SET assigned_waiter_id = p_waiter_id
            WHERE table_id = v_table_id;
            
            SET p_delivery_time_minutes = v_delivery_minutes;
            SET p_result_message = CONCAT('Success: Waiter ', p_waiter_id, 
                                         ' assigned, order delivered in ', 
                                         v_delivery_minutes, ' minutes.');
            COMMIT;
        END IF;
    END IF;
END$$

DELIMITER ;