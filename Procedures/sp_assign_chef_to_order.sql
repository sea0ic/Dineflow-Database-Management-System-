use dineflow;
DELIMITER $$
CREATE PROCEDURE sp_assign_chef_to_order(
    IN p_order_id INT,
    IN p_chef_id INT,
    OUT p_result_message VARCHAR(255)
)
BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_chef_exists INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_message = 'Error: Failed to assign chef.';
    END;
    
    START TRANSACTION;
    -- Check order exists and status
    SELECT status INTO v_order_status
    FROM customer_order
    WHERE order_id = p_order_id;
    
    IF v_order_status IS NULL THEN
        SET p_result_message = 'Error: Order not found.';
        ROLLBACK;
        
    ELSEIF v_order_status NOT IN ('PENDING', 'QUEUED') THEN
        SET p_result_message = 'Error: Order already in progress or completed.';
        ROLLBACK;
        
    ELSE
        -- Verify chef exists and is active
        SELECT COUNT(*) INTO v_chef_exists
        FROM chef c
        JOIN employee e ON c.chef_id = e.employee_id
        WHERE c.chef_id = p_chef_id
          AND e.employment_status = 'ACTIVE';
        
        IF v_chef_exists = 0 THEN
            SET p_result_message = 'Error: Chef not found or inactive.';
            ROLLBACK;
        ELSE
            -- Assign chef and update status
            UPDATE customer_order
            SET chef_id = p_chef_id,
                status = 'IN_PROCESS',
                status_updated_at = NOW(),
                in_process_at = NOW()
            WHERE order_id = p_order_id;
            
            SET p_result_message = CONCAT('Success: Chef ', p_chef_id, ' assigned to order.');
            COMMIT;
        END IF;
    END IF;
END$$

DELIMITER ;