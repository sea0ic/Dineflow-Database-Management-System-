use dineflow;
DELIMITER $$

CREATE PROCEDURE sp_complete_order(
    IN p_order_id INT,
    OUT p_actual_prep_time INT,
    OUT p_result_message VARCHAR(255)
)
BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_in_process_time TIMESTAMP;
    DECLARE v_prep_minutes INT;
    DECLARE v_chef_id INT;
    DECLARE v_estimated_wait INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_message = 'Error: Failed to complete order.';
    END;
    
    START TRANSACTION;
    
    -- Get order details
    SELECT status, in_process_at, chef_id, estimated_wait_time
    INTO v_order_status, v_in_process_time, v_chef_id, v_estimated_wait
    FROM customer_order
    WHERE order_id = p_order_id;
    
    IF v_order_status IS NULL THEN
        SET p_result_message = 'Error: Order not found.';
        ROLLBACK;
        
    ELSEIF v_order_status != 'IN_PROCESS' THEN
        SET p_result_message = 'Error: Order is not in process.';
        ROLLBACK;
        
    ELSEIF v_in_process_time IS NULL THEN
        SET p_result_message = 'Error: Order has no start time.';
        ROLLBACK;
        
    ELSE
        -- Calculate actual prep time in minutes
        SET v_prep_minutes = TIMESTAMPDIFF(MINUTE, v_in_process_time, NOW());
        
        -- Update order to completed
        UPDATE customer_order
        SET status = 'COMPLETED',
            status_updated_at = NOW(),
            completed_at = NOW(),
            actual_prep_time = v_prep_minutes,
            is_flagged_for_review = (v_prep_minutes > v_estimated_wait)
        WHERE order_id = p_order_id;
        
        -- Update chef statistics
        UPDATE chef
        SET total_orders_prepared = total_orders_prepared + 1,
            average_prep_time = (
                (COALESCE(average_prep_time, 0) * total_orders_prepared + v_prep_minutes) 
                / (total_orders_prepared + 1)
            ),
            orders_exceeding_sla = orders_exceeding_sla + 
                CASE WHEN v_prep_minutes > 30 THEN 1 ELSE 0 END
        WHERE chef_id = v_chef_id;
        
        SET p_actual_prep_time = v_prep_minutes;
        SET p_result_message = CONCAT('Success: Order completed in ', v_prep_minutes, ' minutes.');
        COMMIT;
    END IF;
END$$

DELIMITER ;